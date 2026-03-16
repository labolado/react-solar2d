#!/bin/bash
# Run Solar2D integration tests in the real simulator
# Usage:
#   ./run_solar2d_tests.sh              # run all suites
#   ./run_solar2d_tests.sh scroll_drag  # run only suites matching "scroll_drag"
#   ./run_solar2d_tests.sh scroll       # run all scroll-related suites

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROUTE_FILE="$SCRIPT_DIR/tests/solar2d/.route"
SIMULATOR="/Applications/Corona-b3/Corona Simulator.app/Contents/MacOS/Corona Simulator"
MAIN="$SCRIPT_DIR/tests/solar2d/main.lua"

# Write route filter
if [ -n "$1" ]; then
    echo "$1" > "$ROUTE_FILE"
else
    echo "all" > "$ROUTE_FILE"
fi

# Run simulator, capture output
"$SIMULATOR" -no-console yes "$MAIN" 2>&1

EXIT_CODE=$?

# Clean up route file
rm -f "$ROUTE_FILE"

exit $EXIT_CODE
