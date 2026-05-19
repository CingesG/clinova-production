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
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';

import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { AuthGuard } from '../common/auth.guard';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { DoctorService } from './doctor.service';

class DoctorDto {
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' && value.trim() === '' ? undefined : value,
  )
  @IsString()
  username?: string;

  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' && value.trim() === '' ? undefined : value,
  )
  @IsString()
  email?: string;

  @IsString()
  firstName!: string;

  @IsString()
  lastName!: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @IsString()
  branchId!: string;

  @IsString()
  departmentId!: string;

  @IsOptional()
  @IsString()
  bio?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  experienceYears?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  consultationFee?: number;

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsString()
  temporaryPassword?: string;

  @IsOptional()
  @IsBoolean()
  autoGeneratePassword?: boolean;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  serviceIds?: string[];
}

class DoctorBreakDto {
  @IsString()
  startTime!: string;

  @IsString()
  endTime!: string;
}

class ScheduleDto {
  @IsInt()
  dayOfWeek!: number;

  @IsString()
  startTime!: string;

  @IsString()
  endTime!: string;

  @IsInt()
  @Min(1)
  slotMinutes!: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DoctorBreakDto)
  breaks?: DoctorBreakDto[];
}

class TimeOffDto {
  @IsString()
  startsAt!: string;

  @IsString()
  endsAt!: string;

  @IsOptional()
  @IsString()
  reason?: string;
}

class DoctorFeedbackDto {
  @IsInt()
  @Min(1)
  @IsIn([1, 2, 3, 4, 5])
  stars!: number;

  @IsInt()
  @Min(0)
  carePoints!: number;

  @IsOptional()
  @IsString()
  comment?: string;

  @IsOptional()
  @IsString()
  appointmentId?: string;
}

@Controller('doctors')
export class DoctorController {
  constructor(private readonly doctorService: DoctorService) {}

  @Get('suggestions/load-balance')
  loadBalanceSuggestions(
    @Query('serviceId') serviceId: string,
    @Query('branchId') branchId?: string,
    @Query('departmentId') departmentId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.doctorService.suggestLoadBalancedDoctors({
      serviceId,
      branchId,
      departmentId,
      limit: limit != null ? Number(limit) : undefined,
    });
  }

  @Get()
  list(
    @Query('branchId') branchId?: string,
    @Query('departmentId') departmentId?: string,
    @Query('serviceId') serviceId?: string,
    @Query('search') search?: string,
    @Query('active') active?: string,
  ) {
    return this.doctorService.listDoctors({
      branchId,
      departmentId,
      serviceId,
      search,
      active: active === undefined ? true : active === 'true',
    });
  }

  /** Patient «Эмчтэй чат» directory — active doctors only, normalized DTO. */
  @Get('active')
  listActiveForPatient() {
    return this.doctorService.listActiveDoctorsForPatient();
  }

  @Get('me/patients')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('DOCTOR')
  myPatients(@CurrentUser() user: CurrentUserPayload) {
    return this.doctorService.listDoctorPatients(user.sub);
  }

  @Get(':id')
  detail(@Param('id') id: string) {
    return this.doctorService.getDoctor(id);
  }

  @Post()
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN')
  create(@Body() dto: DoctorDto) {
    return this.doctorService.createDoctor(dto);
  }

  @Patch(':id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN')
  update(@Param('id') id: string, @Body() dto: Partial<DoctorDto>) {
    return this.doctorService.updateDoctor(id, dto);
  }

  @Patch('me/profile')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('DOCTOR')
  updateMine(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: Partial<DoctorDto>,
  ) {
    return this.doctorService.updateOwnDoctor(user.sub, dto);
  }

  @Get(':id/schedules')
  listSchedules(@Param('id') id: string) {
    return this.doctorService.listSchedules(id);
  }

  @Post(':id/schedules')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN', 'DOCTOR')
  addSchedule(@Param('id') id: string, @Body() dto: ScheduleDto) {
    return this.doctorService.addSchedule(id, dto);
  }

  @Post(':id/time-offs')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('ADMIN', 'DOCTOR')
  addTimeOff(@Param('id') id: string, @Body() dto: TimeOffDto) {
    return this.doctorService.addTimeOff(id, dto);
  }

  @Post(':id/feedback')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('PATIENT', 'ADMIN', 'STAFF')
  submitFeedback(
    @Param('id') id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: DoctorFeedbackDto,
  ) {
    return this.doctorService.submitDoctorFeedback({
      doctorProfileId: id,
      patientUserId: user.sub,
      stars: dto.stars,
      carePoints: dto.carePoints,
      comment: dto.comment,
      appointmentId: dto.appointmentId,
    });
  }
}
