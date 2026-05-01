# Clinova Backend

## Run

1. `cp .env.example .env`
2. `npm install`
3. `npm run start:dev`

## OpenAI Setup (Clinova AI)

Add these to `.env`:

- `OPENAI_API_KEY=...`
- `OPENAI_MODEL=gpt-4o-mini` (эсвэл ашиглаж байгаа нээлттэй модель)

## Production deploy

Монорепо root: `../render.yaml` (жишээ Blueprint), дэлгэрэнгүй: `../diplom-app/DEPLOY_WEB.md`.

Main AI endpoint:

- `POST /api/ai/chat`
  - body: `{ "message": string, "conversationId"?: string, "userId"?: string }`
  - returns:
    - `reply`
    - `suggestions`
    - `recommendedServices`
    - `recommendedDoctors`
    - `availableSlots`
    - `riskLevel` (`low|medium|high|emergency`)

## Endpoints

- Auth
  - `POST /auth/request-otp`
  - `POST /auth/verify-otp`
  - `POST /auth/admin-login`
- Appointments
  - `GET /appointments/slots`
  - `POST /appointments`
- AI Agent
  - `POST /ai-agent/triage`
- Payments
  - `POST /payments/intent`
- Branches
  - `GET /branches`
- Jobs
  - `POST /jobs/apply`
  - `GET /jobs/applications` (admin)
  - `PATCH /jobs/applications/:id/invite` (admin)
- Emergency
  - `POST /emergency`
