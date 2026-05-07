import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import type { SignOptions } from 'jsonwebtoken';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import { AiAgentController } from './ai/ai-agent.controller';
import { AiAgentService } from './ai/ai-agent.service';
import { AiHealthAgentService } from './ai/ai-health-agent.service';
import { AppointmentController } from './appointment/appointment.controller';
import { AppointmentService } from './appointment/appointment.service';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { BranchController } from './branch/branch.controller';
import { BranchService } from './branch/branch.service';
import { CatalogController } from './catalog/catalog.controller';
import { CatalogService } from './catalog/catalog.service';
import { ChatAccessController } from './chat/chat-access.controller';
import { ChatController } from './chat/chat.controller';
import { ChatPatientContactsService } from './chat/chat-patient-contacts.service';
import { ChatPermissionService } from './chat/chat-permission.service';
import { ChatService } from './chat/chat.service';
import { DoctorChatRequestService } from './chat/doctor-chat-request.service';
import { DashboardController } from './dashboard/dashboard.controller';
import { DashboardService } from './dashboard/dashboard.service';
import { DoctorController } from './doctor/doctor.controller';
import { DoctorService } from './doctor/doctor.service';
import { EmergencyController } from './emergency/emergency.controller';
import { EmergencyService } from './emergency/emergency.service';
import { JobController } from './job/job.controller';
import { JobService } from './job/job.service';
import { MedicalRecordController } from './medical-record/medical-record.controller';
import { MedicalRecordService } from './medical-record/medical-record.service';
import { NotificationController } from './notification/notification.controller';
import { NotificationService } from './notification/notification.service';
import { PaymentController } from './payment/payment.controller';
import { PaymentService } from './payment/payment.service';
import { AuthGuard } from './common/auth.guard';
import { HealthController } from './common/health.controller';
import { MailerService } from './common/mailer.service';
import { PrismaService } from './common/prisma.service';
import { RolesGuard } from './common/roles.guard';
import { RealtimeGateway } from './realtime/realtime.gateway';
import { UsersController } from './users/users.controller';
import { UsersService } from './users/users.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot({
      throttlers: [{ ttl: 60000, limit: 200 }],
    }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET', 'dev-secret'),
        signOptions: {
          expiresIn: config.get<string>('JWT_ACCESS_EXPIRES_IN', '30m') as SignOptions['expiresIn'],
        },
      }),
    }),
  ],
  controllers: [
    HealthController,
    AuthController,
    BranchController,
    CatalogController,
    DoctorController,
    AppointmentController,
    MedicalRecordController,
    JobController,
    NotificationController,
    DashboardController,
    PaymentController,
    EmergencyController,
    AiAgentController,
    ChatController,
    ChatAccessController,
    UsersController,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    PrismaService,
    MailerService,
    AuthGuard,
    RolesGuard,
    AuthService,
    BranchService,
    CatalogService,
    DoctorService,
    AppointmentService,
    MedicalRecordService,
    JobService,
    NotificationService,
    DashboardService,
    PaymentService,
    EmergencyService,
    AiAgentService,
    AiHealthAgentService,
    ChatPermissionService,
    ChatPatientContactsService,
    DoctorChatRequestService,
    ChatService,
    RealtimeGateway,
    UsersService,
  ],
})
export class AppModule {}
