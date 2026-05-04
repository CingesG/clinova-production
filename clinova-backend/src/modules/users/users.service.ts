import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import {
  Prisma,
  Role,
  UserStatus,
} from '@prisma/client';

import {
  MONGOLIA_PHONE_INVALID_MESSAGE,
  normalizeOptionalMongoliaPhone,
} from '../common/mongolia-phone.util';
import { PrismaService } from '../common/prisma.service';

type UpdateProfileInput = {
  firstName?: string;
  lastName?: string;
  nickname?: string | null;
  /** Legacy body key — prefer phoneNumber. */
  phone?: string;
  phoneNumber?: string;
  avatarUrl?: string | null;
  dateOfBirth?: string;
  gender?: string;
  address?: string;
  emergencyContactName?: string;
  emergencyContactPhone?: string;
  medicalHistorySummary?: string;
};

type AdminUserUpdateInput = {
  role?: Role;
  status?: UserStatus;
  branchId?: string | null;
  jobTitle?: string | null;
  password?: string;
};

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  private stripPassword(user: Record<string, unknown>) {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { passwordHash, ...safe } = user;
    return safe;
  }

  async me(userId: string) {
    return this.findById(userId);
  }

  async updateMe(userId: string, input: UpdateProfileInput) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { patientProfile: true },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const rawPhone = input.phoneNumber ?? input.phone;
    let phoneData: string | null | undefined;
    if (rawPhone !== undefined) {
      if (rawPhone === null || String(rawPhone).trim() === '') {
        phoneData = null;
      } else {
        const norm = normalizeOptionalMongoliaPhone(String(rawPhone));
        if (norm === null)
          throw new BadRequestException(MONGOLIA_PHONE_INVALID_MESSAGE);
        phoneData = norm;
      }
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          firstName: input.firstName,
          lastName: input.lastName,
          nickname:
            input.nickname === undefined
              ? undefined
              : input.nickname === null ||
                  String(input.nickname).trim().length === 0
                ? null
                : String(input.nickname).trim(),
          ...(phoneData !== undefined ? { phoneNumber: phoneData } : {}),
          avatarUrl:
            input.avatarUrl === undefined ? undefined : input.avatarUrl,
        },
      });

      if (user.role === Role.PATIENT) {
        const patientProfile = user.patientProfile
          ? user.patientProfile
          : await tx.patientProfile.create({
              data: { userId },
            });

        await tx.patientProfile.update({
          where: { id: patientProfile.id },
          data: {
            dateOfBirth: input.dateOfBirth
                ? new Date(input.dateOfBirth)
                : undefined,
            gender: input.gender,
            address: input.address,
            emergencyContactName: input.emergencyContactName,
            emergencyContactPhone: input.emergencyContactPhone,
            medicalHistorySummary: input.medicalHistorySummary,
          },
        });
      }
    });

    return this.findById(userId);
  }

  async list(filters: {
    role?: Role;
    status?: UserStatus;
    branchId?: string;
    search?: string;
    page?: number;
    pageSize?: number;
  }) {
    const page = Math.max(filters.page ?? 1, 1);
    const pageSize = Math.min(Math.max(filters.pageSize ?? 20, 1), 100);

    const where: Prisma.UserWhereInput = {};

    if (filters.role) where.role = filters.role;
    if (filters.status) where.status = filters.status;
    if (filters.branchId) where.branchId = filters.branchId;
    if (filters.search) {
      where.OR = [
        { email: { contains: filters.search, mode: 'insensitive' } },
        { firstName: { contains: filters.search, mode: 'insensitive' } },
        { lastName: { contains: filters.search, mode: 'insensitive' } },
        { phoneNumber: { contains: filters.search, mode: 'insensitive' } },
      ];
    }

    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        include: {
          branch: {
            select: { id: true, name: true },
          },
          patientProfile: {
            select: { id: true },
          },
          doctorProfile: {
            select: { id: true },
          },
        },
        orderBy: [{ role: 'asc' }, { createdAt: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.user.count({ where }),
    ]);

    const safeItems = items.map((u) =>
      this.stripPassword(u as unknown as Record<string, unknown>),
    );

    return {
      items: safeItems,
      total,
      page,
      pageSize,
    };
  }

  async adminUpdate(id: string, input: AdminUserUpdateInput) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        doctorProfile: true,
        patientProfile: true,
      },
    });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    if (input.branchId) {
      await this.ensureBranch(input.branchId);
    }

    if (input.role && input.role === Role.PATIENT && user.doctorProfile) {
      throw new BadRequestException(
        'This user already has a doctor profile. Remove it before demoting the role.',
      );
    }

    const trimmedPassword = input.password?.trim();
    if (trimmedPassword != null && trimmedPassword.length > 0 && trimmedPassword.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters.');
    }
    const passwordHash =
      trimmedPassword != null && trimmedPassword.length > 0
        ? await bcrypt.hash(trimmedPassword, 10)
        : undefined;

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        role: input.role,
        status: input.status,
        branchId: input.branchId === undefined ? undefined : input.branchId,
        jobTitle: input.jobTitle === undefined ? undefined : input.jobTitle,
        passwordHash,
      },
    });

    if (updated.role === Role.PATIENT && !user.patientProfile) {
      await this.prisma.patientProfile.create({
        data: { userId: id },
      });
    }

    return this.findById(id);
  }

  async ensureCanAccessUser(targetUserId: string, requesterUserId: string) {
    if (targetUserId !== requesterUserId) {
      throw new ForbiddenException('You can only access your own profile.');
    }
  }

  async findById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        branch: {
          select: { id: true, name: true },
        },
        patientProfile: true,
        doctorProfile: {
          include: {
            branch: { select: { id: true, name: true } },
            department: { select: { id: true, name: true } },
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    return this.stripPassword(user as unknown as Record<string, unknown>);
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
}
