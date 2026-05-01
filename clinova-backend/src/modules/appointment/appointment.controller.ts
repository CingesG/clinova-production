import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AppointmentStatus } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
} from 'class-validator';

import { AuthGuard } from '../common/auth.guard';
import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { AppointmentService } from './appointment.service';

class CreateAppointmentDto {
  @IsString()
  doctorId!: string;

  @IsString()
  serviceId!: string;

  @IsDateString()
  startsAt!: string;

  @IsOptional()
  @IsString()
  patientUserId?: string;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsString()
  slotLockId?: string;

  @IsOptional()
  @IsObject()
  intakeAnswers?: Record<string, unknown>;

  @IsOptional()
  @IsBoolean()
  withPaymentIntent?: boolean;
}

class UpdateAppointmentStatusDto {
  @IsEnum(AppointmentStatus)
  status!: AppointmentStatus;

  @IsOptional()
  @IsString()
  cancellationReason?: string;
}

class RescheduleAppointmentDto {
  @IsDateString()
  startsAt!: string;

  @IsOptional()
  @IsString()
  doctorId?: string;
}

class AcquireSlotLockDto {
  @IsString()
  doctorId!: string;

  @IsString()
  serviceId!: string;

  @IsDateString()
  startsAt!: string;
}

class JoinWaitlistDto {
  @IsString()
  serviceId!: string;

  @IsOptional()
  @IsString()
  branchId?: string;

  @IsOptional()
  @IsString()
  departmentId?: string;

  @IsOptional()
  @IsDateString()
  preferredDate?: string;

  @IsOptional()
  @IsInt()
  preferredHourStart?: number;

  @IsOptional()
  @IsInt()
  preferredHourEnd?: number;

  @IsOptional()
  @IsString()
  note?: string;
}

@Controller('appointments')
export class AppointmentController {
  constructor(private readonly appointmentService: AppointmentService) {}

  @Get('slots')
  getSlots(
    @Query('branchId') branchId: string | undefined,
    @Query('departmentId') departmentId: string | undefined,
    @Query('serviceId') serviceId: string | undefined,
    @Query('doctorId') doctorId: string | undefined,
    @Query('date') date: string,
  ) {
    return this.appointmentService.getAvailableSlots({
      branchId,
      departmentId,
      serviceId,
      doctorId,
      date,
    });
  }

  @Get('recommend')
  getRecommendedSlots(
    @Query('branchId') branchId: string | undefined,
    @Query('departmentId') departmentId: string | undefined,
    @Query('serviceId') serviceId: string | undefined,
    @Query('doctorId') doctorId: string | undefined,
    @Query('date') date: string,
    @Query('preferredStartHour') preferredStartHour?: string,
    @Query('preferredEndHour') preferredEndHour?: string,
    @Query('limit') limit?: string,
  ) {
    return this.appointmentService.recommendSlots({
      branchId,
      departmentId,
      serviceId,
      doctorId,
      date,
      preferredStartHour:
        preferredStartHour != null ? Number(preferredStartHour) : undefined,
      preferredEndHour:
        preferredEndHour != null ? Number(preferredEndHour) : undefined,
      limit: limit != null ? Number(limit) : undefined,
    });
  }

  @Get('recommend-auth')
  @UseGuards(AuthGuard)
  getRecommendedSlotsAuth(
    @CurrentUser() user: CurrentUserPayload,
    @Query('branchId') branchId: string | undefined,
    @Query('departmentId') departmentId: string | undefined,
    @Query('serviceId') serviceId: string | undefined,
    @Query('doctorId') doctorId: string | undefined,
    @Query('date') date: string,
    @Query('preferredStartHour') preferredStartHour?: string,
    @Query('preferredEndHour') preferredEndHour?: string,
    @Query('limit') limit?: string,
  ) {
    return this.appointmentService.recommendSlots({
      branchId,
      departmentId,
      serviceId,
      doctorId,
      date,
      requesterUserId: user.sub,
      preferredStartHour:
        preferredStartHour != null ? Number(preferredStartHour) : undefined,
      preferredEndHour:
        preferredEndHour != null ? Number(preferredEndHour) : undefined,
      limit: limit != null ? Number(limit) : undefined,
    });
  }

  @Get('recommend-doctors')
  getRecommendedDoctors(
    @Query('serviceId') serviceId: string,
    @Query('date') date: string,
    @Query('branchId') branchId?: string,
    @Query('departmentId') departmentId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.appointmentService.recommendDoctors({
      serviceId,
      date,
      branchId,
      departmentId,
      limit: limit != null ? Number(limit) : undefined,
    });
  }

  @Get()
  @UseGuards(AuthGuard)
  list(
    @CurrentUser() user: CurrentUserPayload,
    @Query('status') status?: AppointmentStatus,
    @Query('branchId') branchId?: string,
    @Query('doctorId') doctorId?: string,
    @Query('patientId') patientId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.appointmentService.listAppointments(
      { userId: user.sub, role: user.role },
      {
        status,
        branchId,
        doctorId,
        patientId,
        from,
        to,
        page: page ? Number(page) : undefined,
        pageSize: pageSize ? Number(pageSize) : undefined,
      },
    );
  }

  @Post()
  @UseGuards(AuthGuard)
  create(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateAppointmentDto,
  ) {
    return this.appointmentService.createAppointment(
      { userId: user.sub, role: user.role },
      dto,
    );
  }

  @Post('slot-lock')
  @UseGuards(AuthGuard)
  acquireSlotLock(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: AcquireSlotLockDto,
  ) {
    return this.appointmentService.acquireSlotLock(
      { userId: user.sub, role: user.role },
      dto,
    );
  }

  @Patch('slot-lock/:id/release')
  @UseGuards(AuthGuard)
  releaseSlotLock(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return this.appointmentService.releaseSlotLock(
      { userId: user.sub, role: user.role },
      id,
    );
  }

  @Post('waitlist')
  @UseGuards(AuthGuard)
  joinWaitlist(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: JoinWaitlistDto,
  ) {
    return this.appointmentService.joinWaitlist(
      { userId: user.sub, role: user.role },
      dto,
    );
  }

  @Patch(':id/status')
  @UseGuards(AuthGuard)
  updateStatus(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: UpdateAppointmentStatusDto,
  ) {
    return this.appointmentService.updateStatus(
      { userId: user.sub, role: user.role },
      id,
      dto,
    );
  }

  @Patch(':id/reschedule')
  @UseGuards(AuthGuard)
  reschedule(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: RescheduleAppointmentDto,
  ) {
    return this.appointmentService.rescheduleAppointment(
      { userId: user.sub, role: user.role },
      id,
      dto,
    );
  }
}
