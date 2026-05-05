#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${API_BASE_URL:-}" ]]; then
  echo "Error: API_BASE_URL is required for a production web build." >&2
  echo "Example: API_BASE_URL=https://api.example.com $0" >&2
  exit 1
fi

if [[ -z "${SITE_BASE_URL:-}" ]]; then
  echo "Warning: SITE_BASE_URL хоосон — Google-д sitemap/canonical бүрэн биш. Vercel URL-аа заана уу." >&2
fi

bash tool/render_seo_assets.sh

INDEX_BACKUP="${ROOT}/web/.index.html.before_google_inject"
restore_index() {
  if [[ -f "${INDEX_BACKUP}" ]]; then
    mv "${INDEX_BACKUP}" "${ROOT}/web/index.html"
  fi
}
trap restore_index EXIT

cp "${ROOT}/web/index.html" "${INDEX_BACKUP}"
if [[ -n "${GOOGLE_CLIENT_ID:-}" ]]; then
  bash tool/inject_google_signin_meta.sh "$ROOT" "${GOOGLE_CLIENT_ID}"
else
  echo "Warning: GOOGLE_CLIENT_ID хоосон — вэб дээр Google нэвтрэлт ажиллахгүй (tool/inject_google_signin_meta.sh алгассан)." >&2
fi

DEFINES=(
  "--dart-define=API_BASE_URL=${API_BASE_URL}"
)

[[ -z "${SITE_BASE_URL:-}" ]] || DEFINES+=("--dart-define=SITE_BASE_URL=${SITE_BASE_URL}")

[[ -z "${REALTIME_BASE_URL:-}" ]] || DEFINES+=("--dart-define=REALTIME_BASE_URL=${REALTIME_BASE_URL}")

[[ -z "${GOOGLE_CLIENT_ID:-}" ]] || DEFINES+=("--dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}")

for key in FIREBASE_WEB_API_KEY FIREBASE_WEB_AUTH_DOMAIN FIREBASE_WEB_PROJECT_ID \
           FIREBASE_WEB_STORAGE_BUCKET FIREBASE_WEB_MESSAGING_SENDER_ID \
           FIREBASE_WEB_APP_ID FIREBASE_WEB_MEASUREMENT_ID; do
  val="${!key:-}"
  [[ -z "$val" ]] || DEFINES+=("--dart-define=${key}=${val}")
done

flutter build web --release "${DEFINES[@]}"
echo "Output: ${ROOT}/build/web (manifest.json, icons/, flutter_service_worker.js included for PWA)."
