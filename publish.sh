#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$PWD/.tools/bin:$PATH"
REPO="${1:?Usage: bash publish.sh owner/repository}"
command -v gh >/dev/null || { echo 'GitHub CLI (gh) is required.' >&2; exit 1; }
gh auth status
bash release.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
TAG="v$VERSION"
ARCH=$(uname -m)
if [[ ! -d .git ]]; then git init -b main; fi
git add .gitignore Package.swift Sources Tests Resources icon build.sh test.sh swiftpm-env.sh release.sh publish.sh setup-github.sh README.md INSTALL.txt release-notes
if ! git diff --cached --quiet; then git commit -m "Prepare DosMemo $VERSION release"; fi
if ! gh repo view "$REPO" >/dev/null 2>&1; then
    gh repo create "$REPO" --public --source=. --remote=origin
fi
if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/$REPO.git"
fi
REMOTE=$(git remote get-url origin)
case "$REMOTE" in
    "https://github.com/$REPO.git"|"https://github.com/$REPO"|"git@github.com:$REPO.git") ;;
    *) echo "origin differs from requested repository: $REMOTE" >&2; exit 1 ;;
esac
gh auth setup-git
git push -u origin HEAD:main
if ! git rev-parse "$TAG" >/dev/null 2>&1; then git tag "$TAG"; fi
if [[ "$(git rev-parse "$TAG^{commit}")" != "$(git rev-parse HEAD)" ]]; then
    echo 'Release tag points to a different commit; update the app version.' >&2; exit 1
fi
git push origin "$TAG"
SIGNER=$(hdiutil attach -nobrowse -readonly "dist/DosMemo-$VERSION-$ARCH.dmg" | awk -F'\t' 'END {print $NF}')
AUTHORITY=$(codesign -dvv "$SIGNER/DosMemo.app" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)
hdiutil detach "$SIGNER" -quiet
if [[ -n "$AUTHORITY" ]]; then
    SIGNING_NOTE="「${AUTHORITY}」で署名済み(Apple の公証は未取得)。"
else
    SIGNING_NOTE="アドホック署名(Apple の公証は未取得)。"
fi
NOTES_FILE=$(mktemp)
trap 'rm -f "$NOTES_FILE"' EXIT
{
    if [[ -f "release-notes/$TAG.md" ]]; then cat "release-notes/$TAG.md"; echo; fi
    echo "macOS 13以降 / ${ARCH}。DMGを開いてApplicationsへドラッグしてください。${SIGNING_NOTE}初回起動がブロックされた場合は同梱の INSTALL.txt を参照してください。"
} > "$NOTES_FILE"
gh release create "$TAG" "dist/DosMemo-$VERSION-$ARCH.dmg" "dist/DosMemo-$VERSION-$ARCH.dmg.sha256" \
    --repo "$REPO" --verify-tag --title "DosMemo $VERSION" --notes-file "$NOTES_FILE"
