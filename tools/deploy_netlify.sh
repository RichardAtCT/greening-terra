#!/usr/bin/env bash
# Exports the web build and publishes it to Netlify, where the game is its own page, so Safari
# keeps its saves (inside itch.io's cross-site iframe it doesn't).
#   tools/deploy_netlify.sh             export + publish
#   tools/deploy_netlify.sh --no-export publish the existing build/web
# Needs NETLIFY_SITE_ID (kept out of this public repo so the URL stays unlisted), Node 22+, and a
# `netlify login` (or NETLIFY_AUTH_TOKEN in the environment).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -z "${NETLIFY_SITE_ID:-}" ]; then
  echo "Set NETLIFY_SITE_ID to the Netlify site's ID." >&2
  exit 1
fi

if [ "${1:-}" != "--no-export" ]; then
  "$ROOT/tools/export_web.sh"
fi
test -f build/web/index.html || { echo "No build/web/index.html; run without --no-export" >&2; exit 1; }

# Keep the unlisted URL out of search engines.
printf '/*\n  X-Robots-Tag: noindex, nofollow\n' > build/web/_headers

# Netlify injects a "Powered by Netlify" badge (and, for the owner, a toolbar) as a fixed iframe
# over the bottom-right corner of the game. Hide both.
if ! grep -q 'nl-badge-frame' build/web/index.html; then
  sed -i.bak 's|</head>|<style>#nl-badge-frame,#nl-hud-frame{display:none!important}</style></head>|' \
    build/web/index.html
  rm build/web/index.html.bak
fi

npx --yes netlify-cli@27 deploy --dir build/web --prod --no-build --site "$NETLIFY_SITE_ID" \
  --message "$(git describe --tags --always --dirty 2>/dev/null || true)"
