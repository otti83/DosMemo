#!/bin/bash
# Builds a signed release DMG into dist/. Signing follows build.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)

# Stage on a local volume (see build.sh) and build the DMG from there.
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/dosmemo-release.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
mkdir "$STAGING/content"
bash "$ROOT/build.sh" release "$STAGING/content"
APP="$STAGING/content/DosMemo.app"
ln -s /Applications "$STAGING/content/Applications"
ditto --norsrc --noextattr "$ROOT/INSTALL.txt" "$STAGING/content/INSTALL.txt"

DMG_NAME="DosMemo-$VERSION-$ARCH.dmg"
# Not `hdiutil makehybrid`: its HFS output attaches FinderInfo to files,
# which invalidates the app's code signature under strict verification.
hdiutil create -volname "DosMemo $VERSION" -srcfolder "$STAGING/content" -fs HFS+ -format UDZO -ov "$STAGING/$DMG_NAME"
IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)
if [[ -n "$IDENTITY" ]]; then
    codesign --sign "$IDENTITY" --timestamp "$STAGING/$DMG_NAME"
    codesign --verify --verbose=2 "$STAGING/$DMG_NAME"
fi
hdiutil verify "$STAGING/$DMG_NAME"
MOUNT=$(hdiutil attach -nobrowse -readonly "$STAGING/$DMG_NAME" | awk -F'\t' 'END {print $NF}')
codesign --verify --strict --verbose=2 "$MOUNT/DosMemo.app" || { hdiutil detach "$MOUNT" -quiet; exit 1; }
hdiutil detach "$MOUNT" -quiet

mkdir -p "$ROOT/dist"
ditto --norsrc --noextattr "$STAGING/$DMG_NAME" "$ROOT/dist/$DMG_NAME"
(cd "$ROOT/dist" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")
echo "Release: $ROOT/dist/$DMG_NAME (signed by: ${IDENTITY:-ad-hoc})"
