# HANDOFF – ChessApp

Stand: 6. November 2026, Fortsetzung und Sicherung der Gemini-Arbeit.

## Sicherung und Ausgangslage

Geminis Arbeit war auf der Festplatte gespeichert, aber nicht committet. Git stand noch auf `7ad4a9c` (M1 UI-Skeleton). Die alte Übergabe beschrieb deshalb einen deutlich früheren Stand. Der gespeicherte Zwischenstand baute wegen der Actor-/Protokoll-Isolation von `UCIEngine.analyze` nicht.

Eine zusätzliche Wiederherstellungskopie liegt unter `../recovery/ChessApp-saved-2026-11-06.tar.gz` (Quellstand zu Beginn dieser Fortsetzung, ohne Git/Build-Artefakte). Der aktuelle Quellstand wird als Git-Checkpoint im Repository `ChessApp/` gesichert. Es wurde nichts gepusht.

## Meilensteine

| Bereich | Verifizierter Stand |
| --- | --- |
| M1 Brett/Regeln | Regeln, SAN/FEN, Perft, Umwandlung, Brett drehen, legale Ziele. Partie bleibt beim Wechsel der Sidebar erhalten. |
| M2 Engine | Lokaler Stockfish, UCI-Parser, normalisierte Bewertungen, schnelle Antworten, Timeout/Abbruch, Fehlermeldung bei fehlendem Binary. Gleichzeitige Aufträge werden abgewiesen. |
| M3 Spielen | Sechs Bots + Stockfish-Stärkeregler, Farbe, fünf Zeitkontrollen, Inkrement, Aufgabe/Zeitablauf, automatische Speicherung, Analyse öffnen. |
| M4 PGN/Archiv | Datei-/Textimport, Export, Suche, Ergebnis-/Datumsfilter, Löschen inkl. zugehöriger Analysen, Analyse öffnen. Kaputte Züge/FEN werden gemeldet statt still ausgelassen. |
| M5 Analyse | Exakte vorgegebene Gewinnwahrscheinlichkeits-/Zug-Accuracy-Formeln, einfacher Gesamtmittelwert, Basis-Klassifikation, Eröffnungsbuch, sequenzielle abbrechbare Analyse mit Fortschritt und Speicherung. |
| M6 Review | Brett/Zugnavigation, Pfeiltasten, Bewertungsbalken/-graph, Accuracy-Karten, Eröffnung, Klassenübersicht, Alternativzug-Pfeil auf der Stellung vor dem Zug. |
| M7 Puzzles | 20 geprüfte Beispiele, Gegnerzug automatisch, Eingabe/Hint/Lösung/Weiter, Elo K=32, Streak/Ergebnisse gespeichert. Beide Spielerfarben enthalten. |
| M8 Lektionen | Drei lokale JSON-Kurse mit je drei Lektionen und legal geprüften Übungen, gespeicherter Abschluss. |
| M9 Statistik/Settings | Ergebnisse, Puzzle-Rating, Accuracy-Trend, Eröffnungen; Engine-Pfad/Threads/Hash/Tiefe, drei Brettfarben, Ton/Animation, About/GPLv3-Hinweis. |
| Packaging | Release-App unter `dist/ChessApp.app`, lokal ad hoc signiert, Ressourcen im signierbaren Contents/Resources-Bundle. README und make-app.sh vorhanden. |

Dies ist das angeforderte Grundgerüst mit funktionierenden Basisabläufen. Die ausdrücklich für den späteren Review vorgesehenen Spezialfälle bleiben TODOs.

## Frische Verifikation

- `./build.sh test`: Exit 0, **215 bestanden, 0 gescheitert**. Swift-Testing-Dateien werden kompiliert; der CLT-fähige TestRunner führt die Prüfungen tatsächlich aus.
- Abdeckung: bestehende Core-/Perft-Prüfungen, PGN-Kommentare/Varianten/Roundtrip/Schwarzstart/Null-Rochade, ungültige FEN-Zähler, alle Puzzle-/Lektionszüge, Eröffnungen/Formeln, schnelle Engine-Antwort, Abbruch, vier Sekunden Handshake-Timeout, Review-Perspektive/JSON, Bots sowie **echter lokaler Stockfish-Bestzug und Analyseabschluss**.
- `sh Scripts/check-play-flows.sh`: Exit 0. Uhr, Inkrement, Zugrecht, Aufgabe beider Farben, Zeitablauf und idempotentes PGN-Autosave in einem **In-Memory-Store** geprüft.
- `./make-app.sh`: Exit 0, Release-Produkt gebaut (11.46 s inkrementeller Abschluss), App lokal signiert. Einziger Build-Hinweis: `--build-system native` ist deprecated. Keine verbleibenden Compiler-Warnings im finalen Testlauf.
- `git diff --check`: sauber.
- Native UI geprüft: App startet aus dem Bundle; e2–e4 eingegeben, Bot antwortet c7–c5; Partie nach Sidebar-Wechsel noch vorhanden. Puzzle-Datei lädt und Hinweis aktualisiert sich. Drei Kurse und Lektionsinhalt erscheinen. Die App wurde für den Nutzer geöffnet gelassen.
- Nicht interaktiv durchgeklickt: jede Archiv-/Review-/Settings-Variante sowie jede Puzzle-/Lektionsaufgabe. Keine Langzeit-/Speicherlastmessung, keine Prüfung auf Intel oder mit vollem Xcode.

## Bewusste Grenzen / Risiken

- Core Data statt SwiftData: bestehender CLT-kompatibler Ansatz bleibt erhalten; keine Datenmigration eingeführt. Die alte Übergabe nannte dies fälschlich SwiftData.
- Datenbank-Ladefehler führen weiterhin zum bestehenden `fatalError`; Einstellungen und einige Lernfortschritt-Hilfen verwenden noch vereinfachte Fehlerbehandlung. Keine vorhandenen Nutzerdaten wurden gelöscht.
- Nur abgeschlossene Partien werden gespeichert; ein App-Neustart stellt eine laufende Partie nicht wieder her. Sidebar-Wechsel pausiert die Partie.
- 20 lokale Puzzle-Beispiele bestehen aus fünf Mattmustern mit Spiegelungen/Farbwechseln; keine breite Trainingsdatenbank und keine behauptete Lichess-Herkunft.
- Bot-MultiPV nutzt Tiefe 10; dies kann die nominelle Bot-Bedenkzeit überschreiten. Unterhalb der unterstützten Stockfish-Elo-Grenze wird auf 1320 begrenzt; Bot-Elo ist eine ungefähre Beschreibung.
- Engine ohne Auftragswarteschlange; fünf Minuten Analysebudget pro Stellung. AsyncStream meldet Engine-Analysefehler nur durch Abschluss; der Review meldet fehlende Bewertung. Shutdown-Eskalation und Crash-Recovery sind nicht fertig.
- Brilliant/Great/Miss/Book werden noch nicht vergeben. Gesamt-Accuracy ist ein einfacher Mittelwert. Kleine ECO-Auswahl; seltene PGN-Dialekte und mehrere headerlose Partien fehlen.
- Importierte FEN-Zähler müssen ganzzahlig sein, Halbzüge 0…1.000.000 und Zugnummern 1…1.000.000, um Überlauf/ungültige Engine-Eingaben abzuweisen.
- App nur ad hoc signiert, nicht notarisiert; Stockfish wird nicht mitverteilt. Für Weitergabe ist das separate GPLv3-Binary-/Quellcode-Setup zu klären.

## Offene Code-Markierungen

```text
Sources/ChessAppKit/Engine/UCIEngine.swift:7:// TODO(CLAUDE): Warteschlange, automatischer Neustart und feinere Analyse-Timeouts ergänzen.
Sources/ChessAppKit/Engine/UCIEngine.swift:203:        // shortcut: Fünf Minuten pro Stellung, für lange Analysen einstellbares Zeitbudget ergänzen.
Sources/ChessAppKit/Engine/UCIEngine.swift:256:        // TODO(CLAUDE): Beendigung bestätigen und bei nicht reagierenden Prozessen eskalieren.
Sources/ChessAppKit/Bots/Bot.swift:93:        // TODO(CLAUDE): Menschliche Fehlerprofile und zeitbegrenzte MultiPV-Suche kalibrieren.
Sources/ChessAppKit/Bots/Bot.swift:94:        // shortcut: depth 10 finishes before choosing, use a timed engine request for tighter move budgets.
Sources/ChessAppKit/Analysis/AccuracyCalculator.swift:44:        // TODO(CLAUDE): Gesamt-Accuracy exakt (volatilitätsgewichtetes und harmonisches Mittel).
Sources/ChessAppKit/Analysis/OpeningBook.swift:38:    // TODO(CLAUDE): Vollständige ECO-Datenbank und Bewertung der Eröffnungsphase ergänzen.
Sources/ChessAppKit/Analysis/MoveClassifier.swift:56:        // TODO(CLAUDE): Brilliant, Great, Miss und Book anhand verlässlicher Kontextdaten bewerten.
Sources/ChessAppKit/Core/PGN.swift:77:// TODO(CLAUDE): Seltene PGN-Dialekte und mehrere headerlose Partien unterstützen.
Sources/ChessApp/Features/Puzzles/PuzzleView.swift:61:        // TODO(CLAUDE): Puzzle-Auswahl nach Thema, Puzzles aus eigenen Fehlern erzeugen.
```

## Start / Stockfish

```sh
brew install stockfish        # nur nötig, falls noch nicht installiert
./build.sh test
./build.sh run ChessApp
./make-app.sh
open dist/ChessApp.app
```

Engine-Suche: App-/Kit-Ressource → Settings-Pfad → `/opt/homebrew/bin/stockfish` → weitere Systempfade. Die lokale Installation wurde tatsächlich getestet. Der App-Build und alle Ressourcen benötigen keinen Netzwerkdienst.
