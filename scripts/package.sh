#!/bin/bash
# Package react-solar2d as a Solar2D Lua plugin
# Usage: ./scripts/package.sh [version]
# Output: dist/plugin.react-solar2d-{version}.tgz

set -e

VERSION=${1:-v1}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
STAGING="/tmp/react-solar2d-staging"

rm -rf "$STAGING" "$DIST"
mkdir -p "$STAGING" "$DIST"

# metadata
cat > "$STAGING/metadata.lua" << 'EOF'
local metadata = {
  plugin = { format = 'lua' },
}
return metadata
EOF

# Entry point
cp "$ROOT/react_solar2d.lua" "$STAGING/"

# Framework modules
for dir in react renderer components layout style animated navigation hooks lib; do
    if [ -d "$ROOT/$dir" ]; then
        cp -r "$ROOT/$dir" "$STAGING/"
    fi
done

# Test server (UI automation)
mkdir -p "$STAGING/tests/infra"
cp "$ROOT/tests/infra/test_server.lua" "$STAGING/tests/infra/"
cp "$ROOT/tests/infra/base64.lua" "$STAGING/tests/infra/"

# Build
FILENAME="plugin.react-solar2d.tgz"
cd "$STAGING" && tar czf "$DIST/$FILENAME" .

# Summary
FILE_COUNT=$(find "$STAGING" -name "*.lua" | wc -l | tr -d ' ')
SIZE=$(du -h "$DIST/$FILENAME" | cut -f1)
echo "Packaged: dist/$FILENAME ($FILE_COUNT files, $SIZE)"
echo ""
echo "To publish: upload dist/$FILENAME to GitHub release $VERSION"
echo "URL: https://github.com/labolado/react-solar2d/releases/download/$VERSION/plugin.react-solar2d.tgz"

rm -rf "$STAGING"
