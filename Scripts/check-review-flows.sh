#!/bin/sh
# Run ./build.sh build first; reuse the package's compiled model objects.
set -eu
cd "$(dirname "$0")/.."
build=.build/arm64-apple-macosx/debug
swiftc -parse-as-library -swift-version 5 -I "$build/Modules" \
    Sources/ChessApp/Features/Play/PlayViewModel.swift \
    Sources/ChessApp/Features/Play/ClockView.swift \
    Sources/ChessApp/Features/Training/EndgameExercise.swift \
    Sources/ChessApp/Features/Training/PositionTrainingView.swift \
    Sources/ChessApp/Features/Review/ReviewPractice.swift \
    Sources/ChessApp/Features/Review/ReviewView.swift \
    Sources/ChessApp/Features/Review/EvalGraphView.swift \
    Sources/ChessApp/Features/Board/BoardView.swift \
    Sources/ChessApp/Features/Board/PieceView.swift \
    Sources/ChessApp/Features/Board/PromotionPicker.swift \
    Sources/ChessApp/App/AppTheme.swift Sources/ChessApp/App/UIState.swift \
    Scripts/ReviewFlowChecks.swift "$build"/ChessAppKit.build/*.swift.o \
    -o "$build/ReviewFlowChecks"
"$build/ReviewFlowChecks"
