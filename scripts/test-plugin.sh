#!/bin/bash
# Test react-solar2d as a standalone plugin (simulates end-user experience)
# Usage: ./scripts/test-plugin.sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="/tmp/test-react-solar2d-plugin"
LOG="/tmp/solar2d_plugin_test.log"
SIMULATOR="/Applications/Corona-b3/Corona Simulator.app/Contents/MacOS/Corona Simulator"

# 1. Package
echo "=== Packaging plugin ==="
"$ROOT/scripts/package.sh" >/dev/null

# 2. Create test project
echo "=== Creating test project ==="
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"
tar xzf "$ROOT/dist/plugin.react-solar2d.tgz" -C "$TEST_DIR/"

cat > "$TEST_DIR/config.lua" << 'EOF'
application = { content = { width = 320, height = 480, scale = "adaptive", fps = 60 } }
EOF

# Mirror the framework's own build.settings: yoga is a native C plugin that
# any non-trivial layout pulls in, so the standalone tarball test must
# request it too or anything that triggers layout will silently fail to load.
cat > "$TEST_DIR/build.settings" << 'EOF'
local yoga_base = "https://github.com/labolado/solar2d-plugin-yoga/releases/download/v5/"
settings = {
    orientation = { default = "portrait", supported = { "portrait" } },
    plugins = {
        ["plugin.yoga"] = {
            publisherId = "com.labolado",
            supportedPlatforms = {
                ["mac-sim"]    = { url = yoga_base .. "plugin.yoga-mac-sim.tgz" },
                android        = { url = yoga_base .. "plugin.yoga-android.tgz" },
                iphone         = { url = yoga_base .. "plugin.yoga-iphone.tgz" },
                ["iphone-sim"] = { url = yoga_base .. "plugin.yoga-iphone-sim.tgz" },
                ["win32-sim"]  = { url = yoga_base .. "plugin.yoga-win32-sim.tgz" },
            },
        },
    },
}
EOF

cat > "$TEST_DIR/main.lua" << 'LUAEOF'
local log = {}
local function L(msg) log[#log+1] = msg end

L("START")

-- Test 1: require react_solar2d
local ok1, RN = pcall(require, "react_solar2d")
L("react_solar2d: " .. tostring(ok1))
if not ok1 then L("ERR: " .. tostring(RN)) end

-- Test 2: require react separately
local ok2, React = pcall(require, "react")
L("react: " .. tostring(ok2))

-- Test 3: require sub-modules
local ok3 = pcall(require, "components")
L("components: " .. tostring(ok3))
local ok4 = pcall(require, "navigation")
L("navigation: " .. tostring(ok4))
local ok5 = pcall(require, "animated")
L("animated: " .. tostring(ok5))

-- Test 4: render a simple app
if ok1 and ok2 then
    local ce = React.createElement
    local useState = React.useState

    local function App()
        local count, setCount = useState(0)
        return ce("View", {
            style = { flex = 1, backgroundColor = "#1a1a2e", justifyContent = "center", alignItems = "center" },
        },
            ce("Text", { style = { color = "#00FF00", fontSize = 32 } }, "Plugin OK!"),
            ce("Text", { style = { color = "#888", fontSize = 14, marginTop = 8 } }, "Count: " .. count),
            ce(RN.Button, {
                title = "Tap",
                color = "#2196F3",
                onPress = function() setCount(count + 1) end,
            })
        )
    end

    local container = display.newGroup()
    RN.render(ce(App), container)
    RN.startAutoFlush()
    L("RENDER OK")
else
    L("RENDER SKIP")
end

-- Test 5: test_server
local ok6, ts = pcall(require, "tests.infra.test_server")
L("test_server: " .. tostring(ok6))

-- Write results
L("DONE")
local f = io.open("/tmp/solar2d_plugin_test.log", "w")
f:write(table.concat(log, "\n") .. "\n")
f:close()
LUAEOF

# 3. Launch simulator
echo "=== Launching simulator ==="
pkill -f "Corona Simulator" 2>/dev/null || true
sleep 1
"$SIMULATOR" -no-console YES "$TEST_DIR/main.lua" &
SIM_PID=$!

# 4. Wait for results
echo "=== Waiting for results ==="
for i in $(seq 1 15); do
    if [ -f "$LOG" ] && grep -q "DONE" "$LOG" 2>/dev/null; then
        break
    fi
    sleep 1
done

# 5. Report
echo ""
echo "=== Results ==="
if [ -f "$LOG" ]; then
    cat "$LOG"
    echo ""
    if grep -q "RENDER OK" "$LOG" && grep -q "test_server: true" "$LOG"; then
        echo "PASS: Plugin works correctly"
        RESULT=0
    else
        echo "FAIL: Some modules failed to load"
        RESULT=1
    fi
else
    echo "FAIL: No log output (simulator may have crashed)"
    RESULT=1
fi

# Cleanup
kill $SIM_PID 2>/dev/null || true
rm -rf "$TEST_DIR" "$LOG"

exit $RESULT
