-- examples/main.lua
-- Solar2D entry point for react-solar2d demos
-- Uses TabNavigator for switching between demo apps

local path = system.pathForFile("main.lua"):gsub("examples/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local RN = require("react_solar2d")
local React = require("react")
local ce = React.createElement
local Navigation = require("navigation")

local W = display.contentWidth
local H = display.contentHeight
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

-- Safe area
local SAFE_TOP = 0
if display.safeScreenOriginY and display.screenOriginY then
    SAFE_TOP = math.abs(display.safeScreenOriginY - display.screenOriginY)
end
if SAFE_TOP < s(40) then SAFE_TOP = s(40) end

local SAFE_BOTTOM = 0
if display.safeActualContentHeight and display.safeScreenOriginY then
    local safeH = display.safeActualContentHeight
    local safeY = display.safeScreenOriginY
    local screenH = display.actualContentHeight or display.contentHeight
    local originY = display.screenOriginY or 0
    SAFE_BOTTOM = math.max(0, (screenH + originY) - (safeH + safeY))
end

-- Load demo modules
local NewsApp = require("examples.NewsApp")
local QuizApp = require("examples.QuizApp")
local TetrisApp = require("examples.TetrisApp")
local ok_ks, KitchenSinkApp = pcall(require, "examples.KitchenSinkApp")
if not ok_ks then
    print("[main] ERROR loading KitchenSinkApp: " .. tostring(KitchenSinkApp))
    KitchenSinkApp = function() return ce("View", { style = { flex = 1 } },
        ce("Text", { style = { fontSize = 16, color = "#FF0000" } }, "KitchenSink failed to load"))
    end
end

-- Route: read .route file to jump directly to a specific demo
-- Usage: echo "quiz" > examples/.route   then launch simulator
local ROUTE_MAP = { news = "News", quiz = "Quiz", tetris = "Game", sink = "Showcase" }
local initialRoute = "News"

-- Test mode: read .test file to auto-run tests on startup
-- Usage: echo "pressable" > examples/.test   then launch simulator
-- Or: echo "all" > examples/.test   to run all tests
local testMode = nil
local testPath = system.pathForFile(".test", system.ResourceDirectory)
if testPath then
    local f = io.open(testPath, "r")
    if f then
        testMode = f:read("*l")
        f:close()
        testMode = testMode and testMode:gsub("%s+", "")
        print("[TEST] Test mode: " .. tostring(testMode))
    end
end
local routePath = system.pathForFile(".route", system.ResourceDirectory)
if routePath then
    local f = io.open(routePath, "r")
    if f then
        local route = f:read("*l")
        f:close()
        if route and route ~= "" and ROUTE_MAP[route] then
            initialRoute = ROUTE_MAP[route]
            print("[ROUTE] Jumping to: " .. route .. " → " .. initialRoute)
        end
    end
end

-- ============================================================
-- Auto-test runner (if .test file exists)
-- ============================================================
if testMode then
    print("[TEST] Running tests: " .. testMode)
    timer.performWithDelay(1000, function()
        local ok, testRunner = pcall(require, "tests.infra.test_runner_solar2d")
        if not ok then
            print("[TEST] ERROR loading test_runner: " .. tostring(testRunner))
            return
        end
        local results = testRunner.run(testMode)
        print("[TEST] Results: " .. results.passed .. " passed, " .. results.failed .. " failed")

        -- Display results on screen
        local resultText = display.newText({
            text = "Tests: " .. results.passed .. " passed, " .. results.failed .. " failed",
            x = display.contentCenterX,
            y = display.contentCenterY,
            font = native.systemFontBold,
            fontSize = 20,
        })
        if results.failed == 0 then
            resultText:setFillColor(0, 1, 0)
        else
            resultText:setFillColor(1, 0, 0)
        end
    end)
end

-- ============================================================
-- App (TabNavigator-based demo switcher)
-- ============================================================
local Tab = Navigation.createBottomTabNavigator()

local function App()
    return ce(Navigation.NavigationContainer, {},
        ce(Tab.Navigator, {
            initialRouteName = initialRoute,
            tabBarOptions = {
                activeTintColor = "#FF6600",
                inactiveTintColor = "#666688",
                backgroundColor = "#151530",
                iconSize = 18,
                labelSize = 13,
            },
        },
            ce(Tab.Screen, {
                name = "News",
                component = NewsApp,
                options = { tabBarLabel = "热点", tabBarIcon = "热" },
            }),
            ce(Tab.Screen, {
                name = "Quiz",
                component = QuizApp,
                options = { tabBarLabel = "问答", tabBarIcon = "Q" },
            }),
            ce(Tab.Screen, {
                name = "Game",
                component = TetrisApp,
                options = { tabBarLabel = "游戏", tabBarIcon = "T" },
            }),
            ce(Tab.Screen, {
                name = "Showcase",
                component = KitchenSinkApp,
                options = { tabBarLabel = "展示", tabBarIcon = "K" },
            })
        )
    )
end

-- Mount
local container = display.newGroup()
RN.render(ce(App), container)
RN.startAutoFlush()

-- ============================================================
-- Start test server for remote control (optional)
-- ============================================================
timer.performWithDelay(500, function()
    local ok, testServer = pcall(require, "tests.infra.test_server")
    if ok then
        testServer.start(9876)

        -- Register callbacks for remote control
        testServer.onCategoryTap(function(category)
            print("[TEST_SERVER] Category tapped: " .. category)
            -- Dispatch event to KitchenSink
            local event = { name = "kitchensink_navigate", category = category }
            Runtime:dispatchEvent(event)
        end)

        testServer.onNavigate(function(route)
            print("[TEST_SERVER] Navigate to: " .. route)
            -- Dispatch event to KitchenSink
            local event = { name = "kitchensink_navigate", route = route }
            Runtime:dispatchEvent(event)
        end)
    else
        print("[TEST_SERVER] Not started: " .. tostring(testServer))
    end
end)
