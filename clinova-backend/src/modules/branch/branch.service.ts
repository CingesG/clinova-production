import { Injectable, NotFoundException } from '@nestjs/common';
import { BranchStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../common/prisma.service';

type BranchFilters = {
  search?: string;
  status?: BranchStatus;
};

type BranchInput = {
  name: string;
  code: string;
  address: string;
  city: string;
  contactPhone: string;
  contactEmail?: string;
  openingHours: string;
  status?: BranchStatus;
  imageUrl?: string;
  latitude?: number;
  longitude?: number;
};

@Injectable()
export class BranchService {
  constructor(private readonly prisma: PrismaService) {}

  async list(filters: BranchFilters) {
    const where: Prisma.BranchWhereInput = {};

    if (filters.status) {
      where.status = filters.status;
    }

    if (filters.search) {
      where.OR = [
        { name: { contains: filters.search, mode: 'insensitive' } },
        { city: { contains: filters.search, mode: 'insensitive' } },
        { address: { contains: filters.search, mode: 'insensitive' } },
      ];
    }

    return this.prisma.branch.findMany({
      where,
      orderBy: [{ status: 'asc' }, { name: 'asc' }],
      include: {
        _count: {
          select: {
            doctors: true,
            services: true,
            appointments: true,
          },
        },
      },
    });
  }

  async create(input: BranchInput) {
    return this.prisma.branch.create({
      data: input,
    });
  }

  async update(id: string, input: Partial<BranchInput>) {
    await this.ensureExists(id);
    return this.prisma.branch.update({
      where: { id },
      data: input,
    });
  }

  async remove(id: string) {
    await this.ensureExists(id);
    await this.prisma.branch.update({
      where: { id },
      data: {
        status: BranchStatus.INACTIVE,
      },
    });

    return { success: true };
  }

  private async ensureExists(id: string) {
    const branch = await this.prisma.branch.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!branch) {
      throw new NotFoundException('Branch not found.');
    }
  }
}
