import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../common/auth.guard';
import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';

import { ChatPatientContactsService } from './chat-patient-contacts.service';
import { DoctorChatRequestService } from './doctor-chat-request.service';
import { StartConversationDto } from './dto/start-conversation.dto';

type PermissionFlagsDto = { doctorIds: string[] };

type CreateChatRequestDto = {
  doctorProfileId: string;
  note?: string;
};

@Controller('chat')
@UseGuards(AuthGuard)
export class ChatAccessController {
  constructor(
    private readonly contacts: ChatPatientContactsService,
    private readonly chatRequests: DoctorChatRequestService,
  ) {}

  @Get('patient-allowed-doctors')
  @UseGuards(RolesGuard)
  @Roles('PATIENT')
  patientAllowedDoctors(@CurrentUser() user: CurrentUserPayload) {
    return this.contacts.listAllowedDoctorsForPatient(user.sub);
  }

  @Post('conversations/start')
  @UseGuards(RolesGuard)
  @Roles('PATIENT')
  startConversation(
    @CurrentUser() user: CurrentUserPayload,
    @Body() body: StartConversationDto,
  ) {
    const doctorId = String(body?.doctorId ?? '').trim();
    if (!doctorId) {
      throw new BadRequestException('doctorId is required.');
    }
    return this.contacts.startDoctorConversation(user.sub, doctorId);
  }

  @Post('permission-flags')
  @UseGuards(RolesGuard)
  @Roles('PATIENT')
  permissionFlags(
    @CurrentUser() user: CurrentUserPayload,
    @Body() body: PermissionFlagsDto,
  ) {
    const raw = body?.doctorIds;
    const list = Array.isArray(raw)
      ? raw.map((x) => String(x ?? '').trim()).filter(Boolean)
      : [];
    return this.contacts.permissionFlagsForPatient(user.sub, list);
  }

  @Post('requests')
  @UseGuards(RolesGuard)
  @Roles('PATIENT')
  createRequest(
    @CurrentUser() user: CurrentUserPayload,
    @Body() body: CreateChatRequestDto,
  ) {
    const doctorProfileId = String(body?.doctorProfileId ?? '').trim();
    if (!doctorProfileId) {
      throw new BadRequestException('doctorProfileId is required.');
    }
    return this.chatRequests.createRequest(
      user.sub,
      doctorProfileId,
      body?.note,
    );
  }

  @Get('requests/incoming')
  @UseGuards(RolesGuard)
  @Roles('DOCTOR')
  listIncoming(@CurrentUser() user: CurrentUserPayload) {
    return this.chatRequests.listPendingForDoctor(user.sub);
  }

  @Get('requests/mine')
  @UseGuards(RolesGuard)
  @Roles('PATIENT')
  listMine(@CurrentUser() user: CurrentUserPayload) {
    return this.chatRequests.listMineForPatient(user.sub);
  }

  @Patch('requests/:id/accept')
  @UseGuards(RolesGuard)
  @Roles('DOCTOR')
  accept(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return this.chatRequests.accept(id, user.sub);
  }

  @Patch('requests/:id/decline')
  @UseGuards(RolesGuard)
  @Roles('DOCTOR')
  decline(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return this.chatRequests.decline(id, user.sub);
  }
}
