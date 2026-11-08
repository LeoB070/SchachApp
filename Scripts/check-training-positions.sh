#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build=.build/arm64-apple-macosx/debug
swiftc -parse-as-library -swift-version 5 -I "$build/Modules" \
    Sources/ChessApp/Features/Play/PlayViewModel.swift \
    Sources/ChessApp/Features/Play/ClockView.swift \
    Sources/ChessApp/Features/Training/EndgameExercise.swift \
    Scripts/TrainingPositionChecks.swift "$build"/ChessAppKit.build/*.swift.o \
    -o "$build/TrainingPositionChecks"
"$build/TrainingPositionChecks"
