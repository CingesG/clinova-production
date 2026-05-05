/**
 * Deactivates legacy bootstrap demo doctor accounts (demo.doctor01@ … demo.doctor@).
 * Does not touch prisma/seed.ts DOCTOR_SEEDS (doctor.*@clinova.local).
 *
 * Usage: npm run cleanup:demo-doctors
 */
import 'dotenv/config';

import { PrismaClient, Role, UserStatus } from '@prisma/client';

const prisma = new PrismaClient();

const LEGACY_DEMO_DOCTOR_EMAILS = [
  'demo.doctor01@clinova.local',
  'demo.doctor02@clinova.local',
  'demo.doctor03@clinova.local',
  'demo.doctor04@clinova.local',
  'demo.doctor05@clinova.local',
  'demo.doctor06@clinova.local',
  'demo.doctor07@clinova.local',
  'demo.doctor08@clinova.local',
  'demo.doctor@clinova.local',
];

async function main() {
  if (!process.env.DATABASE_URL?.trim()) {
    throw new Error('DATABASE_URL is required.');
  }

  let updatedUsers = 0;
  let updatedProfiles = 0;

  for (const email of LEGACY_DEMO_DOCTOR_EMAILS) {
    const user = await prisma.user.findUnique({
      where: { email },
      include: { doctorProfile: true },
    });
    if (!user) continue;

    if (user.role === Role.DOCTOR || user.doctorProfile) {
      await prisma.user.update({
        where: { id: user.id },
        data: { status: UserStatus.INACTIVE },
      });
      updatedUsers++;
      if (user.doctorProfile) {
        await prisma.doctorProfile.update({
          where: { id: user.doctorProfile.id },
          data: { active: false },
        });
        updatedProfiles++;
      }
    }
  }

  console.log(
    `cleanup-demo-doctors: set INACTIVE on ${updatedUsers} user(s), deactivated ${updatedProfiles} doctor profile(s).`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
