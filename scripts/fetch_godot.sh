#!/usr/bin/env bash
# Fetch a Godot editor binary and matching export templates.
# Editor and template versions must match exactly or the export fails.
#
# If you already have Godot installed, you do not need the editor half of this.
# Point GODOT_BIN at it and this script installs only the templates:
#
#   GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot scripts/fetch_godot.sh
#
# CI wants the two halves separately, so it can cache them under different keys
# and skip the enormous template archive once a slim template is available:
#
#   --editor-only      fetch the editor, leave templates alone
#   --templates-only   fetch templates, leave the editor alone
#   --web-only         after unpacking, keep only the web templates (~40 MB
#                      instead of ~3 GB, which is the difference between a
#                      cacheable directory and one that is not)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_ROOT/.godot-bin"

WANT_EDITOR=1
WANT_TEMPLATES=1
WEB_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --editor-only) WANT_TEMPLATES=0 ;;
    --templates-only) WANT_EDITOR=0 ;;
    --web-only) WEB_ONLY=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# An externally supplied editor decides the version — templates must match it,
# not a pin in this file.
if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
  # "4.7.1.stable.official.a13da4fe" -> "4.7.1-stable"
  detected="$("$GODOT_BIN" --version | head -1)"
  GODOT_VERSION="${GODOT_VERSION:-$(echo "$detected" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z]+).*/\1-\3/')}"
  echo "editor: using $GODOT_BIN ($detected)"
  FETCH_EDITOR=0
else
  GODOT_VERSION="${GODOT_VERSION:-4.7.1-stable}"
  GODOT_BIN="$BIN_DIR/godot"
  FETCH_EDITOR=1
fi

# Godot names the template directory with a dot, not a dash: 4.7.1-stable -> 4.7.1.stable
TEMPLATE_DIR_NAME="${GODOT_VERSION/-/.}"

# Godot reads templates from a different place on each platform. Writing to the
# Linux path on macOS installs them where the editor will never look.
case "$(uname -s)" in
  Darwin)
    TEMPLATES_ROOT="$HOME/Library/Application Support/Godot/export_templates"
    EDITOR_ZIP="Godot_v${GODOT_VERSION}_macos.universal.zip"
    EDITOR_INNER="Godot.app/Contents/MacOS/Godot"
    ;;
  Linux)
    TEMPLATES_ROOT="$HOME/.local/share/godot/export_templates"
    EDITOR_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    EDITOR_INNER="Godot_v${GODOT_VERSION}_linux.x86_64"
    ;;
  *)
    echo "unsupported platform: $(uname -s) — install Godot yourself and set GODOT_BIN" >&2
    exit 1
    ;;
esac

TEMPLATES_DIR="$TEMPLATES_ROOT/$TEMPLATE_DIR_NAME"
BASE_URL="https://github.com/godotengine/godot/releases/download/$GODOT_VERSION"
TEMPLATES_TPZ="Godot_v${GODOT_VERSION}_export_templates.tpz"

if [[ "$FETCH_EDITOR" == 1 && "$WANT_EDITOR" == 1 ]]; then
  mkdir -p "$BIN_DIR"
  if [[ -x "$GODOT_BIN" ]]; then
    echo "editor: already present ($("$GODOT_BIN" --version 2>/dev/null || echo unknown))"
  else
    echo "editor: downloading $EDITOR_ZIP"
    curl -fL --retry 4 --retry-delay 2 -o "$BIN_DIR/$EDITOR_ZIP" "$BASE_URL/$EDITOR_ZIP"
    unzip -q -o "$BIN_DIR/$EDITOR_ZIP" -d "$BIN_DIR"
    mv "$BIN_DIR/$EDITOR_INNER" "$GODOT_BIN"
    chmod +x "$GODOT_BIN"
    rm -f "$BIN_DIR/$EDITOR_ZIP"
    echo "editor: installed $("$GODOT_BIN" --version)"
  fi
fi

if [[ "$WANT_TEMPLATES" == 1 ]]; then
  if [[ -f "$TEMPLATES_DIR/web_release.zip" ]]; then
    echo "templates: already present in $TEMPLATES_DIR"
  else
    echo "templates: downloading $TEMPLATES_TPZ (~1.2 GB, all platforms in one archive)"
    mkdir -p "$TEMPLATES_ROOT"
    tmp="$(mktemp -d)"
    curl -fL --retry 4 --retry-delay 2 -o "$tmp/templates.tpz" "$BASE_URL/$TEMPLATES_TPZ"
    # A .tpz is a zip whose single top-level directory is literally named "templates".
    # It has to be renamed to the version string or Godot reports "no export template found"
    # while the files sit right there.
    unzip -q -o "$tmp/templates.tpz" -d "$tmp"
    rm -rf "$TEMPLATES_DIR"
    mv "$tmp/templates" "$TEMPLATES_DIR"
    rm -rf "$tmp"
    echo "templates: installed to $TEMPLATES_DIR"
  fi

  if [[ "$WEB_ONLY" == 1 ]]; then
    # version.txt has to survive the cull: without it Godot decides the whole
    # directory is not a template set and reports none installed.
    find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 \
      ! -name 'web_*' ! -name 'version.txt' -exec rm -rf {} +
    echo "templates: pruned to web only ($(du -sh "$TEMPLATES_DIR" | cut -f1))"
  fi
fi

echo
echo "godot binary : $GODOT_BIN"
echo "templates    : $TEMPLATES_DIR"
