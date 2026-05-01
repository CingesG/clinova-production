import {
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { AppointmentStatus, Role } from '@prisma/client';

import { PrismaService } from '../common/prisma.service';
import { NotificationService } from '../notification/notification.service';

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationService,
  ) {}

  private asNumber(value: unknown, fallback = 0) {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string') {
      const n = Number(value);
      if (Number.isFinite(n)) return n;
    }
    return fallback;
  }

  async adminSummary() {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);

    const [
      totalUsers,
      totalDoctors,
      totalPatients,
      totalAppointments,
      completedAppointments,
      todayAppointments,
      totalRevenue,
      applicationsCount,
      activeBranches,
      feedbackRows,
    ] = await this.prisma.$transaction([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { role: Role.DOCTOR } }),
      this.prisma.user.count({ where: { role: Role.PATIENT } }),
      this.prisma.appointment.count(),
      this.prisma.appointment.count({
        where: { status: AppointmentStatus.COMPLETED },
      }),
      this.prisma.appointment.count({
        where: {
          startsAt: { gte: todayStart, lt: todayEnd },
        },
      }),
      this.prisma.service.aggregate({
        _sum: { price: true },
      }),
      this.prisma.jobApplication.count(),
      this.prisma.branch.count({
        where: { status: 'ACTIVE' },
      }),
      this.prisma.notification.findMany({
        where: {
          type: 'SYSTEM',
          title: 'DOCTOR_FEEDBACK',
        },
        select: {
          data: true,
        },
      }),
    ]);

    let starsTotal = 0;
    let careTotal = 0;
    let feedbackCount = 0;
    const bonusByDoctor = new Map<
      string,
      { stars: number; care: number; count: number }
    >();
    for (const row of feedbackRows) {
      if (!row.data || typeof row.data !== 'object') continue;
      const data = row.data as Record<string, unknown>;
      if (data['kind'] !== 'DOCTOR_FEEDBACK') continue;
      const stars = this.asNumber(data['stars']);
      const care = this.asNumber(data['carePoints']);
      const doctorProfileId = String(data['doctorProfileId'] ?? '');
      starsTotal += stars;
      careTotal += care;
      feedbackCount += 1;
      if (doctorProfileId) {
        const slot = bonusByDoctor.get(doctorProfileId) ?? {
          stars: 0,
          care: 0,
          count: 0,
        };
        slot.stars += stars;
        slot.care += care;
        slot.count += 1;
        bonusByDoctor.set(doctorProfileId, slot);
      }
    }

    const doctorIds = [...bonusByDoctor.keys()];
    const doctorProfiles = doctorIds.length
      ? await this.prisma.doctorProfile.findMany({
          where: { id: { in: doctorIds } },
          include: {
            user: { select: { firstName: true, lastName: true } },
          },
        })
      : [];
    const doctorNameMap = new Map(
      doctorProfiles.map((doctor) => [
        doctor.id,
        `${doctor.user.firstName ?? ''} ${doctor.user.lastName ?? ''}`.trim() ||
          'Doctor',
      ]),
    );

    const topDoctorBonuses = [...bonusByDoctor.entries()]
      .map(([doctorProfileId, value]) => {
        const avgStars = value.stars / Math.max(1, value.count);
        const avgCare = value.care / Math.max(1, value.count);
        const bonusMnt = Math.round(value.count * 15000 + avgStars * 10000 + avgCare * 6000);
        return {
          doctorProfileId,
          doctorName: doctorNameMap.get(doctorProfileId) ?? 'Doctor',
          feedbackCount: value.count,
          avgStars: Number(avgStars.toFixed(2)),
          avgCarePoints: Number(avgCare.toFixed(2)),
          estimatedBonusMnt: bonusMnt,
        };
      })
      .sort((a, b) => b.estimatedBonusMnt - a.estimatedBonusMnt)
      .slice(0, 6);

    return {
      totalUsers,
      totalDoctors,
      totalPatients,
      totalAppointments,
      completedAppointments,
      todayAppointments,
      revenueSummary: totalRevenue._sum.price ?? 0,
      applicationsCount,
      activeBranches,
      feedbackCount,
      avgDoctorStars: Number(
        (feedbackCount == 0 ? 0 : starsTotal / feedbackCount).toFixed(2),
      ),
      avgDoctorCarePoints: Number(
        (feedbackCount == 0 ? 0 : careTotal / feedbackCount).toFixed(2),
      ),
      estimatedMonthlyBonusPoolMnt: topDoctorBonuses.reduce(
        (sum, row) => sum + row.estimatedBonusMnt,
        0,
      ),
      topDoctorBonuses,
    };
  }

  async doctorSummary(userId: string) {
    const doctor = await this.prisma.doctorProfile.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!doctor) {
      throw new ForbiddenException('Doctor dashboard is only available to doctors.');
    }

    const now = new Date();
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);

    const [todayAppointments, upcomingAppointments, patientCount, feedbackRows] =
      await this.prisma.$transaction([
        this.prisma.appointment.findMany({
          where: {
            doctorId: doctor.id,
            startsAt: { gte: todayStart, lt: todayEnd },
            status: { in: [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED] },
          },
          include: {
            patient: {
              include: {
                user: true,
              },
            },
            service: true,
            branch: true,
          },
          orderBy: { startsAt: 'asc' },
        }),
        this.prisma.appointment.findMany({
          where: {
            doctorId: doctor.id,
            startsAt: { gte: now },
            status: { in: [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED] },
          },
          include: {
            patient: {
              include: {
                user: true,
              },
            },
            service: true,
            branch: true,
          },
          orderBy: { startsAt: 'asc' },
          take: 10,
        }),
        this.prisma.appointment.findMany({
          where: { doctorId: doctor.id },
          distinct: ['patientId'],
          select: { patientId: true },
        }),
        this.prisma.notification.findMany({
          where: {
            userId,
            type: 'SYSTEM',
            title: 'DOCTOR_FEEDBACK',
          },
          select: { data: true },
        }),
      ]);

    await this.ensureDoctorAppointmentReminders(userId, upcomingAppointments);

    const reminders = await this.prisma.notification.findMany({
      where: {
        userId,
        type: 'SYSTEM',
        title: 'APPOINTMENT_REMINDER',
      },
      orderBy: { createdAt: 'desc' },
      take: 12,
    });

    let feedbackCount = 0;
    let starsTotal = 0;
    let careTotal = 0;
    for (const row of feedbackRows) {
      if (!row.data || typeof row.data !== 'object') continue;
      const data = row.data as Record<string, unknown>;
      if (data['kind'] != 'DOCTOR_FEEDBACK') continue;
      starsTotal += this.asNumber(data['stars']);
      careTotal += this.asNumber(data['carePoints']);
      feedbackCount += 1;
    }
    const avgStars = feedbackCount == 0 ? 0 : starsTotal / feedbackCount;
    const avgCarePoints = feedbackCount == 0 ? 0 : careTotal / feedbackCount;
    const estimatedBonusMnt = Math.round(
      feedbackCount * 15000 + avgStars * 10000 + avgCarePoints * 6000,
    );

    return {
      todayAppointments,
      upcomingAppointments,
      reminders,
      unreadReminderCount: reminders.filter((r) => r.readAt == null).length,
      patientCount: patientCount.length,
      feedbackCount,
      avgStars: Number(avgStars.toFixed(2)),
      avgCarePoints: Number(avgCarePoints.toFixed(2)),
      estimatedBonusMnt,
    };
  }

  private async ensureDoctorAppointmentReminders(
    doctorUserId: string,
    upcomingAppointments: Array<{
      id: string;
      startsAt: Date;
      status: AppointmentStatus;
      patient: { user: { firstName: string | null; lastName: string | null } };
      service: { name: string };
      branch: { name: string };
    }>,
  ) {
    if (upcomingAppointments.length === 0) return;
    const now = Date.now();
    const windows = [60, 15];
    const due = upcomingAppointments
      .map((a) => {
        const diffMin = Math.floor((a.startsAt.getTime() - now) / 60000);
        const window = windows.find((w) => diffMin > 0 && diffMin <= w);
        if (!window) return null;
        return { appointment: a, window };
      })
      .filter((x): x is { appointment: (typeof upcomingAppointments)[number]; window: number } => x != null);
    if (due.length === 0) return;

    const appointmentIds = due.map((d) => d.appointment.id);
    const existing = await this.prisma.notification.findMany({
      where: {
        userId: doctorUserId,
        type: 'SYSTEM',
        title: 'APPOINTMENT_REMINDER',
        appointmentId: { in: appointmentIds },
      },
      select: { appointmentId: true, data: true },
    });
    const seenKeys = new Set<string>();
    for (const item of existing) {
      const data =
        item.data && typeof item.data === 'object'
          ? (item.data as Record<string, unknown>)
          : {};
      const win = Number(data['windowMinutes'] ?? 0);
      if (item.appointmentId && win > 0) {
        seenKeys.add(`${item.appointmentId}:${win}`);
      }
    }

    for (const item of due) {
      const key = `${item.appointment.id}:${item.window}`;
      if (seenKeys.has(key)) continue;
      const patientName =
        `${item.appointment.patient.user.firstName ?? ''} ${item.appointment.patient.user.lastName ?? ''}`.trim() ||
        'Patient';
      const startsLabel = item.appointment.startsAt.toISOString();
      await this.notifications.createForUsers([doctorUserId], {
        type: 'SYSTEM',
        title: 'APPOINTMENT_REMINDER',
        body: `${item.window} минутын дараа ${patientName} - ${item.appointment.service.name} (${item.appointment.branch.name}) үзлэгтэй.`,
        appointmentId: item.appointment.id,
        data: {
          kind: 'APPOINTMENT_REMINDER',
          windowMinutes: item.window,
          startsAt: startsLabel,
          patientName,
          serviceName: item.appointment.service.name,
          branchName: item.appointment.branch.name,
        },
      });
    }
  }

  async patientSummary(userId: string) {
    const patient = await this.prisma.patientProfile.findUnique({
      where: { userId },
      include: {
        user: true,
      },
    });
    if (!patient) {
      throw new ForbiddenException(
        'Patient dashboard is only available to patient users.',
      );
    }

    const now = new Date();

    const [upcomingAppointments, appointmentHistory] = await this.prisma.$transaction([
      this.prisma.appointment.findMany({
        where: {
          patientId: patient.id,
          startsAt: { gte: now },
          status: { in: [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED] },
        },
        include: {
          doctor: {
            include: {
              user: true,
              department: true,
            },
          },
          branch: true,
          service: true,
        },
        orderBy: { startsAt: 'asc' },
        take: 10,
      }),
      this.prisma.appointment.findMany({
        where: {
          patientId: patient.id,
          startsAt: { lt: now },
        },
        include: {
          doctor: {
            include: {
              user: true,
              department: true,
            },
          },
          branch: true,
          service: true,
        },
        orderBy: { startsAt: 'desc' },
        take: 20,
      }),
    ]);

    const completionFields = [
      patient.user.firstName,
      patient.user.lastName,
      patient.user.phone,
      patient.address,
      patient.emergencyContactName,
      patient.emergencyContactPhone,
    ];
    const filledFields = completionFields.filter(Boolean).length;
    const profileCompletion = Math.round(
      (filledFields / completionFields.length) * 100,
    );

    const recentMedicalRecords = await this.prisma.medicalRecord.findMany({
      where: { patientId: patient.id },
      orderBy: { updatedAt: 'desc' },
      take: 8,
      include: {
        doctor: {
          include: {
            user: {
              select: { firstName: true, lastName: true },
            },
          },
        },
        appointment: {
          select: { startsAt: true, status: true },
        },
      },
    });

    return {
      upcomingAppointments,
      appointmentHistory,
      profileCompletion,
      medicalHistorySummary: patient.medicalHistorySummary ?? null,
      recentMedicalRecords,
    };
  }
}
