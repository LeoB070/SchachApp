# Windows and Deep Analysis Implementation Plan

> Agent workers implement independent domains and validate each deliverable before integration.

**Goal:** Deliver Windows desktop chess, hardware adaptive deep analysis on Windows/macOS, and verified startup instructions in Git.

**Architecture:** Keep Swift/macOS intact; add a C#/Avalonia Windows application and use local Stockfish UCI on both. Share existing visual assets and training data where practical.

**Tech Stack:** SwiftUI, Swift, C#, Avalonia, .NET, Stockfish UCI.

**Spec:** `docs/superpowers/specs/2026-11-10-windows-deep-analysis-design.md`

## Constraints and review focus

Preserve existing games and ordinary analysis. Validate legal moves, malformed input, unavailable engine, cancellation/restart, resource caps, and process disposal. Avoid binary engine redistribution. Document platform verification honestly.

## Task 1: Mac deep analysis (agent mac_deep)
- [x] Inspect review model, UCI lifecycle, settings and callers.
- [x] Add tested hardware profile and isolated deep analysis UI with live progress and cancellation.
- [x] Build and run targeted Swift assertions and regression checks.

## Task 2: Windows application (agent windows)
- [x] Inspect existing UI/assets and choose current supported .NET/Avalonia packages.
- [x] Build chess play, local engine, archive/import/export and deep analysis with robust boundaries.
- [x] Add meaningful core checks; compile app and Windows publish output.

## Task 3: Integration (root)
- [x] Document exact Mac/Windows start and publish commands, engine setup and feature limitations.
- [x] Add Windows build workflow, ignore build outputs, review diffs and run integrated checks.
Delivery: commit and push to the existing private Git remote, then verify remote HEAD and Windows workflow. Native Windows GUI remains a user-device check.


## Verification record

- Root: `./build.sh test` — 483 passed, 0 failed; play/review flow checks passed.
- Root: `./make-app.sh` — Release app packaged and locally signed; native UI deep search, three PVs and cancellation verified.
- Root: `.NET 8 dotnet run --project Windows/ChessClub.SelfTest -c Release -- /opt/homebrew/bin/stockfish` — 694 passed, including legal moves, strict PGN rejection, persistence, all puzzles/lessons, representative openings, real engine cancellation/restart.
- Root: self-contained `win-x64` publish passed; output verified as Windows x86-64 GUI PE executable.
- Root: Avalonia GUI exercised on macOS: legal move + engine reply, analysis/deep search + stop, board flip while analyzing, puzzle completion, session preservation.
- Independent reviewer: Swift changes and final Windows async/import/storage fixes reviewed; no remaining important findings.
- Limits: no native Windows GUI test, no exhaustive opening dataset replay, no full feature parity (see README).
