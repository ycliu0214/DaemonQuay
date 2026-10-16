#!/bin/zsh
set -euo pipefail
HERE="${0:A:h}"
ROOT="${HERE:h}"
APP="$ROOT/build/DaemonQuay.app"
OUT="$ROOT/build/DaemonQuay-v1.0.0.dmg"
STAGING="$ROOT/build/dmg-staging"
[[ -d "$APP/Contents/MacOS" ]] || { echo "Missing $APP; run zsh Scripts/build.sh first" >&2; exit 1; }
[[ -e "$OUT" ]] && { echo "Refusing to overwrite existing $OUT. Move it aside first." >&2; exit 1; }
rm -rf "$STAGING"
mkdir -p "$STAGING"
/usr/bin/ditto "$APP" "$STAGING/DaemonQuay.app"
/bin/ln -s /Applications "$STAGING/Applications"
/usr/bin/hdiutil create -volname 'DaemonQuay' -srcfolder "$STAGING" -format UDZO -fs HFS+ "$OUT"
rm -rf "$STAGING"
echo "Created $OUT"
echo "NOTE: DMG creation does not sign/notarize the app or disk image. Do not claim public distribution is notarized."
