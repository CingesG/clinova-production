import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import {
  AppointmentStatus,
  AuthProvider,
  NotificationType,
  Prisma,
  Role,
  UserStatus,
} from '@prisma/client';

import { PrismaService } from '../common/prisma.service';
import {
  MONGOLIA_PHONE_INVALID_MESSAGE,
  normalizeOptionalMongoliaPhone,
} from '../common/mongolia-phone.util';
import { USER_DETAIL_ADMIN_SAFE_SELECT } from '../common/user-public-select';
import { ChatPermissionService } from '../chat/chat-permission.service';

type DoctorInput = {
  username?: string;
  email?: string;
  firstName: string;
  lastName: string;
  phone?: string;
  phoneNumber?: string;
  branchId: string;
  departmentId: string;
  bio?: string;
  experienceYears?: number;
  consultationFee?: number;
  avatarUrl?: string;
  serviceIds?: string[];
  active?: boolean;
  temporaryPassword?: string;
  autoGeneratePassword?: boolean;
};

type ScheduleInput = {
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  slotMinutes: number;
  isActive?: boolean;
  breaks?: Array<{ startTime: string; endTime: string }>;
};

type TimeOffInput = {
  startsAt: string;
  endsAt: string;
  reason?: string;
};

type DoctorFeedbackInput = {
  doctorProfileId: string;
  patientUserId: string;
  stars: number;
  carePoints: number;
  comment?: string;
  appointmentId?: string;
};

@Injectable()
export class DoctorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly chatPermission: ChatPermissionService,
  ) {}

  private coerceOptionalDoctorPhone(raw?: string | null): string | undefined {
    if (raw === undefined || raw === null || !String(raw).trim())
      return undefined;
    const n = normalizeOptionalMongoliaPhone(String(raw));
    if (n === null)
      throw new BadRequestException(MONGOLIA_PHONE_INVALID_MESSAGE);
    return n;
  }

  private normalizeLoginId(value: string | undefined) {
    const raw = (value ?? '').trim().toLowerCase();
    if (!raw) return '';
    if (raw.includes('@')) return raw;
    return `${raw}@clinova.local`;
  }

  private generateTemporaryPassword() {
    // Cryptographically strong — each new doctor gets a unique one-time password.
    return randomBytes(12).toString('base64url');
  }

  async listDoctors(filters: {
    branchId?: string;
    departmentId?: string;
    serviceId?: string;
    search?: string;
    active?: boolean;
  }) {
    const where: Prisma.DoctorProfileWhereInput = {};

    if (filters.branchId) where.branchId = filters.branchId;
    if (filters.departmentId) where.departmentId = filters.departmentId;
    if (typeof filters.active === 'boolean') where.active = filters.active;
    if (filters.serviceId) {
      where.services = { some: { serviceId: filters.serviceId } };
    }
    if (filters.search) {
      where.OR = [
        {
          user: {
            firstName: { contains: filters.search, mode: 'insensitive' },
          },
        },
        {
          user: {
            lastName: { contains: filters.search, mode: 'insensitive' },
          },
        },
        {
          user: {
            phoneNumber: {
              contains: filters.search,
              mode: 'insensitive',
            },
          },
        },
      ];
    }

    return this.prisma.doctorProfile.findMany({
      where,
      orderBy: [
        { active: 'desc' },
        { user: { firstName: 'asc' } },
        { user: { lastName: 'asc' } },
      ],
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
            phoneNumber: true,
            avatarUrl: true,
            status: true,
          },
        },
        branch: {
          select: { id: true, name: true },
        },
        department: {
          select: { id: true, name: true },
        },
        services: {
          include: {
            service: {
              select: { id: true, name: true, durationMinutes: true },
            },
          },
        },
        weeklySchedules: {
          include: {
            breaks: true,
          },
          orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
        },
      },
    });
  }

  async suggestLoadBalancedDoctors(filters: {
    serviceId: string;
    branchId?: string;
    departmentId?: string;
    limit?: number;
  }) {
    const { serviceId, branchId, departmentId, limit = 5 } = filters;
    if (!serviceId || serviceId.trim().length === 0) {
      throw new BadRequestException('serviceId is required.');
    }
    const doctors = await this.prisma.doctorProfile.findMany({
      where: {
        active: true,
        branchId,
        departmentId,
        services: { some: { serviceId } },
      },
      include: {
        user: {
          select: { id: true, firstName: true, lastName: true },
        },
      },
    });
    if (doctors.length === 0) return [];

    const now = new Date();
    const dayEnd = new Date(now);
    dayEnd.setHours(23, 59, 59, 999);
    const loads = await this.prisma.appointment.groupBy({
      by: ['doctorId'],
      _count: { _all: true },
      where: {
        doctorId: { in: doctors.map((d) => d.id) },
        startsAt: { gte: now, lte: dayEnd },
        status: { not: AppointmentStatus.CANCELLED },
      },
    });
    const loadMap = new Map(loads.map((x) => [x.doctorId, x._count._all]));
    const ranked = doctors.map((d) => {
      const load = loadMap.get(d.id) ?? 0;
      const score = load * 15 - Math.min(10, d.experienceYears);
      return {
        doctorId: d.id,
        doctorName: `${d.user.firstName ?? ''} ${d.user.lastName ?? ''}`.trim(),
        experienceYears: d.experienceYears,
        activeQueueToday: load,
        score,
        recommendationReason:
          load <= 2
            ? 'Lower queue doctor available now'
            : 'Alternative doctor with similar service scope',
      };
    });
    ranked.sort((a, b) => a.score - b.score);
    return ranked.slice(0, Math.max(1, Math.min(limit, 10)));
  }

  async listDoctorPatients(doctorUserId: string) {
    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { userId: doctorUserId },
      select: { id: true },
    });
    if (!doctor) {
      throw new ForbiddenException('Doctor profile not found for this user.');
    }

    const allowedUserIds =
      await this.chatPermission.listPatientUserIdsForDoctorChat(doctor.id);
    if (allowedUserIds.length === 0) {
      return [];
    }

    const patients = await this.prisma.user.findMany({
      where: {
        id: { in: allowedUserIds },
        role: Role.PATIENT,
        status: UserStatus.ACTIVE,
        patientProfile: { isNot: null },
      },
      orderBy: [{ firstName: 'asc' }, { lastName: 'asc' }],
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
        phoneNumber: true,
        avatarUrl: true,
        patientProfile: {
          select: {
            appointments: {
              where: { doctorId: doctor.id },
              orderBy: { startsAt: 'desc' },
              take: 1,
              select: {
                startsAt: true,
                service: { select: { name: true } },
              },
            },
          },
        },
      },
    });

    return patients.map((user) => {
      const latest = user.patientProfile?.appointments?.[0];
      return {
        id: user.id,
        patientUserId: user.id,
        user: {
          id: user.id,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
          phoneNumber: user.phoneNumber,
          phone: user.phoneNumber,
          avatarUrl: user.avatarUrl,
        },
        serviceName: latest?.service?.name ?? '',
        lastAppointmentAt: latest?.startsAt?.toISOString() ?? null,
        hasVisitedDoctor: Boolean(latest),
      };
    });
  }

  async getDoctor(id: string) {
    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { id },
      include: {
        user: {
          select: USER_DETAIL_ADMIN_SAFE_SELECT,
        },
        branch: true,
        department: true,
        services: {
          include: {
            service: true,
          },
        },
        weeklySchedules: {
          include: {
            breaks: true,
          },
          orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
        },
        timeOffs: {
          orderBy: { startsAt: 'desc' },
          take: 20,
        },
      },
    });

    if (!doctor) {
      throw new NotFoundException('Doctor not found.');
    }

    return doctor;
  }

  async createDoctor(input: DoctorInput) {
    const loginCandidate = (input.username?.trim().length ?? 0) > 0
      ? input.username
      : input.email;
    const email = this.normalizeLoginId(loginCandidate);
    if (!email) {
      throw new BadRequestException('Doctor username or email is required.');
    }
    const temporaryPassword = (input.temporaryPassword?.trim().length ?? 0) > 0
      ? input.temporaryPassword!.trim()
      : (input.autoGeneratePassword == false ? '' : this.generateTemporaryPassword());
    if (!temporaryPassword) {
      throw new BadRequestException(
        'Temporary password is required when autoGeneratePassword is false.',
      );
    }
    if (
      (input.temporaryPassword?.trim().length ?? 0) > 0 &&
      temporaryPassword.length < 12
    ) {
      throw new BadRequestException(
        'Temporary password must be at least 12 characters.',
      );
    }
    const passwordHash = await bcrypt.hash(temporaryPassword, 10);
    const phoneNormalized = this.coerceOptionalDoctorPhone(
      input.phoneNumber ?? input.phone,
    );
    await Promise.all([
      this.ensureBranch(input.branchId),
      this.ensureDepartment(input.departmentId),
      this.ensureServices(input.serviceIds ?? [], input.branchId),
    ]);

    const existingUser = await this.prisma.user.findUnique({
      where: { email },
      include: { doctorProfile: true },
    });

    if (existingUser?.doctorProfile) {
      throw new BadRequestException('Doctor profile already exists for this user.');
    }

    const user = existingUser
      ? await this.prisma.user.update({
          where: { id: existingUser.id },
          data: {
            role: Role.DOCTOR,
            status: UserStatus.ACTIVE,
            authProvider: AuthProvider.EMAIL,
            emailVerified: true,
            firstName: input.firstName,
            lastName: input.lastName,
            ...(phoneNormalized !== undefined
              ? { phoneNumber: phoneNormalized }
              : {}),
            avatarUrl: input.avatarUrl,
            branchId: input.branchId,
            passwordHash,
          },
        })
      : await this.prisma.user.create({
          data: {
            email,
            passwordHash,
            role: Role.DOCTOR,
            status: UserStatus.ACTIVE,
            authProvider: AuthProvider.EMAIL,
            emailVerified: true,
            firstName: input.firstName,
            lastName: input.lastName,
            ...(phoneNormalized !== undefined
              ? { phoneNumber: phoneNormalized }
              : {}),
            avatarUrl: input.avatarUrl,
            branchId: input.branchId,
          },
        });

    const doctor = await this.prisma.doctorProfile.create({
      data: {
        userId: user.id,
        branchId: input.branchId,
        departmentId: input.departmentId,
        bio: input.bio,
        experienceYears: input.experienceYears ?? 0,
        consultationFee: input.consultationFee ?? 0,
        avatarUrl: input.avatarUrl,
        active: input.active ?? true,
        services: input.serviceIds?.length
            ? {
                createMany: {
                  data: input.serviceIds.map((serviceId) => ({ serviceId })),
                },
              }
            : undefined,
      },
    });

    const payload = await this.getDoctor(doctor.id);
    return {
      ...payload,
      provisionedCredentials: {
        username: email.endsWith('@clinova.local')
          ? email.replace('@clinova.local', '')
          : email,
        loginId: email,
        temporaryPassword,
      },
    };
  }

  async updateDoctor(id: string, input: Partial<DoctorInput>) {
    const doctor = await this.getDoctor(id);
    if (input.branchId) {
      await this.ensureBranch(input.branchId);
    }
    if (input.departmentId) {
      await this.ensureDepartment(input.departmentId);
    }
    if (input.serviceIds) {
      await this.ensureServices(input.serviceIds, input.branchId ?? doctor.branchId);
    }

    const rawMerged =
      input.phoneNumber !== undefined ? input.phoneNumber : input.phone;
    let phonePayload: Record<string, string | null> = {};
    if (rawMerged !== undefined) {
      if (rawMerged === null || String(rawMerged).trim() === '') {
        phonePayload = { phoneNumber: null };
      } else {
        const n = this.coerceOptionalDoctorPhone(String(rawMerged));
        phonePayload =
          n === undefined ? { phoneNumber: null } : { phoneNumber: n };
      }
    }

    const userUpdate: Prisma.UserUpdateInput = {};
    if (input.firstName !== undefined) {
      userUpdate.firstName = input.firstName;
    }
    if (input.lastName !== undefined) {
      userUpdate.lastName = input.lastName;
    }
    if (Object.keys(phonePayload).length > 0) {
      Object.assign(userUpdate, phonePayload);
    }
    if (input.avatarUrl !== undefined) {
      userUpdate.avatarUrl = input.avatarUrl;
    }
    if (input.branchId !== undefined) {
      userUpdate.branch = { connect: { id: input.branchId } };
    }

    const profileUpdate: Prisma.DoctorProfileUpdateInput = {};
    if (input.branchId !== undefined) {
      profileUpdate.branch = { connect: { id: input.branchId } };
    }
    if (input.departmentId !== undefined) {
      profileUpdate.department = { connect: { id: input.departmentId } };
    }
    if (input.bio !== undefined) {
      profileUpdate.bio = input.bio;
    }
    if (input.experienceYears !== undefined) {
      profileUpdate.experienceYears = input.experienceYears;
    }
    if (input.consultationFee !== undefined) {
      profileUpdate.consultationFee = input.consultationFee;
    }
    if (input.avatarUrl !== undefined) {
      profileUpdate.avatarUrl = input.avatarUrl;
    }
    if (input.active !== undefined) {
      profileUpdate.active = input.active;
    }

    await this.prisma.$transaction(async (tx) => {
      if (Object.keys(userUpdate).length > 0) {
        await tx.user.update({
          where: { id: doctor.userId },
          data: userUpdate,
        });
      }

      if (Object.keys(profileUpdate).length > 0) {
        await tx.doctorProfile.update({
          where: { id },
          data: profileUpdate,
        });
      }

      if (input.serviceIds) {
        await tx.doctorService.deleteMany({
          where: { doctorId: id },
        });
        if (input.serviceIds.length > 0) {
          await tx.doctorService.createMany({
            data: input.serviceIds.map((serviceId) => ({
              doctorId: id,
              serviceId,
            })),
          });
        }
      }
    });

    return this.getDoctor(id);
  }

  async updateOwnDoctor(
    userId: string,
    input: Partial<Omit<DoctorInput, 'email' | 'branchId' | 'departmentId'>>,
  ) {
    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { userId },
    });
    if (!doctor) {
      throw new ForbiddenException('Doctor profile not found for this user.');
    }

    return this.updateDoctor(doctor.id, input);
  }

  async addSchedule(doctorId: string, input: ScheduleInput) {
    await this.ensureDoctor(doctorId);
    if (input.dayOfWeek < 0 || input.dayOfWeek > 6) {
      throw new BadRequestException('dayOfWeek must be between 0 and 6.');
    }
    if (input.slotMinutes <= 0) {
      throw new BadRequestException('slotMinutes must be greater than zero.');
    }

    return this.prisma.doctorWeeklySchedule.create({
      data: {
        doctorId,
        dayOfWeek: input.dayOfWeek,
        startTime: input.startTime,
        endTime: input.endTime,
        slotMinutes: input.slotMinutes,
        isActive: input.isActive ?? true,
        breaks: input.breaks?.length
            ? {
                create: input.breaks,
              }
            : undefined,
      },
      include: {
        breaks: true,
      },
    });
  }

  async listSchedules(doctorId: string) {
    await this.ensureDoctor(doctorId);
    return this.prisma.doctorWeeklySchedule.findMany({
      where: { doctorId },
      include: { breaks: true },
      orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
    });
  }

  async addTimeOff(doctorId: string, input: TimeOffInput) {
    await this.ensureDoctor(doctorId);
    const startsAt = new Date(input.startsAt);
    const endsAt = new Date(input.endsAt);
    if (startsAt >= endsAt) {
      throw new BadRequestException('Time off end must be after start.');
    }

    return this.prisma.doctorTimeOff.create({
      data: {
        doctorId,
        startsAt,
        endsAt,
        reason: input.reason,
      },
    });
  }

  async submitDoctorFeedback(input: DoctorFeedbackInput) {
    if (input.stars < 1 || input.stars > 5) {
      throw new BadRequestException('stars must be between 1 and 5.');
    }
    if (input.carePoints < 0 || input.carePoints > 5) {
      throw new BadRequestException('carePoints must be between 0 and 5.');
    }

    const [doctor, patient] = await Promise.all([
      this.prisma.doctorProfile.findUnique({
        where: { id: input.doctorProfileId },
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
            },
          },
        },
      }),
      this.prisma.patientProfile.findUnique({
        where: { userId: input.patientUserId },
        select: { id: true },
      }),
    ]);

    if (!doctor) {
      throw new NotFoundException('Doctor not found.');
    }
    if (!patient) {
      throw new ForbiddenException('Only patients can submit doctor feedback.');
    }

    let appointmentId = input.appointmentId;
    if (appointmentId) {
      const appointment = await this.prisma.appointment.findUnique({
        where: { id: appointmentId },
        select: {
          id: true,
          doctorId: true,
          patientId: true,
          status: true,
        },
      });
      if (!appointment) {
        throw new NotFoundException('Appointment not found.');
      }
      if (
        appointment.doctorId !== input.doctorProfileId ||
        appointment.patientId !== patient.id
      ) {
        throw new ForbiddenException('Appointment does not match this patient/doctor.');
      }
      if (appointment.status !== AppointmentStatus.COMPLETED) {
        throw new BadRequestException(
          'Feedback can be submitted after appointment is completed.',
        );
      }
    } else {
      const latestCompleted = await this.prisma.appointment.findFirst({
        where: {
          doctorId: input.doctorProfileId,
          patientId: patient.id,
          status: AppointmentStatus.COMPLETED,
        },
        orderBy: { startsAt: 'desc' },
        select: { id: true },
      });
      appointmentId = latestCompleted?.id;
    }

    const payload = {
      kind: 'DOCTOR_FEEDBACK',
      doctorProfileId: input.doctorProfileId,
      patientUserId: input.patientUserId,
      appointmentId: appointmentId ?? null,
      stars: input.stars,
      carePoints: input.carePoints,
      comment: input.comment?.trim() || null,
      submittedAt: new Date().toISOString(),
    };

    const doctorName =
      `${doctor.user.firstName ?? ''} ${doctor.user.lastName ?? ''}`.trim() ||
      'Doctor';

    await this.prisma.notification.create({
      data: {
        userId: doctor.user.id,
        appointmentId: appointmentId ?? undefined,
        type: NotificationType.SYSTEM,
        title: 'DOCTOR_FEEDBACK',
        body: `Patient submitted ${input.stars}/5 star and ${input.carePoints}/5 care feedback for ${doctorName}.`,
        data: payload,
      },
    });

    return {
      ok: true,
      message: 'Feedback submitted successfully.',
      feedback: payload,
    };
  }

  private async ensureDoctor(id: string) {
    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!doctor) {
      throw new NotFoundException('Doctor not found.');
    }
  }

  private async ensureBranch(id: string) {
    const branch = await this.prisma.branch.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!branch) {
      throw new NotFoundException('Branch not found.');
    }
  }

  private async ensureDepartment(id: string) {
    const department = await this.prisma.department.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!department) {
      throw new NotFoundException('Department not found.');
    }
  }

  private async ensureServices(serviceIds: string[], branchId: string) {
    if (serviceIds.length === 0) return;

    const services = await this.prisma.service.findMany({
      where: {
        id: { in: serviceIds },
      },
      select: {
        id: true,
        branchId: true,
      },
    });

    if (services.length !== serviceIds.length) {
      throw new NotFoundException('One or more services were not found.');
    }

    const foreignBranchService = services.find((service) => service.branchId !== branchId);
    if (foreignBranchService) {
      throw new BadRequestException(
        'Doctor services must belong to the same branch as the doctor.',
      );
    }
  }
}
