#!/bin/zsh
# Testleri çalıştırır, HexNote.app'i derler ve HexNote.dmg kurulum dosyasını üretir.
set -e
cd "$(dirname "$0")"

echo "→ Testler"
T=$(mktemp -d)
swiftc -O Core.swift Tests/main.swift -o "$T/tests"
"$T/tests" 2>/dev/null
rm -rf "$T"

echo "→ Derleme"
./build.sh

echo "→ DMG"
STAGE=$(mktemp -d)
chmod 755 "$STAGE"
cp -R HexNote.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f HexNote.dmg
hdiutil create -volname "HexNote" -srcfolder "$STAGE" -ov -format UDZO -quiet HexNote.dmg
rm -rf "$STAGE"
hdiutil verify -quiet HexNote.dmg
echo "Hazır: $(pwd)/HexNote.dmg ($(du -h HexNote.dmg | cut -f1))"
