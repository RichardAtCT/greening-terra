#!/usr/bin/env bash
# Downloads the pinned Godot editor (Linux x86_64 or macOS) and the web export
# templates into tools/godot/, and links the templates where Godot looks for them.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/tools/godot"
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
mkdir -p "$DEST"
cd "$DEST"

case "$(uname -s)" in
  Linux)
    BIN="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
    TPL_DIR="$HOME/.local/share/godot/export_templates"
    if [ ! -x "$BIN" ]; then
      curl -fSL -o editor.zip "$BASE/${BIN}.zip"
      unzip -o -q editor.zip && rm editor.zip
    fi
    ;;
  Darwin)
    BIN="Godot.app/Contents/MacOS/Godot"
    TPL_DIR="$HOME/Library/Application Support/Godot/export_templates"
    if [ ! -x "$BIN" ]; then
      curl -fSL -o editor.zip "$BASE/Godot_v${GODOT_VERSION}-stable_macos.universal.zip"
      unzip -o -q editor.zip && rm editor.zip
    fi
    ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

if [ ! -f templates/web_nothreads_release.zip ]; then
  curl -fSL -o templates.tpz "$BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  # Only the web templates are needed; skip the other ~1 GB of platforms.
  unzip -o -q templates.tpz 'templates/version.txt' 'templates/web_*'
  rm templates.tpz
fi

mkdir -p "$TPL_DIR"
ln -sfn "$DEST/templates" "$TPL_DIR/${GODOT_VERSION}.stable"
ln -sfn "$DEST/$BIN" "$DEST/godot"

echo "Godot ready: $DEST/godot ($("$DEST/godot" --version))"
