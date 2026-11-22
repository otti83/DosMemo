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
git add .gitignore Package.swift Package.resolved Sources Tests Resources icon build.sh test.sh swiftpm-env.sh release.sh publish.sh setup-github.sh README.md README.ja.md docs INSTALL.txt release-notes
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
if xcrun stapler validate "dist/DosMemo-$VERSION-$ARCH.dmg" >/dev/null 2>&1; then
    SIGNING_NOTE="Developer ID signed and notarized by Apple."
else
    SIGNING_NOTE="Not notarized: macOS may block the first launch (Control-click DosMemo and choose Open)."
fi
NOTES_FILE=$(mktemp)
trap 'rm -f "$NOTES_FILE"' EXIT
{
    if [[ -f "release-notes/$TAG.md" ]]; then cat "release-notes/$TAG.md"; echo; fi
    echo "macOS 13+ / ${ARCH}. ${SIGNING_NOTE}"
} > "$NOTES_FILE"
gh release create "$TAG" "dist/DosMemo-$VERSION-$ARCH.dmg" "dist/DosMemo-$VERSION-$ARCH.dmg.sha256" \
    --repo "$REPO" --verify-tag --title "DosMemo $VERSION" --notes-file "$NOTES_FILE"
