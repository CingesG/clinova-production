/**
 * Idempotent Clinova demo seed (branches, departments, services, doctors, schedules, demo patients, sample appointments).
 * - Never deletes users or resets the database.
 * - Preserves existing admin at chinges_chinges@icloud.com (creates only if missing; never changes password if present).
 * Safe to run multiple times (upsert + targeted demo appointment refresh).
 *
 * Demo email lists for `export-demo-credentials`: see `prisma/seed-lists.ts` (keep in sync when changing seed emails).
 */
import 'dotenv/config';

import * as fs from 'fs/promises';
import * as path from 'path';
import { randomBytes } from 'crypto';

import {
  AppointmentStatus,
  AuthProvider,
  BranchStatus,
  DepartmentStatus,
  PrismaClient,
  Role,
  ServiceStatus,
  UserStatus,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const PRESERVE_ADMIN_EMAIL = 'chinges_chinges@icloud.com';

const DEMO_APPOINTMENT_REASONS = [
  'Clinova demo #1 — Дотор дагнах үзлэг',
  'Clinova demo #2 — Хүүхдийн урьдчилан сэргийлэх үзлэг',
  'Clinova demo #3 — Эмэгтэйчүүдийн хяналт',
  'Clinova demo #4 — ЧХХ шалтгаантай үзлэг',
  'Clinova demo #5 — Маргаашийн ерөнхий цаг',
] as const;

function requireEnvDatabaseUrl() {
  if (!process.env.DATABASE_URL?.trim()) {
    throw new Error('DATABASE_URL is required for prisma seed.');
  }
}

function normalizeMnPhone(raw: string): string {
  const digits = raw.replace(/\D/g, '');
  if (digits.startsWith('976') && digits.length >= 11) {
    return `+${digits}`;
  }
  if (digits.length === 8) {
    return `+976${digits}`;
  }
  if (digits.length > 0) {
    return digits.startsWith('976') ? `+${digits}` : `+976${digits}`;
  }
  return raw.trim();
}

function avatarFor(userKey: string): string {
  const enc = encodeURIComponent(userKey);
  return `https://api.dicebear.com/7.x/identicon/svg?seed=${enc}`;
}

/** Bundled Flutter asset path (resolved client-side); not an HTTP URL. */
function demoDoctorBundledAvatar(filename: string): string {
  return `flutter-asset:assets/images/doctors/${filename}`;
}

function secureRandomPassword(): string {
  return randomBytes(18).toString('base64url');
}

type BranchSeed = {
  code: string;
  name: string;
  address: string;
  contactPhone: string;
  contactEmail: string;
  openingHours: string;
  latitude: number;
  longitude: number;
};

const BRANCH_SEEDS: BranchSeed[] = [
  {
    code: 'CLIN_TUV',
    name: 'Clinova Төв салбар',
    address: 'Улаанбаатар, Сүхбаатар дүүрэг, 1-р хороо',
    contactPhone: '+97677001122',
    contactEmail: 'tuv@clinova.demo',
    openingHours: 'Даваа–Баасан 08:00–20:00, Бямба 09:00–14:00',
    latitude: 47.9184,
    longitude: 106.9177,
  },
  {
    code: 'CLIN_HUHD',
    name: 'Clinova Хүүхдийн салбар',
    address: 'Улаанбаатар, Баянзүрх дүүрэг',
    contactPhone: '+97677002233',
    contactEmail: 'huuhdiin@clinova.demo',
    openingHours: 'Даваа–Бямба 09:00–19:00',
    latitude: 47.9231,
    longitude: 106.9378,
  },
  {
    code: 'CLIN_EMEG',
    name: 'Clinova Эмэгтэйчүүдийн салбар',
    address: 'Улаанбаатар, Хан-Уул дүүрэг',
    contactPhone: '+97677003344',
    contactEmail: 'emegtei@clinova.demo',
    openingHours: 'Даваа–Баасан 08:30–18:30',
    latitude: 47.8942,
    longitude: 106.9159,
  },
  {
    code: 'CLIN_GEM',
    name: 'Clinova Гэмтэл, сэргээн засах салбар',
    address: 'Улаанбаатар, Баянгол дүүрэг',
    contactPhone: '+97677004455',
    contactEmail: 'gemtel@clinova.demo',
    openingHours: 'Даваа–Бямба 08:00–18:00',
    latitude: 47.905,
    longitude: 106.9,
  },
  {
    code: 'CLIN_CHK',
    name: 'Clinova Чих хамар хоолойн салбар',
    address: 'Улаанбаатар, Сонгинохайрхан дүүрэг',
    contactPhone: '+97677005566',
    contactEmail: 'chkh@clinova.demo',
    openingHours: 'Даваа–Бямба 09:00–18:00',
    latitude: 47.8865,
    longitude: 106.7052,
  },
];

const DEPARTMENT_SEEDS: Array<{ name: string; description: string }> = [
  { name: 'Дотор', description: 'Дотоодын өвчин, ерөнхий оношилгоо' },
  { name: 'Хүүхэд', description: 'Хүүхдийн эмчилгээ, урьдчилан сэргийлэлт' },
  { name: 'Эмэгтэйчүүд', description: 'Эмэгтэйчүүдийн эрүүл мэнд, жирэмсэн хяналт' },
  { name: 'Гэмтэл согог', description: 'Гэмтэл, сэргээн засал, сураг алдалт' },
  { name: 'Чих хамар хоолой', description: 'ЧХХ өвчин, сонсголын шинжилгээ' },
  { name: 'Шүд', description: 'Шүдний эмчилгээ, ариутгал' },
  { name: 'Зүрх судас', description: 'Зүрх судасны оношилгоо, ЭКГ' },
  { name: 'Мэдрэл', description: 'Нейрологи, толгой өвдөлт' },
  { name: 'Арьс харшил', description: 'Арьсны өвчин, харшил' },
  { name: 'Нүд', description: 'Нүдний үзлэг, харааны шинжилгээ' },
];

/** Service title per branch; department links by name. */
const SERVICE_SEEDS: Array<{
  name: string;
  departmentName: string;
  price: number;
  durationMinutes: number;
  description: string;
}> = [
  {
    name: 'Ерөнхий үзлэг',
    departmentName: 'Дотор',
    price: 30_000,
    durationMinutes: 30,
    description: 'Ерөнхий эмчийн үзлэг, зөвлөгөө',
  },
  {
    name: 'Хүүхдийн үзлэг',
    departmentName: 'Хүүхэд',
    price: 35_000,
    durationMinutes: 30,
    description: 'Хүүхдийн эрүүл мэндийн үзлэг',
  },
  {
    name: 'Эмэгтэйчүүдийн үзлэг',
    departmentName: 'Эмэгтэйчүүд',
    price: 45_000,
    durationMinutes: 40,
    description: 'Эмэгтэйчүүдийн үзлэг, хяналт',
  },
  {
    name: 'Гэмтлийн зөвлөгөө',
    departmentName: 'Гэмтэл согог',
    price: 40_000,
    durationMinutes: 30,
    description: 'Гэмтэл, согогийн зөвлөгөө',
  },
  {
    name: 'ЧХХ үзлэг',
    departmentName: 'Чих хамар хоолой',
    price: 35_000,
    durationMinutes: 30,
    description: 'Чих хамар хоолойн мэргэжилтэнтэй үзлэг',
  },
  {
    name: 'Шүдний үзлэг',
    departmentName: 'Шүд',
    price: 25_000,
    durationMinutes: 30,
    description: 'Шүдний ерөнхий үзлэг',
  },
  {
    name: 'Зүрхний ЭКГ зөвлөгөө',
    departmentName: 'Зүрх судас',
    price: 50_000,
    durationMinutes: 45,
    description: 'Зүрх судасны оношилгоо, ЭКГ',
  },
  {
    name: 'Мэдрэлийн зөвлөгөө',
    departmentName: 'Мэдрэл',
    price: 45_000,
    durationMinutes: 40,
    description: 'Мэдрэлийн эмчийн зөвлөгөө',
  },
  {
    name: 'Арьс харшлын үзлэг',
    departmentName: 'Арьс харшил',
    price: 35_000,
    durationMinutes: 30,
    description: 'Арьс харшлын оношилгоо',
  },
  {
    name: 'Нүдний үзлэг',
    departmentName: 'Нүд',
    price: 40_000,
    durationMinutes: 30,
    description: 'Нүдний эмчийн үзлэг',
  },
];

type DoctorSeed = {
  email: string;
  firstName: string;
  lastName: string;
  phone: string;
  branchCode: string;
  departmentName: string;
  primaryServiceName: string;
  bio: string;
  experienceYears: number;
  consultationFee: number;
  /** PNG under `diplom-app/assets/images/doctors/` (bundled in the app). */
  portraitFile: string;
};

const DOCTOR_SEEDS: DoctorSeed[] = [
  {
    email: 'doctor.enkhbayar@clinova.local',
    firstName: 'Энхбаяр',
    lastName: 'Бат',
    phone: '99112233',
    branchCode: 'CLIN_TUV',
    departmentName: 'Дотор',
    primaryServiceName: 'Ерөнхий үзлэг',
    bio: 'Дотрын тасгийн мэргэшсэн эмч. Хоол боловсруулах эрхтэн, ерөнхий дотоодын оношилгоонд төвлөрнө.',
    experienceYears: 12,
    consultationFee: 30_000,
    portraitFile: 'doctor-01.jpg',
  },
  {
    email: 'doctor.solongo@clinova.local',
    firstName: 'Солонго',
    lastName: 'Наран',
    phone: '88071574',
    branchCode: 'CLIN_HUHD',
    departmentName: 'Хүүхэд',
    primaryServiceName: 'Хүүхдийн үзлэг',
    bio: 'Хүүхдийн эмч — урьдчилан сэргийлэлт, халуурах, хоол тэжээлийн зөвлөгөө.',
    experienceYears: 8,
    consultationFee: 35_000,
    portraitFile: 'doctor-02.jpg',
  },
  {
    email: 'doctor.ariunzaya@clinova.local',
    firstName: 'Ариунзаяа',
    lastName: 'Дөлгөөн',
    phone: '99001122',
    branchCode: 'CLIN_EMEG',
    departmentName: 'Эмэгтэйчүүд',
    primaryServiceName: 'Эмэгтэйчүүдийн үзлэг',
    bio: 'Эмэгтэйчүүдийн эрүүл мэнд, жирэмсэн хяналт, эрт илрүүлэлт.',
    experienceYears: 10,
    consultationFee: 45_000,
    portraitFile: 'doctor-03.jpg',
  },
  {
    email: 'doctor.temuulen@clinova.local',
    firstName: 'Тэмүүлэн',
    lastName: 'Ган',
    phone: '88112233',
    branchCode: 'CLIN_GEM',
    departmentName: 'Гэмтэл согог',
    primaryServiceName: 'Гэмтлийн зөвлөгөө',
    bio: 'Гэмтэл, сэргээн заслын чиглэлээр зөвлөгөө өгнө.',
    experienceYears: 9,
    consultationFee: 40_000,
    portraitFile: 'doctor-04.jpg',
  },
  {
    email: 'doctor.munkherdene@clinova.local',
    firstName: 'Мөнх-Эрдэнэ',
    lastName: 'Сүх',
    phone: '99118877',
    branchCode: 'CLIN_CHK',
    departmentName: 'Чих хамар хоолой',
    primaryServiceName: 'ЧХХ үзлэг',
    bio: 'Чих хамар хоолойын мэргэжилтэн — сонсгол, ярьсангүйрлийн үзлэг.',
    experienceYears: 7,
    consultationFee: 35_000,
    portraitFile: 'doctor-05.jpg',
  },
  {
    email: 'doctor.oyunchimeg@clinova.local',
    firstName: 'Оюунчимэг',
    lastName: 'Цэцэг',
    phone: '88990011',
    branchCode: 'CLIN_TUV',
    departmentName: 'Шүд',
    primaryServiceName: 'Шүдний үзлэг',
    bio: 'Шүдний эмч — ариутгал, ерөнхий оношилгоо, анхны эмчилгээний төлөвлөгөө.',
    experienceYears: 11,
    consultationFee: 25_000,
    portraitFile: 'doctor-06.jpg',
  },
  {
    email: 'doctor.batorgil@clinova.local',
    firstName: 'Бат-Оргил',
    lastName: 'Энх',
    phone: '99007766',
    branchCode: 'CLIN_TUV',
    departmentName: 'Зүрх судас',
    primaryServiceName: 'Зүрхний ЭКГ зөвлөгөө',
    bio: 'Зүрх судасны эмч — даралт, зүрхний иог дагаж хяналт.',
    experienceYears: 14,
    consultationFee: 50_000,
    portraitFile: 'doctor-07.jpg',
  },
  {
    email: 'doctor.nomin@clinova.local',
    firstName: 'Номин',
    lastName: 'Дарь',
    phone: '88665544',
    branchCode: 'CLIN_HUHD',
    departmentName: 'Мэдрэл',
    primaryServiceName: 'Мэдрэлийн зөвлөгөө',
    bio: 'Мэдрэлийн эмч — толгой өвдөлт, нойр, стрессийн зөвлөгөө.',
    experienceYears: 6,
    consultationFee: 45_000,
    portraitFile: 'doctor-08.jpg',
  },
  {
    email: 'doctor.enkhjin@clinova.local',
    firstName: 'Энхжин',
    lastName: 'Саруул',
    phone: '99114455',
    branchCode: 'CLIN_EMEG',
    departmentName: 'Арьс харшил',
    primaryServiceName: 'Арьс харшлын үзлэг',
    bio: 'Арьс харшлын эмч — тууралт, харшил, арьсны үзлэг.',
    experienceYears: 5,
    consultationFee: 35_000,
    portraitFile: 'doctor-01.jpg',
  },
  {
    email: 'doctor.huslen@clinova.local',
    firstName: 'Хүслэн',
    lastName: 'Түвшин',
    phone: '88009988',
    branchCode: 'CLIN_CHK',
    departmentName: 'Нүд',
    primaryServiceName: 'Нүдний үзлэг',
    bio: 'Нүдний эмч — ойр, холын харааны үзлэг, зөвлөгөө.',
    experienceYears: 9,
    consultationFee: 40_000,
    portraitFile: 'doctor-02.jpg',
  },
];

type PatientSeed = {
  email: string;
  firstName: string;
  lastName: string;
  phone: string;
  address: string;
};

const PATIENT_SEEDS: PatientSeed[] = [
  {
    email: 'demo.patient1@clinova.local',
    firstName: 'Анужин',
    lastName: 'Бат-Эрдэнэ',
    phone: '86081466',
    address: 'Улаанбаатар, Хан-Уул, 15-р хороо',
  },
  {
    email: 'demo.patient2@clinova.local',
    firstName: 'Мөнх',
    lastName: 'Наранцэцэг',
    phone: '88119900',
    address: 'Улаанбаатар, Баянзүрх, 26-р хороо',
  },
  {
    email: 'demo.patient3@clinova.local',
    firstName: 'Энх',
    lastName: 'Төгөлдөр',
    phone: '99008877',
    address: 'Улаанбаатар, Сүхбаатар, 8-р хороо',
  },
];

async function ensureAdminAccount() {
  const existing = await prisma.user.findUnique({
    where: { email: PRESERVE_ADMIN_EMAIL },
  });
  if (existing) {
    if (existing.role !== Role.ADMIN) {
      await prisma.user.update({
        where: { id: existing.id },
        data: { role: Role.ADMIN, status: UserStatus.ACTIVE },
      });
    }
    console.log(`Admin preserved: ${PRESERVE_ADMIN_EMAIL}`);
    return;
  }

  const pwd = process.env.DEFAULT_ADMIN_PASSWORD?.trim();
  if (!pwd || pwd.length < 12) {
    throw new Error(
      'DEFAULT_ADMIN_PASSWORD must be set (min 12 chars) to create the initial admin — user not found.',
    );
  }

  const passwordHash = await bcrypt.hash(pwd, 10);
  await prisma.user.create({
    data: {
      email: PRESERVE_ADMIN_EMAIL,
      passwordHash,
      role: Role.ADMIN,
      status: UserStatus.ACTIVE,
      authProvider: AuthProvider.EMAIL,
      emailVerified: true,
      firstName: 'Admin',
      lastName: 'Clinova',
    },
  });
  console.log(`Admin created: ${PRESERVE_ADMIN_EMAIL}`);
}

async function syncDoctorWeekSchedules(doctorId: string) {
  for (const dayOfWeek of [1, 2, 3, 4, 5]) {
    await prisma.doctorWeeklySchedule.deleteMany({
      where: { doctorId, dayOfWeek },
    });
    await prisma.doctorWeeklySchedule.createMany({
      data: [
        {
          doctorId,
          dayOfWeek,
          startTime: '09:00',
          endTime: '12:00',
          slotMinutes: 30,
          isActive: true,
        },
        {
          doctorId,
          dayOfWeek,
          startTime: '13:00',
          endTime: '17:00',
          slotMinutes: 30,
          isActive: true,
        },
      ],
    });
  }
}

/** Next Mon–Fri datetime at hour/minute after dayOffset days (skip weekends). */
function nextWeekdayAt(hour: number, minute: number, dayOffset: number): Date {
  const d = new Date();
  d.setDate(d.getDate() + dayOffset);
  while (d.getDay() === 0 || d.getDay() === 6) {
    d.setDate(d.getDate() + 1);
  }
  d.setHours(hour, minute, 0, 0);
  if (d.getTime() <= Date.now() + 60_000) {
    d.setDate(d.getDate() + 7);
    while (d.getDay() === 0 || d.getDay() === 6) {
      d.setDate(d.getDate() + 1);
    }
  }
  return d;
}

async function refreshDemoAppointments(
  patients: Array<{ userId: string; patientProfileId: string }>,
  doctorsOrdered: Array<{
    doctorId: string;
    departmentId: string;
    branchId: string;
    primaryServiceId: string;
  }>,
) {
  await prisma.appointment.deleteMany({
    where: { reason: { in: [...DEMO_APPOINTMENT_REASONS] } },
  });

  const specs: Array<{
    patientIndex: number;
    doctorIndex: number;
    status: AppointmentStatus;
    hour: number;
    minute: number;
    dayOffset: number;
    reason: string;
  }> = [
    {
      patientIndex: 0,
      doctorIndex: 0,
      status: AppointmentStatus.CONFIRMED,
      hour: 10,
      minute: 0,
      dayOffset: 1,
      reason: DEMO_APPOINTMENT_REASONS[0],
    },
    {
      patientIndex: 1,
      doctorIndex: 1,
      status: AppointmentStatus.COMPLETED,
      hour: 11,
      minute: 0,
      dayOffset: 2,
      reason: DEMO_APPOINTMENT_REASONS[1],
    },
    {
      patientIndex: 2,
      doctorIndex: 2,
      status: AppointmentStatus.PENDING,
      hour: 14,
      minute: 0,
      dayOffset: 2,
      reason: DEMO_APPOINTMENT_REASONS[2],
    },
    {
      patientIndex: 0,
      doctorIndex: 4,
      status: AppointmentStatus.CONFIRMED,
      hour: 10,
      minute: 30,
      dayOffset: 3,
      reason: DEMO_APPOINTMENT_REASONS[3],
    },
    {
      patientIndex: 1,
      doctorIndex: 6,
      status: AppointmentStatus.CONFIRMED,
      hour: 15,
      minute: 0,
      dayOffset: 4,
      reason: DEMO_APPOINTMENT_REASONS[4],
    },
  ];

  for (const spec of specs) {
    const patient = patients[spec.patientIndex];
    const doc = doctorsOrdered[spec.doctorIndex];
    if (!patient || !doc) continue;

    let startsAt = nextWeekdayAt(spec.hour, spec.minute, spec.dayOffset);
    const svc = await prisma.service.findUnique({
      where: { id: doc.primaryServiceId },
    });
    const duration = svc?.durationMinutes ?? 30;
    let endsAt = new Date(startsAt.getTime() + duration * 60_000);

    for (let attempt = 0; attempt < 12; attempt++) {
      const clash = await prisma.appointment.findFirst({
        where: {
          doctorId: doc.doctorId,
          startsAt,
          status: { not: AppointmentStatus.CANCELLED },
        },
      });
      if (!clash) break;
      startsAt = new Date(startsAt.getTime() + 30 * 60_000);
      endsAt = new Date(startsAt.getTime() + duration * 60_000);
    }

    await prisma.appointment.create({
      data: {
        patientId: patient.patientProfileId,
        doctorId: doc.doctorId,
        branchId: doc.branchId,
        departmentId: doc.departmentId,
        serviceId: doc.primaryServiceId,
        createdByUserId: patient.userId,
        startsAt,
        endsAt,
        status: spec.status,
        reason: spec.reason,
      },
    });
  }
}

async function main() {
  requireEnvDatabaseUrl();

  const sharedDoctorPassword = process.env.DEMO_DOCTOR_PASSWORD?.trim();
  const patientPassword =
    process.env.DEMO_PATIENT_PASSWORD ?? 'ClinovaPatient123!';
  const patientPasswordHash = await bcrypt.hash(patientPassword, 10);

  await ensureAdminAccount();

  const branchMap = new Map<string, { id: string; code: string; name: string }>();
  for (const b of BRANCH_SEEDS) {
    const row = await prisma.branch.upsert({
      where: { code: b.code },
      create: {
        code: b.code,
        name: b.name,
        address: b.address,
        city: 'Улаанбаатар',
        contactPhone: b.contactPhone,
        contactEmail: b.contactEmail,
        openingHours: b.openingHours,
        status: BranchStatus.ACTIVE,
        latitude: b.latitude,
        longitude: b.longitude,
      },
      update: {
        name: b.name,
        address: b.address,
        city: 'Улаанбаатар',
        contactPhone: b.contactPhone,
        contactEmail: b.contactEmail,
        openingHours: b.openingHours,
        status: BranchStatus.ACTIVE,
        latitude: b.latitude,
        longitude: b.longitude,
      },
    });
    branchMap.set(b.code, { id: row.id, code: row.code, name: row.name });
  }

  const departmentMap = new Map<string, { id: string; name: string }>();
  for (const d of DEPARTMENT_SEEDS) {
    const row = await prisma.department.upsert({
      where: { name: d.name },
      create: {
        name: d.name,
        description: d.description,
        status: DepartmentStatus.ACTIVE,
      },
      update: {
        description: d.description,
        status: DepartmentStatus.ACTIVE,
      },
    });
    departmentMap.set(d.name, row);
  }

  const serviceKey = (branchId: string, serviceName: string) =>
    `${branchId}::${serviceName}`;
  const servicesByKey = new Map<
    string,
    { id: string; branchId: string; departmentId: string; durationMinutes: number }
  >();

  for (const branch of branchMap.values()) {
    for (const s of SERVICE_SEEDS) {
      const dept = departmentMap.get(s.departmentName);
      if (!dept) throw new Error(`Missing department: ${s.departmentName}`);

      const row = await prisma.service.upsert({
        where: {
          branchId_name: { branchId: branch.id, name: s.name },
        },
        create: {
          name: s.name,
          description: s.description,
          branchId: branch.id,
          departmentId: dept.id,
          price: s.price,
          durationMinutes: s.durationMinutes,
          status: ServiceStatus.ACTIVE,
        },
        update: {
          description: s.description,
          departmentId: dept.id,
          price: s.price,
          durationMinutes: s.durationMinutes,
          status: ServiceStatus.ACTIVE,
        },
      });
      servicesByKey.set(serviceKey(branch.id, s.name), {
        id: row.id,
        branchId: branch.id,
        departmentId: dept.id,
        durationMinutes: row.durationMinutes,
      });
    }
  }

  const doctorResults: Array<{
    userId: string;
    doctorId: string;
    branchId: string;
    departmentId: string;
    primaryServiceId: string;
    email: string;
  }> = [];

  const doctorCredentialRows: Array<{
    email: string;
    username: string;
    loginId: string;
    password?: string;
    passwordNote?: string;
  }> = [];

  for (const doc of DOCTOR_SEEDS) {
    const branch = branchMap.get(doc.branchCode);
    if (!branch) throw new Error(`Unknown branch: ${doc.branchCode}`);
    const dept = departmentMap.get(doc.departmentName);
    if (!dept) throw new Error(`Unknown department: ${doc.departmentName}`);
    const svc = servicesByKey.get(serviceKey(branch.id, doc.primaryServiceName));
    if (!svc) throw new Error(`Missing service ${doc.primaryServiceName} for branch`);

    const email = doc.email.trim().toLowerCase();
    const phoneNumber = normalizeMnPhone(doc.phone);

    const existingUser = await prisma.user.findUnique({
      where: { email },
      select: { id: true, passwordHash: true },
    });

    let newPasswordHash: string | undefined;
    let plainForCred: string | undefined;
    let credNote: string | undefined;

    if (sharedDoctorPassword) {
      newPasswordHash = await bcrypt.hash(sharedDoctorPassword, 10);
      plainForCred = sharedDoctorPassword;
    } else if (!existingUser || !existingUser.passwordHash) {
      plainForCred = secureRandomPassword();
      newPasswordHash = await bcrypt.hash(plainForCred, 10);
    } else {
      credNote =
        'Password not changed this run. Set DEMO_DOCTOR_PASSWORD to rotate all seeded doctor passwords, or delete the user and re-seed.';
    }

    const user = await prisma.user.upsert({
      where: { email },
      create: {
        email,
        passwordHash: newPasswordHash!,
        role: Role.DOCTOR,
        status: UserStatus.ACTIVE,
        authProvider: AuthProvider.EMAIL,
        emailVerified: true,
        firstName: doc.firstName,
        lastName: doc.lastName,
        phoneNumber,
        branchId: branch.id,
        avatarUrl: demoDoctorBundledAvatar(doc.portraitFile),
      },
      update: {
        firstName: doc.firstName,
        lastName: doc.lastName,
        phoneNumber,
        branchId: branch.id,
        role: Role.DOCTOR,
        status: UserStatus.ACTIVE,
        emailVerified: true,
        avatarUrl: demoDoctorBundledAvatar(doc.portraitFile),
        ...(newPasswordHash ? { passwordHash: newPasswordHash } : {}),
      },
    });

    doctorCredentialRows.push({
      email,
      username: email.split('@')[0] ?? email,
      loginId: email,
      ...(plainForCred ? { password: plainForCred } : {}),
      ...(credNote ? { passwordNote: credNote } : {}),
    });

    const profile = await prisma.doctorProfile.upsert({
      where: { userId: user.id },
      create: {
        userId: user.id,
        branchId: branch.id,
        departmentId: dept.id,
        bio: doc.bio,
        experienceYears: doc.experienceYears,
        consultationFee: doc.consultationFee,
        avatarUrl: demoDoctorBundledAvatar(doc.portraitFile),
        active: true,
      },
      update: {
        branchId: branch.id,
        departmentId: dept.id,
        bio: doc.bio,
        experienceYears: doc.experienceYears,
        consultationFee: doc.consultationFee,
        avatarUrl: demoDoctorBundledAvatar(doc.portraitFile),
        active: true,
      },
    });

    await prisma.doctorService.upsert({
      where: {
        doctorId_serviceId: {
          doctorId: profile.id,
          serviceId: svc.id,
        },
      },
      create: {
        doctorId: profile.id,
        serviceId: svc.id,
      },
      update: {},
    });

    await syncDoctorWeekSchedules(profile.id);

    doctorResults.push({
      userId: user.id,
      doctorId: profile.id,
      branchId: branch.id,
      departmentId: dept.id,
      primaryServiceId: svc.id,
      email,
    });
  }

  const patientResults: Array<{ userId: string; patientProfileId: string }> = [];

  for (const p of PATIENT_SEEDS) {
    const email = p.email.trim().toLowerCase();
    const phoneNumber = normalizeMnPhone(p.phone);

    const user = await prisma.user.upsert({
      where: { email },
      create: {
        email,
        passwordHash: patientPasswordHash,
        role: Role.PATIENT,
        status: UserStatus.ACTIVE,
        authProvider: AuthProvider.EMAIL,
        emailVerified: true,
        firstName: p.firstName,
        lastName: p.lastName,
        phoneNumber,
      },
      update: {
        firstName: p.firstName,
        lastName: p.lastName,
        phoneNumber,
        role: Role.PATIENT,
        status: UserStatus.ACTIVE,
        emailVerified: true,
        passwordHash: patientPasswordHash,
      },
    });

    const profile = await prisma.patientProfile.upsert({
      where: { userId: user.id },
      create: {
        userId: user.id,
        address: p.address,
        emergencyContactName: 'Ойрын хүн',
        emergencyContactPhone: phoneNumber,
      },
      update: {
        address: p.address,
        emergencyContactPhone: phoneNumber,
      },
    });

    patientResults.push({ userId: user.id, patientProfileId: profile.id });
  }

  const demoMessageRoom =
    patientResults[0] && doctorResults[0]
      ? `room-${[patientResults[0].userId, doctorResults[0].userId].sort().join('-')}`
      : null;

  if (demoMessageRoom && patientResults[0] && doctorResults[0]) {
    const text = 'Сайн байна уу эмч ээ, ойролцоох цагуудаас зөвлөгөө авах боломжтой юу?';
    const exists = await prisma.message.findFirst({
      where: {
        roomId: demoMessageRoom,
        senderId: patientResults[0].userId,
        text,
      },
    });
    if (!exists) {
      await prisma.message.create({
        data: {
          roomId: demoMessageRoom,
          senderId: patientResults[0].userId,
          receiverId: doctorResults[0].userId,
          text,
        },
      });
    }
  }

  const doctorsOrdered = doctorResults.map((r) => ({
    doctorId: r.doctorId,
    departmentId: r.departmentId,
    branchId: r.branchId,
    primaryServiceId: r.primaryServiceId,
  }));

  await refreshDemoAppointments(patientResults, doctorsOrdered);

  const seedOutDir = path.join(__dirname, '..', 'seed-output');
  await fs.mkdir(seedOutDir, { recursive: true });
  await fs.writeFile(
    path.join(seedOutDir, 'doctor-credentials.local.json'),
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        doctors: doctorCredentialRows,
      },
      null,
      2,
    ),
    'utf-8',
  );

  console.log('--- Clinova demo seed (idempotent) complete ---');
  console.log(`Branches: ${branchMap.size}, Departments: ${departmentMap.size}`);
  console.log(
    `Services: ${SERVICE_SEEDS.length * branchMap.size} (${SERVICE_SEEDS.length} types × ${branchMap.size} branches)`,
  );
  console.log(`Doctors: ${doctorResults.length}, Demo patients: ${patientResults.length}`);
  console.log(`Admin: ${PRESERVE_ADMIN_EMAIL} (password unchanged if already existed)`);
  console.log(
    'Doctor credentials written to seed-output/doctor-credentials.local.json',
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
