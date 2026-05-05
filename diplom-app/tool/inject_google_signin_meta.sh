#!/usr/bin/env bash
# Replace __GOOGLE_SIGNIN_CLIENT_ID__ in web/index.html with GOOGLE_CLIENT_ID.
# Usage: inject_google_signin_meta.sh REPO_ROOT "CLIENT_ID"
set -euo pipefail
ROOT="${1:?root required}"
export INJECT_ROOT="$ROOT"
export INJECT_GOOGLE_CID="${2:?client id required}"
INDEX="${ROOT}/web/index.html"
if [[ ! -f "$INDEX" ]]; then
  echo "inject_google_signin_meta: missing ${INDEX}" >&2
  exit 1
fi
if ! grep -q '__GOOGLE_SIGNIN_CLIENT_ID__' "$INDEX"; then
  echo "inject_google_signin_meta: placeholder __GOOGLE_SIGNIN_CLIENT_ID__ not found in index.html" >&2
  exit 1
fi
python3 - <<'PY'
import pathlib, os, sys
root = pathlib.Path(os.environ["INJECT_ROOT"])
cid = os.environ["INJECT_GOOGLE_CID"].strip()
if not cid:
    sys.exit("inject_google_signin_meta: empty client id")
index = root / "web" / "index.html"
text = index.read_text(encoding="utf-8")
ph = "__GOOGLE_SIGNIN_CLIENT_ID__"
if ph not in text:
    sys.exit("inject_google_signin_meta: placeholder missing")
index.write_text(text.replace(ph, cid), encoding="utf-8")
PY
