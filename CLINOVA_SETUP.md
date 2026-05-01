# Clinova Production Starter

## 1) Project structure (frontend + backend)

```text
diplom/
  diplom-app/                 # Flutter mobile app
    lib/
      src/
        app/
        core/theme/
        features/
          splash/
          auth/
          home/
          appointments/
          ai_agent/
          admin/
          settings/
  clinova-backend/            # NestJS backend
    prisma/schema.prisma
    src/
      main.ts
      modules/
        app.module.ts
        auth/
        appointment/
        ai/
```

## 2) Flutter modules included

- Clean-ish feature-first structure with Riverpod and GoRouter.
- Implemented screens:
  - Splash, Auth, Home, Appointment, AI Agent, Admin, Settings.
- Language switch (`en`, `mn`) through Riverpod controller.

## 3) Backend modules included

- NestJS starter with modular controllers/services:
  - `auth`: request OTP, verify OTP, admin login.
  - `appointments`: get slots, create appointment.
  - `ai-agent`: triage and doctor/slot recommendation.
- Prisma schema includes core entities:
  - Users, Doctors, Branches, Departments, Appointments.

## 4) API endpoints

- `POST /auth/request-otp`
- `POST /auth/verify-otp`
- `POST /auth/admin-login`
- `GET /appointments/slots`
- `POST /appointments`
- `POST /ai-agent/triage`

## 5) AI agent logic

- `ai-agent` endpoint is implemented as an orchestration point.
- Current behavior:
  - Parses symptom text.
  - Infers department.
  - Returns doctor + slot suggestion.
  - Returns booking next action.
- Production upgrade:
  - Connect OpenAI function-calling.
  - Tools: `searchDoctors`, `getBranchLoad`, `checkSlots`, `bookAppointment`.
  - Add guardrails for emergency symptoms.

## 6) Setup instructions

### Flutter app

1. `cd /Users/chinges/diplom/diplom-app`
2. `flutter pub get`
3. `flutter run -d 39D6A9E3-7B8B-435B-8ECA-F55BB7AEBC28`

### Backend app

1. `cd /Users/chinges/diplom/clinova-backend`
2. `cp .env.example .env`
3. `npm install`
4. `npx prisma generate`
5. `npm run start:dev`

## 7) Environment variables

Defined in `clinova-backend/.env.example`:

- `PORT`
- `DATABASE_URL`
- `JWT_SECRET`
- `OPENAI_API_KEY`
- `STRIPE_SECRET_KEY`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- SMTP mail auth (see **`SMTP_*`** keys in `.env.example`)

## Admin credentials

- No demo credentials are hardcoded anymore.
- Set these values in backend `.env`:
  - `ADMIN_EMAIL`
  - `ADMIN_PASSWORD`
