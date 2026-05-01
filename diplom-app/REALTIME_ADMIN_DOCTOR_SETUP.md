# Clinova Realtime + Admin/Doctor Setup

This guide covers the exact values you need to run admin-created doctor accounts, realtime chat/call events, and Google web sign-in.

## 1) Backend `.env` (clinova-backend)

Эднийг **`clinova-backend/.env`** дотор тохируулна (яг нэршлүүдийг үлгэрчилсэн дүрсийг `clinova-backend/.env.example`-ээс үз):

- **`DATABASE_URL`** → PostgreSQL connection string (dashboard-ээс буулгана — Render / Neon / Supabase).
- **`JWT_SECRET`** → хүчтэй санамсаргүй утга (`openssl rand -base64 48` гэх мэт).
- **Access/token хугацаа** (`JWT_ACCESS_EXPIRES_IN`, `REFRESH_TOKEN_DAYS`) — үлгэрчилэл шиг үлдээж болно.
- **`DEFAULT_ADMIN_EMAIL`**, **`DEFAULT_ADMIN_PASSWORD`** → уулын орчны demo (production-д хүчтэй нууц).
- **`OPENAI_API_KEY`** → OpenAI платформыгээс үүссэн түлхүүр (голчлон `your_openai_api_key_here` гэж бичээд голыг локал `.env`-дээ наана).
- **`OPENAI_MODEL`** → жишээ: `gpt-4o-mini`
- **`GOOGLE_CLIENT_ID`** → Google Cloud Console OAuth Web Client ID (`…apps.googleusercontent.com`).

## 2) Google OAuth URL / Client ID

1. Open Google Cloud Console.
2. Create OAuth 2.0 Client ID (Web).
3. Add authorized origins:
   - `http://localhost:3000`
   - your production web URL
4. Add authorized redirect URI:
   - `https://<your-domain>/auth/callback`
5. Copy the generated **Client ID** into `GOOGLE_CLIENT_ID`.

## 3) Flutter Web `.env` / dart-define

Provide these app-side values when running web:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3001 \
  --dart-define=SOCKET_URL=http://localhost:3001/realtime \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
```

For release:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.your-domain.com \
  --dart-define=SOCKET_URL=https://api.your-domain.com/realtime \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
```

## 4) Admin-created doctor login

When Admin creates doctor:
- Admin enters `username` (recommended) and profile data.
- Backend generates a temporary password (or accepts manual one).
- Response includes:
  - `username`
  - `loginId`
  - `temporaryPassword`

Doctor signs in with either:
- `username` (for example `doctor.bat`) OR
- `loginId` (for example `doctor.bat@clinova.local`)

## 5) Realtime events available

- `chat:join`
- `chat:message`
- `chat:typing`
- `presence:changed`
- `call:join`
- `call:offer`
- `call:answer`
- `call:ice`
- `call:end`
- `appointments:booked`
- `appointments:updated`

## 6) Security notes

- Never commit `.env` or raw API keys.
- Share doctor temporary password securely and rotate after first sign-in.
- Use HTTPS in production for API and websocket endpoints.
