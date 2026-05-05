# Demo нэвтрэлт (Clinova)

## Admin

- **Имэйл:** `chinges_chinges@icloud.com` (`DEFAULT_ADMIN_EMAIL`)
- **Нууц:** `.env` дээрх `DEFAULT_ADMIN_PASSWORD` (хамгийн багадаа **12 тэмдэгт**), зөвхөн хэрэглэгч **байхгүй** үед үүсгэнэ. Байвал seed/bootstrap **нууцыг хэзээ ч өөрчлөхгүй**.

## Эмч — `npm run prisma:seed` (10 эмч, single source of truth)

Эмчийн имэйлүүд:

- `doctor.enkhbayar@clinova.local` … `doctor.huslen@clinova.local` (бүгд `@clinova.local`)

**Нууц:**

- `DEMO_DOCTOR_PASSWORD` заасан бол бүх 10 эмчид ижил нууц тохируулагдана (idempotent seed дахин ажиллуулахад шинэчлэгдэнэ).
- Хоосан бол анхны ажиллуулалтад эмч бүрт **өөр санамсаргүй нууц** үүсгэгдэнэ. Утгууд зөвхөн **`clinova-backend/seed-output/doctor-credentials.local.json`** файлд бичигдэж, консоль дээр нууц хэвлэгдэхгүй.
- Дахин seed хийхэд хуучин эмчийн нууц **хадгалагдана** (`DEMO_DOCTOR_PASSWORD` биш бол hash өөрчлөхгүй).

Нэвтрэхдээ **бүтэн имэйл** эсвэл **username** (`doctor.enkhbayar` гэх мэт) ашиглана.

## Хуучин bootstrap roster (устгах / идэвхгүй болгох)

`demo.doctor01@clinova.local` … `demo.doctor08@`, `demo.doctor@clinova.local` зэрэг хуучин данс **програм асаахад автоматаар үүсэхгүй**. Идэвхгүй болгох:

```bash
cd clinova-backend && npm run cleanup:demo-doctors
```

## Demo нэг эмч / өвчтөн — зөвхөн `SEED_DEMO_ACCOUNTS_ON_BOOT=true` үед

`.env.example` дахь `DEMO_DOCTOR_EMAIL`, `DEMO_PATIENT_EMAIL` зэрэг нь энэ тунахыг идэвхжүүлсэн үед л гарч ирнэ. Production-д ихэвчлэн **`SEED_DEMO_ACCOUNTS_ON_BOOT=false`** (default).

## Өвчтөн seed (3 demo)

`demo.patient1@clinova.local` гэх мэт — нууц нь `DEMO_PATIENT_PASSWORD` эсвэл default `ClinovaPatient123!`.

**Жинхэнэ өвчтөн** вэбээр **`POST /auth/register`** + OTP (эсвэл `REGISTER_SKIP_EMAIL_VERIFICATION=true` зөвхөн dev).

## Илгээмж (OTP)

Production: `EMAIL_DEBUG=false`, `OTP_DEBUG=false`. Gmail App Password эсвэл Resend — `.env.example` харна уу.
