# Schachclub Implementation Plan

Goal: Freigegebene Tiergegner und Einsteigertraining in der bestehenden App umsetzen.
Architecture: Bestehende BotLibrary, SwiftUI-Ansichten und gebündelte JSON-Daten erweitern.
Tech Stack: Swift, SwiftUI, SwiftPM; keine zusätzlichen Abhängigkeiten.
Spec: ../specs/2026-11-07-characters-design.md

## Global Constraints
Bestehende Bot-IDs und Nutzerdaten erhalten. Elo-Werte als ungefähr kennzeichnen.

## Review Focus
Legale Züge bei schwachen Bots; Matt/Patt; abgebrochene Tasks; vollständige Porträts im App-Bundle; legale Puzzlefolgen beider Farben.

## Aufgaben
- [x] Tests für 100er-Abstufungen, legale Zufallszüge und erweiterte Puzzleinhalte ergänzen und fehlschlagen sehen.
- [x] BotLibrary und Zugauswahl erweitern; bestehende starke Bots beibehalten.
- [x] Illustrierten Charakteratlas lokal speichern, Porträts einbinden und Auswahlkarten erstellen.
- [x] Einsteiger-Puzzles, Themenbeschreibungen, Schwierigkeitsfilter und Lösungsfortschritt ergänzen.
- [x] TestRunner, Puzzle-/Spielabläufe und Release-Bundle prüfen.
