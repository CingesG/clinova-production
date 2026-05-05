# Clinova production deploy — задарсан алхмууд

Фронт: **Flutter web** (моно репонд `diplom-app/`).  
Бэкенд: **NestJS + Prisma** (`clinova-backend/`).

## 0) Яаралтай аюулгүй байдал

- Өмнө `.env`/чат/GitHub дээр илэрсэн **OpenAI key, Gmail app password, JWT secret** зэргээ **буцааж солино** — production дээр шинэ key-үүд л ашиглана.
- **`.env` файлыг commit хийж болохгүй** (`clinova-backend/.gitignore` хамгаалсан).

## 1) Үүлэн PostgreSQL ба Prisma migrate

Жишээ: [Neon](https://neon.tech), Supabase Postgres, Render Postgres.  
Dashboard-ээс **`DATABASE_URL`** connection string авна (`postgresql://…`).

## 2) Backend — Render дээр (эсвэл Railway)

Repo root-д `render.yaml` жишээ байна (**`rootDir: clinova-backend`**). Render дээр Blueprint эсвэл гараар Web Service үүсгэнэ:

- **Root Directory**: `clinova-backend`
- **Build (санал болгох)**: `npm ci && npx prisma generate && npx prisma migrate deploy && npm run build`
- **Start**: `npm run start:prod` (`start:prod` нь `node dist/main.js` — Nest `main.ts`→`dist/main.js`)
- **Анхаар**: Production-д **`prisma migrate deploy`** ашиглана. Түргэн локал/demo reset-д л `prisma db push` тохиромжтой. Шинэ DB дээр migrate дараа нь нэг удаа **`npm run prisma:seed`** (заавал биш, demo өгөгдөл хэрэгтэй бол).
- Үүлэн **`PORT`** ихэвчлэн автоматаар өгөгддөг; код `process.env.PORT` уншина.

**Environment variables** (үлгэр — бодит утгууд зөвхөн dashboard-д):

| Variable | Анхаарах зүйл |
|----------|----------------|
| `NODE_ENV` | `production` |
| `DATABASE_URL` | PostgreSQL URI |
| `JWT_SECRET` | урт санамсаргүй |
| `FRONTEND_URL` | түүхий веб URL (**trailing slash битгий**), жишээ `https://clinova-xxxx.vercel.app` |
| `CORS_ORIGIN` | Шаардлагатай бол коммаар (`https://clinova.mn,https://www.clinova.mn`) |
| `ALLOW_LEGACY_DEV_CORS` | production-д ихэвчлэн `false` (localhost/ngrok руу засагдана хэрэв `true`) |
| `OPENAI_API_KEY` | Шинэ key |
| `STRIPE_SECRET_KEY` | Live эсвэл test (дипломд test хүртэл) |
| SMTP keys | Gmail app password **шинэ** |
| Seed/admin зэрэг | Үглэсэн үлгэр см `clinova-backend/.env.example` |

Nest дээр `NODE_ENV=production` байх үед браузероос зөвхөн **`FRONTEND_URL`** / **`CORS_ORIGIN`**-д зөвшөөрөлтэй (**REST + Socket.IO realtime** адил жагсаалт).

Realtime / chat ажиллахын тулд фронт дээр `REALTIME_BASE_URL` ихэвчлэн API-тай ижил домэйн байхад хангалттай (`Env.dart`-д `REALTIME_BASE_URL`-г билдийн `dart-define`-аар API-тай адил өгөх).

## 3) Frontend — Vercel (**зөвхөн Flutter web**; backend Render дээр тусдаа)

### 3.0 Эхний deploy-д хэрэгтэй хоёр URL (`Environment Variables`)

Билдийн үед **заавал** Vercel **Settings → Environment Variables** дотор (Production-д) орно:

| Хувьсагч | Утгыг юугаар бөглөх вэ |
|----------|--------------------------|
| **`API_BASE_URL`** | Render дээрх backend-ийн гол URL (**суурь төгсгөл, trailing slash байхгүй**). Backend URL хараахан байхгүй байвал түр placeholder ашиглаж болно. |
| **`SITE_BASE_URL`** | Энэ Vercel вэб аппын бүтэн URL (**trailing slash байхгүй**). SEO (`robots.txt`, `sitemap.xml`, canonical / Open Graph)-д орно. |

**Түр жишээ (эхний deploy, бодит URL гармагц шинэчил)**:

```text
API_BASE_URL=https://clinova-api-production.onrender.com
SITE_BASE_URL=https://clinova-production.vercel.app
```

Утгыг **`API_BASE_URL`**, **`SITE_BASE_URL`**‑аараа солиод дахин **Redeploy** хийнэ (**Deployments**‑оос эсвэл `main`-д хоосон commit push). Мөн Render дээр **`FRONTEND_URL`** (ба шаардлагатай **`CORS_ORIGIN`**)‑ийг **фронтын бодит Vercel URL**-тай тохируулна — эс бөгөөс браузерыг **CORS**-оор блоклох болно.

### 3.1 Vercel Project Settings (дашбоард)

Репонд `diplom-app/vercel.json` аль хэдийн **build / output / rewrites**-ийг уншана. Dashboard дээр доорхийг давхар шалга (эсвэл override хий):

| Талбар | Утга |
|--------|------|
| **Root Directory** | `diplom-app` (**монорепоны үед заавал**; зөвхөн энэ хавтаст билдэгдэнэ) |
| **Build Command** | `bash tool/vercel_flutter_build.sh` (өөрчлөөгүй бол `vercel.json`-оос автоматаар) |
| **Output Directory** | `build/web` |
| **Install Command** | `exit 0` эсвэл хоосон (`vercel.json` доторхыг үлдээж болно; Flutter-ийг энэ скрипт дотор clone хийнэ) |
| **Framework Preset** | Other / тохируулаагүй (Flutter гэж сонгоно гэж алга) |

Биелэгдэх файл: **`tool/vercel_flutter_build.sh`** — Linux билд машин дээр stable **Flutter clone** хийж `flutter build web --release`-д дээрх env-ээс **`--dart-define=API_BASE_URL=…`** дамжуулна, **`SITE_BASE_URL`**-ийг **`tool/render_seo_assets.sh`** дамжуулаад SEO файл үүсгэнэ (**эхэн удаагийн билд удаж болно**).

**Нэмэлт env (сонголтын)** — онцлон Google/Firebase вэб эсвэл realtime өөр суурьтой бол:

| Variable |
|----------|
| `REALTIME_BASE_URL` (ихэвчлэн `API_BASE_URL`-тай ижил үлдээвэл оруулаагүй үлдээж болно) |
| **`GOOGLE_CLIENT_ID`** (Vercel **Production** — заавал; доор Google Cloud хэсэг) |
| `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_AUTH_DOMAIN`, `FIREBASE_WEB_PROJECT_ID`, `FIREBASE_WEB_STORAGE_BUCKET`, `FIREBASE_WEB_MESSAGING_SENDER_ID`, `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_MEASUREMENT_ID` |

### 3.2 Google Sign-In (OAuth) — Flutter web + бэкенд

**Vercel (frontend билд)**

| Variable | Утга |
|----------|------|
| `GOOGLE_CLIENT_ID` | Google Cloud Console-ийн **Web application** OAuth client ID (`*.apps.googleusercontent.com`). **`VERCEL=1`** билдэд хоосон бол билд унаж, `tool/vercel_flutter_build.sh` алдаа өгнө. |
| `API_BASE_URL` | `https://clinova-api-production.onrender.com` (эсвэл өөрийн API) |
| `SITE_BASE_URL` | `https://clinova-production.vercel.app` (эсвэл өөрийн Vercel URL) |

Билдийн үед `web/index.html` доторх `__GOOGLE_SIGNIN_CLIENT_ID__` placeholder нь `GOOGLE_CLIENT_ID`-аар солиогдож, Flutter-д `--dart-define=GOOGLE_CLIENT_ID=…` дамжина.

**Render (backend)**

| Variable | Утга |
|----------|------|
| `GOOGLE_CLIENT_ID` | Ижил **Web** OAuth client ID (жишээ нь `xxxxx.apps.googleusercontent.com`) |
| `GOOGLE_CLIENT_IDS` | Олон client (iOS/Android + web) зэрэгцүүлэх бол коммаар: `web-id.apps.googleusercontent.com,ios-id.apps.googleusercontent.com` — id_token `aud`-ийг `google-auth-library` энд тааруулна |

Бэкенд: `POST /auth/google` санаар `{ "idToken": "…" }` — OTP шаардахгүй, шинэ хэрэглэгчийг **PATIENT** + `patientProfile`-той автоматаар үүсгэнэ (`phoneNumber` хоосон байж болно).

**Google Cloud Console — тохиргоо (бүх бодит хэрэглэгч нэвтрэх)**

1. **APIs & Services → OAuth consent screen**: **User type = External** (жижиг түгжилтгүй продукт бол).
2. **Publishing status**:
   - **Testing** байвал зөвхөн **Test users** жагсаалтад орсон Gmail-үүд нэвтэрнэ — өөр хэрэглэгчид блоклогдоно.
   - **Бүх хэрэглэгч** зөвшөөрөхийн тулд **Publish → Production** (verification шаардлага гарч болно).
3. **Credentials → OAuth 2.0 Client IDs**:
   - Flutter **web** / Vercel-д **Web application** client ашиглана (Android/iOS client биш).
4. **Authorized JavaScript origins** (дор хаяж):
   - `https://clinova-production.vercel.app`
   - `http://localhost:3164` (локал хөгжүүлэлт)
5. Хөгжүүлэлтийн **redirect URIs** өөрийн портуудтай нийцүүлнэ (Flutter web ихэвчлэн popup/one tap — Console-ийн заавартай).

**Локаль `flutter build web` жишээ**

```bash
cd diplom-app
flutter clean && flutter pub get
flutter build web --release \
  --dart-define=API_BASE_URL=https://clinova-api-production.onrender.com \
  --dart-define=SITE_BASE_URL=https://clinova-production.vercel.app \
  --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Локальд `web/index.html` дахь meta-д placeholder үлдэнэ бол **эсвэл** дээрхийг ажиллуулаасан өмнө `tool/inject_google_signin_meta.sh`-аар орлуул **эсвэл** `bash tool/build_web_release.sh`-д `GOOGLE_CLIENT_ID` зааж билд хийнэ (скрипт meta-г автоматаар inject хийж, дараа нь `index.html`-ийг сэргээнэ).

Локально ижил утгуудаар шалгах:

```bash
cd diplom-app
export API_BASE_URL="https://your-api-host"
export SITE_BASE_URL="https://your-vercel-domain"
bash tool/build_web_release.sh   # flutter build web + SEO
```

**PWA одоо аль хэдийн:** `web/manifest.json` (`standalone`, `/` start URL), `flutter build web`-ийн сервис воркер, iOS дээр Safari → Хуваалцах → **Нүүрэн дэлгэцэнд нэмэх**.

### Custom domain

Vercel **Domains**: `clinova.mn`, `www` → DNS A/CNAME заавартай нэмнэ.

## 4) DNS / HTTPS

Бэкенд (`api.…`), фронт (`www`/apex) аль алинд нь проваайдерийн гаргалт автоматаар **HTTPS**.

## 5) Google Search / SEO (дипломын шоукейс)

1. **`robots.txt` / `sitemap.xml`** билдийн үед `SITE_BASE_URL` заасан байх үед `tool/render_seo_assets.sh` үүсгэнэ.
2. [Google Search Console](https://search.google.com/search-console) — өөрийн домэйнээр нэвтэрч **Sitemaps** → `https://таны-домэйн/sitemap.xml` submit хий.
3. **Индекс** нь SPA Flutter дээр бүрэн найдвартай биш боловч title/description/canonical ба sitemap хангалтанд ойртуулна.

## 6) Альтернатив: гар дээр билд хийгээд Vercel рүү ачаалах

Таны компьютер дээр Flutter суусан бол:

```bash
cd diplom-app
export SITE_BASE_URL="https://YOUR_DOMAIN"; export API_BASE_URL="https://YOUR_API"
bash tool/build_web_release.sh
```

Дараа нь `build/web`-ийг Vercel **Static Upload** эсвэл CI-ийн артефакт дамжуулаарай (`vercel deploy --prebuilt` гэх мэт).

---

## Нэмэлт анхааруулга

Google Sign-In **web**-д Firebase web түлхүүр (`FIREBASE_WEB_*`) + `GOOGLE_CLIENT_ID` билдийн `dart-define` шаардлагатай бол тусад нь нэмнэ (`lib/config/env.dart`).
