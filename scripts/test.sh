#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
# Some Command Line Tools releases omit TestingMacros from automatic plugin discovery.
SWIFT_BIN="$(xcrun --find swiftc)"
TESTING_PLUGIN="$(dirname "$(dirname "$SWIFT_BIN")")/lib/swift/host/plugins/testing/libTestingMacros.dylib"
FLAGS=()
if [ -f "$TESTING_PLUGIN" ]; then
    FLAGS+=(-Xswiftc -load-plugin-library -Xswiftc "$TESTING_PLUGIN")
fi
swift test --disable-sandbox --cache-path .build/cache "${FLAGS[@]}" "$@"
