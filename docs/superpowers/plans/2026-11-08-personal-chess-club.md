# Personal chess club implementation plan

> **For agentic workers:** Use focused independent domains, then integrate and review.

**Goal:** Implement the approved warm club design, personal home, guided review, bot personality and expanded personal puzzles.
**Architecture:** Keep SwiftUI and Core Data, reuse boards, bot portraits and Stockfish. Derive progress from existing stores, preserve schemas and saved data.
**Tech Stack:** Swift 5 mode, macOS 14, SwiftUI, Core Data, local UCI Stockfish.
**Spec:** ../../../../reports/Schach App mit mehr Persönlichkeit.md and user's approved puzzle proposal in conversation.

## Global constraints
- Preserve existing uncommitted work and stores; no commits or destructive reset.
- No new dependencies, no network required in product, no external services.
- Honor light/dark preferences, large accessible board, no unverified chess explanations.
- Only approved features 1–3 plus agreed puzzles; defer 4–6.

## Review focus
- Empty archive, missing Stockfish and malformed analysis remain usable.
- Imported games never attributed to the human without matching player identity.
- Cancellation/navigation never changes the next puzzle or records duplicate results.
- Retry/hints cannot inflate rated progress; old saved data remains readable.
- Home actions reach real content, current game can resume, light/dark and compact windows remain usable.

### Task 1: Personal home and visual identity
- [x] Add HomeView and default home route, latest-game review sheet, learning/puzzle/play actions.
- [x] Reuse persistent PlayViewModel and existing progress; show actual numbers and bot victories.
- [x] Warm dynamic palette and consistent panels, stronger typography, bot reactions and rematch.
- [x] Test bot outcome/reaction and victory derivation, navigation and appearance.

### Task 2: Guided review
- [x] Select up to three meaningful own mistakes from analysis, validate recommended moves.
- [x] Add retry mode with board interaction, reveal and next key moment; never modify source game.
- [x] Explain only verifiable effects or analysis facts; retain full review functionality.
- [x] Add focused regression checks for own side, legal moves, resets and empty cases.

### Task 3: Puzzle expansion
- [x] Add graduated hints, retry practice, solution explanation, failed-puzzle repeat and source filters.
- [x] Extend bundled puzzles with verified diverse multi-move themes and explanations.
- [x] Generate own-game puzzles from saved own mistakes, validate with Stockfish and unique best move; retain source metadata, handle missing engine/cancellation.
- [x] Add regression checks for source/correctness/attempt accounting and legal bundled lines.

### Task 4: Integration and delivery
- [x] Build app and test runner, run puzzle/play/navigation/appearance checks; inspect real rendered app screens.
- [x] Review changes relative to session snapshot and fix important findings.
- [x] Build signed release bundle and report verified scope and any remaining limits.

## Decisions
Proceed under the user's explicit “auf gehts” authorization without another approval round. Independent domains may be delegated per dispatching-parallel-agents skill. Keep the existing dirty workspace to preserve changes; snapshot before this task is /tmp/chess-club-before.

## Final verification
- User steering: replace all illustrated animal portraits with deterministic code-drawn 7×7 pixel mosaics; no generated image used. Neutral first names, legacy name matching preserves victories.
- Debug build + 469 TestRunner assertions passed, 0 failures.
- Club, review, play, puzzle and appearance flow checks passed; real read-only Stockfish candidate check passed.
- All seven sections rendered at four widths in light and dark; both empty and seeded in-memory history inspected. Contrast and sheet backgrounds corrected.
- Independent puzzle audit: 52 legal unique positions, 8 multi-move combinations, 19 solver decisions rechecked with Stockfish 19 depth 16 / MultiPV 2.
- Independent code review findings fixed: unsupported personal underpromotions excluded and bot-specific progression/result reactions added.
- Release built and ad hoc signed at dist/ChessApp.app. Source/user database and original saved games were not migrated or rewritten.
- Limits: personal puzzles contain one clear verified decision, imported games require explicit “Du” attribution; the collection is intentionally curated rather than a large downloaded database.
