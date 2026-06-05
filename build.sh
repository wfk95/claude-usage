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

# Marketing version baked into Info.plist. CI passes the pushed tag via $VERSION
# (e.g. "v1.2"); a local build falls back to the latest tag, then a 0.0.0 dev
# placeholder. The leading "v" is stripped so the plist gets a clean "1.2".
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)}"
VERSION="${VERSION#v}"

echo "› Compiling…"
rm -rf "$BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# UNIVERSAL=1 builds a universal (arm64 + x86_64) binary for distribution.
if [ "${UNIVERSAL:-0}" = "1" ]; then
    echo "  (universal: arm64 + x86_64)"
    swiftc -O -swift-version 5 -target arm64-apple-macosx13.0  -o "$MACOS/$APP.arm64"  Sources/*.swift
    swiftc -O -swift-version 5 -target x86_64-apple-macosx13.0 -o "$MACOS/$APP.x86_64" Sources/*.swift
    lipo -create "$MACOS/$APP.arm64" "$MACOS/$APP.x86_64" -output "$MACOS/$APP"
    rm "$MACOS/$APP.arm64" "$MACOS/$APP.x86_64"
else
    swiftc -O -swift-version 5 -target "$TARGET" -o "$MACOS/$APP" Sources/*.swift
fi

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
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
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
