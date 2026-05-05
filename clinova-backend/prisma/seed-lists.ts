/**
 * Keep in sync with `prisma/seed.ts` (DOCTOR_SEEDS / PATIENT_SEEDS emails).
 * Used by demo tooling; seed.ts remains the source for full seed data.
 */
export const PRESERVE_ADMIN_EMAIL = 'chinges_chinges@icloud.com' as const;

export const SEEDED_DOCTOR_EMAILS: readonly string[] = [
  'doctor.enkhbayar@clinova.local',
  'doctor.solongo@clinova.local',
  'doctor.ariunzaya@clinova.local',
  'doctor.temuulen@clinova.local',
  'doctor.munkherdene@clinova.local',
  'doctor.oyunchimeg@clinova.local',
  'doctor.batorgil@clinova.local',
  'doctor.nomin@clinova.local',
  'doctor.enkhjin@clinova.local',
  'doctor.huslen@clinova.local',
];

/** Explicit demo patients from seed.ts. */
export const SEEDED_DEMO_PATIENT_EMAILS: readonly string[] = [
  'demo.patient1@clinova.local',
  'demo.patient2@clinova.local',
  'demo.patient3@clinova.local',
];
