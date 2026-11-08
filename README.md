<div align="center">

# ♞ Dein Schachclub

### Ein guter Zug. Eine neue Idee. Dein nächster Schritt.

Eine persönliche Schach-App für den Mac — zum Spielen, Verstehen und Besserwerden.

**Offline · Einzeltraining · SwiftUI · Stockfish als lokale Engine**

[App herunterladen](https://github.com/LeoB070/SchachApp/releases) · [Loslegen](#auf-deinem-mac-loslegen) · [Stockfish installieren](#stockfish-die-engine-hinter-dem-brett)

</div>

![Dein Schachclub: persönliche Startseite mit Trainingswegen](docs/images/club-home.png)

Du hast eine gute Stellung erreicht — und sie dann doch noch aus der Hand gegeben?
Hier endet die Partie nicht mit dem Ergebnis. Schau dir die entscheidenden Momente
an, finde selbst einen besseren Zug und spiele die Stellung noch einmal gegen einen
Bot. Später begegnet dir die Idee erneut, bis du sie am Brett wiedererkennst.

**Dein Schachclub ist dein Trainingspartner.** Ohne Konto in der App, ohne
Onlinegegner und in deinem eigenen Tempo. Nach Installation der separaten Engine
bleiben Partien, Analyse und Training auf deinem Mac.

## Was dich am Brett erwartet

| Spielen | Verstehen | Dranbleiben |
|---|---|---|
| 15 Botgegner mit eigenen Pixelporträts, unterschiedlichen Stärken und direkter Revanche | Lokale Stockfish-Analyse mit Bewertungsverlauf, Zugqualität und Eröffnungsnamen | Geplante Puzzle-Wiederholungen nach 1, 3, 7, 14 und 30 Tagen |
| Farbe und Bedenkzeit selbst wählen — oder entspannt ohne Uhr spielen | Bis zu drei Schlüsselmomente selbst verbessern und Zugkandidaten vergleichen | Persönliche Übungsempfehlungen aus deinen protokollierten Ergebnissen |
| Eine Analysestellung separat gegen einen Bot weiterspielen | Sichtbare Brettfolgen statt bloßer Zahlen: Schach, Schlagen und Matt | Eigene Eröffnungsvarianten aktiv trainieren und Endspiele gezielt üben |

### Aus deinen Partien wird dein Training

- **Deine zweite Chance:** Stockfish prüft eigene Fehler und erstellt daraus eindeutige Übungsentscheidungen.
- **Heute wiederholen:** Schwierige Aufgaben kommen mit Abstand zurück. Hinweise und Fehler setzen das Intervall zurück; Wiederholungen verändern dein Puzzle-Rating nicht.
- **Ein Muster nach dem anderen:** 52 kuratierte Puzzles, darunter mehrzügige Kombinationen, mit Themenfiltern und Hinweisen von der Idee bis zum Zielfeld.
- **Meine Eröffnungen:** PGN-Hauptvarianten speichern, eine Farbe wählen und die eigenen Züge auf dem Brett abrufen. Der persönliche Eröffnungsbaum zeigt deine Fortsetzungen samt Ergebnissen und Fallzahlen.
- **Endspiele zum Ausprobieren:** Kleine Übungsstellungen mit konkretem Ziel, etwa Matt mit Turm oder Bauernumwandlung.
- **Dein Archiv:** Partien als PGN importieren, wieder ansehen und exportieren. Trainingssitzungen überschreiben keine Originalpartien.

![Partierückblick mit Brett, Analyse und entscheidenden Momenten](docs/images/club-review.png)

![Endspiele am Brett: Turmmatt, Damenmatt und Bauernumwandlung](docs/images/club-endgames.png)

## Auf deinem Mac loslegen

**Voraussetzung:** Mac mit Apple Silicon (M1 oder neuer), macOS 14 oder neuer.
Intel-Macs sind bisher nicht geprüft. Das Repository ist privat: Du brauchst eine
GitHub-Einladung und musst sie annehmen, bevor du Code oder Releases öffnen kannst.

### Einfach: fertige App herunterladen

1. Unter [Releases](https://github.com/LeoB070/SchachApp/releases) das ZIP der App herunterladen und entpacken.
2. `ChessApp.app` in deinen Programme-Ordner ziehen.
3. Stockfish separat installieren, siehe unten.
4. App öffnen und losspielen. Falls die Engine nicht automatisch gefunden wird, ihre ausführbare Datei unter **Einstellungen** auswählen.

Die App ist lokal ad hoc signiert, aber nicht von Apple notarisiert. macOS kann
beim ersten Öffnen eine Sicherheitsbestätigung verlangen. Nutze dafür die
[offizielle Apple-Anleitung](https://support.apple.com/de-de/102445), wenn du dem
Download vertraust; die Sicherheitseinstellungen müssen nicht global abgeschaltet werden.

### Oder: selbst bauen

Du brauchst Swift 6 und die Xcode Command Line Tools. Volles Xcode ist nicht nötig.
Installiere die Tools bei Bedarf mit `xcode-select --install` und prüfe anschließend
`swift --version`.

```sh
git clone https://github.com/LeoB070/SchachApp.git
cd SchachApp
./make-app.sh
open dist/ChessApp.app
```

Alternativ im privaten Repo über **Code → Download ZIP** herunterladen, entpacken,
im Terminal in den Ordner wechseln und die letzten beiden Befehle ausführen.

## Stockfish: die Engine hinter dem Brett

Stockfish wird **nicht mitgeliefert**. Mit vorhandenem [Homebrew](https://brew.sh/) genügt:

```sh
brew install stockfish
```

Die App sucht automatisch unter `/opt/homebrew/bin/stockfish` und
`/usr/local/bin/stockfish`. Ohne Homebrew geht es über den
[offiziellen macOS-Download](https://stockfishchess.org/download/); wähle danach
die ausführbare Engine-Datei in den App-Einstellungen aus.

**Stockfish ist freie Software unter GPLv3.** Nutzung und Weitergabe sind unter
den Lizenzbedingungen erlaubt. Wer die Engine selbst mitverteilt, muss unter
anderem Lizenz und passenden Quellcode beziehungsweise dessen Bezugsstelle
bereitstellen — auch bei privater Weitergabe. Dieses Projekt nutzt eine separat
installierte Engine als eigenen UCI-Prozess. Siehe die
[offiziellen Stockfish-Hinweise](https://official-stockfish.github.io/docs/stockfish-wiki/Developers.html#terms-of-use)
und [Fremdkomponenten](THIRD_PARTY.md).

## Dein Fortschritt gehört dir

Partien und Lernfortschritt werden lokal gespeichert. Es gibt keinen App-Login,
kein Matchmaking und keine Synchronisierung mit einem Server. Eigene Partien
werden am Spielernamen **„Du“** erkannt; importierte fremde Partien gelten nicht
automatisch als deine Ergebnisse. Sichere deine Daten selbst, wenn du auf einen
anderen Mac wechselst.

Ein paar ehrliche Grenzen: Die Aufgabensammlung ist bewusst klein. Bot-Elo und
geschätzte Partie-Elo sind Trainingsorientierungen, keine offiziellen Wertungen.
Empfehlungen zeigen ihre Fallzahlen; wenige Versuche ergeben noch kein belastbares
Schwächenprofil. Der Eröffnungstrainer importiert die PGN-Hauptlinie, keinen
vollständigen Variantenkurs. Endspieltraining ersetzt keine perfekten Tablebase-Urteile.

<details>
<summary><strong>Für Neugierige: Technik und Checks</strong></summary>

SwiftUI, Core Data, ein eigener Schachkern und ein separater UCI-Prozess.
Keine externen Swift-Paketabhängigkeiten.

```sh
./build.sh build
./build.sh test
sh Scripts/check-play-flows.sh
sh Scripts/check-club-flows.sh
sh Scripts/check-review-flows.sh
sh Scripts/check-puzzle-flows.sh
sh Scripts/check-repetition.sh
sh Scripts/check-training-insights.sh
sh Scripts/check-training-positions.sh
sh Scripts/check-review-candidates.sh
sh Scripts/check-opening-training.sh
sh Scripts/check-navigation-layout.sh
```

`build.sh` verwendet den nativen SwiftPM-Builder. In der Command-Line-Tools-Umgebung
werden die Swift-Testing-Tests kompiliert; die ausführbaren Assertions laufen im
zusätzlichen TestRunner und den Flowchecks.

</details>

---

**Mach aus „Das hätte ich sehen müssen“ ein „Das kenne ich“.**
