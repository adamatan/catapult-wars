#!/usr/bin/env bash
# Fetch the pinned Godot editor binary and matching web export templates.
# Editor and template versions must match exactly or the export fails.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.6-stable}"
# Godot names the template directory with a dot, not a dash: 4.6-stable -> 4.6.stable
TEMPLATE_DIR_NAME="${GODOT_VERSION/-/.}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_ROOT/.godot-bin"
GODOT_BIN="$BIN_DIR/godot"
TEMPLATES_ROOT="$HOME/.local/share/godot/export_templates"
TEMPLATES_DIR="$TEMPLATES_ROOT/$TEMPLATE_DIR_NAME"

BASE_URL="https://github.com/godotengine/godot/releases/download/$GODOT_VERSION"
EDITOR_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
TEMPLATES_TPZ="Godot_v${GODOT_VERSION}_export_templates.tpz"

mkdir -p "$BIN_DIR"

if [[ -x "$GODOT_BIN" ]]; then
  echo "editor: already present ($("$GODOT_BIN" --version 2>/dev/null || echo unknown))"
else
  echo "editor: downloading $EDITOR_ZIP"
  curl -fsSL --retry 4 --retry-delay 2 -o "$BIN_DIR/$EDITOR_ZIP" "$BASE_URL/$EDITOR_ZIP"
  unzip -q -o "$BIN_DIR/$EDITOR_ZIP" -d "$BIN_DIR"
  mv "$BIN_DIR/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN"
  chmod +x "$GODOT_BIN"
  rm -f "$BIN_DIR/$EDITOR_ZIP"
  echo "editor: installed $("$GODOT_BIN" --version)"
fi

if [[ -f "$TEMPLATES_DIR/web_release.zip" ]]; then
  echo "templates: already present in $TEMPLATES_DIR"
else
  echo "templates: downloading $TEMPLATES_TPZ"
  mkdir -p "$TEMPLATES_ROOT"
  tmp="$(mktemp -d)"
  curl -fsSL --retry 4 --retry-delay 2 -o "$tmp/templates.tpz" "$BASE_URL/$TEMPLATES_TPZ"
  # A .tpz is a zip whose single top-level directory is literally named "templates".
  # It has to be renamed to the version string or Godot reports "no export template found"
  # while the files sit right there.
  unzip -q -o "$tmp/templates.tpz" -d "$tmp"
  rm -rf "$TEMPLATES_DIR"
  mv "$tmp/templates" "$TEMPLATES_DIR"
  rm -rf "$tmp"
  echo "templates: installed to $TEMPLATES_DIR"
fi

echo
echo "godot binary : $GODOT_BIN"
echo "templates    : $TEMPLATES_DIR"
