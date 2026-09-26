#!/usr/bin/env bash
# Exports the "Web" preset headless into build/web/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$("$ROOT/tools/godot_bin.sh")"
cd "$ROOT"
rm -rf build/web && mkdir -p build/web
# The exporter caches each text resource's binary conversion in .godot/exported and doesn't redo it
# when only the resource's script changed, so a stale build can miss data. Start clean every time.
rm -rf "$ROOT/.godot/exported"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release "Web" build/web/index.html
test -f build/web/index.wasm || { echo "Export failed: build/web/index.wasm missing" >&2; exit 1; }
# Lets a newly deployed version take over as soon as the page asks (see WebUpdate), instead of
# after every copy of the game is closed. Godot's service worker has no such listener.
cat >> build/web/index.service.worker.js <<'JS'

self.addEventListener('message', (event) => {
	if (event.data === 'skip-waiting') {
		self.skipWaiting();
	}
});
JS
echo "Exported to build/web/ ($(du -sh build/web | cut -f1))"
