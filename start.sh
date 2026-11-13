#!/bin/sh
# Guided local setup; software installation remains an explicit user action.
set -eu
cd "$(dirname "$0")"

printf '\n♞  Dein Schachclub — macOS-Start\n'
printf '────────────────────────────────────────\n'
printf '\n[1/4] Mac und Entwicklerwerkzeuge prüfen\n'
if [ "$(uname -s)" != Darwin ]; then
    printf 'Dieser Starter benötigt macOS. Windows: siehe README.md.\n' >&2
    exit 1
fi
macos=$(sw_vers -productVersion)
if [ "${macos%%.*}" -lt 14 ]; then
    printf 'macOS %s erkannt. Benötigt wird macOS 14 oder neuer.\n' "$macos" >&2
    exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
    printf 'Die Xcode Command Line Tools fehlen. Führe aus:\n\n  xcode-select --install\n\nDanach dieses Skript erneut starten.\n' >&2
    exit 1
fi
swift_version=$(swift --version)
swift_major=$(printf '%s\n' "$swift_version" | sed -n 's/.*Swift version \([0-9][0-9]*\).*/\1/p' | head -1)
if [ -z "$swift_major" ] || [ "$swift_major" -lt 6 ]; then
    printf 'Swift 6 oder neuer benötigt. Aktualisiere die Command Line Tools über die macOS-Softwareupdates.\n' >&2
    exit 1
fi
printf '✓ macOS %s · Swift %s\n' "$macos" "$swift_major"

printf '\n[2/4] Stockfish suchen\n'
engine=''
for candidate in /opt/homebrew/bin/stockfish /usr/local/bin/stockfish; do
    if [ -x "$candidate" ]; then engine=$candidate; break; fi
done
if [ -n "$engine" ]; then
    printf '✓ Engine gefunden: %s\n' "$engine"
else
    printf 'Hinweis: Keine Engine an den Standardpfaden gefunden.\n'
    printf 'Mit Homebrew installieren: brew install stockfish\n'
    printf 'Oder von https://stockfishchess.org/download/ laden und in den App-Einstellungen auswählen.\n'
    printf 'Die App startet auch ohne Engine; Engine-Bots und Analyse benötigen Stockfish.\n'
fi

printf '\n[3/4] App bauen und lokal signieren\n'
printf 'Der erste Build kann einige Minuten dauern. Build-Ausgabe: dist/setup.log\n'
mkdir -p dist
if ! ./make-app.sh > dist/setup.log 2>&1; then
    printf '\nDer Build ist fehlgeschlagen. Letzte Meldungen:\n' >&2
    tail -n 30 dist/setup.log >&2
    printf '\nVollständiges Protokoll: %s/dist/setup.log\n' "$PWD" >&2
    exit 1
fi
printf '✓ App erstellt: dist/ChessApp.app\n'

printf '\n[4/4] Dein Schachclub öffnen\n'
if ! open dist/ChessApp.app; then
    printf 'Die App konnte nicht geöffnet werden. Öffne dist/ChessApp.app im Finder.\n' >&2
    exit 1
fi
printf '✓ Start an macOS übergeben. Viel Spaß am Brett!\n'
printf 'Erneut starten: ./start.sh — oder dist/ChessApp.app im Finder öffnen.\n\n'
