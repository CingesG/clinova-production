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

DEFINES=(
  "--dart-define=API_BASE_URL=${API_BASE_URL}"
)

[[ -z "${REALTIME_BASE_URL:-}" ]] || DEFINES+=("--dart-define=REALTIME_BASE_URL=${REALTIME_BASE_URL}")

[[ -z "${GOOGLE_CLIENT_ID:-}" ]] || DEFINES+=("--dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}")

for key in FIREBASE_WEB_API_KEY FIREBASE_WEB_AUTH_DOMAIN FIREBASE_WEB_PROJECT_ID \
           FIREBASE_WEB_STORAGE_BUCKET FIREBASE_WEB_MESSAGING_SENDER_ID \
           FIREBASE_WEB_APP_ID FIREBASE_WEB_MEASUREMENT_ID; do
  val="${!key:-}"
  [[ -z "$val" ]] || DEFINES+=("--dart-define=${key}=${val}")
done

flutter build web --release "${DEFINES[@]}"
echo "Output: ${ROOT}/build/web"
