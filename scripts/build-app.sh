#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/Readback Reader.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$BUILD_DIR/ReadbackReader" "$MACOS_DIR/Readback Reader"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Readback Reader</string>
  <key>CFBundleIdentifier</key>
  <string>local.readback.reader</string>
  <key>CFBundleName</key>
  <string>Readback Reader</string>
  <key>CFBundleDisplayName</key>
  <string>Readback Reader</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Built locally for personal use.</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>Readback Reader/Read Selection</string>
      </dict>
      <key>NSMessage</key>
      <string>readSelectionService</string>
      <key>NSPortName</key>
      <string>Readback Reader</string>
      <key>NSSendTypes</key>
      <array>
        <string>public.utf8-plain-text</string>
        <string>NSStringPboardType</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

# Keep the app's designated requirement stable so macOS can remember Accessibility permission across rebuilds.
codesign --force --deep --sign - \
  --requirements '=designated => identifier "local.readback.reader"' \
  "$APP_DIR"

echo "$APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
  INSTALL_DIR="/Applications/Readback Reader.app"
  rm -rf "$INSTALL_DIR"
  cp -R "$APP_DIR" "$INSTALL_DIR"
  echo "$INSTALL_DIR"
fi
