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
- **Build**: `npm ci && npx prisma generate && npm run build`
- **Start**: `npx prisma migrate deploy && node dist/main.js`
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
API_BASE_URL=https://clinova-api.onrender.com
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
| `GOOGLE_CLIENT_ID` |
| `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_AUTH_DOMAIN`, `FIREBASE_WEB_PROJECT_ID`, `FIREBASE_WEB_STORAGE_BUCKET`, `FIREBASE_WEB_MESSAGING_SENDER_ID`, `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_MEASUREMENT_ID` |

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
