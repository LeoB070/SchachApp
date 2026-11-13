# Beiträge und Entwicklung

Danke für dein Interesse an Dein Schachclub. Für Fehler und Vorschläge bitte
zuerst nach bestehenden [Issues](https://github.com/LeoB070/SchachApp/issues) suchen.
Größere Änderungen am besten vor der Umsetzung in einem Issue besprechen.

## Projektstruktur

| Pfad | Inhalt |
| --- | --- |
| `Sources/ChessApp/` | macOS-Oberfläche und Trainingsabläufe in SwiftUI |
| `Sources/ChessAppKit/` | Schachregeln, Engine-Anbindung, Analyse und Persistenz |
| `Sources/ChessAppKit/Resources/` | Figuren, Eröffnungsdaten, Puzzles und Lektionen |
| `Tests/` und `Sources/TestRunner/` | Swift-Tests und ausführbare Kernprüfungen |
| `Scripts/` | Zusätzliche Flow-, Daten- und Darstellungsprüfungen |
| `Windows/` | Windows-App in C# / Avalonia und SelfTest |
| `docs/` | Plattformhinweise, Release-Anleitung und Designhistorie |

## macOS entwickeln

Voraussetzungen: macOS 14+, Swift 6 und Xcode Command Line Tools.
Die vorhandenen Flow-Skripte und der Test-Wrapper verwenden Apple-Silicon-Buildpfade.
Stockfish für vollständige Engine-Prüfungen separat installieren.

```sh
./build.sh build
./build.sh run ChessApp
./build.sh test
```

Der Test-Wrapper kompiliert die Swift-Testing-Tests und führt anschließend den
zusätzlichen `TestRunner` aus, damit Assertions auch in der CLT-Umgebung laufen.
Nach Änderungen an einem Trainingsablauf die passende Flowprüfung ausführen,
beispielsweise:

```sh
sh Scripts/check-play-flows.sh
sh Scripts/check-review-flows.sh
sh Scripts/check-puzzle-flows.sh
sh Scripts/check-opening-training.sh
```

Weitere `check-*.sh`-Skripte liegen unter `Scripts/`.
Den Terminal-Starter mit `python3 Scripts/check-start.py` prüfen (Python 3,
keine zusätzlichen Pakete; Build und App-Start werden dabei simuliert).

## Windows entwickeln

Voraussetzung: .NET 8 SDK, für die Oberfläche Windows 10/11 x64.

```powershell
dotnet run --project Windows/ChessClub
dotnet run --project Windows/ChessClub.SelfTest -c Release
dotnet publish Windows/ChessClub/ChessClub.csproj -c Release -r win-x64 --self-contained true -o dist/windows
```

Zum Weitergeben den gesamten Ausgabeordner verwenden. Der Workflow
[Windows desktop](.github/workflows/windows.yml) führt SelfTest und Paketierung aus.

## Pull Requests

- Änderungen auf eine nachvollziehbare Aufgabe begrenzen.
- Verhalten vorher/nachher und ausgeführte Prüfungen beschreiben.
- Bei sichtbaren Änderungen einen Screenshot ergänzen.
- Keine Spielstände, Zugangsdaten, lokalen Buildordner oder Engine-Binärdateien einchecken.
- Herkunfts- und Lizenzhinweise bei neuen Ressourcen in `THIRD_PARTY.md` ergänzen.

Beiträge zum eigenen Projektcode erfolgen unter der [MIT-Lizenz](LICENSE).
