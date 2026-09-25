#!/usr/bin/env bash
# Exports the "Web" preset headless into build/web/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$("$ROOT/tools/godot_bin.sh")"
cd "$ROOT"
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release "Web" build/web/index.html
test -f build/web/index.wasm || { echo "Export failed: build/web/index.wasm missing" >&2; exit 1; }
echo "Exported to build/web/ ($(du -sh build/web | cut -f1))"
