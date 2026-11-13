#!/bin/sh
# Install missing prerequisites, then build and open the local app.
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
    printf 'Entwicklerwerkzeuge fehlen. Starte den Apple-Installer (xcode-select --install).\n'
    xcode-select --install || printf 'Falls bereits ein Installationsdialog offen ist, schließe die Installation dort ab.\n'
    printf 'Im Apple-Dialog installieren. Nach Abschluss hier Enter drücken: '
    if ! read -r answer || ! xcrun --find swift >/dev/null 2>&1; then
        printf '\nDie Werkzeuge sind noch nicht verfügbar. Installation abschließen und ./start.sh erneut ausführen.\n' >&2
        exit 1
    fi
fi
swift_version=$(swift --version)
swift_major=$(printf '%s\n' "$swift_version" | sed -n 's/.*Swift version \([0-9][0-9]*\).*/\1/p' | head -1)
if [ -z "$swift_major" ] || [ "$swift_major" -lt 6 ]; then
    printf 'Swift 6 oder neuer benötigt. Aktualisiere die Command Line Tools über die macOS-Softwareupdates.\n' >&2
    exit 1
fi
printf '✓ macOS %s · Swift %s\n' "$macos" "$swift_major"

printf '\n[2/4] Homebrew und Stockfish einrichten\n'
brew_bin=$(command -v brew || true)
for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -z "$brew_bin" ] && [ -x "$candidate" ]; then brew_bin=$candidate; fi
done
if [ -z "$brew_bin" ]; then
    if [ "${macos%%.*}" -lt 15 ]; then
        printf 'Die aktuelle Homebrew-Neuinstallation benötigt offiziell macOS 15+.\nStockfish manuell installieren: https://stockfishchess.org/download/\nDanach die App mit ./make-app.sh bauen. Siehe docs/MACOS-SETUP.md.\n' >&2
        exit 1
    fi
    printf 'Homebrew fehlt. Lade den offiziellen Installer von https://brew.sh/.\n'
    printf 'Der Installer erläutert Änderungen und fragt ggf. nach deinem Mac-Passwort.\n'
    installer=$(mktemp -t schachclub-homebrew)
    trap 'rm -f "$installer"' 0
    if ! curl --fail --show-error --location --connect-timeout 15 --max-time 180 --proto '=https' \
        https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
        printf 'Homebrew-Download fehlgeschlagen. Internetverbindung prüfen und erneut starten.\n' >&2
        exit 1
    fi
    if ! /bin/bash "$installer"; then
        printf 'Homebrew-Installation nicht abgeschlossen. Hinweise oben prüfen und erneut starten.\n' >&2
        exit 1
    fi
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then brew_bin=$candidate; break; fi
    done
    if [ -z "$brew_bin" ]; then
        printf 'Homebrew wurde nicht gefunden. Hinweise des Installers prüfen.\n' >&2
        exit 1
    fi
fi
printf '✓ Homebrew gefunden: %s\n' "$brew_bin"
if "$brew_bin" list --versions stockfish >/dev/null 2>&1; then
    printf '✓ Stockfish bereits installiert\n'
else
    printf 'Stockfish installieren (brew install stockfish) …\n'
    if ! "$brew_bin" install stockfish; then
        printf 'Stockfish-Installation fehlgeschlagen. Die App wurde nicht gebaut. Hinweise oben prüfen.\n' >&2
        exit 1
    fi
    printf '✓ Stockfish installiert\n'
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
