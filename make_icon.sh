#!/bin/bash
# Generates Resources/AppIcon.icns from make_icon.swift.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p Resources
PNG=/tmp/cu_icon_1024.png
ICONSET=/tmp/cu.iconset

echo "› Rendering icon…"
swiftc -O make_icon.swift -o /tmp/cu_genicon
/tmp/cu_genicon "$PNG"

rm -rf "$ICONSET"; mkdir -p "$ICONSET"
emit() { sips -z "$1" "$1" "$PNG" --out "$ICONSET/$2" >/dev/null; }
emit 16   icon_16x16.png
emit 32   icon_16x16@2x.png
emit 32   icon_32x32.png
emit 64   icon_32x32@2x.png
emit 128  icon_128x128.png
emit 256  icon_128x128@2x.png
emit 256  icon_256x256.png
emit 512  icon_256x256@2x.png
emit 512  icon_512x512.png
cp "$PNG" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "✓ Resources/AppIcon.icns"
