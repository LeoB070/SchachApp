# Persönliches Offline-Schachtraining

Goal: Die im Bericht Praktische Funktionen für die Schachapp vorgeschlagenen Ergänzungen als kleine vollständige Offline-Funktionen umsetzen.
Architecture: Bestehendes SwiftUI-Brett, lokale Stockfish-Engine und Persistenz wiederverwenden. Keine Abhängigkeiten oder Onlinekonten. Originalpartien und vorhandene Arbeitskopie bleiben erhalten.
Spec: ../../../../reports/Praktische Funktionen für die Schachapp.md und Freigabe im Chat am 2026-11-08.

## Constraints und Entscheidungen
- macOS 14+, Swift 5 Sprachmodus, keine neuen Abhängigkeiten.
- Alle Funktionen dienen Einzeltraining; keine Multiplayer- oder Videoplattform.
- Bestehende ungesicherte Änderungen bewahren; keine automatischen Commits.
- Agenten bearbeiten getrennte Dateien in der vorhandenen Arbeitskopie. Hauptagent integriert Startseite/Navigation/Statistik und prüft Gesamtbuild.
- Wiederholungen zählen nicht zum Puzzle-Rating. Fehler/unterstützte Antworten führen zu früherer Wiederholung.
- Trainingspartien überschreiben keine Originalpartien und verfälschen keine Spielstatistik.
- Kleine Stichproben sichtbar machen; keine unbelegten Motive oder strategischen Erklärungen erzeugen.

## Aufgaben
- [x] 1: Puzzle-Wiederholungsplan dauerhaft speichern, fälligen Modus anbieten, mit deterministischen Checks prüfen. Verantwortlich: PuzzleView, PersonalPuzzles, neue Schedule-Datei/Checks.
- [x] 2: Analysestellung gegen Bot weiterspielen; sichere separate Sitzung; Review um Kandidatenübung und überprüfbare Zugerklärung ergänzen; Endspielübungen auf gleicher Spiellogik anbieten. Verantwortlich: Play/Review und neue Endspielansicht/Checks.
- [x] 3: Eigene Eröffnungsvarianten lokal per PGN speichern und aktiv üben; lokale Eröffnungsstatistik mit Fallzahlen. Verantwortlich: neue Openings-Dateien/Checks.
- [x] 4: Startseite mit fälligen Wiederholungen und Trainingsempfehlung verknüpfen; eigene Fehlerquoten nach Thema/Phase, Fallzahlen und direkte Übungslinks; Navigation ergänzen.
- [x] 5: Gesamtbuild, vorhandene und neue Flowchecks; unabhängige Codeprüfung; README und Appbundle aktualisieren.

## Review-Fokus
Falsche Spielerfarbe, veraltete Tasks bei Sitzungswechsel, beschädigte Speicherdaten, aus eigener FEN exportierte PGN, doppelte/unterstützte Trainingsversuche. Jede Aufgabe fügt passende kleine Assertions hinzu. Lizenzpflichtige Konkurrenzinhalte werden nicht übernommen.

## Fortschritt
Umsetzung freigegeben; Brainstorming anhand vorherigem Bericht abgeschlossen. User bittet ausdrücklich um Umsetzung mit Agenten. Kein weiterer Freigabeschritt nötig.

Prüfung: Debugbuild grün; TestRunner 475/475; neun Flowchecks grün; Navigation neun Bereiche bei vier Breiten in hell/dunkel grün. Einzelreviews für Wiederholung/Insights und Stellung/Eröffnungen genehmigt. Retention-Inflation durch frühes Wiederholen korrigiert und erneut geprüft.

Zusatzauftrag: Privates GitHub-Repo LeoB070/SchachApp mit deutschem README, aktuellen Screenshots und herunterladbarem App-Release. Damit sind Snapshot-Commit und Push ausdrücklich Teil des Auftrags. Stockfish bleibt separat; offizielle Lizenzhinweise in THIRD_PARTY.md.

Downloadcheck: Releasebundle ad hoc signiert, nur Systembibliotheken, keine Stockfish-Dateien. Kopie unter /private/tmp/SchachApp-Downloadcheck erfolgreich über echte App-Oberfläche gestartet; Startseite und neue Navigation sichtbar. README-Bilder stammen aus gerenderten In-Memory-Beispieldaten, nicht aus privaten Partien.

Abschlussreview: Spezifikation erfüllt, Qualität freigegeben, keine offenen hohen/mittleren Befunde. Repo/Release-Upload und unabhängiger Quellcode-Klon folgen als abschließende Distribution.
