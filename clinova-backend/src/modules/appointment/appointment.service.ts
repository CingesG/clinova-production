import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AppointmentStatus,
  Prisma,
  Role,
} from '@prisma/client';

import { NotificationService } from '../notification/notification.service';
import { PaymentService } from '../payment/payment.service';
import { PrismaService } from '../common/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

type Requester = {
  userId: string;
  role: Role;
};

type SlotFilters = {
  branchId?: string;
  departmentId?: string;
  serviceId?: string;
  doctorId?: string;
  date: string;
};

type RecommendSlotFilters = SlotFilters & {
  requesterUserId?: string;
  preferredStartHour?: number;
  preferredEndHour?: number;
  limit?: number;
};

type RecommendDoctorFilters = {
  serviceId: string;
  date: string;
  branchId?: string;
  departmentId?: string;
  limit?: number;
};

type CreateAppointmentInput = {
  patientUserId?: string;
  doctorId: string;
  serviceId: string;
  startsAt: string;
  reason?: string;
  intakeAnswers?: Record<string, unknown>;
  slotLockId?: string;
  withPaymentIntent?: boolean;
};

type AppointmentStatusUpdateInput = {
  status: AppointmentStatus;
  cancellationReason?: string;
};

type RescheduleInput = {
  startsAt: string;
  doctorId?: string;
};

type SlotLockInput = {
  doctorId: string;
  serviceId: string;
  startsAt: string;
};

type WaitlistInput = {
  serviceId: string;
  branchId?: string;
  departmentId?: string;
  preferredDate?: string;
  preferredHourStart?: number;
  preferredHourEnd?: number;
  note?: string;
};

@Injectable()
export class AppointmentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationService: NotificationService,
    private readonly realtimeGateway: RealtimeGateway,
    private readonly paymentService: PaymentService,
  ) {}

  private parseDateOnly(dateInput: string) {
    const date = new Date(`${dateInput}T00:00:00`);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException('Invalid date.');
    }
    return date;
  }

  private addMinutes(date: Date, minutes: number) {
    return new Date(date.getTime() + minutes * 60_000);
  }

  private lockDurationMs() {
    return 2 * 60_000;
  }

  private combineDateAndTime(date: Date, hhmm: string) {
    const [hour, minute] = hhmm.split(':').map(Number);
    if (
      Number.isNaN(hour) ||
      Number.isNaN(minute) ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59
    ) {
      throw new BadRequestException(`Invalid time: ${hhmm}`);
    }

    const combined = new Date(date);
    combined.setHours(hour, minute, 0, 0);
    return combined;
  }

  private overlaps(
    startA: Date,
    endA: Date,
    startB: Date,
    endB: Date,
  ) {
    return startA < endB && endA > startB;
  }

  private toDateOnlyIso(date: Date) {
    return date.toISOString().split('T')[0]!;
  }

  private humanTimeLabel(date: Date) {
    return date.toLocaleString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });
  }

  private async getPatientProfileId(requester: Requester, patientUserId?: string) {
    if (requester.role === Role.PATIENT) {
      const patient = await this.prisma.patientProfile.findUnique({
        where: { userId: requester.userId },
        select: { id: true },
      });
      if (!patient) {
        throw new ForbiddenException('Patient profile not found.');
      }
      return patient.id;
    }

    if (!patientUserId) {
      throw new BadRequestException('patientUserId is required for staff or admin booking.');
    }

    const patient = await this.prisma.patientProfile.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) {
      throw new NotFoundException('Patient profile not found.');
    }
    return patient.id;
  }

  private async getAppointmentScope(requester: Requester) {
    if (requester.role === Role.ADMIN || requester.role === Role.STAFF) {
      return {};
    }

    if (requester.role === Role.DOCTOR) {
      const doctor = await this.prisma.doctorProfile.findUnique({
        where: { userId: requester.userId },
        select: { id: true },
      });
      if (!doctor) {
        throw new ForbiddenException('Doctor profile not found.');
      }
      return { doctorId: doctor.id };
    }

    const patient = await this.prisma.patientProfile.findUnique({
      where: { userId: requester.userId },
      select: { id: true },
    });
    if (!patient) {
      throw new ForbiddenException('Patient profile not found.');
    }
    return { patientId: patient.id };
  }

  async getAvailableSlots(filters: SlotFilters) {
    const targetDate = this.parseDateOnly(filters.date);
    const nextDate = new Date(targetDate);
    nextDate.setDate(nextDate.getDate() + 1);

    const targetDayOfWeek = targetDate.getDay();
    const service = filters.serviceId
      ? await this.prisma.service.findUnique({
          where: { id: filters.serviceId },
          select: {
            id: true,
            branchId: true,
            departmentId: true,
            durationMinutes: true,
            status: true,
          },
        })
      : null;

    if (filters.serviceId && !service) {
      throw new NotFoundException('Service not found.');
    }

    const doctors = await this.prisma.doctorProfile.findMany({
      where: {
        active: true,
        branchId: filters.branchId ?? service?.branchId,
        departmentId: filters.departmentId ?? service?.departmentId,
        id: filters.doctorId,
        services: filters.serviceId
            ? {
                some: {
                  serviceId: filters.serviceId,
                },
              }
            : undefined,
      },
      include: {
        user: {
          select: {
            firstName: true,
            lastName: true,
          },
        },
        branch: {
          select: {
            id: true,
            name: true,
          },
        },
        department: {
          select: {
            id: true,
            name: true,
          },
        },
        weeklySchedules: {
          where: {
            dayOfWeek: targetDayOfWeek,
            isActive: true,
          },
          include: {
            breaks: true,
          },
          orderBy: { startTime: 'asc' },
        },
        timeOffs: {
          where: {
            startsAt: { lt: nextDate },
            endsAt: { gt: targetDate },
          },
        },
        appointments: {
          where: {
            startsAt: { gte: targetDate, lt: nextDate },
            status: { not: AppointmentStatus.CANCELLED },
          },
          orderBy: { startsAt: 'asc' },
        },
      },
    });

    const duration = service?.durationMinutes ?? 30;
    const now = new Date();
    const slots: Array<Record<string, unknown>> = [];
    const activeLocks = await this.prisma.appointmentSlotLock.findMany({
      where: {
        releasedAt: null,
        expiresAt: { gt: now },
      },
      select: {
        doctorId: true,
        startsAt: true,
      },
    });
    const lockSet = new Set(
      activeLocks.map((lock) => `${lock.doctorId}::${lock.startsAt.toISOString()}`),
    );

    for (const doctor of doctors) {
      for (const schedule of doctor.weeklySchedules) {
        let cursor = this.combineDateAndTime(targetDate, schedule.startTime);
        const scheduleEnd = this.combineDateAndTime(targetDate, schedule.endTime);
        const stepMinutes = schedule.slotMinutes;

        while (this.addMinutes(cursor, duration) <= scheduleEnd) {
          const slotStart = new Date(cursor);
          const slotEnd = this.addMinutes(slotStart, duration);

          const inBreak = schedule.breaks.some((item) =>
            this.overlaps(
              slotStart,
              slotEnd,
              this.combineDateAndTime(targetDate, item.startTime),
              this.combineDateAndTime(targetDate, item.endTime),
            ),
          );

          const inTimeOff = doctor.timeOffs.some((item) =>
            this.overlaps(slotStart, slotEnd, item.startsAt, item.endsAt),
          );

          const conflict = doctor.appointments.some((appointment) =>
            this.overlaps(slotStart, slotEnd, appointment.startsAt, appointment.endsAt),
          );

          const isLocked = lockSet.has(`${doctor.id}::${slotStart.toISOString()}`);
          if (
            slotStart > now &&
            !inBreak &&
            !inTimeOff &&
            !conflict &&
            !isLocked
          ) {
            slots.push({
              doctorId: doctor.id,
              doctorName: `${doctor.user.firstName ?? ''} ${doctor.user.lastName ?? ''}`.trim(),
              branchId: doctor.branch.id,
              branchName: doctor.branch.name,
              departmentId: doctor.department.id,
              departmentName: doctor.department.name,
              serviceId: service?.id ?? null,
              startsAt: slotStart.toISOString(),
              endsAt: slotEnd.toISOString(),
            });
          }

          cursor = this.addMinutes(cursor, stepMinutes);
        }
      }
    }

    slots.sort((a, b) =>
      String(a.startsAt).localeCompare(String(b.startsAt)),
    );

    return slots;
  }

  async recommendSlots(filters: RecommendSlotFilters) {
    let {
      preferredStartHour,
      preferredEndHour,
      limit = 5,
      requesterUserId,
      ...slotFilters
    } = filters;

    if (requesterUserId && (preferredStartHour == null || preferredEndHour == null)) {
      const recent = await this.prisma.appointment.findMany({
        where: {
          patient: { userId: requesterUserId },
          status: { not: AppointmentStatus.CANCELLED },
        },
        select: { startsAt: true },
        orderBy: { startsAt: 'desc' },
        take: 10,
      });
      if (recent.length > 0) {
        const avgHour =
          recent.reduce((sum, item) => sum + item.startsAt.getHours(), 0) / recent.length;
        const center = Math.round(avgHour);
        preferredStartHour ??= Math.max(0, center - 2);
        preferredEndHour ??= Math.min(24, center + 3);
      }
    }

    const slots = await this.getAvailableSlots(slotFilters);
    if (slots.length === 0) return [];

    const doctorIds = Array.from(
      new Set(slots.map((slot) => slot['doctorId']?.toString() ?? '').filter(Boolean)),
    );
    const targetDate = this.parseDateOnly(slotFilters.date);
    const nextDate = new Date(targetDate);
    nextDate.setDate(nextDate.getDate() + 1);

    const doctorLoadRows = await this.prisma.appointment.groupBy({
      by: ['doctorId'],
      _count: { _all: true },
      where: {
        doctorId: { in: doctorIds },
        status: { not: AppointmentStatus.CANCELLED },
        startsAt: { gte: targetDate, lt: nextDate },
      },
    });
    const loadMap = new Map(doctorLoadRows.map((r) => [r.doctorId, r._count._all]));

    const now = Date.now();
    const scored: Array<Record<string, unknown>> = [];
    for (const slot of slots) {
      const startsAtIso = slot['startsAt']?.toString();
      if (!startsAtIso) continue;
      const startsAt = new Date(startsAtIso);
      const minutesFromNow = Math.max(
        0,
        Math.round((startsAt.getTime() - now) / 60_000),
      );
      const doctorId = slot['doctorId']?.toString() ?? '';
      const doctorLoad = loadMap.get(doctorId) ?? 0;
      const hour = startsAt.getHours();
      const preferencePenalty =
        preferredStartHour != null && preferredEndHour != null
          ? hour < preferredStartHour || hour >= preferredEndHour
            ? 120
            : 0
          : 0;
      const score = minutesFromNow + doctorLoad * 15 + preferencePenalty;
      scored.push({
        ...slot,
        score,
        doctorLoad,
        minutesFromNow,
        recommendationReason:
          preferencePenalty === 0
            ? 'Best balanced nearby slot'
            : 'Nearest available slot',
      });
    }
    scored.sort((a, b) => Number(a['score']) - Number(b['score']));
    return scored.slice(0, Math.max(1, Math.min(limit, 10)));
  }

  async recommendDoctors(filters: RecommendDoctorFilters) {
    const { serviceId, branchId, departmentId, date, limit = 5 } = filters;
    const doctors = await this.prisma.doctorProfile.findMany({
      where: {
        active: true,
        branchId,
        departmentId,
        services: {
          some: { serviceId },
        },
      },
      include: {
        user: { select: { firstName: true, lastName: true } },
      },
    });
    if (doctors.length === 0) return [];

    const targetDate = this.parseDateOnly(date);
    const nextDate = new Date(targetDate);
    nextDate.setDate(nextDate.getDate() + 1);
    const loadRows = await this.prisma.appointment.groupBy({
      by: ['doctorId'],
      _count: { _all: true },
      where: {
        doctorId: { in: doctors.map((d) => d.id) },
        startsAt: { gte: targetDate, lt: nextDate },
        status: { not: AppointmentStatus.CANCELLED },
      },
    });
    const loadMap = new Map(loadRows.map((r) => [r.doctorId, r._count._all]));
    const slots = await this.getAvailableSlots({
      date,
      serviceId,
      branchId,
      departmentId,
    });
    const firstSlotByDoctor = new Map<string, string>();
    for (const slot of slots) {
      const doctorId = slot['doctorId']?.toString();
      const startsAt = slot['startsAt']?.toString();
      if (!doctorId || !startsAt || firstSlotByDoctor.has(doctorId)) continue;
      firstSlotByDoctor.set(doctorId, startsAt);
    }

    const nowMs = Date.now();
    const ranked = doctors.map((doctor) => {
      const load = loadMap.get(doctor.id) ?? 0;
      const nextSlotIso = firstSlotByDoctor.get(doctor.id);
      const nextSlotMinutes =
        nextSlotIso != null
          ? Math.max(0, Math.round((new Date(nextSlotIso).getTime() - nowMs) / 60_000))
          : 24 * 60;
      const score = load * 20 + nextSlotMinutes;
      return {
        doctorId: doctor.id,
        doctorName: `${doctor.user.firstName ?? ''} ${doctor.user.lastName ?? ''}`.trim(),
        doctorLoad: load,
        nextAvailableAt: nextSlotIso ?? null,
        score,
        recommendationReason:
          load <= 2 ? 'Lower queue pressure doctor' : 'Balanced doctor workload suggestion',
      };
    });
    ranked.sort((a, b) => a.score - b.score);
    return ranked.slice(0, Math.max(1, Math.min(limit, 10)));
  }

  async acquireSlotLock(requester: Requester, input: SlotLockInput) {
    const startsAt = new Date(input.startsAt);
    if (Number.isNaN(startsAt.getTime())) {
      throw new BadRequestException('Invalid appointment start date.');
    }
    if (startsAt <= new Date()) {
      throw new BadRequestException('Slot lock must be in the future.');
    }

    const service = await this.prisma.service.findUnique({
      where: { id: input.serviceId },
      select: { id: true, durationMinutes: true, branchId: true },
    });
    if (!service) throw new NotFoundException('Service not found.');

    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { id: input.doctorId },
      include: {
        services: {
          select: { serviceId: true },
        },
      },
    });
    if (!doctor || !doctor.active) {
      throw new NotFoundException('Doctor not found.');
    }
    if (doctor.branchId !== service.branchId) {
      throw new BadRequestException('Doctor and service must belong to the same branch.');
    }
    const offersService = doctor.services.some((item) => item.serviceId === input.serviceId);
    if (!offersService) {
      throw new BadRequestException('Selected doctor does not provide the chosen service.');
    }

    const endsAt = this.addMinutes(startsAt, service.durationMinutes);
    const expiresAt = new Date(Date.now() + this.lockDurationMs());

    const lock = await this.prisma.$transaction(async (tx) => {
      const ownLock = await tx.appointmentSlotLock.findFirst({
        where: {
          doctorId: input.doctorId,
          serviceId: input.serviceId,
          startsAt,
          lockedByUserId: requester.userId,
          releasedAt: null,
          expiresAt: { gt: new Date() },
        },
      });
      if (ownLock) {
        return tx.appointmentSlotLock.update({
          where: { id: ownLock.id },
          data: { expiresAt },
        });
      }

      const activeLock = await tx.appointmentSlotLock.findFirst({
        where: {
          doctorId: input.doctorId,
          startsAt,
          releasedAt: null,
          expiresAt: { gt: new Date() },
        },
        select: { id: true },
      });
      if (activeLock) {
        throw new ConflictException('That slot is currently reserved by another user.');
      }

      const overlap = await tx.appointment.findFirst({
        where: {
          doctorId: input.doctorId,
          status: { not: AppointmentStatus.CANCELLED },
          startsAt: { lt: endsAt },
          endsAt: { gt: startsAt },
        },
        select: { id: true },
      });
      if (overlap) {
        throw new ConflictException('That slot is no longer available.');
      }

      return tx.appointmentSlotLock.create({
        data: {
          doctorId: input.doctorId,
          serviceId: input.serviceId,
          startsAt,
          endsAt,
          lockedByUserId: requester.userId,
          expiresAt,
        },
      });
    });

    return {
      lockId: lock.id,
      doctorId: lock.doctorId,
      serviceId: lock.serviceId,
      startsAt: lock.startsAt.toISOString(),
      endsAt: lock.endsAt.toISOString(),
      expiresAt: lock.expiresAt.toISOString(),
    };
  }

  async releaseSlotLock(requester: Requester, lockId: string) {
    const lock = await this.prisma.appointmentSlotLock.findUnique({
      where: { id: lockId },
      select: { id: true, lockedByUserId: true, releasedAt: true },
    });
    if (!lock) return { ok: true };
    if (lock.releasedAt) return { ok: true };
    if (lock.lockedByUserId !== requester.userId && requester.role !== Role.ADMIN) {
      throw new ForbiddenException('You cannot release another user lock.');
    }
    await this.prisma.appointmentSlotLock.update({
      where: { id: lockId },
      data: { releasedAt: new Date() },
    });
    return { ok: true };
  }

  async createAppointment(requester: Requester, input: CreateAppointmentInput) {
    const patientId = await this.getPatientProfileId(requester, input.patientUserId);
    const service = await this.prisma.service.findUnique({
      where: { id: input.serviceId },
      include: {
        branch: { select: { id: true, name: true } },
        department: { select: { id: true, name: true } },
      },
    });
    if (!service) {
      throw new NotFoundException('Service not found.');
    }

    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { id: input.doctorId },
      include: {
        user: true,
        services: {
          select: { serviceId: true },
        },
      },
    });
    if (!doctor || !doctor.active) {
      throw new NotFoundException('Doctor not found.');
    }

    if (doctor.branchId !== service.branchId) {
      throw new BadRequestException(
        'Doctor and service must belong to the same branch.',
      );
    }

    const offersService = doctor.services.some(
      (item) => item.serviceId === input.serviceId,
    );
    if (!offersService) {
      throw new BadRequestException(
        'Selected doctor does not provide the chosen service.',
      );
    }

    const startsAt = new Date(input.startsAt);
    if (Number.isNaN(startsAt.getTime())) {
      throw new BadRequestException('Invalid appointment start date.');
    }
    if (startsAt <= new Date()) {
      throw new BadRequestException('Appointments must be booked in the future.');
    }

    const endsAt = this.addMinutes(startsAt, service.durationMinutes);
    const weekday = startsAt.getDay();

    const schedules = await this.prisma.doctorWeeklySchedule.findMany({
      where: {
        doctorId: doctor.id,
        dayOfWeek: weekday,
        isActive: true,
      },
      include: { breaks: true },
    });

    const sameDay = new Date(startsAt);
    sameDay.setHours(0, 0, 0, 0);
    const nextDay = new Date(sameDay);
    nextDay.setDate(nextDay.getDate() + 1);

    const timeOffs = await this.prisma.doctorTimeOff.findMany({
      where: {
        doctorId: doctor.id,
        startsAt: { lt: nextDay },
        endsAt: { gt: sameDay },
      },
    });

    const fitsSchedule = schedules.some((schedule) => {
      const scheduleStart = this.combineDateAndTime(sameDay, schedule.startTime);
      const scheduleEnd = this.combineDateAndTime(sameDay, schedule.endTime);
      const insideWindow = startsAt >= scheduleStart && endsAt <= scheduleEnd;
      const inBreak = schedule.breaks.some((item) =>
        this.overlaps(
          startsAt,
          endsAt,
          this.combineDateAndTime(sameDay, item.startTime),
          this.combineDateAndTime(sameDay, item.endTime),
        ),
      );
      return insideWindow && !inBreak;
    });

    if (!fitsSchedule) {
      throw new BadRequestException('Selected time is outside doctor availability.');
    }

    const timeOffConflict = timeOffs.some((timeOff) =>
      this.overlaps(startsAt, endsAt, timeOff.startsAt, timeOff.endsAt),
    );
    if (timeOffConflict) {
      throw new BadRequestException('Doctor is not available during that time.');
    }

    const appointment = await this.prisma.$transaction(
      async (tx) => {
        if (input.slotLockId) {
          const lock = await tx.appointmentSlotLock.findUnique({
            where: { id: input.slotLockId },
          });
          if (!lock) {
            throw new ConflictException('Slot lock is missing. Please select a time again.');
          }
          if (lock.releasedAt || lock.expiresAt.getTime() <= Date.now()) {
            throw new ConflictException('Slot lock has expired. Please select a time again.');
          }
          if (lock.lockedByUserId !== requester.userId) {
            throw new ForbiddenException('Slot lock belongs to another user.');
          }
          if (
            lock.doctorId !== doctor.id ||
            lock.serviceId !== service.id ||
            lock.startsAt.getTime() !== startsAt.getTime()
          ) {
            throw new ConflictException('Slot lock does not match selected booking details.');
          }
        }

        const overlap = await tx.appointment.findFirst({
          where: {
            doctorId: doctor.id,
            status: { not: AppointmentStatus.CANCELLED },
            startsAt: { lt: endsAt },
            endsAt: { gt: startsAt },
          },
          select: { id: true },
        });

        if (overlap) {
          throw new ConflictException('That slot was just taken.');
        }

        const created = await tx.appointment.create({
          data: {
            patientId,
            doctorId: doctor.id,
            branchId: service.branchId,
            departmentId: service.departmentId,
            serviceId: service.id,
            startsAt,
            endsAt,
            reason: input.reason,
            intakeAnswers: input.intakeAnswers as Prisma.InputJsonValue | undefined,
            status:
              requester.role === Role.ADMIN || requester.role === Role.STAFF
                  ? AppointmentStatus.CONFIRMED
                  : AppointmentStatus.PENDING,
            createdByUserId: requester.userId,
            paymentStatus: 'PENDING',
          },
          include: {
            patient: {
              include: {
                user: true,
              },
            },
            doctor: {
              include: {
                user: true,
              },
            },
            branch: true,
            department: true,
            service: true,
          },
        });

        if (input.slotLockId) {
          await tx.appointmentSlotLock.update({
            where: { id: input.slotLockId },
            data: {
              releasedAt: new Date(),
              appointmentId: created.id,
            },
          });
        }

        return created;
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      },
    );

    await this.notificationService.createForUsers(
      [appointment.patient.user.id, doctor.userId],
      {
        type: 'APPOINTMENT_CREATED',
        title: 'Appointment booked',
        body: `You are booked for ${appointment.service.name} with Dr. ${doctor.user.firstName ?? ''} ${doctor.user.lastName ?? ''} at ${this.humanTimeLabel(appointment.startsAt)}.`,
        appointmentId: appointment.id,
        data: {
          appointmentId: appointment.id,
          status: appointment.status,
          leaveReminderHint: 'Consider leaving 20 minutes earlier for check-in.',
          startsAt: appointment.startsAt.toISOString(),
        },
      },
    );

    this.realtimeGateway.emitAppointmentBooked(appointment);
    if (!input.withPaymentIntent) {
      return appointment;
    }
    const intent = await this.paymentService.createPaymentIntent(
      Math.max(service.price, 1),
      appointment.id,
    );
    await this.prisma.appointment.update({
      where: { id: appointment.id },
      data: {
        paymentIntentId: intent.clientSecret ?? null,
        paymentStatus: 'INTENT_CREATED',
      },
    });
    await this.notificationService.createForUsers([appointment.patient.user.id], {
      type: 'PAYMENT_REQUIRED',
      title: 'Payment pending',
      body: `Complete payment to finalize booking: ${service.name}`,
      appointmentId: appointment.id,
      data: {
        appointmentId: appointment.id,
        paymentMode: intent.mode,
      },
    });
    return {
      ...appointment,
      paymentIntent: intent,
    };
  }

  async listAppointments(
    requester: Requester,
    filters: {
      status?: AppointmentStatus;
      branchId?: string;
      doctorId?: string;
      patientId?: string;
      from?: string;
      to?: string;
      page?: number;
      pageSize?: number;
    },
  ) {
    const page = Math.max(filters.page ?? 1, 1);
    const pageSize = Math.min(Math.max(filters.pageSize ?? 20, 1), 100);
    const where: Prisma.AppointmentWhereInput = {
      ...(await this.getAppointmentScope(requester)),
    };

    if (
      (requester.role === Role.ADMIN || requester.role === Role.STAFF) &&
      filters.doctorId
    ) {
      where.doctorId = filters.doctorId;
    }
    if (
      (requester.role === Role.ADMIN || requester.role === Role.STAFF) &&
      filters.patientId
    ) {
      where.patientId = filters.patientId;
    }
    if (filters.status) where.status = filters.status;
    if (filters.branchId) where.branchId = filters.branchId;
    if (filters.from || filters.to) {
      where.startsAt = {};
      if (filters.from) where.startsAt.gte = new Date(filters.from);
      if (filters.to) where.startsAt.lte = new Date(filters.to);
    }

    const [items, total] = await this.prisma.$transaction([
      this.prisma.appointment.findMany({
        where,
        include: {
          patient: {
            include: {
              user: true,
            },
          },
          doctor: {
            include: {
              user: true,
              department: true,
            },
          },
          branch: true,
          service: true,
        },
        orderBy: { startsAt: 'asc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.appointment.count({ where }),
    ]);

    return {
      items,
      total,
      page,
      pageSize,
    };
  }

  private async getAppointmentForUpdate(id: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id },
      include: {
        patient: {
          include: {
            user: true,
          },
        },
        doctor: {
          include: {
            user: true,
          },
        },
        service: true,
      },
    });

    if (!appointment) {
      throw new NotFoundException('Appointment not found.');
    }

    return appointment;
  }

  private ensureCanManageAppointment(
    requester: Requester,
    appointment: Awaited<ReturnType<AppointmentService['getAppointmentForUpdate']>>,
  ) {
    if (requester.role === Role.ADMIN || requester.role === Role.STAFF) {
      return;
    }

    if (
      requester.role === Role.DOCTOR &&
      appointment.doctor.userId === requester.userId
    ) {
      return;
    }

    if (
      requester.role === Role.PATIENT &&
      appointment.patient.userId === requester.userId
    ) {
      return;
    }

    throw new ForbiddenException('You do not have access to this appointment.');
  }

  async updateStatus(
    requester: Requester,
    appointmentId: string,
    input: AppointmentStatusUpdateInput,
  ) {
    const appointment = await this.getAppointmentForUpdate(appointmentId);
    this.ensureCanManageAppointment(requester, appointment);

    if (requester.role === Role.PATIENT && input.status !== AppointmentStatus.CANCELLED) {
      throw new ForbiddenException('Patients may only cancel their own appointments.');
    }

    if (
      requester.role === Role.PATIENT &&
      appointment.startsAt.getTime() - Date.now() < 2 * 60 * 60 * 1000
    ) {
      throw new ForbiddenException(
        'Appointments can only be cancelled at least 2 hours in advance.',
      );
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: input.status,
        cancellationReason:
          input.status === AppointmentStatus.CANCELLED
              ? input.cancellationReason
              : null,
        cancelledAt:
          input.status === AppointmentStatus.CANCELLED ? new Date() : null,
        version: { increment: 1 },
      },
      include: {
        patient: {
          include: { user: true },
        },
        doctor: {
          include: { user: true },
        },
        service: true,
      },
    });

    const notificationType =
      input.status === AppointmentStatus.CANCELLED
        ? 'APPOINTMENT_CANCELLED'
        : 'APPOINTMENT_CONFIRMED';

    await this.notificationService.createForUsers(
      [updated.patient.user.id, updated.doctor.user.id],
      {
        type: notificationType,
        title: `Appointment ${input.status.toLowerCase()}`,
        body: `${updated.service.name} on ${updated.startsAt.toISOString()}`,
        appointmentId: updated.id,
        data: { appointmentId: updated.id, status: updated.status },
      },
    );

    this.realtimeGateway.emitAppointmentUpdated(updated);
    if (input.status === AppointmentStatus.CANCELLED) {
      await this.autoMatchWaitlistForCancelled({
        serviceId: updated.serviceId,
        cancelledStart: updated.startsAt,
        branchId: appointment.branchId,
        departmentId: appointment.departmentId,
      });
      const suggestDate = this.toDateOnlyIso(updated.startsAt);
      const nextBest = await this.recommendSlots({
        date: suggestDate,
        serviceId: updated.serviceId,
        branchId: appointment.branchId,
        departmentId: appointment.departmentId,
        requesterUserId: updated.patient.userId,
        limit: 3,
      });
      if (nextBest.length > 0) {
        const first = nextBest[0]!['startsAt']?.toString();
        await this.notificationService.createForUsers([updated.patient.user.id], {
          type: 'APPOINTMENT_CANCELLED',
          title: 'Appointment cancelled, next best time found',
          body:
            first != null
              ? `Try rebooking at ${this.humanTimeLabel(new Date(first))}.`
              : 'Try the next available recommended slot.',
          appointmentId: updated.id,
          data: {
            appointmentId: updated.id,
            recommendations: nextBest,
          },
        });
      }
    }
    return updated;
  }

  async rescheduleAppointment(
    requester: Requester,
    appointmentId: string,
    input: RescheduleInput,
  ) {
    const appointment = await this.getAppointmentForUpdate(appointmentId);
    this.ensureCanManageAppointment(requester, appointment);

    const targetDoctorId = input.doctorId ?? appointment.doctorId;

    const recreated = await this.createAppointment(requester, {
      patientUserId:
        requester.role === Role.PATIENT ? undefined : appointment.patient.userId,
      doctorId: targetDoctorId,
      serviceId: appointment.serviceId,
      startsAt: input.startsAt,
      reason: appointment.reason ?? undefined,
    });

    await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: AppointmentStatus.CANCELLED,
        cancellationReason: `Rescheduled to ${recreated.startsAt.toISOString()}`,
        cancelledAt: new Date(),
        version: { increment: 1 },
      },
    });

    this.realtimeGateway.emitAppointmentUpdated(recreated);
    return recreated;
  }

  async joinWaitlist(requester: Requester, input: WaitlistInput) {
    if (requester.role !== Role.PATIENT) {
      throw new ForbiddenException('Only patients can join waitlist.');
    }
    const preferredDate = input.preferredDate ? new Date(input.preferredDate) : undefined;
    const row = await this.prisma.appointmentWaitlist.create({
      data: {
        userId: requester.userId,
        serviceId: input.serviceId,
        branchId: input.branchId,
        departmentId: input.departmentId,
        preferredDate:
          preferredDate && !Number.isNaN(preferredDate.getTime()) ? preferredDate : undefined,
        preferredHourStart: input.preferredHourStart,
        preferredHourEnd: input.preferredHourEnd,
        note: input.note,
      },
    });
    return row;
  }

  private async autoMatchWaitlistForCancelled(input: {
    serviceId: string;
    cancelledStart: Date;
    branchId?: string;
    departmentId?: string;
  }) {
    const rows = await this.prisma.appointmentWaitlist.findMany({
      where: {
        serviceId: input.serviceId,
        status: 'WAITING',
        OR: [
          { branchId: null },
          { branchId: input.branchId },
        ],
      },
      orderBy: { createdAt: 'asc' },
      take: 40,
    });
    if (rows.length === 0) return;
    const cancelledHour = input.cancelledStart.getHours();
    const cancelledDay = this.toDateOnlyIso(input.cancelledStart);
    const scored = rows.map((row) => {
      let score = 0;
      if (row.departmentId && input.departmentId && row.departmentId !== input.departmentId) {
        score += 200;
      }
      if (row.preferredDate) {
        const prefDay = this.toDateOnlyIso(row.preferredDate);
        score += prefDay === cancelledDay ? 0 : 60;
      }
      if (
        row.preferredHourStart != null &&
        row.preferredHourEnd != null &&
        (cancelledHour < row.preferredHourStart || cancelledHour >= row.preferredHourEnd)
      ) {
        score += 45;
      }
      score += Math.max(0, Math.floor((Date.now() - row.createdAt.getTime()) / 3_600_000) * -1);
      return { row, score };
    });
    scored.sort((a, b) => a.score - b.score);
    const candidate = scored[0]!.row;
    await this.prisma.appointmentWaitlist.update({
      where: { id: candidate.id },
      data: {
        status: 'MATCHED',
        matchedAt: new Date(),
      },
    });
    await this.notificationService.createForUsers([candidate.userId], {
      type: 'WAITLIST_MATCHED',
      title: 'New slot available',
      body: `A cancelled slot opened at ${this.humanTimeLabel(input.cancelledStart)}.`,
      data: {
        serviceId: input.serviceId,
        suggestedStartsAt: input.cancelledStart.toISOString(),
        waitlistId: candidate.id,
      },
    });
  }
}
