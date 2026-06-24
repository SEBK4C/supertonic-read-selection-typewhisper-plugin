#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT_DIR/dist/SupertonicReadSelectionPlugin.bundle"
PLUGIN_ID="com.sebk4c.typewhisper.tts.supertonic-read-selection"
DEFAULTS_DOMAIN="${TYPEWHISPER_DEFAULTS_DOMAIN:-com.typewhisper.mac}"
PLUGIN_DIR="${TYPEWHISPER_PLUGIN_DIR:-$HOME/Library/Application Support/TypeWhisper/Plugins}"
DEST="$PLUGIN_DIR/SupertonicReadSelectionPlugin.bundle"

if [[ ! -d "$BUNDLE" ]]; then
    echo "Bundle not found at $BUNDLE. Run scripts/build-supertonic-plugin.sh first." >&2
    exit 1
fi

mkdir -p "$PLUGIN_DIR"

case "$DEST" in
    "$PLUGIN_DIR/SupertonicReadSelectionPlugin.bundle")
        rm -rf "$DEST"
        ;;
    *)
        echo "Refusing to remove unexpected destination: $DEST" >&2
        exit 1
        ;;
esac

COPYFILE_DISABLE=1 ditto --norsrc --noextattr "$BUNDLE" "$DEST"

if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$DEST" >/dev/null 2>&1 || true
fi

defaults write "$DEFAULTS_DOMAIN" "plugin.$PLUGIN_ID.enabled" -bool true

echo "Installed and enabled:"
echo "  $DEST"
echo "Restart TypeWhisper to load the plugin runtime and show its Settings button."
