#!/bin/sh
# XCBuild (Standard-Builder) benötigt volles Xcode; hier ist nur CommandLineTools
# installiert, deshalb wird auf den nativen Builder ausgewichen.
# Nutzung: ./build.sh build  |  ./build.sh test  |  ./build.sh run
set -e
cmd="$1"
shift || true
exec swift "$cmd" --build-system native "$@"
