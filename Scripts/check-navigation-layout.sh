#!/bin/sh
# Run ./build.sh build first; render the real views using an in-memory store.
set -eu
cd "$(dirname "$0")/.."
build=.build/arm64-apple-macosx/debug
sources=$(rg --files Sources/ChessApp -g '*.swift' | rg -v '/ChessApp.swift$')
accessor="$build/ChessApp.build/DerivedSources/resource_bundle_accessor.swift"
if [ -f "$accessor" ]; then
    sources="$sources $accessor"
fi
swiftc -parse-as-library -swift-version 5 -I "$build/Modules" \
    $sources Scripts/NavigationLayoutChecks.swift "$build"/ChessAppKit.build/*.swift.o \
    -o "$build/NavigationLayoutChecks"
"$build/NavigationLayoutChecks"
