#!/usr/bin/env bash
# Prints the Godot binary to use: $GODOT if set, else tools/godot/godot, else godot on PATH.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -n "${GODOT:-}" ]; then echo "$GODOT"
elif [ -x "$ROOT/tools/godot/godot" ]; then echo "$ROOT/tools/godot/godot"
elif command -v godot >/dev/null 2>&1; then command -v godot
else echo "Godot not found. Run tools/setup_godot.sh or set GODOT=/path/to/godot" >&2; exit 1
fi
