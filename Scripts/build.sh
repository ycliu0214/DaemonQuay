#!/bin/zsh
set -euo pipefail
HERE="${0:A:h}"
ROOT="${HERE:h}"
APP="$ROOT/build/DaemonQuay.app"
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple Xcode Command Line Tools needed: xcode-select --install" >&2
  exit 1
fi
SDK="$(xcrun --sdk macosx --show-sdk-path)"
# Rebuild the bundle from scratch so no stale compiled plugin survives a rebuild.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Languages" "$APP/Contents/Resources/Modules"
cp "$ROOT"/Resources/Languages/*.json "$APP/Contents/Resources/Languages/"
cp "$ROOT/Resources/Icons/MenuBarTemplate.png" "$APP/Contents/Resources/MenuBarTemplate.png"
# Generate all required AppIcon sizes and compile an ICNS with macOS iconutil.
ICONSET="$ROOT/build/DaemonQuay.iconset"
mkdir -p "$ICONSET"
for px in 16 32 128 256 512; do
  /usr/bin/sips -s format png -z "$px" "$px" "$ROOT/Resources/Icons/AppIcon.png" --out "$ICONSET/icon_${px}x${px}.png" >/dev/null
done
cp "$ICONSET/icon_32x32.png" "$ICONSET/icon_16x16@2x.png"
/usr/bin/sips -z 64 64 "$ROOT/Resources/Icons/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ROOT/Resources/Icons/AppIcon.png" "$ICONSET/icon_512x512@2x.png"
/usr/bin/iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# The GUI contains no service-specific module implementation.
SWIFT_FILES=("$ROOT"/Sources/DaemonQuay/**/*.swift(N))
(( ${#SWIFT_FILES} > 0 )) || { echo "Missing Swift app files" >&2; exit 1; }
xcrun swiftc -O -sdk "$SDK" -target arm64-apple-macosx14.0 \
  "${SWIFT_FILES[@]}" -o "$APP/Contents/MacOS/DaemonQuay"

# One native, short-lived module executable; packaged with each service definition.
MODULE_EXEC="$ROOT/build/module-control"
xcrun swiftc -O -sdk "$SDK" -target arm64-apple-macosx14.0 \
  "$ROOT/Sources/ModuleHost/main.swift" -o "$MODULE_EXEC"
for dir in "$ROOT"/Modules/*(/N); do
  id="${dir:t}"
  mkdir -p "$APP/Contents/Resources/Modules/$id"
  cp "$dir/module.json" "$dir/service.json" "$APP/Contents/Resources/Modules/$id/"
  cp "$MODULE_EXEC" "$APP/Contents/Resources/Modules/$id/module-control"
  chmod 755 "$APP/Contents/Resources/Modules/$id/module-control"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>DaemonQuay</string>
<key>CFBundleDisplayName</key><string>DaemonQuay</string>
<key>CFBundleIdentifier</key><string>local.daemonquay.manager</string>
<key>CFBundleExecutable</key><string>DaemonQuay</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>29</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --deep "$APP"
echo "Built: $APP"
echo "Service modules packaged:"
find "$APP/Contents/Resources/Modules" -name module.json -print
