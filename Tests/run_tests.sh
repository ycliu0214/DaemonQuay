#!/bin/zsh
set -euo pipefail
HERE="${0:A:h}"
ROOT="${HERE:h}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
xcrun swiftc -O "$ROOT/Sources/ModuleHost/main.swift" -o "$TMP/module-control"
export DAEMONQUAY_TEST_MODULE_HOST="$TMP/module-control"
/usr/bin/python3 -m unittest discover -s "$HERE" -v
