import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  DepartmentStatus,
  ServiceStatus,
} from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

import { AuthGuard } from '../common/auth.guard';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { CatalogService } from './catalog.service';

class DepartmentDto {
  @IsString()
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsEnum(DepartmentStatus)
  status?: DepartmentStatus;
}

class ServiceDto {
  @IsString()
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsString()
  branchId!: string;

  @IsString()
  departmentId!: string;

  @IsNumber()
  price!: number;

  @IsInt()
  @Min(1)
  durationMinutes!: number;

  @IsOptional()
  @IsEnum(ServiceStatus)
  status?: ServiceStatus;
}

@Controller()
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('departments')
  departments(@Query('status') status?: DepartmentStatus) {
    return this.catalogService.listDepartments(status);
  }

  @Post('departments')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN')
  createDepartment(@Body() dto: DepartmentDto) {
    return this.catalogService.createDepartment(dto);
  }

  @Patch('departments/:id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN')
  updateDepartment(@Param('id') id: string, @Body() dto: Partial<DepartmentDto>) {
    return this.catalogService.updateDepartment(id, dto);
  }

  @Get('services')
  services(
    @Query('branchId') branchId?: string,
    @Query('departmentId') departmentId?: string,
    @Query('doctorId') doctorId?: string,
    @Query('status') status?: ServiceStatus,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.catalogService.listServices({
      branchId,
      departmentId,
      doctorId,
      status,
      search,
      page: page ? Number(page) : undefined,
      pageSize: pageSize ? Number(pageSize) : undefined,
    });
  }

  @Get('services/:id/intake-schema')
  getServiceIntakeSchema(@Param('id') id: string) {
    return this.catalogService.getServiceIntakeSchema(id);
  }

  @Post('services')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN')
  createService(@Body() dto: ServiceDto) {
    return this.catalogService.createService(dto);
  }

  @Patch('services/:id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN')
  updateService(@Param('id') id: string, @Body() dto: Partial<ServiceDto>) {
    return this.catalogService.updateService(id, dto);
  }

  @Delete('services/:id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN')
  removeService(@Param('id') id: string) {
    return this.catalogService.removeService(id);
  }
}
