import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JobApplicationStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../common/prisma.service';

type JobInput = {
  fullName: string;
  email: string;
  phone?: string;
  desiredRole: string;
  branchId?: string;
  departmentId?: string;
  resumeUrl?: string;
  coverLetter?: string;
};

type JobUpdate = {
  status?: JobApplicationStatus;
  internalNote?: string;
};

@Injectable()
export class JobService {
  constructor(private readonly prisma: PrismaService) {}

  async apply(input: JobInput) {
    const application = await this.prisma.jobApplication.create({
      data: {
        fullName: input.fullName,
        email: input.email.trim().toLowerCase(),
        phone: input.phone,
        desiredRole: input.desiredRole,
        branchId: input.branchId,
        departmentId: input.departmentId,
        resumeUrl: input.resumeUrl,
        coverLetter: input.coverLetter,
      },
    });

    const admins = await this.prisma.user.findMany({
      where: { role: 'ADMIN' },
      select: { id: true },
    });

    if (admins.length > 0) {
      await this.prisma.notification.createMany({
        data: admins.map((admin) => ({
          userId: admin.id,
          type: 'JOB_APPLICATION_SUBMITTED',
          title: 'New job application received',
          body: `${input.fullName} applied for ${input.desiredRole}.`,
          data: { applicationId: application.id },
        })),
      });
    }

    return application;
  }

  async list(filters: {
    status?: JobApplicationStatus;
    search?: string;
    page?: number;
    pageSize?: number;
  }) {
    const page = Math.max(filters.page ?? 1, 1);
    const pageSize = Math.min(Math.max(filters.pageSize ?? 20, 1), 100);

    const where: Prisma.JobApplicationWhereInput = {};
    if (filters.status) where.status = filters.status;
    if (filters.search) {
      where.OR = [
        { fullName: { contains: filters.search, mode: 'insensitive' } },
        { email: { contains: filters.search, mode: 'insensitive' } },
        { desiredRole: { contains: filters.search, mode: 'insensitive' } },
      ];
    }

    const [items, total] = await this.prisma.$transaction([
      this.prisma.jobApplication.findMany({
        where,
        include: {
          branch: {
            select: { id: true, name: true },
          },
          department: {
            select: { id: true, name: true },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.jobApplication.count({ where }),
    ]);

    return {
      items,
      total,
      page,
      pageSize,
    };
  }

  async update(id: string, input: JobUpdate) {
    await this.ensureApplication(id);
    return this.prisma.jobApplication.update({
      where: { id },
      data: input,
    });
  }

  private async ensureApplication(id: string) {
    const item = await this.prisma.jobApplication.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!item) {
      throw new NotFoundException('Job application not found.');
    }
  }
}
