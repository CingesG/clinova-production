import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AppointmentStatus, Role } from '@prisma/client';

import { PrismaService } from '../common/prisma.service';

type RecordInput = {
  appointmentId: string;
  diagnosis?: string;
  symptoms?: string;
  treatmentPlan?: string;
  prescription?: string;
  note?: string;
};

@Injectable()
export class MedicalRecordService {
  constructor(private readonly prisma: PrismaService) {}

  async upsertRecord(
    requester: { userId: string; role: Role },
    input: RecordInput,
  ) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: input.appointmentId },
      include: {
        doctor: true,
      },
    });

    if (!appointment) {
      throw new NotFoundException('Appointment not found.');
    }

    if (
      requester.role === Role.DOCTOR &&
      appointment.doctor.userId !== requester.userId
    ) {
      throw new ForbiddenException(
        'You can only write records for your own appointments.',
      );
    }

    if (
      appointment.status !== AppointmentStatus.CONFIRMED &&
      appointment.status !== AppointmentStatus.COMPLETED
    ) {
      throw new ForbiddenException(
        'Medical records can only be created for handled appointments.',
      );
    }

    return this.prisma.medicalRecord.upsert({
      where: {
        appointmentId: input.appointmentId,
      },
      create: {
        appointmentId: input.appointmentId,
        patientId: appointment.patientId,
        doctorId: appointment.doctorId,
        diagnosis: input.diagnosis,
        symptoms: input.symptoms,
        treatmentPlan: input.treatmentPlan,
        prescription: input.prescription,
        note: input.note,
      },
      update: {
        diagnosis: input.diagnosis,
        symptoms: input.symptoms,
        treatmentPlan: input.treatmentPlan,
        prescription: input.prescription,
        note: input.note,
      },
    });
  }

  async getByAppointment(
    requester: { userId: string; role: Role },
    appointmentId: string,
  ) {
    const record = await this.prisma.medicalRecord.findUnique({
      where: { appointmentId },
      include: {
        appointment: {
          include: {
            patient: {
              include: { user: true },
            },
            doctor: {
              include: { user: true },
            },
          },
        },
      },
    });

    if (!record) {
      throw new NotFoundException('Medical record not found.');
    }

    if (requester.role === Role.ADMIN) {
      return record;
    }

    if (
      requester.role === Role.DOCTOR &&
      record.appointment.doctor.userId === requester.userId
    ) {
      return record;
    }

    if (
      requester.role === Role.PATIENT &&
      record.appointment.patient.userId === requester.userId
    ) {
      return record;
    }

    throw new ForbiddenException('You do not have access to this medical record.');
  }
}
