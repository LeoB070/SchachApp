<div align="center">

# Dein Schachclub

**Spielen. Verstehen. Besser werden.**

Dein persönlicher Schachtrainer für macOS und Windows.
Botpartien, lokale Stockfish-Analyse und gezieltes Training – ohne App-Konto.

![Version](https://img.shields.io/badge/Version-1.1.0-3d6b57)
![macOS](https://img.shields.io/badge/macOS-14%2B-333333)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4)
[![MIT-Lizenz](https://img.shields.io/badge/Lizenz-MIT-blue)](LICENSE)

[Download](https://github.com/LeoB070/SchachApp/releases) · [Installation](#installation) · [macOS Schritt für Schritt](docs/MACOS-SETUP.md) · [Entwicklung](CONTRIBUTING.md) · [Änderungen](CHANGELOG.md)

</div>

![Startseite mit persönlichen Trainingswegen](docs/images/club-home.png)

Eine Partie endet hier nicht mit dem Ergebnis. Untersuche entscheidende Momente,
finde bessere Züge und trainiere die Ideen, die du beim nächsten Mal erkennen möchtest.
Partien und Lernfortschritt bleiben auf deinem Gerät.

## Funktionen

- **Spielen:** Auf dem Mac warten 15 Botgegner mit eigenen Pixelporträts, verschiedenen Spielstärken und wählbarer Bedenkzeit.
- **Analysieren:** Stockfish zeigt Bewertungen und Alternativen. Der Mac-Partierückblick ergänzt Zugqualität, Bewertungsverlauf und Schlüsselmomente.
- **Trainieren:** 52 kuratierte Puzzles, Lektionen und Endspielübungen. Auf dem Mac kommen geplante Wiederholungen und Aufgaben aus eigenen Fehlern hinzu.
- **Eröffnungen lernen:** Eröffnungslexikon auf beiden Plattformen; eigene PGN-Hauptvarianten und persönlicher Eröffnungsbaum auf dem Mac.
- **Partien sammeln:** Lokales Archiv sowie PGN-Import und -Export zum Austausch zwischen Geräten.
- **Anpassen:** Helle und dunkle Darstellung, verschiedene Brettfarben und Figurensätze.

Die **Mac-Version bietet den größeren Funktionsumfang**. Windows unterstützt unter
anderem lokales Spiel zu zweit, vier Stockfish-Botstufen und Stellungsanalyse.
Die [Plattformübersicht](docs/PLATFORMS.md) beschreibt Unterschiede und Tiefanalyse.

<table>
<tr>
<td><img src="docs/images/club-review.png" alt="Partierückblick mit Brett, Zugqualität und Bewertungsverlauf"></td>
<td><img src="docs/images/club-endgames.png" alt="Endspieltraining mit Turmmatt, Damenmatt und Bauernumwandlung"></td>
</tr>
<tr><td align="center">Die entscheidenden Momente verstehen</td><td align="center">Typische Endspiele gezielt üben</td></tr>
</table>

## Installation

### macOS

**Neu hier?** Die [Schritt-für-Schritt-Anleitung für macOS](docs/MACOS-SETUP.md)
führt vom ersten Terminal-Befehl bis zur geöffneten App.

**Voraussetzung:** macOS 14 oder neuer. Bisher auf Apple Silicon geprüft;
Intel-Macs sind nicht verifiziert.

1. Unter [Releases](https://github.com/LeoB070/SchachApp/releases) ein macOS-App-ZIP herunterladen und entpacken. Die aktuelle Version ist **1.1.0**.
2. `ChessApp.app` in den Programme-Ordner ziehen.
3. [Stockfish einrichten](#stockfish-einrichten), dann die App öffnen.

Die App ist ad hoc signiert und nicht von Apple notarisiert. Falls macOS das
Öffnen blockiert, folge der [Apple-Anleitung zum Öffnen vertrauenswürdiger Apps](https://support.apple.com/de-de/102445).

### Windows

**Voraussetzung:** Windows 10/11 x64, [Git](https://git-scm.com/downloads/win)
und das [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).
In PowerShell:

```powershell
git clone https://github.com/LeoB070/SchachApp.git
cd SchachApp
dotnet run --project Windows/ChessClub
```

Alternativ stellt der Workflow [Windows desktop](https://github.com/LeoB070/SchachApp/actions/workflows/windows.yml)
einen Build als Artefakt bereit. Zum Herunterladen von Actions-Artefakten ist ein
GitHub-Login erforderlich. Den gesamten Ordner entpacken und `DeinSchachclub.exe` starten.

### Stockfish einrichten

**Die Schachanalyse und Engine-Bots werden von [Stockfish](https://stockfishchess.org/) unterstützt.**
Stockfish ist ein eigenständiges Open-Source-Projekt unter **GPLv3** und wird
**nicht mit dieser App gebündelt**. Die App kommuniziert mit der separat
installierten Engine über das UCI-Protokoll.

Auf dem Mac mit [Homebrew](https://brew.sh/):

```sh
brew install stockfish
```

Die App erkennt `/opt/homebrew/bin/stockfish` und `/usr/local/bin/stockfish`.
Alternativ die passende Engine für macOS oder Windows von der
[offiziellen Downloadseite](https://stockfishchess.org/download/) herunterladen,
entpacken und die ausführbare Datei in den App-Einstellungen auswählen.
Unter Windows ist das die `.exe`, nicht das ZIP-Archiv.

Ohne installierte Engine stehen Stockfish-Bots und Engine-Analyse nicht zur Verfügung.
Herkunft und Lizenzen aller Fremdkomponenten stehen in [THIRD_PARTY.md](THIRD_PARTY.md).

## Aus dem Quellcode bauen

Für macOS genügt der geführte Installer im entpackten Quellcode-Ordner:

```sh
sh start.sh
```

`start.sh` installiert fehlende Xcode Command Line Tools, Homebrew und Stockfish,
baut die App und öffnet sie. Bestätigungen im Apple- oder Homebrew-Installer
bleiben erforderlich. Für eine neue Homebrew-Installation wird offiziell macOS 15+
unterstützt; die App selbst benötigt macOS 14+.
Die [Schritt-für-Schritt-Anleitung](docs/MACOS-SETUP.md) beginnt beim ZIP-Download
und benötigt kein vorinstalliertes Git. Die Build-Ausgabe steht in `dist/setup.log`.

Entwicklungsstart, Prüfungen und Windows-Paketierung sind in
[CONTRIBUTING.md](CONTRIBUTING.md) beschrieben. Für neue Versionen gibt es eine
[Release-Anleitung](docs/RELEASING.md).

## Daten und Grenzen

Es gibt keinen App-Login, kein Online-Matchmaking und keine Server-Synchronisierung.
Partien lassen sich per PGN zwischen Geräten übertragen; Git synchronisiert keine
Spielstände. Windows speichert lokale Daten unter `%LOCALAPPDATA%\DeinSchachclub`.

Bot-Elo und geschätzte Partie-Elo dienen der Trainingsorientierung und sind keine
offiziellen Wertungen. Die Puzzlesammlung ist bewusst klein. Der Mac-Eröffnungstrainer
verarbeitet PGN-Hauptlinien; Endspielübungen ersetzen keine Tablebases.

## Mitmachen und Lizenz

Fehler gefunden oder eine Idee? Erstelle ein
[Issue](https://github.com/LeoB070/SchachApp/issues/new/choose).
Hinweise für Codebeiträge stehen in [CONTRIBUTING.md](CONTRIBUTING.md).

Der eigene Projektcode steht unter der [MIT-Lizenz](LICENSE).
Mitgelieferte Figuren, Daten, Schriften und Bibliotheken behalten ihre jeweiligen
Lizenzen; siehe [Fremdkomponenten](THIRD_PARTY.md). Stockfish ist ein separates
Projekt und fällt nicht unter die MIT-Lizenz dieses Repositories.
