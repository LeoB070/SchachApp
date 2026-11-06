# HANDOFF.md – ChessApp Grundgerüst

Stand: 6. Nov 2026. Erstellt von der Umsetzung des Prompt-Rahmens `01_Rahmen_Workhorse.md`.
Dieses Dokument ist der offizielle Übergabestand für den nächsten Bearbeiter (Claude Code Review per `02_ClaudeCode_Review.md` und die folgenden Meilensteine).

## 1. Stand der Meilensteine

| Meilenstein | Status | Was fertig ist |
|-------------|--------|----------------|
| **M1 – Gerüst und Brett** | **Fertig (Kern) / teilweise (UI)** | Paket-Skeleton (Package.swift, Library `ChessAppKit`, Executable `ChessApp`, Tests, `build.sh` Wrapper wegen fehlendem Xcode). Eigene Schachregeln komplett: `Piece`, `Square`, `Move` (UCI, Flags), `Position` (FEN ein/aus, `make`, `legalMoves`, Rochade/En-passant/Umwandlung, Schach/Matt/Patt, Materialregel, Wiederholungsschlüssel), `SAN` (Notation + Parse inkl. Rochade, Disambiguierung, +/#), `GameOutcome`. Perft verifiziert: Start 20/400/8902/197281, Kiwipete 48/2039/97862, Position 3 14/191/2812. Alle 85 Tests grün (`./build.sh test`). `Position.move(from:to:)` Lookup für UI-Klick-Züge. UI-Skeleton: `RootView` (Sidebar Spielen/Analyse/Puzzles/Lernen/Archiv/Statistik/Einstellungen), `BoardView` (8×8, Unicode-Figuren, Brett drehen, Klick-Klick, legale Ziele, letzter Zug), `PlayView`/`PlayViewModel` (lokale Partie, SAN-Zugliste, Umwandlungs-Dialog, Partieende), `PieceView`, `PromotionPicker`, `MoveListView`, `ClockView` (Stub), `SettingsView` (Stub), Platzhalter-Views für die übrigen Bereiche. SwiftData-Modelle: `AppSettings`, `SavedGame`, `GameAnalysisEntry`, `PuzzleProgress`, `PuzzleResult`, `LessonProgress`. |
| **M2 – Engine-Anbindung** | Fehlt (nur Stub geplant) | `ChessEngine`-Protokoll und `UCIEngine` noch nicht gebaut. Stockfish liegt bereits unter `/opt/homebrew/bin/stockfish` (siehe Setup unten). |
| **M3 – Spielen gegen die Engine** | Fehlt | `PlayViewModel` hat noch keinen Gegner; Bots/Uhr/Autospeichern fehlen. |
| **M4 – PGN und Archiv** | Fehlt | `PGN.swift` existiert als Kommentar-Platzhalter; Archiv-View fehlt. |
| **M5 – Analyse** | Fehlt | WinProbability/Accuracy/MoveClassifier/OpeningBook/GameReviewService fehlen. |
| **M6 – Review-Ansicht** | Fehlt | `ReviewView`/`EvalGraphView` fehlen. |
| **M7 – Puzzles** | Fehlt | `puzzles.json`, `PuzzleView`, Rating fehlen. |
| **M8 – Lektionen** | Fehlt | `lessons/*.json`, Lesson-Views fehlen. |
| **M9 – Statistik und Einstellungen** | Fehlt | `StatsView`, echte `SettingsView`, About fehlen. |

## 2. Build-Status

- **Baut das Projekt?** Ja. `./build.sh build` (bzw. `swift build --build-system native`) läuft ohne Fehler durch.
- **Hinweis:** Auf dieser Maschine ist nur die CommandLineTools installiert, kein volles Xcode. Der Standard-Builder (XCBuild) scheitert mit "Unknown error parsing property list"; deshalb wird `--build-system native` verwendet (Deprecation-Warnung ist harmlos). Wrapper: `ChessApp/build.sh` (`./build.sh build|test|run`).
- **Verbleibende Warnungen:** Nur die oben genannte `--build-system native` Deprecation. Keine Compiler-Warnings im Code.
- **App-Start:** `./build.sh run` startet ein Fenster (nicht interaktiv getestet, da kein GUI-Test hier möglich; manuell durch nächsten Bearbeiter zu prüfen).

## 3. Tests

- **Laufen:** 85 Tests in `Sources/TestRunner/main.swift` + Swift-Testing-Dateien unter `Tests/ChessAppKitTests/`, alle grün (`./build.sh test` → "Ergebnis: 85 bestanden, 0 gescheitert", Exit 0).
- **Scheitern:** Keine.
- **Einschränkung:** `swift test` kompiliert unter den CLT, führt die Tests aber nicht aus (kein Xcode-Host). Deshalb gibt es zusätzlich `Sources/TestRunner/main.swift` (selbstgebauter Runner, Exit 1 bei Fehler). Das Test-Target `ChessAppKitTests` (Swift-Testing) ist für späteres Xcode-lauffähig vorgehalten.
- **Abdeckung:** Perft, FEN-Roundtrips, Umwandlung, Rochade, En-passant, Materialregel, GameOutcome-Prioritäten, SAN-Notation/-Parse, `Position.move(from:to:)` Lookup.

## 4. TODO(CLAUDE)-Liste

`grep -rn "TODO(CLAUDE) ."` liefert derzeit **keine Treffer** – im fertigen M1-Kern sind keine offenen Stellen markiert.

Die `// TODO(CLAUDE)`-Stubs entstehen erst ab M2/M3 (Engine-Nebenläufigkeit, Timeouts, Neustart, Serialisierung, sauberes Beenden; Bot-Feinabstimmung; PGN-Randfälle; exakte Gesamt-Accuracy; Zugklassen Brilliant/Great/Miss/Book; ECO-Datenbank; Puzzle-Auswahl; …). Nach jedem Meilenstein mit `grep -rn "TODO(CLAUDE) .` die Liste in dieses Dokument übernehmen.

## 5. Unsicherheiten

- `AppTheme`-Farben sind hardcodiert (Grün/Blau/Holz) und werden in Task 9 über `AppSettings.boardTheme` gesteuert – derzeit noch nicht verkabelt (SettingsView ist Stub).
- `PlayViewModel` arbeitet aktuell ohne Engine (zwei Menschen am selben Gerät); Engine-Gegner kommt in Task 3/4.
- Die Promotion-Logik blockiert auf `pendingPromotion` und setzt erst nach Auswahl fort – funktioniert für Klick-Züge, Tastatur-/Notations-Eingabe kommt später.
- SwiftData `ModelContainer` im `init()` von `ChessAppMain` nutzt `try!`-ähnliches `fatalError` bei DB-Fehler – akzeptiert für das Gerüst, ggf. später eleganter behandeln.

## 6. Setup-Schritte (Stockfish)

1. Stockfish installieren: `brew install stockfish` → Binary unter `/opt/homebrew/bin/stockfish` (bereits vorhanden auf dieser Maschine).
2. Optional für App-Bundle: Apple-Silicon-Binary nach `ChessApp/Sources/ChessAppKit/Resources/Stockfish/stockfish` kopieren (`chmod +x`); Platzhalter-README liegt dort bereits.
3. Pfad-Fallback in `EngineLocator` (Task 3): erst App-Bundle-Ressource, sonst Einstellungen-Pfad, sonst `/opt/homebrew/bin/stockfish`; wenn nichts gefunden: freundliche Fehleransicht mit Hinweis `brew install stockfish`.
4. Lizenz: Stockfish steht unter der GPLv3, Quelle https://github.com/official-stockfish/Stockfish (About-Ansicht in Task 9).

## Nächste Schritte (M2)

`protocol ChessEngine` + `UCIEngine` (Process über stdin/stdout, UCI-Parser, `analyze`/`bestMove`, Einstellungen Threads/Hash/Skill/ELO), überall `// TODO(CLAUDE)` für Nebenläufigkeit/Timeouts/Neustart. Dann M3 (Gegner, Uhr, Bots, Speichern).
