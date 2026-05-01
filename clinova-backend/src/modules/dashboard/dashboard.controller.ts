import { Controller, Get, UseGuards } from '@nestjs/common';

import { AuthGuard } from '../common/auth.guard';
import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { DashboardService } from './dashboard.service';

@Controller('dashboard')
@UseGuards(AuthGuard)
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('admin')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  admin() {
    return this.dashboardService.adminSummary();
  }

  @Get('doctor')
  @UseGuards(RolesGuard)
  @Roles('DOCTOR')
  doctor(@CurrentUser() user: CurrentUserPayload) {
    return this.dashboardService.doctorSummary(user.sub);
  }

  @Get('patient')
  @UseGuards(RolesGuard)
  @Roles('PATIENT')
  patient(@CurrentUser() user: CurrentUserPayload) {
    return this.dashboardService.patientSummary(user.sub);
  }
}
