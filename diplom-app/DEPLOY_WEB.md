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

## 3) Frontend — Vercel (Flutter web)

Vercel project **Root Directory**: `diplom-app` (моно repo бол заавал тохируулна).

Билдийн env (**Settings → Environment Variables**):

| Variable | Яагаад хэрэгтэй |
|---------|----------------|
| **`API_BASE_URL`** | Продукт бэкендийн base (жишээ `https://clinova-api.onrender.com`) |
| **`SITE_BASE_URL`** | Ижил домэйний веб сайт (`https://таны-про.vercel.app` эсвэл custom domain); **canonical, sitemap, robots** үүсгэнэ |
| Опционал | `REALTIME_BASE_URL`, `GOOGLE_CLIENT_ID`, `FIREBASE_WEB_*` |

`vercel.json` нь биелүүлэгч: **`tool/vercel_flutter_build.sh`** (үлдэхийг машин Linux дээр Flutter stable clone хийж билдлэнэ; эхэн удаагийн билд их цаг авч болно).

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
