# macOS: Schritt für Schritt starten

[Zur README](../README.md)

Diese Anleitung baut die App auf deinem Mac. Du brauchst macOS 14 oder neuer,
eine Internetverbindung für den Download und ausreichend Platz für Entwicklerwerkzeuge.
Der Quellbuild ist bisher auf Apple Silicon geprüft.

## 1. Terminal öffnen

Öffne mit `⌘ Leertaste` die Spotlight-Suche, tippe **Terminal** und drücke Enter.
Befehle aus dieser Anleitung jeweils kopieren, einfügen und mit Enter ausführen.

## 2. Projekt herunterladen – ohne Git

Öffne die [Release-Seite](https://github.com/LeoB070/SchachApp/releases/tag/v1.1.0)
und lade unter **Assets → Source code (zip)** den Quellcode herunter.
Entpacke das ZIP per Doppelklick. Dafür brauchst du weder Git noch Xcode.

Tippe im Terminal `cd ` (mit Leerzeichen), ziehe den entpackten Projektordner
ins Terminal und drücke Enter. So funktioniert es auch bei Leerzeichen im Ordnernamen.

## 3. Alles einrichten und starten

```sh
sh start.sh
```

Das Skript zeigt vier Schritte und verwendet vorhandene Installationen weiter:

1. **Mac und Entwicklerwerkzeuge:** Fehlen die Xcode Command Line Tools,
   öffnet es den Apple-Installationsdialog. Dort **Installieren** wählen,
   die Installation abwarten und anschließend im Terminal Enter drücken.
2. **Homebrew und Stockfish:** Fehlt Homebrew, lädt und startet das Skript den
   [offiziellen Homebrew-Installer](https://brew.sh/). Dieser zeigt seine Änderungen
   und fordert ggf. Enter oder dein Mac-Administratorpasswort an. Anschließend
   wird Stockfish über `brew install stockfish` installiert, falls es fehlt.
3. **App bauen:** Die App wird kompiliert und lokal signiert. Der erste Build
   kann einige Minuten dauern. Die Compiler-Ausgabe steht in `dist/setup.log`.
4. **App öffnen:** Nach erfolgreichem Build öffnet sich `dist/ChessApp.app`.

Bei der Passworteingabe zeigt das Terminal keine Zeichen an; das ist normal.
Gib dein Passwort ausschließlich in den Systemdialog beziehungsweise die
Passwortabfrage des offiziellen Homebrew-Installers ein.

### Voraussetzungen und Systemgrenzen

Die App benötigt macOS 14+, der Quellbuild Swift 6+. Für eine **neue Homebrew-
Installation unterstützt Homebrew offiziell macOS 15+**; siehe die
[aktuellen Voraussetzungen](https://docs.brew.sh/Installation).
Apple Silicon ist die bisher geprüfte Architektur.

Wenn Swift trotz installierter Werkzeuge älter als Version 6 ist, zeigt der
Starter den nötigen Updatehinweis. Die Command Line Tools dann über
**Systemeinstellungen → Allgemein → Softwareupdate** aktualisieren und den
Starter erneut ausführen. Das Skript führt kein Betriebssystem-Upgrade durch.

Auf macOS 14 ohne Homebrew kannst du die Engine von
[stockfishchess.org/download](https://stockfishchess.org/download/) herunterladen,
mit `sh make-app.sh` bauen und `dist/ChessApp.app` im Finder öffnen. Wähle die
entpackte Engine anschließend in den App-Einstellungen aus.

## 4. So sieht der Start aus

Beispiel bei vorhandenen Werkzeugen; Versionen und Pfade hängen vom Mac ab:

```text
♞  Dein Schachclub — macOS-Start
────────────────────────────────────────

[1/4] Mac und Entwicklerwerkzeuge prüfen
✓ macOS 15.0 · Swift 6

[2/4] Homebrew und Stockfish einrichten
✓ Homebrew gefunden: /opt/homebrew/bin/brew
Stockfish installieren (brew install stockfish) …
✓ Stockfish installiert

[3/4] App bauen und lokal signieren
Der erste Build kann einige Minuten dauern. Build-Ausgabe: dist/setup.log
✓ App erstellt: dist/ChessApp.app

[4/4] Dein Schachclub öffnen
✓ Start an macOS übergeben. Viel Spaß am Brett!
```

Installationsausgaben bleiben im Terminal sichtbar. Bei einem Buildfehler zeigt
der Starter die letzten Meldungen und öffnet keine möglicherweise veraltete App.
Abgebrochene Installationen kannst du mit `sh start.sh` erneut aufnehmen.

## 5. Am Brett loslegen

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
| `git` oder Entwicklerwerkzeuge fehlen | `sh start.sh` ausführen und den Apple-Installationsdialog abschließen. |
| Swift ist zu alt | Command Line Tools über macOS-Softwareupdate aktualisieren. |
| `cd: no such file or directory` | Den tatsächlichen Projektordner hinter `cd ` ins Terminal ziehen. |
| `Permission denied` bei `./start.sh` | `sh start.sh` verwenden. |
| Build schlägt fehl | `cat dist/setup.log` ausführen und die Fehlermeldung prüfen. |
| macOS blockiert einen heruntergeladenen Build | Der [Apple-Anleitung](https://support.apple.com/de-de/102445) für vertrauenswürdige Apps folgen. |
| Keine Engine-Bots oder Analyse | Stockfish installieren und den Engine-Pfad in der App wählen. |

## Später aktualisieren

App schließen, wichtige Partien vorher als PGN exportieren und lokale Daten sichern.
Bei einer Git-Arbeitskopie ohne lokale Änderungen (optional für Entwickler):

```sh
cd ~/Developer/SchachApp
git pull --ff-only
./start.sh
```

Wenn Git lokale Änderungen oder abweichende Branches meldet, diese zuerst klären;
der Befehl verwirft sie nicht automatisch. Bei einem ZIP-Download stattdessen die
neue Version in einen eigenen Ordner entpacken und dort den Starter ausführen.
Hinweise zur jeweiligen Version stehen im [Changelog](../CHANGELOG.md).
