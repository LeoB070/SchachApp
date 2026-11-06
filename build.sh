#!/bin/sh
# XCBuild (Standard-Builder) benötigt volles Xcode; hier ist nur CommandLineTools
# installiert, deshalb wird auf den nativen Builder ausgewichen.
# Nutzung: ./build.sh build  |  ./build.sh test  |  ./build.sh run
set -e
cmd="$1"
shift || true
if [ "$cmd" = "test" ]; then
    # `swift test` kann ohne Xcode nur bauen; die Assertions laufen über TestRunner.
    swift test --build-system native "$@"
    exec .build/arm64-apple-macosx/debug/TestRunner
fi
exec swift "$cmd" --build-system native "$@"
