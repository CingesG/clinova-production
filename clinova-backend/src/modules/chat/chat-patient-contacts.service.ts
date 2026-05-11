import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { AppointmentStatus, DoctorChatRequestStatus } from '@prisma/client';

import { PrismaService } from '../common/prisma.service';
import { USER_PUBLIC_SELECT } from '../common/user-public-select';
import { CHAT_DM_FORBIDDEN_MN, ChatPermissionService } from './chat-permission.service';

@Injectable()
export class ChatPatientContactsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly chatPermission: ChatPermissionService,
  ) {}

  private async requirePatientProfileId(patientUserId: string) {
    const patient = await this.prisma.patientProfile.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) {
      throw new ForbiddenException(
        'Patient profile is required for this action.',
      );
    }
    return patient.id;
  }

  /**
   * Doctors the patient may open a DM with (appointment ever booked, non-cancelled,
   * or accepted chat request).
   */
  async listAllowedDoctorsForPatient(patientUserId: string) {
    const patientId = await this.requirePatientProfileId(patientUserId);

    const fromAppt = await this.prisma.appointment.findMany({
      where: {
        patientId,
        status: { not: AppointmentStatus.CANCELLED },
      },
      include: {
        doctor: {
          include: {
            user: { select: USER_PUBLIC_SELECT },
            department: { select: { id: true, name: true } },
            branch: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: { startsAt: 'desc' },
    });

    const acceptedReqs = await this.prisma.doctorChatRequest.findMany({
      where: {
        patientId,
        status: DoctorChatRequestStatus.ACCEPTED,
      },
      include: {
        doctor: {
          include: {
            user: { select: USER_PUBLIC_SELECT },
            department: { select: { id: true, name: true } },
            branch: { select: { id: true, name: true } },
          },
        },
      },
    });

    type Entry = {
      doctor: (typeof fromAppt)[number]['doctor'];
      relation: 'APPOINTMENT' | 'CHAT_ACCEPTED';
      appointmentStatus?: string;
      lastAppointmentStartsAt?: string | null;
    };

    const byDoctor = new Map<string, Entry>();

    for (const a of fromAppt) {
      const id = a.doctorId;
      if (!byDoctor.has(id)) {
        byDoctor.set(id, {
          doctor: a.doctor,
          relation: 'APPOINTMENT',
          appointmentStatus: a.status,
          lastAppointmentStartsAt: a.startsAt.toISOString(),
        });
      }
    }

    for (const r of acceptedReqs) {
      if (byDoctor.has(r.doctorId)) continue;
      byDoctor.set(r.doctorId, {
        doctor: r.doctor,
        relation: 'CHAT_ACCEPTED',
        appointmentStatus: 'CHAT_ACCEPTED',
        lastAppointmentStartsAt: null,
      });
    }

    return [...byDoctor.values()].map((e) => ({
      ...e.doctor,
      chatRelation: e.relation,
      displayAppointmentStatus: e.appointmentStatus,
      lastAppointmentStartsAt: e.lastAppointmentStartsAt,
    }));
  }

  async permissionFlagsForPatient(
    patientUserId: string,
    doctorIds: string[],
  ): Promise<
    Record<
      string,
      { canChat: boolean; pendingRequest: boolean; hasAppointment: boolean }
    >
  > {
    const patientId = await this.requirePatientProfileId(patientUserId);
    const ids = [...new Set(doctorIds.filter((x) => x && x.trim().length > 0))];
    if (ids.length === 0) return {};

    const appts = await this.prisma.appointment.findMany({
      where: {
        patientId,
        doctorId: { in: ids },
        status: { not: AppointmentStatus.CANCELLED },
      },
      distinct: ['doctorId'],
      select: { doctorId: true },
    });
    const hasAppt = new Set(appts.map((a) => a.doctorId));

    const accepted = await this.prisma.doctorChatRequest.findMany({
      where: {
        patientId,
        doctorId: { in: ids },
        status: DoctorChatRequestStatus.ACCEPTED,
      },
      select: { doctorId: true },
    });
    const hasAccepted = new Set(accepted.map((r) => r.doctorId));

    const pending = await this.prisma.doctorChatRequest.findMany({
      where: {
        patientId,
        doctorId: { in: ids },
        status: DoctorChatRequestStatus.PENDING,
      },
      select: { doctorId: true },
    });
    const hasPending = new Set(pending.map((r) => r.doctorId));

    const out: Record<
      string,
      { canChat: boolean; pendingRequest: boolean; hasAppointment: boolean }
    > = {};
    for (const id of ids) {
      const ap = hasAppt.has(id);
      const acc = hasAccepted.has(id);
      const canChat = ap || acc;
      out[id] = {
        canChat,
        hasAppointment: ap,
        pendingRequest: hasPending.has(id) && !canChat,
      };
    }
    return out;
  }

  async buildMyChatDoctorsSummary(patientUserId: string) {
    const rows = await this.listAllowedDoctorsForPatient(patientUserId);
    return rows.map((row) => {
      const {
        chatRelation,
        displayAppointmentStatus,
        lastAppointmentStartsAt,
        ...doctor
      } = row as Record<string, unknown>;
      return {
        doctor,
        chatRelation,
        appointmentStatusLabel: displayAppointmentStatus,
        lastAppointmentStartsAt,
      };
    });
  }

  /**
   * Find-or-create style: DM room id is deterministic per patient user + doctor profile.
   * Caller must be allowed to chat (appointment or accepted chat request).
   */
  async startDoctorConversation(patientUserId: string, doctorProfileId: string) {
    const doctorId = doctorProfileId.trim();
    if (!doctorId) {
      throw new BadRequestException('doctorId is required.');
    }

    const patientProfile = await this.prisma.patientProfile.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patientProfile) {
      throw new ForbiddenException(
        'Patient profile is required for this action.',
      );
    }

    const mayChat = await this.chatPermission.patientDoctorPairMayChat(
      patientUserId,
      doctorId,
    );
    if (!mayChat) {
      throw new ForbiddenException(CHAT_DM_FORBIDDEN_MN);
    }

    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { id: doctorId },
      select: {
        id: true,
        user: { select: USER_PUBLIC_SELECT },
      },
    });
    if (!doctor) {
      throw new BadRequestException('Doctor not found.');
    }

    const roomId = `room-${patientUserId}-doc-${doctorId}`;
    const u = doctor.user;
    const first = (u.firstName ?? '').trim();
    const last = (u.lastName ?? '').trim();
    const name = `${first} ${last}`.trim() || 'Doctor';

    return {
      id: roomId,
      patientId: patientProfile.id,
      doctorId: doctor.id,
      doctor: {
        id: doctor.id,
        name,
        avatarUrl: u.avatarUrl ?? null,
        userId: u.id,
      },
    };
  }
}
