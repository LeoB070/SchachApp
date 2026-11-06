# ChessApp

Offline macOS chess app built with SwiftUI, Core Data and a local Stockfish process.
Requires macOS 14+, Apple Silicon and Swift 6 Command Line Tools. No package dependencies or network service.

```sh
./build.sh build
./build.sh test
./build.sh run ChessApp
```

`build.sh` uses SwiftPM's native builder because the default builder needs full Xcode on this machine. `test` compiles the Swift Testing suite, then executes the standalone TestRunner (the CLT environment cannot launch the Swift Testing bundle). The runner checks chess rules/perft, PGN, learning resources, analysis formulas, engine lifecycle and a real Stockfish search when installed.

```sh
./Scripts/check-play-flows.sh # after a debug build: in-memory clock/save checks
./make-app.sh                # release build → dist/ChessApp.app
open dist/ChessApp.app
```

The app bundle is signed ad hoc for local use; it is not notarized. Stockfish is not redistributed in the bundle. Install it with `brew install stockfish`, or choose an existing executable in Settings. Search order: bundled binary, configured path, Homebrew/system paths. Stockfish is GPLv3; source: https://github.com/official-stockfish/Stockfish.

Play against one of six sample bots or choose Stockfish's skill level. Select your color and time control under New Game. Completed games save locally, and can be opened for analysis from Play or Archive. Archive accepts PGN files and pasted PGN, and exports PGN files. Puzzles track rating/streak, and lessons save completion. Settings control board colors, sounds, animations and engine resources.

This is the requested scaffold, with working basic flows. The 20 puzzle examples cover five mate patterns reflected across colors/files; they are not a large training dataset. Advanced classifications, exact aggregate accuracy, complete ECO coverage, engine queuing/recovery and human bot tuning remain explicit TODOs. See [HANDOFF.md](HANDOFF.md) for verified status, limits and recovery details.
