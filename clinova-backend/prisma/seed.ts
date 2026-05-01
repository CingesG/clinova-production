import 'dotenv/config';

import {
  AppointmentStatus,
  JobApplicationStatus,
  PrismaClient,
  Role,
  UserStatus,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  await prisma.notification.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.medicalRecord.deleteMany();
  await prisma.appointment.deleteMany();
  await prisma.doctorBreak.deleteMany();
  await prisma.doctorTimeOff.deleteMany();
  await prisma.doctorWeeklySchedule.deleteMany();
  await prisma.doctorService.deleteMany();
  await prisma.message.deleteMany();
  await prisma.jobApplication.deleteMany();
  await prisma.otpCode.deleteMany();
  await prisma.doctorProfile.deleteMany();
  await prisma.patientProfile.deleteMany();
  await prisma.service.deleteMany();
  await prisma.department.deleteMany();
  await prisma.branch.deleteMany();
  await prisma.user.deleteMany();

  const branchSeeds = [
    {
      name: 'Clinova Central',
      code: 'CENTRAL',
      address: 'Sukhbaatar District, 1st Khoroo, Peace Ave 15',
      city: 'Ulaanbaatar',
      contactPhone: '+97670110000',
      contactEmail: 'central@clinova.mn',
      openingHours: 'Mon–Sat 08:00–20:00',
      latitude: 47.9184,
      longitude: 106.9177,
    },
    {
      name: 'Clinova Riverfront',
      code: 'RIVER',
      address: 'Khan-Uul District, River Garden Complex B',
      city: 'Ulaanbaatar',
      contactPhone: '+97670110001',
      contactEmail: 'river@clinova.mn',
      openingHours: 'Mon–Sun 09:00–21:00',
      latitude: 47.8942,
      longitude: 106.9159,
    },
    {
      name: 'Clinova Bayanzurkh',
      code: 'BAYANZURKH',
      address: 'Bayanzurkh District, 18-r khoroo, Ikh Nayramdal St 42',
      city: 'Ulaanbaatar',
      contactPhone: '+97670110002',
      contactEmail: 'bayanzurkh@clinova.mn',
      openingHours: 'Mon–Sat 08:00–19:30',
      latitude: 47.9231,
      longitude: 106.9378,
    },
    {
      name: 'Clinova Songinokhairkhan',
      code: 'SONGINO',
      address: 'Songinokhairkhan District, 32-r khoroo, Health Center 7',
      city: 'Ulaanbaatar',
      contactPhone: '+97670110003',
      contactEmail: 'songino@clinova.mn',
      openingHours: 'Mon–Sat 09:00–20:00',
      latitude: 47.8865,
      longitude: 106.7052,
    },
    {
      name: 'Clinova Darkhan',
      code: 'DARKHAN',
      address: 'Darkhan-Uul, 1-r microdistrict, Medical row 3',
      city: 'Darkhan',
      contactPhone: '+97670110004',
      contactEmail: 'darkhan@clinova.mn',
      openingHours: 'Mon–Fri 08:30–18:00',
      latitude: 49.4867,
      longitude: 105.9228,
    },
  ];

  const branches: Awaited<ReturnType<typeof prisma.branch.create>>[] = [];
  for (const b of branchSeeds) {
    branches.push(await prisma.branch.create({ data: b }));
  }

  const branchByCode = new Map(branches.map((b) => [b.code, b]));

  const departmentNames = [
    'Pediatrics',
    'Gynecology',
    'Trauma',
    'ENT',
    'Dentistry',
    'Internal Medicine',
    'Surgery',
    'Cardiology',
    'Dermatology',
    'Neurology',
  ];

  const departments = new Map<string, { id: string; name: string }>();
  for (const name of departmentNames) {
    const department = await prisma.department.create({
      data: {
        name,
        description: `${name} services at Clinova`,
      },
    });
    departments.set(name, department);
  }

  /** One service type per branch (slug used in map key: `${slug}_${branchCode}`) */
  const serviceTypeDefs = [
    {
      slug: 'ent',
      name: 'ENT Consultation',
      departmentName: 'ENT' as const,
      price: 60_000,
      durationMinutes: 30,
    },
    {
      slug: 'ped',
      name: 'Pediatric Checkup',
      departmentName: 'Pediatrics' as const,
      price: 70_000,
      durationMinutes: 30,
    },
    {
      slug: 'derm',
      name: 'Dermatology Consultation',
      departmentName: 'Dermatology' as const,
      price: 80_000,
      durationMinutes: 30,
    },
    {
      slug: 'card',
      name: 'Cardiology Follow-up',
      departmentName: 'Cardiology' as const,
      price: 95_000,
      durationMinutes: 45,
    },
    {
      slug: 'gyn',
      name: 'Gynecology Consultation',
      departmentName: 'Gynecology' as const,
      price: 75_000,
      durationMinutes: 40,
    },
    {
      slug: 'neuro',
      name: 'Neurology Consultation',
      departmentName: 'Neurology' as const,
      price: 88_000,
      durationMinutes: 40,
    },
    {
      slug: 'dent',
      name: 'Dental Consultation',
      departmentName: 'Dentistry' as const,
      price: 55_000,
      durationMinutes: 30,
    },
  ];

  const services = new Map<string, { id: string; branchId: string; departmentId: string }>();

  for (const branch of branches) {
    for (const st of serviceTypeDefs) {
      const key = `${st.slug}_${branch.code}`;
      const service = await prisma.service.create({
        data: {
          name: `${st.name} · ${branch.name}`,
          description: `${st.name} at ${branch.name}`,
          branchId: branch.id,
          departmentId: departments.get(st.departmentName)!.id,
          price: st.price,
          durationMinutes: st.durationMinutes,
        },
      });
      services.set(key, service);
    }
  }

  const adminEmail =
    process.env.DEFAULT_ADMIN_EMAIL ?? 'chinges_chinges@icloud.com';
  const adminPassword =
    process.env.DEFAULT_ADMIN_PASSWORD ?? 'ClinovaAdmin123!';
  const adminPasswordHash = await bcrypt.hash(adminPassword, 10);

  await prisma.user.create({
    data: {
      email: adminEmail,
      passwordHash: adminPasswordHash,
      role: Role.ADMIN,
      status: UserStatus.ACTIVE,
      firstName: 'Chinges',
      lastName: 'Admin',
    },
  });

  await prisma.user.create({
    data: {
      email: 'reception@clinova.mn',
      passwordHash: await bcrypt.hash('ClinovaStaff123!', 10),
      role: Role.STAFF,
      status: UserStatus.ACTIVE,
      firstName: 'Bolor',
      lastName: 'Reception',
      branchId: branches[0]!.id,
      jobTitle: 'Receptionist',
    },
  });

  const patientUser = await prisma.user.create({
    data: {
      email: 'patient@clinova.mn',
      passwordHash: await bcrypt.hash('ClinovaPatient123!', 10),
      role: Role.PATIENT,
      status: UserStatus.ACTIVE,
      firstName: 'Anu',
      lastName: 'Patient',
      phone: '+97699112233',
      patientProfile: {
        create: {
          address: 'Zaisan, Ulaanbaatar',
          emergencyContactName: 'Gerel',
          emergencyContactPhone: '+97688112233',
        },
      },
    },
    include: {
      patientProfile: true,
    },
  });

  /**
   * Every branch gets at least two doctors on different departments (mock roster).
   * serviceSlugs must match keys created above for that branchCode.
   */
  const doctorSeeds: Array<{
    email: string;
    firstName: string;
    lastName: string;
    branchCode: string;
    departmentName: string;
    serviceSlugs: string[];
    bio: string;
    fee: number;
  }> = [
    {
      email: 'saruul@clinova.mn',
      firstName: 'Saruul',
      lastName: 'Bat',
      branchCode: 'CENTRAL',
      departmentName: 'ENT',
      serviceSlugs: ['ent'],
      bio: 'ENT specialist — Central branch.',
      fee: 60_000,
    },
    {
      email: 'ochir@clinova.mn',
      firstName: 'Ochir',
      lastName: 'Ganbold',
      branchCode: 'CENTRAL',
      departmentName: 'Pediatrics',
      serviceSlugs: ['ped'],
      bio: 'Pediatrician — well-child and acute care.',
      fee: 70_000,
    },
    {
      email: 'namuun@clinova.mn',
      firstName: 'Namuun',
      lastName: 'Erdene',
      branchCode: 'RIVER',
      departmentName: 'Dermatology',
      serviceSlugs: ['derm'],
      bio: 'Dermatologist — Riverfront clinic.',
      fee: 80_000,
    },
    {
      email: 'anar@clinova.mn',
      firstName: 'Anar',
      lastName: 'Bold',
      branchCode: 'RIVER',
      departmentName: 'Cardiology',
      serviceSlugs: ['card'],
      bio: 'Cardiology follow-up and risk counseling.',
      fee: 95_000,
    },
    {
      email: 'tsetsgee@clinova.mn',
      firstName: 'Tsetsgee',
      lastName: 'Lkhagvasuren',
      branchCode: 'BAYANZURKH',
      departmentName: 'Gynecology',
      serviceSlugs: ['gyn'],
      bio: "Women's health — Bayanzurkh branch.",
      fee: 75_000,
    },
    {
      email: 'munkh@clinova.mn',
      firstName: 'Munkh-Erdene',
      lastName: 'Dorj',
      branchCode: 'BAYANZURKH',
      departmentName: 'Neurology',
      serviceSlugs: ['neuro'],
      bio: 'Neurology outpatient consultations.',
      fee: 88_000,
    },
    {
      email: 'bold@clinova.mn',
      firstName: 'Bold',
      lastName: 'Saikhan',
      branchCode: 'SONGINO',
      departmentName: 'ENT',
      serviceSlugs: ['ent'],
      bio: 'ENT — Songinokhairkhan satellite clinic.',
      fee: 60_000,
    },
    {
      email: 'enkhjin@clinova.mn',
      firstName: 'Enkhjin',
      lastName: 'Tseren',
      branchCode: 'SONGINO',
      departmentName: 'Cardiology',
      serviceSlugs: ['card'],
      bio: 'Cardiology — Songinokhairkhan; focus on hypertension follow-up.',
      fee: 85_000,
    },
    {
      email: 'delgermaa@clinova.mn',
      firstName: 'Delgermaa',
      lastName: 'Purev',
      branchCode: 'DARKHAN',
      departmentName: 'Pediatrics',
      serviceSlugs: ['ped'],
      bio: 'Pediatrician — Darkhan regional hub.',
      fee: 70_000,
    },
    {
      email: 'batbayar@clinova.mn',
      firstName: 'Batbayar',
      lastName: 'Chuluun',
      branchCode: 'DARKHAN',
      departmentName: 'Dermatology',
      serviceSlugs: ['derm'],
      bio: 'Dermatology — Darkhan branch.',
      fee: 80_000,
    },
    {
      email: 'dental.central@clinova.mn',
      firstName: 'Nandin',
      lastName: 'Tsogoo',
      branchCode: 'CENTRAL',
      departmentName: 'Dentistry',
      serviceSlugs: ['dent'],
      bio: 'General dentistry — Central branch.',
      fee: 55_000,
    },
    {
      email: 'dental.river@clinova.mn',
      firstName: 'Altangerel',
      lastName: 'Smile',
      branchCode: 'RIVER',
      departmentName: 'Dentistry',
      serviceSlugs: ['dent'],
      bio: 'Dentistry — Riverfront.',
      fee: 55_000,
    },
    {
      email: 'dental.bayanzurkh@clinova.mn',
      firstName: 'Oyunbold',
      lastName: 'Dental',
      branchCode: 'BAYANZURKH',
      departmentName: 'Dentistry',
      serviceSlugs: ['dent'],
      bio: 'Dentistry — Bayanzurkh.',
      fee: 55_000,
    },
    {
      email: 'dental.songino@clinova.mn',
      firstName: 'Enkhtuya',
      lastName: 'Tooth',
      branchCode: 'SONGINO',
      departmentName: 'Dentistry',
      serviceSlugs: ['dent'],
      bio: 'Dentistry — Songinokhairkhan.',
      fee: 55_000,
    },
    {
      email: 'dental.darkhan@clinova.mn',
      firstName: 'Munkhzul',
      lastName: 'Dentist',
      branchCode: 'DARKHAN',
      departmentName: 'Dentistry',
      serviceSlugs: ['dent'],
      bio: 'Dentistry — Darkhan.',
      fee: 55_000,
    },
  ];

  const createdDoctors: Array<{
    user: { id: string };
    doctor: { id: string };
  }> = [];

  for (const item of doctorSeeds) {
    const branch = branchByCode.get(item.branchCode);
    if (!branch) {
      throw new Error(`Unknown branch code: ${item.branchCode}`);
    }

    const user = await prisma.user.create({
      data: {
        email: item.email,
        passwordHash: await bcrypt.hash('ClinovaDoctor123!', 10),
        role: Role.DOCTOR,
        status: UserStatus.ACTIVE,
        firstName: item.firstName,
        lastName: item.lastName,
        branchId: branch.id,
      },
    });

    const serviceLinks = item.serviceSlugs.map((slug) => {
      const key = `${slug}_${item.branchCode}`;
      const svc = services.get(key);
      if (!svc) {
        throw new Error(`Missing service key ${key} for doctor ${item.email}`);
      }
      return { serviceId: svc.id };
    });

    const doctor = await prisma.doctorProfile.create({
      data: {
        userId: user.id,
        branchId: branch.id,
        departmentId: departments.get(item.departmentName)!.id,
        bio: item.bio,
        consultationFee: item.fee,
        experienceYears: 6,
        services: {
          createMany: {
            data: serviceLinks,
          },
        },
      },
    });

    createdDoctors.push({ user, doctor });

    for (const dayOfWeek of [1, 2, 3, 4, 5]) {
      await prisma.doctorWeeklySchedule.create({
        data: {
          doctorId: doctor.id,
          dayOfWeek,
          startTime: '09:00',
          endTime: '17:00',
          slotMinutes: 30,
          breaks: {
            create: [{ startTime: '12:00', endTime: '13:00' }],
          },
        },
      });
    }
  }

  const appointmentStart = new Date();
  appointmentStart.setDate(appointmentStart.getDate() + 1);
  appointmentStart.setHours(10, 30, 0, 0);
  const appointmentEnd = new Date(appointmentStart.getTime() + 30 * 60_000);

  const central = branchByCode.get('CENTRAL')!;
  const entCentral = services.get('ent_CENTRAL')!;

  await prisma.appointment.create({
    data: {
      patientId: patientUser.patientProfile!.id,
      doctorId: createdDoctors[0]!.doctor.id,
      branchId: central.id,
      departmentId: departments.get('ENT')!.id,
      serviceId: entCentral.id,
      startsAt: appointmentStart,
      endsAt: appointmentEnd,
      status: AppointmentStatus.CONFIRMED,
      reason: 'Ear pain and fever',
      createdByUserId: patientUser.id,
    },
  });

  await prisma.message.create({
    data: {
      roomId: [patientUser.id, createdDoctors[0]!.user.id].sort().join(':'),
      senderId: patientUser.id,
      receiverId: createdDoctors[0]!.user.id,
      text: 'Сайн байна уу эмч ээ, маргаашийн цаг баталгаажсан уу?',
    },
  });

  await prisma.jobApplication.create({
    data: {
      fullName: 'Temuulen Gan',
      email: 'temuulen@example.com',
      phone: '+97699110022',
      desiredRole: 'Nurse',
      branchId: central.id,
      departmentId: departments.get('Pediatrics')!.id,
      resumeUrl: 'https://example.com/resume/temuulen.pdf',
      coverLetter: 'Interested in joining Clinova pediatrics team.',
      status: JobApplicationStatus.PENDING,
    },
  });

  console.log(
    `Clinova seed completed: ${branches.length} branches, ${services.size} services, ${createdDoctors.length} doctors.`,
  );
  console.log('Demo credentials:');
  console.log(`- Admin: ${adminEmail} / ${adminPassword}`);
  console.log('- Patient: patient@clinova.mn / ClinovaPatient123!');
  console.log('- Doctor: saruul@clinova.mn / ClinovaDoctor123!');
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
