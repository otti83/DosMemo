#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
if [[ $# -gt 0 ]]; then shift; fi
echo "Building DosMemo ($CONFIG)..."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT/.build/module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build --disable-sandbox --build-system native -c "$CONFIG"

APP="$ROOT/DosMemo.app"
BIN_DIR="$(swift build --disable-sandbox --build-system native -c "$CONFIG" --show-bin-path)"
EXEC="$BIN_DIR/DosMemo"

if [[ ! -x "$EXEC" ]]; then
    echo "Build failed: executable not found at $EXEC"
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$EXEC" "$APP/Contents/MacOS/DosMemo"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Copy SPM-generated resource bundle (Localizable.strings etc.)
RESOURCE_BUNDLE="$BIN_DIR/DosMemo_DosMemo.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
fi

# Optional icon
if [[ -f "$ROOT/icon/AppIcon.icns" ]]; then
    cp "$ROOT/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

# Ad-hoc sign for Gatekeeper / local execution
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "Built: $APP"
