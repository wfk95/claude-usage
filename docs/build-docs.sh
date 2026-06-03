#!/bin/bash
# Renders documentation screenshots from the real app code, then preps the icon.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "› Compiling render harness…"
# All sources except AppDelegate.swift (which owns @main).
SRC=$(ls Sources/*.swift | grep -v 'AppDelegate.swift')
swiftc -O -target arm64-apple-macosx13.0 \
    -o /tmp/cu_docs_render \
    docs/render/main.swift $SRC

echo "› Rendering screenshots…"
/tmp/cu_docs_render

echo "› Preparing icon…"
[ -f /tmp/cu_icon_1024.png ] || ./make_icon.sh
sips -z 220 220 /tmp/cu_icon_1024.png --out docs/assets/icon.png >/dev/null

echo "✓ docs/assets ready"
