#!/usr/bin/env bash
# Export the web build to build/web/.
#
#   scripts/build_web.sh            release build
#   scripts/build_web.sh --debug    debug build (bigger, with the console)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$REPO_ROOT/.godot-bin/godot}"
OUT_DIR="$REPO_ROOT/build/web"

MODE="--export-release"
if [[ "${1:-}" == "--debug" ]]; then
  MODE="--export-debug"
fi

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "godot not found at $GODOT_BIN — run scripts/fetch_godot.sh first" >&2
  exit 1
fi

# build/ holds export output and screenshots. Without a .gdignore the editor
# imports those PNGs as project assets and packs them into the very build that
# produced them.
mkdir -p "$REPO_ROOT/build"
touch "$REPO_ROOT/build/.gdignore"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Import first so the export doesn't race the filesystem scan.
"$GODOT_BIN" --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true

"$GODOT_BIN" --headless --path "$REPO_ROOT" "$MODE" "Web" "$OUT_DIR/index.html"

echo
echo "exported to $OUT_DIR"
du -sh "$OUT_DIR"
ls -1 "$OUT_DIR"
