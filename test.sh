#!/bin/bash
# Runs the unit tests. Usage: bash test.sh [extra swift test arguments]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
source "$ROOT/swiftpm-env.sh"
swift test "${SWIFTPM_ARGS[@]}" "$@"
