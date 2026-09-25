#!/usr/bin/env bash
# Exports the web build and pushes it to itch.io with butler.
#   tools/deploy.sh             export + push
#   tools/deploy.sh --no-export push the existing build/web
# Needs butler on PATH (or BUTLER=/path/to/butler) and a one-off `butler login`
# (or BUTLER_API_KEY in the environment).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ITCH_TARGET:-richardat/greening-tessera:web}"
BUTLER="${BUTLER:-butler}"
cd "$ROOT"

if ! command -v "$BUTLER" >/dev/null 2>&1; then
  echo "butler not found. Install it from https://itch.io/docs/butler/ or set BUTLER=/path/to/butler" >&2
  exit 1
fi

if [ "${1:-}" != "--no-export" ]; then
  "$ROOT/tools/export_web.sh"
fi
test -f build/web/index.html || { echo "No build/web/index.html; run without --no-export" >&2; exit 1; }

VERSION="$(git describe --tags --always --dirty 2>/dev/null || date +%Y%m%d%H%M)"
"$BUTLER" push build/web "$TARGET" --userversion "$VERSION"
"$BUTLER" status "$TARGET" || true
