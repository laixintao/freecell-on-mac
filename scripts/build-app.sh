#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
python3 scripts/check-release.py
build_args=(--disable-sandbox --cache-path .build/cache -c "${1:-release}")
if [[ -n "${RELEASE_ARCH:-}" ]]; then
    [[ "$RELEASE_ARCH" == arm64 || "$RELEASE_ARCH" == x86_64 ]]
    build_args+=(--arch "$RELEASE_ARCH")
fi
swift build "${build_args[@]}"
binary_dir="$(swift build "${build_args[@]}" --show-bin-path)"
APP="$PWD/dist/FreeCell.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$binary_dir/FreeCell" "$APP/Contents/MacOS/FreeCell"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
printf 'Built: %s\n' "$APP"
