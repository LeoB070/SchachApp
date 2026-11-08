#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build=.build/arm64-apple-macosx/debug
swiftc -parse-as-library -swift-version 5 -I "$build/Modules" \
    Sources/ChessApp/App/UIState.swift Sources/ChessApp/App/AppTheme.swift \
    Sources/ChessApp/Features/Board/PieceView.swift Sources/ChessApp/Features/Board/BoardView.swift \
    Sources/ChessApp/Features/Puzzles/PuzzleView.swift Sources/ChessApp/Features/Puzzles/PersonalPuzzles.swift \
    Sources/ChessApp/Features/Puzzles/PuzzleReviewStore.swift \
    Scripts/RepetitionChecks.swift "$build"/ChessAppKit.build/*.swift.o -o "$build/RepetitionChecks"
"$build/RepetitionChecks"
