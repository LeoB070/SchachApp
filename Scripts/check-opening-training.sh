#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build=.build/arm64-apple-macosx/debug
swiftc -parse-as-library -swift-version 5 -I "$build/Modules" \
 Sources/ChessApp/Features/Openings/OpeningTraining.swift \
 Scripts/OpeningTrainingChecks.swift "$build"/ChessAppKit.build/*.swift.o -o "$build/OpeningTrainingChecks"
"$build/OpeningTrainingChecks"
