#!/bin/bash
# Builds a universal, zipped ClaudeUsage.app locally — the same artifact CI ships.
# To actually publish a GitHub Release, push a version tag:
#   git tag v1.0 && git push origin v1.0
set -euo pipefail
cd "$(dirname "$0")"

UNIVERSAL=1 ./build.sh
ditto -c -k --keepParent build/ClaudeUsage.app ClaudeUsage.zip

echo "✓ ClaudeUsage.zip ($(du -h ClaudeUsage.zip | cut -f1 | tr -d ' '))"
echo "  Architectures: $(lipo -archs build/ClaudeUsage.app/Contents/MacOS/ClaudeUsage)"
echo "  Publish with:  git tag v1.0 && git push origin v1.0"
