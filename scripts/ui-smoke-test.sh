#!/bin/bash
# UI Smoke Test — automatically explore all KitchenSink demo pages
# Navigates to each demo, taps buttons, scrolls, captures screenshots
# Usage: ./scripts/ui-smoke-test.sh
# Requires: simulator running with test_server on port 9876

BASE="http://localhost:9876"
OUT="./test-results/$(date +%Y%m%d-%H%M%S)"
ERRORS=0
PAGES=0

mkdir -p "$OUT"

# Helper: screenshot
shot() {
    local label="$1"
    curl -s "$BASE/screenshot?label=$label" | python3 -c "
import sys, json, base64
d = json.load(sys.stdin)
if d.get('base64'):
    open('$OUT/${label}.png', 'wb').write(base64.b64decode(d['base64']))
" 2>/dev/null
}

# Helper: tap text (returns success/fail)
tap() {
    local text="$1"
    local result=$(curl -s -X POST "$BASE/tap-text" -d "text=$text" 2>/dev/null)
    if echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('success') else 1)" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for test server
echo "Waiting for test server..."
for i in $(seq 1 30); do
    curl -s --connect-timeout 1 "$BASE/status" >/dev/null 2>&1 && break
    sleep 1
done
curl -s "$BASE/status" >/dev/null 2>&1 || { echo "FAIL: test server not running"; exit 1; }
echo "Test server ready"

# Navigate to Showcase tab
tap "展示"
sleep 1

# All demo routes (from examples/kitchen_sink/*Screens.lua)
DEMOS="
Basics:View
Basics:Text
Basics:Image
Basics:Button
Basics:Pressable
Basics:Touchable
Basics:LinearGradient
Forms:TextInput
Forms:Switch
Forms:Modal
Forms:Indicator
Forms:KeyboardAV
Lists:ScrollView
Lists:FlatList
Lists:VirtualList
Lists:SectionList
Lists:RefreshControl
Nav:StackNav
Nav:Headers
Nav:DrawerNav
Animation:Timing
Animation:Spring
Animation:Sequence
Animation:Parallel
Animation:Loop
Overlay:Alert
Overlay:ActionSheet
Overlay:Toast
Overlay:Popover
Layout:Flexbox
Layout:Responsive
Layout:SafeArea
Layout:Spacing
Advanced:Badge
Advanced:Progress
Advanced:Accordion
Advanced:Dropdown
Advanced:Card
Interop:ReactInSolar
Interop:AsyncStorage
Interop:VectorIcons
Interop:Slider
Interop:DeviceInfo
Interop:DateTimePicker
Canvas:Canvas
Canvas:Tetris
Touch:Draggable
Touch:Pinch
Touch:Drawing
Touch:Stickers
Touch:Gamepad
"

for entry in $DEMOS; do
    cat_key=$(echo "$entry" | cut -d: -f1)
    route=$(echo "$entry" | cut -d: -f2)

    echo "  [$cat_key] $route"

    # Navigate directly
    RESULT=$(curl -s -X POST "$BASE/navigate" -d "route=$route" 2>/dev/null)
    NAV_OK=$(echo "$RESULT" | python3 -c "import sys,json; print('yes' if json.load(sys.stdin).get('success') else 'no')" 2>/dev/null)
    sleep 1

    if [ "$NAV_OK" != "yes" ]; then
        echo "     SKIP (route not found)"
        continue
    fi

    PAGES=$((PAGES + 1))

    # Screenshot
    shot "${cat_key}_${route}"

    # Find and tap up to 3 buttons on the page
    BUTTONS=$(curl -s "$BASE/tree?depth=10" | python3 -c "
import sys, json
skip = {'基础','表单','列表','导航','动画','弹层','布局','高级','互操','Canvas','热点','问答','游戏','展示','热','Q','T','K'}
def collect_text(node):
    texts = []
    if node.get('text'): texts.append(node['text'])
    for c in node.get('children',[]): texts.extend(collect_text(c))
    return texts
def find(node, results, depth=0):
    if depth > 10: return
    if node.get('pressable'):
        for t in collect_text(node):
            if 1 < len(t) < 40 and not t.startswith('←') and t not in skip:
                results.append(t); break
    for c in node.get('children',[]): find(c, results, depth+1)
r = []; find(json.load(sys.stdin).get('tree',{}), r)
seen = set()
for x in r[:3]:
    if x not in seen: seen.add(x); print(x)
" 2>/dev/null)

    while IFS= read -r btn; do
        [ -z "$btn" ] && continue
        echo "     tap: $btn"
        tap "$btn" || { echo "     tap failed" >> "$OUT/errors.log"; ERRORS=$((ERRORS + 1)); }
        sleep 0.8
    done <<< "$BUTTONS"

    # Scroll down and back
    curl -s -X POST "$BASE/drag" -d "x=187&y=500&dx=0&dy=-150&ms=200" >/dev/null 2>&1
    sleep 0.3

    # Screenshot after interactions
    shot "${cat_key}_${route}_after"

    # Dismiss any overlay (tap outside)
    curl -s -X POST "$BASE/tap" -d "x=10&y=10" >/dev/null 2>&1
    sleep 0.3

done

# Summary
SCREENSHOTS=$(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "========================================"
echo "  Pages visited: $PAGES"
echo "  Screenshots: $SCREENSHOTS (in $OUT)"
echo "  Errors: $ERRORS"
if [ -f "$OUT/errors.log" ]; then
    echo "  Error log: $OUT/errors.log"
    cat "$OUT/errors.log"
fi
echo "========================================"
