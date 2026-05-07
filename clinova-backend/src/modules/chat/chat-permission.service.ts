import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import {
  AppointmentStatus,
  DoctorChatRequestStatus,
  Role,
} from '@prisma/client';

import { PrismaService } from '../common/prisma.service';

/** Patient-facing rule copy (MN) per product spec. */
export const CHAT_DM_FORBIDDEN_MN =
  'Эмчтэй чатлахын тулд цаг захиалах эсвэл чат хүсэлтээ зөвшөөрүүлэх шаардлагатай.';

export type DoctorDmRoomParts = {
  patientUserId: string;
  doctorProfileId: string;
};

@Injectable()
export class ChatPermissionService {
  constructor(private readonly prisma: PrismaService) {}

  static parseDoctorDmRoom(roomId: string): DoctorDmRoomParts | null {
    const prefix = 'room-';
    const mid = '-doc-';
    if (!roomId.startsWith(prefix) || !roomId.includes(mid)) return null;
    const rest = roomId.slice(prefix.length);
    const idx = rest.lastIndexOf(mid);
    if (idx < 0) return null;
    const patientUserId = rest.slice(0, idx).trim();
    const doctorProfileId = rest.slice(idx + mid.length).trim();
    if (!patientUserId || !doctorProfileId) return null;
    return { patientUserId, doctorProfileId };
  }

  async patientDoctorPairMayChat(
    patientUserId: string,
    doctorProfileId: string,
  ): Promise<boolean> {
    const patient = await this.prisma.patientProfile.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) return false;

    const appt = await this.prisma.appointment.findFirst({
      where: {
        patientId: patient.id,
        doctorId: doctorProfileId,
        status: { not: AppointmentStatus.CANCELLED },
      },
      select: { id: true },
    });
    if (appt) return true;

    const accepted = await this.prisma.doctorChatRequest.findFirst({
      where: {
        patientId: patient.id,
        doctorId: doctorProfileId,
        status: DoctorChatRequestStatus.ACCEPTED,
      },
      select: { id: true },
    });
    return Boolean(accepted);
  }

  async listPatientUserIdsForDoctorChat(doctorProfileId: string) {
    const fromAppt = await this.prisma.appointment.findMany({
      where: {
        doctorId: doctorProfileId,
        status: { not: AppointmentStatus.CANCELLED },
      },
      select: {
        patient: { select: { userId: true } },
      },
    });
    const fromChat = await this.prisma.doctorChatRequest.findMany({
      where: {
        doctorId: doctorProfileId,
        status: DoctorChatRequestStatus.ACCEPTED,
      },
      select: {
        patient: { select: { userId: true } },
      },
    });
    const ids = new Set<string>();
    for (const row of fromAppt) {
      ids.add(row.patient.userId);
    }
    for (const row of fromChat) {
      ids.add(row.patient.userId);
    }
    return [...ids];
  }

  /**
   * REST + socket: only participants may read/send DM; link must be appointment or accepted request.
   */
  async assertMayAccessDoctorDmRoom(options: {
    actorUserId: string;
    actorRole: Role;
    roomId: string;
  }) {
    const parsed = ChatPermissionService.parseDoctorDmRoom(options.roomId);
    if (!parsed) {
      throw new BadRequestException('Invalid chat room id.');
    }
    const { patientUserId, doctorProfileId } = parsed;

    if (options.actorRole === Role.PATIENT) {
      if (options.actorUserId !== patientUserId) {
        throw new ForbiddenException(CHAT_DM_FORBIDDEN_MN);
      }
    } else if (options.actorRole === Role.DOCTOR) {
      const profile = await this.prisma.doctorProfile.findUnique({
        where: { userId: options.actorUserId },
        select: { id: true },
      });
      if (!profile || profile.id !== doctorProfileId) {
        throw new ForbiddenException(CHAT_DM_FORBIDDEN_MN);
      }
    } else {
      throw new ForbiddenException(CHAT_DM_FORBIDDEN_MN);
    }

    const ok = await this.patientDoctorPairMayChat(patientUserId, doctorProfileId);
    if (!ok) {
      throw new ForbiddenException(CHAT_DM_FORBIDDEN_MN);
    }
  }

  /**
   * Socket handlers only know [userId]; load role from DB then apply DM rules.
   */
  async assertMayAccessDoctorDmRoomForUserId(userId: string, roomId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true },
    });
    if (!user) {
      throw new ForbiddenException(CHAT_DM_FORBIDDEN_MN);
    }
    await this.assertMayAccessDoctorDmRoom({
      actorUserId: userId,
      actorRole: user.role,
      roomId,
    });
  }
}
