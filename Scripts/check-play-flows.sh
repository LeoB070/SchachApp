#!/bin/sh
# Run ./build.sh build first; reuse the package's compiled model objects.
set -eu
cd "$(dirname "$0")/.."
build=.build/arm64-apple-macosx/debug
swiftc -parse-as-library -swift-version 5 -I "$build/Modules" \
    Sources/ChessApp/Features/Play/PlayViewModel.swift \
    Sources/ChessApp/Features/Play/ClockView.swift \
    Scripts/PlayFlowChecks.swift "$build"/ChessAppKit.build/*.swift.o \
    -o "$build/PlayFlowChecks"
"$build/PlayFlowChecks"
