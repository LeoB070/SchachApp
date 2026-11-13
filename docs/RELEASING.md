# Eine neue Version veröffentlichen

Aktuelle Version: **1.1.0**. Tags folgen dem Schema `vMAJOR.MINOR.PATCH`:
Fehlerkorrekturen erhöhen PATCH, kompatible Funktionen MINOR und inkompatible
Änderungen MAJOR. Frühere Downloads bleiben unter ihren bisherigen Tags erhalten.

## 1. Quellstand vorbereiten

- `CHANGELOG.md` um die tatsächlichen Änderungen und das Veröffentlichungsdatum ergänzen.
- Versionsnummern in `make-app.sh` (`CFBundleShortVersionString`),
  `Sources/ChessAppKit/Kit.swift` und `Windows/ChessClub/ChessClub.csproj` angleichen.
- `CFBundleVersion` in `make-app.sh` für jeden neuen macOS-Build erhöhen.
- Versionsbadge der README aktualisieren.
- `./build.sh test` und die betroffenen Flowprüfungen auf einem Apple-Silicon-Mac ausführen.
- Den Windows-Workflow für genau den zu veröffentlichenden Commit erfolgreich abschließen lassen.
- Beide Apps starten und Installation, Stockfish-Pfadauswahl sowie PGN-Import/-Export prüfen.

## 2. Pakete erstellen

macOS, aus dem Repository-Stamm:

```sh
./make-app.sh
# Für 1.1.0 auf Apple Silicon:
ditto -c -k --sequesterRsrc --keepParent dist/ChessApp.app dist/SchachApp-1.1.0-macOS-arm64.zip
shasum -a 256 dist/SchachApp-1.1.0-macOS-arm64.zip
```

Das Paket ist ad hoc signiert und nicht notarisiert. Dies in den Release-Hinweisen
angeben. Die Architektur im Dateinamen muss dem tatsächlich gebauten Paket entsprechen.

Windows, in PowerShell:

```powershell
dotnet run --project Windows/ChessClub.SelfTest -c Release
dotnet publish Windows/ChessClub/ChessClub.csproj -c Release -r win-x64 --self-contained true -o dist/windows
Compress-Archive -Path dist/windows/* -DestinationPath dist/SchachApp-1.1.0-Windows-x64.zip -Force
Get-FileHash dist/SchachApp-1.1.0-Windows-x64.zip -Algorithm SHA256
```

Den vollständigen Windows-Ausgabeordner paketieren. ZIP-Inhalt prüfen und
beide Pakete nach dem Entpacken testweise starten.

## 3. Hinweise und Lizenzen beilegen

`LICENSE` und `THIRD_PARTY.md` mit den Paketen bereitstellen. Die mitgelieferten
Ressourcen müssen ihre Lizenz- und Herkunftsdateien behalten. Die Windows-
Paketabhängigkeiten und Inter-Schrift sind in `THIRD_PARTY.md` aufgeführt.
Stockfish nicht zu diesen App-Paketen hinzufügen; auf die separate Installation
und die offizielle Downloadseite verweisen.

## 4. GitHub-Release erstellen

1. Den geprüften Stand committen und pushen.
2. Auf GitHub unter **Releases → Draft a new release** den Tag `v1.1.0`
   für genau diesen Commit anlegen.
3. Titel `Dein Schachclub 1.1.0` und die Änderungen aus dem Changelog eintragen.
4. App-ZIPs, `LICENSE`, `THIRD_PARTY.md` und eine `SHA256SUMS.txt` mit den
   Prüfsummen der ZIPs anhängen.
5. Downloadlinks und Paketnamen im Entwurf prüfen, dann veröffentlichen.
6. Den Changelog-Link für 1.1.0 auf die Release-Seite und den Vergleich für
   `Unreleased` auf `v1.1.0...HEAD` umstellen. Versionshinweise in dieser Anleitung aktualisieren. Bereits veröffentlichte Tags nicht verschieben.

Vor dem ersten öffentlichen Release unter **Settings → General → Change repository
visibility** die gewünschte Sichtbarkeit einstellen. Vorher auch die Git-Historie
auf private Informationen prüfen: Gelöschte Dateien können dort weiterhin vorhanden sein.

## Updates für Nutzer

Die App besitzt keinen automatischen Updater. Neue Versionen erscheinen unter
[GitHub Releases](https://github.com/LeoB070/SchachApp/releases). Nutzer können das
Repository über **Watch → Custom → Releases** abonnieren.

Vor einem Update wichtige Partien als PGN exportieren und lokale Daten sichern.
Danach die App schließen und das App-Paket beziehungsweise den vollständigen
Windows-Programmordner ersetzen. Bei Änderungen am Speicherformat nötige
Migrationsschritte ausdrücklich in den Release-Hinweisen dokumentieren.
