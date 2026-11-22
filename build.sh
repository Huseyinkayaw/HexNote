#!/bin/zsh
# HexNote.app derler. Kullanım: ./build.sh  (sonra HexNote.app'i /Applications'a sürükleyebilirsin)
set -e
cd "$(dirname "$0")"
APP=HexNote.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -o "$APP/Contents/MacOS/HexNote" Core.swift main.swift -framework AppKit
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>HexNote</string>
  <key>CFBundleDisplayName</key><string>HexNote</string>
  <key>CFBundleIdentifier</key><string>local.hexnote</string>
  <key>CFBundleExecutable</key><string>HexNote</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
EOF
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Hazır: $(pwd)/$APP"
