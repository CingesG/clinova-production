#!/usr/bin/env bash
# Vercel дээр Flutter web билд (Linux). Project root: diplom-app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FL="${HOME}/flutter_vercel_stable"
export PATH="$FL/bin:${PATH}"

if [[ ! -x "$FL/bin/flutter" ]]; then
  rm -rf "$FL"
  git clone https://github.com/flutter/flutter.git -b stable "$FL" --depth 1
fi

flutter config --enable-web --no-analytics
flutter precache --web
flutter pub get

# Vercel env-ээр дамжуулаагүй тохиолдолд бодит production backend / фронтын URL (placeholder биш).
export API_BASE_URL="${API_BASE_URL:-https://clinova-api-production.onrender.com}"
export SITE_BASE_URL="${SITE_BASE_URL:-https://clinova-production.vercel.app}"

if [[ "${VERCEL:-}" == "1" ]] && [[ -z "${GOOGLE_CLIENT_ID:-}" ]]; then
  echo "Error: Vercel Flutter web билдэд GOOGLE_CLIENT_ID environment variable заавал (OAuth Web client ID)." >&2
  echo "Vercel: Settings → Environment Variables → GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com" >&2
  exit 1
fi

bash tool/render_seo_assets.sh

if [[ -n "${GOOGLE_CLIENT_ID:-}" ]]; then
  bash tool/inject_google_signin_meta.sh "$ROOT" "${GOOGLE_CLIENT_ID}"
fi

DEFINES=(
  --dart-define=API_BASE_URL="${API_BASE_URL}"
  --dart-define=SITE_BASE_URL="${SITE_BASE_URL}"
  --dart-define=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
)
[[ -z "${REALTIME_BASE_URL:-}" ]] || DEFINES+=(--dart-define=REALTIME_BASE_URL="${REALTIME_BASE_URL}")

for key in FIREBASE_WEB_API_KEY FIREBASE_WEB_AUTH_DOMAIN FIREBASE_WEB_PROJECT_ID \
           FIREBASE_WEB_STORAGE_BUCKET FIREBASE_WEB_MESSAGING_SENDER_ID \
           FIREBASE_WEB_APP_ID FIREBASE_WEB_MEASUREMENT_ID; do
  v="${!key:-}"
  [[ -z "$v" ]] || DEFINES+=(--dart-define="${key}=${v}")
done

# PWA strategy none: avoid stale service-worker JS after deploy (see index.html version.json).
flutter build web --release --pwa-strategy=none "${DEFINES[@]}"

# Cache-bust marker for optional SW cleanup in index.html (when SW enabled later).
BUILD_ID="$(date -u +%Y%m%d%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo local)"
echo "{\"version\":\"${BUILD_ID}\"}" > build/web/version.json

echo "Build complete: build/web (PWA strategy: none; CanvasKit bundled on origin)."
