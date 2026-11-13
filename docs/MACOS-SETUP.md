# macOS: Schritt für Schritt starten

[Zur README](../README.md)

Diese Anleitung baut die App auf deinem Mac. Du brauchst macOS 14 oder neuer,
eine Internetverbindung für den Download und ausreichend Platz für Entwicklerwerkzeuge.
Der Quellbuild ist bisher auf Apple Silicon geprüft.

## 1. Terminal öffnen

Öffne mit `⌘ Leertaste` die Spotlight-Suche, tippe **Terminal** und drücke Enter.
Befehle aus dieser Anleitung jeweils kopieren, einfügen und mit Enter ausführen.

## 2. Entwicklerwerkzeuge installieren

```sh
xcode-select --install
```

Im macOS-Dialog **Installieren** wählen und die Installation abwarten.
Wenn die Werkzeuge bereits installiert sind, kannst du direkt weitermachen.
Prüfe die Swift-Version:

```sh
swift --version
```

Benötigt wird **Swift 6 oder neuer**. Bei einer älteren Version die Command Line
Tools über **Systemeinstellungen → Allgemein → Softwareupdate** aktualisieren.
Volles Xcode ist für diesen Build nicht erforderlich.

## 3. Projekt herunterladen

```sh
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/LeoB070/SchachApp.git
cd SchachApp
```

Das Projekt liegt jetzt in deinem Benutzerordner unter `Developer/SchachApp`.
Wenn du es schon geklont hast, öffne stattdessen den vorhandenen Projektordner.

Alternativ auf GitHub **Code → Download ZIP** wählen, das ZIP entpacken und den
Ordner im Terminal öffnen: `cd ` eingeben (mit Leerzeichen), den entpackten Ordner
ins Terminal ziehen und Enter drücken.

## 4. Stockfish installieren

Stockfish übernimmt Engine-Bots und Analyse. Die Engine wird separat installiert
und ist nicht im App-Paket enthalten.

Wenn [Homebrew](https://brew.sh/) bereits installiert ist:

```sh
brew install stockfish
```

Ohne Homebrew kannst du die passende macOS-Engine direkt von
[stockfishchess.org/download](https://stockfishchess.org/download/) herunterladen
und entpacken. Wähle ihre ausführbare Datei später in den App-Einstellungen aus.
Den Starter kannst du auch ohne Engine ausführen; er weist auf die fehlende
Engine hin und öffnet die App trotzdem.

## 5. Geführten Start ausführen

Im Projektordner:

```sh
./start.sh
```

Bei einem ZIP-Download kann das Ausführungsrecht fehlen. Dann funktioniert:

```sh
sh start.sh
```

Der Starter zeigt nacheinander, was er gerade macht. Beispielausgabe
(Pfade und Versionsangaben hängen von deinem Mac ab):

```text
♞  Dein Schachclub — macOS-Start
────────────────────────────────────────

[1/4] Mac und Entwicklerwerkzeuge prüfen
✓ macOS 14.0 · Swift 6

[2/4] Stockfish suchen
✓ Engine gefunden: /opt/homebrew/bin/stockfish

[3/4] App bauen und lokal signieren
Der erste Build kann einige Minuten dauern. Build-Ausgabe: dist/setup.log
✓ App erstellt: dist/ChessApp.app

[4/4] Dein Schachclub öffnen
✓ Start an macOS übergeben. Viel Spaß am Brett!
```

Der Starter installiert keine Software im Hintergrund. Bei fehlenden Werkzeugen
zeigt er den nächsten Schritt an. Der erste Build kann einige Minuten dauern;
die Compiler-Ausgabe wird in `dist/setup.log` gespeichert. Bei einem Fehler zeigt
der Starter die letzten Meldungen und öffnet keine möglicherweise veraltete App.

## 6. Am Brett loslegen

Nach dem Öffnen kannst du eine Botpartie, Puzzles oder Lektionen auswählen.
Falls Stockfish nicht erkannt wird, wähle in den **Einstellungen** die entpackte,
ausführbare Engine-Datei. Wähle kein ZIP und keinen Ordner.

Für spätere Starts genügt ein Doppelklick auf `dist/ChessApp.app`. Du kannst die
App auch in den Programme-Ordner kopieren. Das Terminal darf danach geschlossen werden.
`./start.sh` prüft und baut die App bei erneutem Aufruf wieder; unveränderte
Buildschritte werden vom vorhandenen Buildsystem wiederverwendet.

## Häufige Probleme

| Meldung / Situation | Nächster Schritt |
| --- | --- |
| `git` oder Entwicklerwerkzeuge fehlen | Schritt 2 abschließen und das Terminal erneut öffnen. |
| Swift ist zu alt | Command Line Tools über macOS-Softwareupdate aktualisieren. |
| `cd: no such file or directory` | Den tatsächlichen Projektordner hinter `cd ` ins Terminal ziehen. |
| `Permission denied` bei `./start.sh` | `sh start.sh` verwenden. |
| Build schlägt fehl | `cat dist/setup.log` ausführen und die Fehlermeldung prüfen. |
| macOS blockiert einen heruntergeladenen Build | Der [Apple-Anleitung](https://support.apple.com/de-de/102445) für vertrauenswürdige Apps folgen. |
| Keine Engine-Bots oder Analyse | Stockfish installieren und den Engine-Pfad in der App wählen. |

## Später aktualisieren

App schließen, wichtige Partien vorher als PGN exportieren und lokale Daten sichern.
Bei einer unveränderten Git-Arbeitskopie:

```sh
cd ~/Developer/SchachApp
git pull --ff-only
./start.sh
```

Wenn Git lokale Änderungen oder abweichende Branches meldet, diese zuerst klären;
der Befehl verwirft sie nicht automatisch. Bei einem ZIP-Download stattdessen die
neue Version in einen eigenen Ordner entpacken und dort den Starter ausführen.
Hinweise zur jeweiligen Version stehen im [Changelog](../CHANGELOG.md).
