#!/bin/bash
# Builds DosMemo.app.
#
# Usage: bash build.sh [release|debug] [output-dir]
#   output-dir defaults to $DOSMEMO_BUILD_DIR/app (a local volume: apps on
#   network shares pick up Finder info that breaks their code signature, and
#   macOS then kills them at launch).
#
# Signing: set DOSMEMO_SIGN_IDENTITY to choose a codesigning identity ("-" for
# ad-hoc). Otherwise the first "Developer ID Application" identity is used,
# then "Apple Development", falling back to ad-hoc signing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
echo "Building DosMemo ($CONFIG)..."
source "$ROOT/swiftpm-env.sh"
OUT_DIR="${2:-$DOSMEMO_BUILD_DIR/app}"
swift build "${SWIFTPM_ARGS[@]}" -c "$CONFIG" --product DosMemo
BIN_DIR="$(swift build "${SWIFTPM_ARGS[@]}" -c "$CONFIG" --show-bin-path)"
EXEC="$BIN_DIR/DosMemo"
[[ -x "$EXEC" ]] || { echo "Build failed: executable not found at $EXEC" >&2; exit 1; }

find_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n "s/^ *[0-9][0-9]*) [0-9A-F]\{40\} \"\($1[^\"]*\)\"$/\1/p" | head -n 1
}
IDENTITY="${DOSMEMO_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then IDENTITY="$(find_identity 'Developer ID Application: ')"; fi
if [[ -z "$IDENTITY" ]]; then IDENTITY="$(find_identity 'Apple Development: ')"; fi
if [[ -z "$IDENTITY" ]]; then IDENTITY="-"; fi

# Assemble and sign on a local volume: network shares (SMB/AFP) attach
# Finder info and resource forks that codesign rejects.
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/dosmemo-build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/DosMemo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto --norsrc --noextattr "$EXEC" "$APP/Contents/MacOS/DosMemo"
ditto --norsrc --noextattr "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
for lproj in "$ROOT"/Resources/*.lproj; do
    ditto --norsrc --noextattr "$lproj" "$APP/Contents/Resources/$(basename "$lproj")"
done
ditto --norsrc --noextattr "$ROOT/Resources/markdown" "$APP/Contents/Resources/markdown"
ditto --norsrc --noextattr "$ROOT/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"

if [[ "$IDENTITY" == "-" ]]; then
    echo "Signing: ad-hoc"
    codesign --force --sign - "$APP"
else
    echo "Signing: $IDENTITY"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/DosMemo.app"
ditto --norsrc --noextattr "$APP" "$OUT_DIR/DosMemo.app"
codesign --verify --strict "$OUT_DIR/DosMemo.app" \
    || { echo "error: the signature broke when copying to $OUT_DIR (network volume?)" >&2; exit 1; }
echo "Built: $OUT_DIR/DosMemo.app"
