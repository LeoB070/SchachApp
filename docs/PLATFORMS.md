# Plattformen und Funktionsumfang

[Zur README](../README.md)

### Aktueller Windows-Umfang

Die Windows-App übernimmt Palette, Startseitenaufbau, Emil-Pixelporträt,
Brettfarben und Originalfiguren. Plattformtypische Controls unterscheiden sich;
die Darstellung ist an die Mac-App angelehnt und nicht pixelidentisch.

| In Windows vorhanden | Bisher nur in der Mac-Version |
|---|---|
| Lokales Spiel für zwei Personen oder gegen Stockfish, vier Botstufen, freie Farbwahl, Umwandlung | Schachuhr und 15 individuelle Botpersönlichkeiten |
| Normale Stellungsanalyse und Tiefanalyse, FEN laden, Partieverlauf durchgehen | Vollständige Partieauswertung mit Accuracy, Zugklassen und Bewertungsgraph |
| 52 Puzzles, Lektionen und Endspielübungen, lokaler Abschlussfortschritt | Puzzle-Rating, geplante Wiederholungen und automatische Aufgaben aus eigenen Fehlern |
| Eröffnungslexikon, PGN-Import/-Export und lokales Partienarchiv | Eigene Eröffnungsvarianten aktiv trainieren und persönliche Trainingsempfehlungen |
| Helle/dunkle Darstellung, fünf Brettfarben und drei Figurensätze | Vollständige Funktionsgleichheit der beiden Apps |

Die Windows-Daten liegen unter `%LOCALAPPDATA%\DeinSchachclub`.
Beim normalen Beenden wird eine gespielte Partie archiviert; eine laufende
Partie wird nach einem Neustart nicht automatisch am Brett fortgesetzt.

### Tiefanalyse

Die Tiefanalyse untersucht die **aktuell angezeigte Brettstellung**, nicht
automatisch jede Stellung der gesamten Partie. Sie verwendet ein eigenes Ressourcenprofil:
verfügbare CPU-Threads und RAM werden automatisch erkannt, mit Reserven für
Betriebssystem und Oberfläche. Normales Spielen behält seine eigenen Parameter.
Die Oberfläche zeigt die gewählten Ressourcen sowie den tatsächlichen
Analysefortschritt; eine laufende Suche lässt sich abbrechen. Das Zeitbudget
beträgt höchstens 30 Minuten pro Stellung. Bei 16 erkannten logischen Prozessoren
(mit aktiviertem SMT) verwendet das Profil 14 Threads und
Zieltiefe 30; der Hash-Speicher richtet sich nach dem RAM und ist auf 4 GB begrenzt.

Mehr Threads sind keine garantierte Suchtiefe. Komplexe Stellungen brauchen
auch auf einem Ryzen 7 deutlich länger; entscheidend ist die angezeigte,
tatsächlich erreichte Tiefe. [Stockfish erklärt Threads und Hash](https://official-stockfish.github.io/docs/stockfish-wiki/Stockfish-FAQ.html).

