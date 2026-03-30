#!/bin/bash
# Install react-solar2d into a local Solar2D project
# Usage: ./scripts/install-local.sh /path/to/your/project
set -e

TARGET="${1:?Usage: $0 /path/to/your/project}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$TARGET/main.lua" ]; then
    echo "Error: $TARGET/main.lua not found. Is this a Solar2D project?"
    exit 1
fi

# Package and extract
"$ROOT/scripts/package.sh" >/dev/null
tar xzf "$ROOT/dist/plugin.react-solar2d.tgz" -C "$TARGET/"

echo "Installed to $TARGET"
echo "Now add to your main.lua:"
echo '  local RN = require("react_solar2d")'
