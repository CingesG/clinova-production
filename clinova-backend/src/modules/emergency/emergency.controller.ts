import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsNumber } from 'class-validator';
import { EmergencyService } from './emergency.service';
import { AuthGuard } from '../common/auth.guard';

class EmergencyDto {
  @IsNumber()
  lat!: number;

  @IsNumber()
  lng!: number;
}

@Controller('emergency')
@UseGuards(AuthGuard)
export class EmergencyController {
  constructor(private readonly emergencyService: EmergencyService) {}

  @Post()
  trigger(@Body() dto: EmergencyDto) {
    return this.emergencyService.triggerEmergency(dto.lat, dto.lng);
  }
}
