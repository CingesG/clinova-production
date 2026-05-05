/**
 * Local-only: writes demo/test login credentials to gitignored files.
 * Never logs raw passwords. Refuses production unless ALLOW_DEMO_CREDENTIAL_EXPORT=true.
 */
import 'dotenv/config';

import * as fs from 'fs/promises';
import * as path from 'path';
import { randomBytes, randomInt } from 'crypto';

import {
  AuthProvider,
  PrismaClient,
  Role,
  UserStatus,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

import {
  PRESERVE_ADMIN_EMAIL,
  SEEDED_DEMO_PATIENT_EMAILS,
  SEEDED_DOCTOR_EMAILS,
} from '../seed-lists';

const prisma = new PrismaClient();
const BCRYPT_ROUNDS = 12;

function assertSafeToRun() {
  const nodeEnv = (process.env.NODE_ENV ?? '').toLowerCase();
  if (
    nodeEnv === 'production' &&
    process.env.ALLOW_DEMO_CREDENTIAL_EXPORT !== 'true'
  ) {
    throw new Error(
      'Refusing to run in NODE_ENV=production without ALLOW_DEMO_CREDENTIAL_EXPORT=true',
    );
  }
  if (!process.env.DATABASE_URL?.trim()) {
    throw new Error('DATABASE_URL is required.');
  }
}

/** 14–18 chars: upper, lower, number, symbol. */
function generateSecureTemporaryPassword(): string {
  const targetLen = randomInt(14, 19);
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghijkmnpqrstuvwxyz';
  const num = '23456789';
  const sym = '!@#$%&*_-+=';
  const pool = upper + lower + num + sym;
  const pick = (s: string) => s[randomInt(s.length)];

  const required = [pick(upper), pick(lower), pick(num), pick(sym)];
  const rest: string[] = [];
  const buf = randomBytes(targetLen * 2);
  let i = 0;
  while (required.length + rest.length < targetLen) {
    rest.push(pool[buf[i++] % pool.length]);
  }
  const chars = [...required, ...rest];
  for (let j = chars.length - 1; j > 0; j--) {
    const k = randomInt(j + 1);
    [chars[j], chars[k]] = [chars[k], chars[j]];
  }
  return chars.slice(0, targetLen).join('');
}

function displayName(
  first: string | null,
  last: string | null,
  email: string,
): string {
  const f = first?.trim() ?? '';
  const l = last?.trim() ?? '';
  if (f || l) return `${f} ${l}`.trim();
  return email;
}

function loginIdFromEmail(email: string): string {
  return email.trim().toLowerCase();
}

function usernameFromEmail(email: string): string | null {
  const e = email.trim().toLowerCase();
  const at = e.indexOf('@');
  if (at <= 0) return null;
  return e.slice(0, at);
}

function isDemoPatientEmail(email: string): boolean {
  const e = email.trim().toLowerCase();
  if (e === PRESERVE_ADMIN_EMAIL.toLowerCase()) return false;
  if (SEEDED_DOCTOR_EMAILS.includes(e)) return false;
  if (SEEDED_DEMO_PATIENT_EMAILS.includes(e)) return true;
  if (e.endsWith('@clinova.local')) return true;
  const local = e.split('@')[0] ?? '';
  if (/^demo[._-]/i.test(local) || /demo\.patient/i.test(local)) return true;
  if (/^test[._-](user|patient|demo)/i.test(local)) return true;
  if (e.includes('+demo') || e.includes('+test')) return true;
  return false;
}

type CredentialRow = {
  role: string;
  firstName: string | null;
  lastName: string | null;
  name: string;
  email: string;
  username: string | null;
  loginId: string;
  temporaryPassword: string | null;
  passwordNote?: string;
  status: string;
  emailVerified: boolean;
  department?: string | null;
  branch?: string | null;
};

function buildTxt(
  adminRows: CredentialRow[],
  doctorRows: CredentialRow[],
  patientRows: CredentialRow[],
): string {
  const lines: string[] = [];
  const pw = (r: CredentialRow) =>
    r.temporaryPassword ??
    (r.passwordNote != null ? `(see note) ${r.passwordNote}` : '(not set)');

  lines.push('ADMIN');
  for (const r of adminRows) {
    lines.push(`Email: ${r.email}`);
    lines.push(`Login: ${r.loginId}`);
    lines.push(`Password: ${pw(r)}`);
    lines.push(`Status: ${r.status} | emailVerified: ${r.emailVerified}`);
    lines.push('');
  }

  lines.push('DOCTORS');
  let i = 1;
  for (const r of doctorRows) {
    lines.push(`${i}. Name: ${r.name}`);
    lines.push(`   Email: ${r.email}`);
    lines.push(`   Username: ${r.username ?? '—'}`);
    lines.push(`   Login ID: ${r.loginId}`);
    lines.push(`   Password: ${pw(r)}`);
    if (r.department) lines.push(`   Department: ${r.department}`);
    if (r.branch) lines.push(`   Branch: ${r.branch}`);
    if (r.passwordNote && r.temporaryPassword == null) {
      lines.push(`   Note: ${r.passwordNote}`);
    }
    lines.push('');
    i++;
  }

  lines.push('DEMO PATIENTS');
  i = 1;
  for (const r of patientRows) {
    lines.push(`${i}. Name: ${r.name}`);
    lines.push(`   Email: ${r.email}`);
    lines.push(`   Login: ${r.loginId}`);
    lines.push(`   Password: ${pw(r)}`);
    if (r.passwordNote && r.temporaryPassword == null) {
      lines.push(`   Note: ${r.passwordNote}`);
    }
    lines.push('');
    i++;
  }

  return lines.join('\n');
}

async function main() {
  assertSafeToRun();

  const resetAdmin = process.env.RESET_ADMIN_PASSWORD_FOR_DEMO === 'true';
  const resetDoctors =
    process.env.RESET_DOCTOR_PASSWORDS_FOR_DEMO === 'true';
  const resetDemoPatients =
    process.env.RESET_DEMO_PATIENT_PASSWORDS === 'true';
  const envDoctorPwd = process.env.DEMO_DOCTOR_PASSWORD?.trim();
  const envPatientPwd = process.env.DEMO_PATIENT_PASSWORD?.trim();

  const adminRows: CredentialRow[] = [];
  const doctorRows: CredentialRow[] = [];
  const patientRows: CredentialRow[] = [];

  const generatedAt = new Date().toISOString();

  // --- Admin ---
  const adminEmailNorm = PRESERVE_ADMIN_EMAIL.toLowerCase();
  let adminUser = await prisma.user.findUnique({
    where: { email: adminEmailNorm },
  });

  if (!adminUser) {
    const plain = generateSecureTemporaryPassword();
    const passwordHash = await bcrypt.hash(plain, BCRYPT_ROUNDS);
    adminUser = await prisma.user.create({
      data: {
        email: adminEmailNorm,
        passwordHash,
        role: Role.ADMIN,
        status: UserStatus.ACTIVE,
        authProvider: AuthProvider.EMAIL,
        emailVerified: true,
        firstName: 'Admin',
        lastName: 'Clinova',
      },
    });
    adminRows.push({
      role: 'ADMIN',
      firstName: adminUser.firstName,
      lastName: adminUser.lastName,
      name: displayName(
        adminUser.firstName,
        adminUser.lastName,
        adminUser.email,
      ),
      email: adminUser.email,
      username: usernameFromEmail(adminUser.email),
      loginId: loginIdFromEmail(adminUser.email),
      temporaryPassword: plain,
      status: adminUser.status,
      emailVerified: adminUser.emailVerified,
    });
  } else {
    if (resetAdmin) {
      const plain = generateSecureTemporaryPassword();
      const passwordHash = await bcrypt.hash(plain, BCRYPT_ROUNDS);
      await prisma.user.update({
        where: { id: adminUser.id },
        data: {
          passwordHash,
          status: UserStatus.ACTIVE,
          emailVerified: true,
          role: Role.ADMIN,
        },
      });
      adminRows.push({
        role: 'ADMIN',
        firstName: adminUser.firstName,
        lastName: adminUser.lastName,
        name: displayName(
          adminUser.firstName,
          adminUser.lastName,
          adminUser.email,
        ),
        email: adminUser.email,
        username: usernameFromEmail(adminUser.email),
        loginId: loginIdFromEmail(adminUser.email),
        temporaryPassword: plain,
        status: UserStatus.ACTIVE,
        emailVerified: true,
      });
    } else {
      await prisma.user.update({
        where: { id: adminUser.id },
        data: {
          status: UserStatus.ACTIVE,
          emailVerified: true,
          role: Role.ADMIN,
        },
      });
      adminRows.push({
        role: 'ADMIN',
        firstName: adminUser.firstName,
        lastName: adminUser.lastName,
        name: displayName(
          adminUser.firstName,
          adminUser.lastName,
          adminUser.email,
        ),
        email: adminUser.email,
        username: usernameFromEmail(adminUser.email),
        loginId: loginIdFromEmail(adminUser.email),
        temporaryPassword: null,
        passwordNote:
          'Password not changed. Use your existing admin password, or run with RESET_ADMIN_PASSWORD_FOR_DEMO=true.',
        status: UserStatus.ACTIVE,
        emailVerified: true,
      });
    }
  }

  // --- Seeded doctors ---
  for (const rawEmail of SEEDED_DOCTOR_EMAILS) {
    const email = rawEmail.trim().toLowerCase();
    const user = await prisma.user.findUnique({
      where: { email },
      include: {
        doctorProfile: {
          include: {
            branch: { select: { name: true } },
            department: { select: { name: true } },
          },
        },
      },
    });

    if (!user?.doctorProfile) {
      doctorRows.push({
        role: 'DOCTOR',
        firstName: user?.firstName ?? null,
        lastName: user?.lastName ?? null,
        name: user
          ? displayName(user.firstName, user.lastName, user.email)
          : email,
        email,
        username: usernameFromEmail(email),
        loginId: loginIdFromEmail(email),
        temporaryPassword: null,
        passwordNote:
          'Missing doctor profile — run: npm run prisma:seed (password not updated)',
        status: user?.status ?? 'MISSING',
        emailVerified: user?.emailVerified ?? false,
        department: null,
        branch: null,
      });
      continue;
    }

    let plain: string;
    if (resetDoctors) {
      plain = generateSecureTemporaryPassword();
    } else if (envDoctorPwd) {
      plain = envDoctorPwd;
    } else {
      plain = generateSecureTemporaryPassword();
    }

    const passwordHash = await bcrypt.hash(plain, BCRYPT_ROUNDS);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        role: Role.DOCTOR,
        status: UserStatus.ACTIVE,
        emailVerified: true,
      },
    });

    const dept = user.doctorProfile.department?.name ?? null;
    const br = user.doctorProfile.branch?.name ?? null;

    doctorRows.push({
      role: 'DOCTOR',
      firstName: user.firstName,
      lastName: user.lastName,
      name: displayName(user.firstName, user.lastName, user.email),
      email: user.email,
      username: usernameFromEmail(user.email),
      loginId: loginIdFromEmail(user.email),
      temporaryPassword: plain,
      passwordNote:
        !resetDoctors && envDoctorPwd
          ? 'Password set from DEMO_DOCTOR_PASSWORD'
          : undefined,
      status: UserStatus.ACTIVE,
      emailVerified: true,
      department: dept,
      branch: br,
    });
  }

  doctorRows.sort((a, b) => a.email.localeCompare(b.email));

  // --- Demo / test patients only ---
  const allPatients = await prisma.user.findMany({
    where: { role: Role.PATIENT },
    include: { patientProfile: true },
  });
  const demoPatients = allPatients.filter((u) => isDemoPatientEmail(u.email));

  for (const user of demoPatients) {
    let plain: string;
    if (resetDemoPatients) {
      plain = generateSecureTemporaryPassword();
    } else if (envPatientPwd) {
      plain = envPatientPwd;
    } else {
      plain = generateSecureTemporaryPassword();
    }

    const passwordHash = await bcrypt.hash(plain, BCRYPT_ROUNDS);
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        status: UserStatus.ACTIVE,
        emailVerified: true,
      },
    });

    patientRows.push({
      role: 'PATIENT',
      firstName: user.firstName,
      lastName: user.lastName,
      name: displayName(user.firstName, user.lastName, user.email),
      email: user.email,
      username: usernameFromEmail(user.email),
      loginId: loginIdFromEmail(user.email),
      temporaryPassword: plain,
      passwordNote:
        !resetDemoPatients && envPatientPwd
          ? 'Password set from DEMO_PATIENT_PASSWORD'
          : undefined,
      status: UserStatus.ACTIVE,
      emailVerified: true,
    });
  }

  patientRows.sort((a, b) => a.email.localeCompare(b.email));

  const outDir = path.join(process.cwd(), 'seed-output');
  await fs.mkdir(outDir, { recursive: true });
  const jsonPath = path.join(outDir, 'login-credentials.local.json');
  const txtPath = path.join(outDir, 'login-credentials.local.txt');

  const payload = {
    generatedAt,
    admin: adminRows,
    doctors: doctorRows,
    demoPatients: patientRows,
    flags: {
      RESET_ADMIN_PASSWORD_FOR_DEMO: resetAdmin,
      RESET_DOCTOR_PASSWORDS_FOR_DEMO: resetDoctors,
      RESET_DEMO_PATIENT_PASSWORDS: resetDemoPatients,
      hadDemoDoctorPasswordEnv: Boolean(envDoctorPwd),
      hadDemoPatientPasswordEnv: Boolean(envPatientPwd),
    },
  };

  await fs.writeFile(jsonPath, JSON.stringify(payload, null, 2), 'utf-8');
  await fs.writeFile(
    txtPath,
    buildTxt(adminRows, doctorRows, patientRows),
    'utf-8',
  );

  console.log(
    'Credentials written to seed-output/login-credentials.local.txt',
  );
}

void main()
  .catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
