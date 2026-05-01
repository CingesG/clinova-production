import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DepartmentStatus, Prisma, ServiceStatus } from '@prisma/client';

import { PrismaService } from '../common/prisma.service';

type DepartmentInput = {
  name: string;
  description?: string;
  status?: DepartmentStatus;
};

type ServiceInput = {
  name: string;
  description?: string;
  branchId: string;
  departmentId: string;
  price: number;
  durationMinutes: number;
  status?: ServiceStatus;
};

type ListServiceFilters = {
  branchId?: string;
  departmentId?: string;
  doctorId?: string;
  status?: ServiceStatus;
  search?: string;
  page?: number;
  pageSize?: number;
};

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  listDepartments(status?: DepartmentStatus) {
    return this.prisma.department.findMany({
      where: status ? { status } : undefined,
      orderBy: { name: 'asc' },
    });
  }

  createDepartment(input: DepartmentInput) {
    return this.prisma.department.create({
      data: input,
    });
  }

  async updateDepartment(id: string, input: Partial<DepartmentInput>) {
    await this.ensureDepartment(id);
    return this.prisma.department.update({
      where: { id },
      data: input,
    });
  }

  async listServices(filters: ListServiceFilters) {
    const page = Math.max(filters.page ?? 1, 1);
    const pageSize = Math.min(Math.max(filters.pageSize ?? 20, 1), 100);

    const where: Prisma.ServiceWhereInput = {};

    if (filters.branchId) where.branchId = filters.branchId;
    if (filters.departmentId) where.departmentId = filters.departmentId;
    if (filters.status) where.status = filters.status;
    if (filters.search) {
      where.OR = [
        { name: { contains: filters.search, mode: 'insensitive' } },
        { description: { contains: filters.search, mode: 'insensitive' } },
      ];
    }
    if (filters.doctorId) {
      where.doctors = {
        some: {
          doctorId: filters.doctorId,
        },
      };
    }

    const [items, total] = await this.prisma.$transaction([
      this.prisma.service.findMany({
        where,
        include: {
          branch: {
            select: { id: true, name: true },
          },
          department: {
            select: { id: true, name: true },
          },
          doctors: {
            include: {
              doctor: {
                include: {
                  user: {
                    select: {
                      id: true,
                      firstName: true,
                      lastName: true,
                    },
                  },
                },
              },
            },
          },
        },
        orderBy: [{ status: 'asc' }, { name: 'asc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.service.count({ where }),
    ]);

    return {
      items,
      total,
      page,
      pageSize,
    };
  }

  async createService(input: ServiceInput) {
    if (input.durationMinutes <= 0) {
      throw new BadRequestException('Duration must be greater than zero.');
    }

    await Promise.all([
      this.ensureBranch(input.branchId),
      this.ensureDepartment(input.departmentId),
    ]);

    return this.prisma.service.create({
      data: input,
    });
  }

  async updateService(id: string, input: Partial<ServiceInput>) {
    await this.ensureService(id);

    if (input.branchId) {
      await this.ensureBranch(input.branchId);
    }
    if (input.departmentId) {
      await this.ensureDepartment(input.departmentId);
    }
    if (
      typeof input.durationMinutes === 'number' &&
      input.durationMinutes <= 0
    ) {
      throw new BadRequestException('Duration must be greater than zero.');
    }

    return this.prisma.service.update({
      where: { id },
      data: input,
    });
  }

  async getServiceIntakeSchema(serviceId: string) {
    const service = await this.prisma.service.findUnique({
      where: { id: serviceId },
      select: {
        id: true,
        name: true,
        intakeSchema: true,
      },
    });
    if (!service) {
      throw new NotFoundException('Service not found.');
    }
    if (service.intakeSchema) {
      return {
        serviceId: service.id,
        schema: service.intakeSchema,
      };
    }
    const defaultSchema = this.buildDefaultIntakeSchema(service.name);
    return {
      serviceId: service.id,
      schema: defaultSchema,
    };
  }

  private buildDefaultIntakeSchema(serviceName: string) {
    const n = serviceName.toLowerCase();
    const base = [
      {
        id: 'mainConcern',
        label: 'Main concern',
        labelMn: 'Гол зовиур',
        type: 'text',
        required: true,
      },
      {
        id: 'symptomDurationDays',
        label: 'Symptoms for how many days?',
        labelMn: 'Шинж тэмдэг хэдэн өдөр үргэлжилж байна вэ?',
        type: 'number',
      },
      {
        id: 'painLevel',
        label: 'Pain level (0-10)',
        labelMn: 'Өвдөлтийн түвшин (0-10)',
        type: 'number',
      },
    ];
    if (n.includes('dental') || n.includes('tooth')) {
      return [
        ...base,
        {
          id: 'sensitiveToCold',
          label: 'Sensitive to cold?',
          labelMn: 'Хүйтэнд мэдрэмтгий юу?',
          type: 'boolean',
        },
        {
          id: 'painLocation',
          label: 'Pain location',
          labelMn: 'Өвдөлтийн байрлал',
          type: 'select',
          options: ['Upper left', 'Upper right', 'Lower left', 'Lower right', 'Front'],
          optionsMn: ['Дээд зүүн', 'Дээд баруун', 'Доод зүүн', 'Доод баруун', 'Урд'],
        },
        {
          id: 'recentTreatment',
          label: 'Recent dental treatment',
          labelMn: 'Сүүлийн шүдний эмчилгээ',
          type: 'text',
        },
      ];
    }
    if (n.includes('skin') || n.includes('derma')) {
      return [
        ...base,
        {
          id: 'hasRash',
          label: 'Do you have visible rash?',
          labelMn: 'Арьсан дээр ил харагдах тууралт байна уу?',
          type: 'boolean',
        },
        {
          id: 'skinImageUrl',
          label: 'Skin photo URL',
          labelMn: 'Арьсны зураг (URL)',
          type: 'image_url',
          showWhen: { field: 'hasRash', equals: true },
        },
        {
          id: 'itchingLevel',
          label: 'Itching level (0-10)',
          labelMn: 'Загатнах түвшин (0-10)',
          type: 'number',
        },
      ];
    }
    if (n.includes('check-up') || n.includes('checkup')) {
      return [
        ...base,
        { id: 'heightCm', label: 'Height (cm)', labelMn: 'Өндөр (см)', type: 'number' },
        { id: 'weightKg', label: 'Weight (kg)', labelMn: 'Жин (кг)', type: 'number' },
        {
          id: 'takesMedication',
          label: 'Taking any medication?',
          labelMn: 'Одоогоор эм ууж байгаа юу?',
          type: 'boolean',
        },
      ];
    }
    if (n.includes('cardio') || n.includes('heart')) {
      return [
        ...base,
        {
          id: 'shortnessOfBreath',
          label: 'Shortness of breath?',
          labelMn: 'Амьсгаадах шинж байна уу?',
          type: 'boolean',
        },
        {
          id: 'bloodPressure',
          label: 'Latest blood pressure',
          labelMn: 'Сүүлийн цусны даралт',
          type: 'text',
        },
      ];
    }
    return base;
  }

  async removeService(id: string) {
    await this.ensureService(id);
    await this.prisma.service.update({
      where: { id },
      data: {
        status: ServiceStatus.INACTIVE,
      },
    });
    return { success: true };
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

  private async ensureService(id: string) {
    const service = await this.prisma.service.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!service) {
      throw new NotFoundException('Service not found.');
    }
  }
}
