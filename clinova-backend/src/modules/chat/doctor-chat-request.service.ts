import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  DoctorChatRequestStatus,
  NotificationType,
} from '@prisma/client';

import { PrismaService } from '../common/prisma.service';
import { USER_PUBLIC_SELECT } from '../common/user-public-select';
import { NotificationService } from '../notification/notification.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

import { ChatPermissionService } from './chat-permission.service';

@Injectable()
export class DoctorChatRequestService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationService,
    private readonly realtime: RealtimeGateway,
    private readonly permissions: ChatPermissionService,
  ) {}

  async createRequest(
    patientUserId: string,
    doctorProfileId: string,
    note?: string,
  ) {
    const patient = await this.prisma.patientProfile.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) {
      throw new ForbiddenException('Patient profile required.');
    }

    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { id: doctorProfileId },
      select: {
        id: true,
        userId: true,
        user: { select: { firstName: true, lastName: true } },
      },
    });
    if (!doctor) {
      throw new NotFoundException('Doctor not found.');
    }

    const mayAlready = await this.permissions.patientDoctorPairMayChat(
      patientUserId,
      doctorProfileId,
    );
    if (mayAlready) {
      throw new BadRequestException('Chat is already available for this doctor.');
    }

    const dupPending = await this.prisma.doctorChatRequest.findFirst({
      where: {
        patientId: patient.id,
        doctorId: doctorProfileId,
        status: DoctorChatRequestStatus.PENDING,
      },
    });
    if (dupPending) {
      throw new BadRequestException(
        'A pending chat request already exists for this doctor.',
      );
    }

    const row = await this.prisma.doctorChatRequest.create({
      data: {
        patientId: patient.id,
        doctorId: doctorProfileId,
        note: note?.trim() || null,
        status: DoctorChatRequestStatus.PENDING,
      },
      include: {
        patient: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
        doctor: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
      },
    });

    const patientName =
      `${row.patient.user.firstName ?? ''} ${row.patient.user.lastName ?? ''}`.trim() ||
      'Өвчтөн';
    await this.notifications.createForUsers([doctor.userId], {
      type: NotificationType.CHAT_REQUEST_RECEIVED,
      title: 'Чат хүсэлт',
      body: `${patientName} эмчид чатлах хүсэлт илгээсэн байна.`,
      data: {
        kind: 'CHAT_REQUEST',
        requestId: row.id,
        doctorProfileId,
        patientUserId,
      },
    });

    this.realtime.emitChatRequestToDoctor(doctor.userId, {
      requestId: row.id,
      doctorProfileId,
      patientUserId,
      patientName,
      note: row.note,
      createdAt: row.createdAt.toISOString(),
    });

    return row;
  }

  async listPendingForDoctor(doctorUserId: string) {
    const profile = await this.prisma.doctorProfile.findUnique({
      where: { userId: doctorUserId },
      select: { id: true },
    });
    if (!profile) {
      throw new ForbiddenException('Doctor profile not found.');
    }
    return this.prisma.doctorChatRequest.findMany({
      where: {
        doctorId: profile.id,
        status: DoctorChatRequestStatus.PENDING,
      },
      orderBy: { createdAt: 'asc' },
      include: {
        patient: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
      },
    });
  }

  async listMineForPatient(patientUserId: string) {
    const patient = await this.prisma.patientProfile.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) {
      throw new ForbiddenException('Patient profile required.');
    }
    return this.prisma.doctorChatRequest.findMany({
      where: { patientId: patient.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        doctor: {
          include: {
            user: { select: USER_PUBLIC_SELECT },
            department: { select: { id: true, name: true } },
          },
        },
      },
    });
  }

  private async resolveAsDoctor(
    requestId: string,
    doctorUserId: string,
    next: Exclude<DoctorChatRequestStatus, 'PENDING'>,
  ) {
    const profile = await this.prisma.doctorProfile.findUnique({
      where: { userId: doctorUserId },
      select: { id: true },
    });
    if (!profile) {
      throw new ForbiddenException('Doctor profile not found.');
    }

    const row = await this.prisma.doctorChatRequest.findFirst({
      where: { id: requestId, doctorId: profile.id },
      include: {
        patient: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
        doctor: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
      },
    });
    if (!row) {
      throw new NotFoundException('Request not found.');
    }
    if (row.status !== DoctorChatRequestStatus.PENDING) {
      throw new BadRequestException('This request is no longer pending.');
    }

    const updated = await this.prisma.doctorChatRequest.update({
      where: { id: row.id },
      data: {
        status: next,
        respondedAt: new Date(),
      },
      include: {
        patient: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
        doctor: {
          include: { user: { select: USER_PUBLIC_SELECT } },
        },
      },
    });

    const patientUserId = row.patient.user.id;
    const doctorName =
      `${row.doctor.user.firstName ?? ''} ${row.doctor.user.lastName ?? ''}`.trim() ||
      'Эмч';

    if (next === DoctorChatRequestStatus.ACCEPTED) {
      await this.notifications.createForUsers([patientUserId], {
        type: NotificationType.CHAT_REQUEST_ACCEPTED,
        title: 'Чат зөвшөөрөгдлөө',
        body: `${doctorName} таны чат хүсэлтийг зөвшөөрлөө. Одоо чатаа нээнэ үү.`,
        data: {
          kind: 'CHAT_REQUEST_ACCEPTED',
          requestId: row.id,
          doctorProfileId: row.doctorId,
        },
      });
      this.realtime.emitChatRequestResolved(patientUserId, {
        outcome: 'ACCEPTED',
        requestId: row.id,
        doctorProfileId: row.doctorId,
        doctorName,
      });
    } else {
      this.realtime.emitChatRequestResolved(patientUserId, {
        outcome: 'DECLINED',
        requestId: row.id,
        doctorProfileId: row.doctorId,
      });
    }

    return updated;
  }

  async accept(requestId: string, doctorUserId: string) {
    return this.resolveAsDoctor(
      requestId,
      doctorUserId,
      DoctorChatRequestStatus.ACCEPTED,
    );
  }

  async decline(requestId: string, doctorUserId: string) {
    return this.resolveAsDoctor(
      requestId,
      doctorUserId,
      DoctorChatRequestStatus.DECLINED,
    );
  }
}
