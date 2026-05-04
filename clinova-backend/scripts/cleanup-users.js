/**
 * Production cleanup: delete all users EXCEPT KEEP_EMAIL and related rows.
 *
 * Env:
 *   DATABASE_URL — required (never hardcoded in this repo)
 *   KEEP_EMAIL — required; this account is preserved
 *   CONFIRM_CLEANUP_USERS — YES_DELETE_TEST_USERS for real deletes (ignored in --dry-run)
 *
 * Args:
 *   --dry-run — print plan + counts only; zero writes
 *
 * Run from clinova-backend (loads ../.env if present):
 *   KEEP_EMAIL=user@icloud.com DATABASE_URL="$DATABASE_URL" node scripts/cleanup-users.js --dry-run
 */

'use strict';

const path = require('path');
require('dotenv').config({
  path: path.resolve(__dirname, '../.env'),
  quiet: true,
});

const { PrismaClient } = require('@prisma/client');

function die(msg, code = 1) {
  console.error('[cleanup-users]', msg);
  process.exit(code);
}

function normalizeEmail(e) {
  return String(e ?? '')
    .trim()
    .toLowerCase();
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  if (
    typeof process.env.DATABASE_URL !== 'string' ||
    process.env.DATABASE_URL.trim() === ''
  ) {
    die('DATABASE_URL is missing.');
  }

  const keepEmailNorm = normalizeEmail(process.env.KEEP_EMAIL);
  if (!keepEmailNorm) {
    die('KEEP_EMAIL is required.');
  }

  if (!dryRun && process.env.CONFIRM_CLEANUP_USERS !== 'YES_DELETE_TEST_USERS') {
    die(
      'Destructive mode blocked: CONFIRM_CLEANUP_USERS=YES_DELETE_TEST_USERS missing (use --dry-run to preview).',
    );
  }

  const prisma = new PrismaClient();

  try {
    const keepUser = await prisma.user.findFirst({
      where: { email: { equals: keepEmailNorm, mode: 'insensitive' } },
      select: {
        id: true,
        email: true,
        role: true,
        patientProfile: { select: { id: true } },
        doctorProfile: { select: { id: true } },
      },
    });

    if (!keepUser) {
      die(`Abort: KEEP_EMAIL not found (${keepEmailNorm}).`);
    }

    const deleteUsersRaw = await prisma.user.findMany({
      where: { id: { not: keepUser.id } },
      select: { id: true, email: true, role: true },
    });

    const deleteIds = deleteUsersRaw.map((u) => u.id);

    const apptTouchFilter = {
      OR: [
        { patient: { userId: { in: deleteIds } } },
        { doctor: { userId: { in: deleteIds } } },
      ],
    };

    const locksWhere = {
      OR: [
        { lockedByUserId: { in: deleteIds } },
        {
          appointment: apptTouchFilter,
        },
      ],
    };

    console.log('[cleanup-users]', dryRun ? 'MODE: DRY-RUN' : 'MODE: DELETE');
    console.log('[cleanup-users]', 'Preserve:', {
      id: keepUser.id,
      email: keepUser.email,
      role: keepUser.role,
    });
    console.log('[cleanup-users]', 'Delete count:', deleteUsersRaw.length);
    if (deleteUsersRaw.length === 0) {
      console.log('[cleanup-users]', 'No other users.');
      return;
    }
    console.log(
      '[cleanup-users]',
      'Delete list (id, email, role):',
      deleteUsersRaw
        .map((u) => `${u.id} | ${u.email} | ${u.role}`)
        .join('\n'),
    );

    if (keepUser.patientProfile?.id && deleteIds.length > 0) {
      const bad = await prisma.appointment.count({
        where: {
          patientId: keepUser.patientProfile.id,
          doctor: { userId: { in: deleteIds } },
        },
      });
      if (bad > 0) {
        die(
          `Abort: ${bad} appointment(s): KEEP patient's doctor is in delete set.`,
        );
      }
    }

    if (keepUser.doctorProfile?.id && deleteIds.length > 0) {
      const bad = await prisma.appointment.count({
        where: {
          doctorId: keepUser.doctorProfile.id,
          patient: { userId: { in: deleteIds } },
        },
      });
      if (bad > 0) {
        die(
          `Abort: ${bad} appointment(s): KEEP doctor sees patients in delete set.`,
        );
      }
    }

    const deleteEmailsDistinct = [
      ...new Set(deleteUsersRaw.map((u) => normalizeEmail(u.email))),
    ];

    /** Prisma insensitive match per-email (covers mixed-case OTP rows). */
    const emailOrInsensitive = deleteEmailsDistinct.map((em) => ({
      email: { equals: em, mode: 'insensitive' },
    }));

    const apptDelCount = await prisma.appointment.count({
      where: apptTouchFilter,
    });

    const slotLocksToDeleteCount = await prisma.appointmentSlotLock.count({
      where: locksWhere,
    });

    const msgSenderCount = await prisma.message.count({
      where: {
        OR: [
          { senderId: { in: deleteIds } },
          { receiverId: { in: deleteIds } },
        ],
      },
    });

    const otpWhere = {
      OR: [{ userId: { in: deleteIds } }, ...emailOrInsensitive],
    };

    const otpCount = await prisma.otpCode.count({ where: otpWhere });

    const jobAppWhere = { OR: emailOrInsensitive };

    const jobAppCount = await prisma.jobApplication.count({
      where: jobAppWhere,
    });

    console.log('[cleanup-users]', 'Planned removals:', {
      appointments: apptDelCount,
      appointmentSlotLocks: slotLocksToDeleteCount,
      messages: msgSenderCount,
      otp_codes: otpCount,
      job_applications_match_emails: jobAppCount,
      users: deleteIds.length,
    });

    if (dryRun) {
      console.log('[cleanup-users]', 'Dry-run OK — exiting without changes.');
      return;
    }

    await prisma.$transaction(
      async (tx) => {
        await tx.appointmentSlotLock.deleteMany({ where: locksWhere });

        /** Payment + MedicalRecord cascade from Appointment FK in DB. Notification.appointment → SetNull. */
        await tx.appointment.deleteMany({ where: apptTouchFilter });

        await tx.message.deleteMany({
          where: {
            OR: [
              { senderId: { in: deleteIds } },
              { receiverId: { in: deleteIds } },
            ],
          },
        });

        await tx.otpCode.deleteMany({ where: otpWhere });

        await tx.jobApplication.deleteMany({
          where: jobAppWhere,
        });

        const delUsers = await tx.user.deleteMany({
          where: { id: { in: deleteIds } },
        });

        console.log('[cleanup-users]', 'Users deleted:', delUsers.count);

        const keeper = await tx.user.count({ where: { id: keepUser.id } });
        if (keeper !== 1) {
          throw new Error(
            '[cleanup-users] Post-delete integrity check failed (keeper missing).',
          );
        }
      },
      { maxWait: 60000, timeout: 120000 },
    );

    console.log('[cleanup-users]', 'Done; preserved:', keepUser.email);
  } catch (e) {
    console.error('[cleanup-users]', e);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
}

void main();
