import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  IsOptional,
  IsString,
} from 'class-validator';

import { AuthGuard } from '../common/auth.guard';
import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { MedicalRecordService } from './medical-record.service';

class MedicalRecordDto {
  @IsString()
  appointmentId!: string;

  @IsOptional()
  @IsString()
  diagnosis?: string;

  @IsOptional()
  @IsString()
  symptoms?: string;

  @IsOptional()
  @IsString()
  treatmentPlan?: string;

  @IsOptional()
  @IsString()
  prescription?: string;

  @IsOptional()
  @IsString()
  note?: string;
}

@Controller('medical-records')
@UseGuards(AuthGuard)
export class MedicalRecordController {
  constructor(private readonly medicalRecordService: MedicalRecordService) {}

  @Post()
  upsert(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: MedicalRecordDto,
  ) {
    return this.medicalRecordService.upsertRecord(
      { userId: user.sub, role: user.role },
      dto,
    );
  }

  @Get('appointment/:appointmentId')
  getByAppointment(
    @CurrentUser() user: CurrentUserPayload,
    @Param('appointmentId') appointmentId: string,
  ) {
    return this.medicalRecordService.getByAppointment(
      { userId: user.sub, role: user.role },
      appointmentId,
    );
  }
}
