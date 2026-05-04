/**
 * Dev/admin: delete a single user by email + related rows so they can re-register.
 *
 * Safety:
 * - Requires ALLOW_DELETE_TEST_USER=1
 * - Refuses NODE_ENV=production unless ALLOW_DELETE_TEST_USER_IN_PRODUCTION=1
 * - Refuses ADMIN unless ALLOW_DELETE_ADMIN_USER=1
 * - Refuses doctors who have any appointment (would remove real patient bookings)
 *
 * Usage (from clinova-backend):
 *   ALLOW_DELETE_TEST_USER=1 npx ts-node prisma/delete-user-by-email.ts you@example.com
 */
import 'dotenv/config';

import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

function fail(msg: string): never {
  console.error(msg);
  process.exit(1);
}

async function main() {
  const raw = process.argv[2]?.trim();
  if (!raw) {
    fail(
      'Usage: ALLOW_DELETE_TEST_USER=1 npx ts-node prisma/delete-user-by-email.ts <email>',
    );
  }

  if (process.env.ALLOW_DELETE_TEST_USER !== '1') {
    fail('Refusing: set ALLOW_DELETE_TEST_USER=1 for this one-off script.');
  }

  if (
    process.env.NODE_ENV === 'production' &&
    process.env.ALLOW_DELETE_TEST_USER_IN_PRODUCTION !== '1'
  ) {
    fail(
      'Refusing: NODE_ENV=production. Set ALLOW_DELETE_TEST_USER_IN_PRODUCTION=1 if you really mean it.',
    );
  }

  const email = raw.toLowerCase();

  const user = await prisma.user.findFirst({
    where: { email: { equals: email, mode: 'insensitive' } },
    include: {
      patientProfile: { select: { id: true } },
      doctorProfile: { select: { id: true } },
    },
  });

  if (!user) {
    console.log(`No user found for email: ${email} (nothing to delete).`);
    return;
  }

  if (
    user.role === Role.ADMIN &&
    process.env.ALLOW_DELETE_ADMIN_USER !== '1'
  ) {
    fail(
      'Refusing: user is ADMIN. Set ALLOW_DELETE_ADMIN_USER=1 to override.',
    );
  }

  if (user.doctorProfile?.id) {
    const appointmentCount = await prisma.appointment.count({
      where: { doctorId: user.doctorProfile.id },
    });
    if (appointmentCount > 0) {
      fail(
        `Refusing: user is a doctor with ${appointmentCount} appointment(s). Deleting would remove patient bookings.`,
      );
    }
  }

  await prisma.$transaction(async (tx) => {
    await tx.otpCode.deleteMany({
      where: {
        OR: [{ userId: user.id }, { email: { equals: user.email, mode: 'insensitive' } }],
      },
    });

    if (user.patientProfile?.id) {
      await tx.appointment.deleteMany({
        where: { patientId: user.patientProfile.id },
      });
    }

    await tx.message.deleteMany({
      where: {
        OR: [{ senderId: user.id }, { receiverId: user.id }],
      },
    });

    await tx.appointmentSlotLock.deleteMany({
      where: { lockedByUserId: user.id },
    });

    await tx.refreshToken.deleteMany({ where: { userId: user.id } });

    await tx.user.delete({ where: { id: user.id } });
  });

  console.log(
    `Deleted user ${user.id} (${user.email}). Related OTPs, appointments (as patient), messages, locks, tokens removed.`,
  );
  console.log('They can register again with the same email.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
