#!/bin/bash
# Builds a signed (and, with Developer ID, notarized) release DMG into dist/.
#
# Notarization needs a "Developer ID Application" identity (see build.sh) and
# a notarytool keychain profile, created once with:
#   xcrun notarytool store-credentials dosmemo-notary
# Set DOSMEMO_NOTARY_PROFILE to use another profile name.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)
PROFILE="${DOSMEMO_NOTARY_PROFILE:-dosmemo-notary}"

# Stage on a local volume (see build.sh) and build the DMG from there.
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/dosmemo-release.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
mkdir "$STAGING/content"
bash "$ROOT/build.sh" release "$STAGING/content"
APP="$STAGING/content/DosMemo.app"
IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)

NOTARIZE=false
if [[ "$IDENTITY" == "Developer ID Application:"* ]]; then
    if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
        NOTARIZE=true
    else
        echo "warning: notarytool profile '$PROFILE' not found; the DMG will not be notarized." >&2
    fi
else
    echo "warning: not signed with Developer ID (${IDENTITY:-ad-hoc}); Gatekeeper will block the downloaded DMG." >&2
fi

notarize() {
    local file="$1" log
    log=$(xcrun notarytool submit "$file" --keychain-profile "$PROFILE" --wait 2>&1) || { echo "$log" >&2; return 1; }
    echo "$log"
    if ! grep -q 'status: Accepted' <<<"$log"; then
        local id
        id=$(sed -n 's/^ *id: //p' <<<"$log" | head -n 1)
        [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2
        return 1
    fi
}

if $NOTARIZE; then
    # Notarize and staple the app itself so it also passes Gatekeeper offline
    # after being copied out of the DMG.
    ditto -c -k --keepParent "$APP" "$STAGING/DosMemo.zip"
    notarize "$STAGING/DosMemo.zip"
    xcrun stapler staple "$APP"
fi

ln -s /Applications "$STAGING/content/Applications"
ditto --norsrc --noextattr "$ROOT/INSTALL.txt" "$STAGING/content/INSTALL.txt"

DMG_NAME="DosMemo-$VERSION-$ARCH.dmg"
DMG="$STAGING/$DMG_NAME"
# Not `hdiutil makehybrid`: its HFS output attaches FinderInfo to files,
# which invalidates the app's code signature under strict verification.
hdiutil create -volname "DosMemo $VERSION" -srcfolder "$STAGING/content" -fs HFS+ -format UDZO -ov "$DMG"
if [[ -n "$IDENTITY" ]]; then
    codesign --sign "$IDENTITY" --timestamp "$DMG"
    codesign --verify --verbose=2 "$DMG"
fi
if $NOTARIZE; then
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi
hdiutil verify "$DMG"
MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" | awk -F'\t' 'END {print $NF}')
codesign --verify --strict --verbose=2 "$MOUNT/DosMemo.app" || { hdiutil detach "$MOUNT" -quiet; exit 1; }
if $NOTARIZE; then
    spctl --assess --type execute --verbose=2 "$MOUNT/DosMemo.app" || { hdiutil detach "$MOUNT" -quiet; exit 1; }
fi
hdiutil detach "$MOUNT" -quiet

mkdir -p "$ROOT/dist"
ditto --norsrc --noextattr "$DMG" "$ROOT/dist/$DMG_NAME"
(cd "$ROOT/dist" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")
echo "Release: $ROOT/dist/$DMG_NAME (signed by: ${IDENTITY:-ad-hoc}; notarized: $NOTARIZE)"
