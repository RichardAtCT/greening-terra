#!/usr/bin/env bash
# Runs the GUT test suite headless. Extra arguments go to GUT (e.g. -gselect=test_movement).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$("$ROOT/tools/godot_bin.sh")"
cd "$ROOT"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless -s addons/gut/gut_cmdln.gd "$@"
