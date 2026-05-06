/**
 * One-time production helper: set a new password for an existing ADMIN user.
 *
 * Usage:
 *   ADMIN_RESET_PASSWORD='<min 12 chars>' npm run admin:reset-password
 *   ADMIN_RESET_EMAIL=you@example.com ADMIN_RESET_PASSWORD='...' npm run admin:reset-password
 *
 * - Does not log passwords or password hashes.
 * - Refuses non-ADMIN accounts (doctors/patients/staff are untouched).
 */
import 'dotenv/config';

import * as bcrypt from 'bcrypt';
import { PrismaClient, Role, UserStatus } from '@prisma/client';

const DEFAULT_ADMIN_EMAIL = 'chinges_chinges@icloud.com';
const BCRYPT_ROUNDS = 10;

const prisma = new PrismaClient();

async function main() {
  if (!process.env.DATABASE_URL?.trim()) {
    console.error('DATABASE_URL is required.');
    process.exit(1);
  }

  const emailRaw =
    process.env.ADMIN_RESET_EMAIL?.trim() || DEFAULT_ADMIN_EMAIL;
  const password = process.env.ADMIN_RESET_PASSWORD?.trim();

  if (!password || password.length < 12) {
    console.error(
      'ADMIN_RESET_PASSWORD is required and must be at least 12 characters.',
    );
    process.exit(1);
  }

  const user = await prisma.user.findFirst({
    where: {
      email: { equals: emailRaw, mode: 'insensitive' },
    },
    select: { id: true, email: true, role: true },
  });

  if (!user) {
    console.error('No user found for that email.');
    process.exit(1);
  }

  if (user.role !== Role.ADMIN) {
    console.error(
      'Refusing: user is not ADMIN. This script only updates ADMIN accounts.',
    );
    process.exit(1);
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  await prisma.user.update({
    where: { id: user.id },
    data: {
      passwordHash,
      emailVerified: true,
      status: UserStatus.ACTIVE,
    },
  });

  console.log(`Admin password reset complete for ${user.email}`);
}

void main()
  .catch((err: unknown) => {
    const msg = err instanceof Error ? err.message : 'Unexpected error.';
    console.error(msg);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
