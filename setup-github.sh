#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$ROOT/.tools/bin:$PATH"

if ! command -v gh >/dev/null 2>&1; then
    case "$(uname -m)" in
        arm64) ARCH=arm64 ;;
        x86_64) ARCH=amd64 ;;
        *) echo 'Unsupported CPU architecture.' >&2; exit 1 ;;
    esac
    WORK=$(mktemp -d)
    trap 'rm -rf "$WORK"' EXIT
    curl --fail --silent --show-error --location --connect-timeout 15 \
        https://api.github.com/repos/cli/cli/releases/latest -o "$WORK/release.json"
    URL=$(python3 - "$WORK/release.json" "$ARCH" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    release = json.load(f)
suffix = '_macOS_' + sys.argv[2] + '.zip'
asset = next(a for a in release['assets'] if a['name'].endswith(suffix))
url = asset['browser_download_url']
if not url.startswith('https://github.com/cli/cli/releases/download/'):
    raise SystemExit('Unexpected GitHub CLI download URL')
print(url)
PY
)
    curl --fail --silent --show-error --location --connect-timeout 15 "$URL" -o "$WORK/gh.zip"
    ditto -x -k "$WORK/gh.zip" "$WORK/unpacked"
    GH_BIN=$(find "$WORK/unpacked" -type f -path '*/bin/gh' -print -quit)
    test -n "$GH_BIN"
    mkdir -p "$ROOT/.tools/bin"
    install -m 755 "$GH_BIN" "$ROOT/.tools/bin/gh"
fi

gh --version
if ! gh auth status >/dev/null 2>&1; then
    gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git
gh auth status
echo 'GitHub setup complete. Publish with: bash publish.sh otti83/DosMemo'
