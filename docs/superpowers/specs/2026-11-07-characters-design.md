# Freundlicher Schachclub
Vom Nutzer freigegeben: Tiercharaktere mit illustrierten Porträts, Gegner von 100 bis 1000 Elo in 100er-Schritten, schönere Gegnerauswahl und zusätzliche Einsteiger-Puzzles mit Themen und Fortschritt.

SwiftUI und lokale Ressourcen bleiben bestehen. Vorhandene Bot-IDs und Spielstände bleiben erhalten. Niedrige Elo-Werte sind Schätzungen: häufige zufällige legale Züge schwächen die Stockfish-Auswahl zusätzlich ab. Keine neuen Abhängigkeiten.

## Ansätze
Gewählt: lokale Porträts und Karten im vorhandenen Neue-Partie-Dialog, bestehendes Puzzleformat erweitern. Reine Symbole erfüllen den Bilderwunsch nicht; ein umfassender Navigationsumbau ist unnötig.

## Bildquelle und Prompt
Mit dem eingebauten image_gen-Tool erzeugt. Projektdatei: `Sources/ChessAppKit/Resources/bot-characters.png`.

Prompt: Use case: stylized-concept. Asset type: chess app character portrait atlas. Create ONE square sprite atlas, exactly 4 columns and 4 rows, 16 equally sized square cells with no gutters. Each cell is a centered head-and-shoulders portrait of a different friendly cute woodland animal chess club character, polished soft clay 3D illustration, warm cream background in every cell, consistent scale, readable at 64px, no text, no borders. Row 1: tiny chick with eggshell hat, sleepy sloth, curious bunny, shy hedgehog. Row 2: cheerful bear cub, playful otter, red squirrel with scarf, happy panda. Row 3: fox with green scarf, young raccoon, wise owl with glasses, cautious turtle. Row 4: quick cheetah, elegant cat, silver robot with chess crown, friendly blue fish. Every portrait contained entirely in its own cell with generous margin. This is one cohesive atlas to be cropped into 16 app avatars.

## Verifikation
314 TestRunner-Prüfungen bestanden, keine Fehler. Spielabläufe geprüft. Puzzle-Flow prüft Filtergrenzen, leere Kombinationen, Themenwechsel sowie alle 24 neuen Aufgaben durch Brettklick-Aufrufe einschließlich automatischer Gegnerantwort und Damenumwandlung. Gegnerkarten und Puzzleansicht im Release-Bundle visuell geprüft.

Grenzen: Elo-Angaben sind nicht gegen menschliche Wertungen kalibriert. Die 44 Aufgaben enthalten gespiegelte und farbgetauschte Varianten von elf Grundstellungen. Kein Langzeit-Spielstärkevergleich.
