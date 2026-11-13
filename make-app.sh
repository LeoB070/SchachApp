#!/bin/sh
# Erstellt ein lokal signiertes macOS-App-Bundle ohne gebündeltes Stockfish.
set -eu
cd "$(dirname "$0")"
./build.sh build -c release --product ChessApp
bin_dir=$(swift build --build-system native -c release --show-bin-path)
app="dist/ChessApp.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/ChessApp" "$app/Contents/MacOS/ChessApp"
# Das Kit lädt hier vor dem SwiftPM-Fallback, damit das App-Bundle signierbar bleibt.
ditto "$bin_dir/ChessApp_ChessAppKit.bundle" "$app/Contents/Resources/ChessApp_ChessAppKit.bundle"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY.md "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>ChessApp</string>
    <key>CFBundleIdentifier</key><string>local.chessapp</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleName</key><string>ChessApp</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1.0</string>
    <key>CFBundleVersion</key><string>3</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if find "$app/Contents" -type f \( -name 'stockfish' -o -name 'stockfish-*' \) | grep -q .; then
    echo "Abbruch: Das App-Bundle enthält Stockfish. Diese Distribution verwendet eine separat installierte Engine." >&2
    exit 1
fi
codesign --force --deep --sign - "$app"
printf 'App erstellt: %s/%s\n' "$PWD" "$app"
