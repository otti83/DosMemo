# Shared SwiftPM settings for build.sh and test.sh (sourced, not executed).
#
# Build products go to a local cache directory instead of ./.build: the
# project is often checked out on a network share, where SwiftPM's atomic
# renames and code signing fail, and module caches embed absolute paths that
# break when the checkout moves.
DOSMEMO_BUILD_DIR="${DOSMEMO_BUILD_DIR:-$HOME/Library/Caches/com.dosmemo.build}"
export CLANG_MODULE_CACHE_PATH="$DOSMEMO_BUILD_DIR/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
SWIFTPM_ARGS=(--disable-sandbox --scratch-path "$DOSMEMO_BUILD_DIR")
