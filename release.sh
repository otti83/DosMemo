#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
bash "$ROOT/build.sh" release
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)
mkdir -p "$ROOT/dist"
STAGING=$(mktemp -d "$ROOT/dist/staging.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
mkdir "$STAGING/content"
ditto "$ROOT/DosMemo.app" "$STAGING/content/DosMemo.app"
ln -s /Applications "$STAGING/content/Applications"
cp "$ROOT/INSTALL.txt" "$STAGING/content/INSTALL.txt"
DMG="$ROOT/dist/DosMemo-$VERSION-$ARCH.dmg"
hdiutil makehybrid -hfs -hfs-volume-name "DosMemo $VERSION" -o "$STAGING/source.dmg" "$STAGING/content" -ov
hdiutil convert "$STAGING/source.dmg" -format UDZO -o "$DMG" -ov
hdiutil verify "$DMG"
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Release: $DMG"
