/**
 * Mongolian MSISDN normalization for Clinova (+976 + 8 national digits).
 * Does not integrate SMS — used for validation + storage only.
 */

export const MONGOLIA_PHONE_INVALID_MESSAGE = 'Утасны дугаар буруу байна.';

/** Returns +976xxxxxxxx or null when input is absent or invalid (non-blocking). */
export function tryNormalizeMongoliaPhone(raw: string | undefined | null): string | null {
  if (raw === undefined || raw === null) return null;
  const trimmed = raw.trim().replace(/\s+/g, '');
  if (!trimmed) return null;

  let digits: string;

  if (trimmed.startsWith('+976')) {
    digits = trimmed.slice(4).replace(/\D/g, '');
  } else if (trimmed.startsWith('976')) {
    digits = trimmed.slice(3).replace(/\D/g, '');
  } else {
    digits = trimmed.replace(/\D/g, '');
  }

  if (digits.length !== 8 || !/^\d{8}$/.test(digits)) return null;

  return `+976${digits}`;
}

/** Validates only when callers pass a meaningful string after trim (optional field UX). */
export function normalizeOptionalMongoliaPhone(
  raw: string | undefined | null,
): string | undefined | null {
  if (raw === undefined || raw === null) return raw;
  if (String(raw).trim() === '') return undefined;
  const n = tryNormalizeMongoliaPhone(raw);
  return n ?? null;
}
