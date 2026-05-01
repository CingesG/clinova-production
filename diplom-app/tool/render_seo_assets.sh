#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SITE_BASE="${SITE_BASE_URL:-}"
SITE_BASE="$(echo -n "${SITE_BASE}" | sed 's:/*$::')"
export _CLINOVA_SITE_BASE="${SITE_BASE}"

python3 <<'PY'
import os
import re
from pathlib import Path

root = Path.cwd()
site = os.environ.get("_CLINOVA_SITE_BASE", "").strip().rstrip("/")

inject_pat = re.compile(
    r"(<!-- CLINOVA_SEO_INJECT_BEGIN -->).*?(<!-- CLINOVA_SEO_INJECT_END -->)",
    re.DOTALL,
)

index_path = root / "web" / "index.html"
text = index_path.read_text(encoding="utf-8")

if not inject_pat.search(text):
    raise SystemExit("Missing CLINOVA_SEO_INJECT_BEGIN/END markers in web/index.html")

if not site:
    inner = (
        "  <!-- SITE_BASE_URL билдийн env-д (жишээ https://your-app.vercel.app) заана "
        "→ canonical + sitemap + og:url үүснэ -->"
    )
    (root / "web" / "robots.txt").write_text(
        "User-agent: *\nAllow: /\n\n"
        "# Продакшн билдийн өмнө: export SITE_BASE_URL=https://...\n",
        encoding="utf-8",
    )
    sm = root / "web" / "sitemap.xml"
    if sm.exists():
        sm.unlink()
else:
    base = site
    routes = ["", "/welcome", "/auth/login"]
    urls = "".join(
        "  <url><loc>%s%s</loc><changefreq>weekly</changefreq>"
        "<priority>0.85</priority></url>\n" % (base, p)
        for p in routes
    )
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{urls}"
        "</urlset>\n"
    )
    (root / "web" / "sitemap.xml").write_text(body, encoding="utf-8")
    (root / "web" / "robots.txt").write_text(
        "User-agent: *\nAllow: /\nDisallow:\n\n" + f"Sitemap: {base}/sitemap.xml\n",
        encoding="utf-8",
    )
    desc = (
        "Clinova — smart AI healthcare appointments, realtime chat, "
        "and patient management."
    )
    inner = f"""  <link rel=\"canonical\" href=\"{base}/\" />
  <meta property=\"og:url\" content=\"{base}/\" />
  <meta property=\"og:type\" content=\"website\" />
  <meta property=\"og:title\" content=\"Clinova — Smart AI healthcare &amp; appointments\" />
  <meta property=\"og:description\" content=\"{desc}\" />
  <meta name=\"twitter:card\" content=\"summary_large_image\" />"""


def subst(m):
    end = (m.group(2) or "").strip()
    return f"{m.group(1)}\n{inner}\n  {end}"


index_path.write_text(inject_pat.sub(subst, text, count=1), encoding="utf-8")

if site:
    print(f"SEO: canonical, robots.txt, sitemap.xml → {site}/")
else:
    print("SEO: SITE_BASE_URL хоосон — canonical placeholder, sitemap үүсээгүй.")
PY
