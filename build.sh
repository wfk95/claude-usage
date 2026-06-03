#!/bin/bash
# Builds ClaudeUsage.app — a self-contained menu bar app. No Xcode project needed,
# just the Swift compiler from Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeUsage"
BUNDLE="build/$APP.app"
MACOS="$BUNDLE/Contents/MacOS"
RESOURCES="$BUNDLE/Contents/Resources"
TARGET="arm64-apple-macosx13.0"

echo "› Compiling…"
rm -rf "$BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

swiftc -O -target "$TARGET" \
    -o "$MACOS/$APP" \
    Sources/*.swift

echo "› Bundling icon…"
[ -f Resources/AppIcon.icns ] || ./make_icon.sh
cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"

echo "› Writing Info.plist…"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Claude Usage</string>
    <key>CFBundleDisplayName</key><string>Claude Usage</string>
    <key>CFBundleIdentifier</key><string>com.fk.ClaudeUsage</string>
    <key>CFBundleExecutable</key><string>$APP</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "› Code signing (ad-hoc)…"
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "✓ Built $BUNDLE"
echo "  Run with:  open \"$BUNDLE\""
