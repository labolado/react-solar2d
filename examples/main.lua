-- main.lua
-- Solar2D entry point for react-solar2d demos
-- Uses TabNavigator for switching between demo apps

-- Framework path: go up one level from examples/ to reach react-solar2d root
local path = system.pathForFile("main.lua"):gsub("examples/main.lua$", "")
local examplesPath = path .. "examples/"
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. examplesPath .. "?.lua;" .. examplesPath .. "?/init.lua;" .. package.path

-- Yoga plugin (optional)
local YOGA = path .. "plugins/yoga/build-solar2d/"
package.cpath = YOGA .. "?.dylib;" .. YOGA .. "?.so;" .. package.cpath

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
local NewsApp = require("NewsApp")
local QuizApp = require("QuizApp")
local TetrisApp = require("TetrisApp")
local ok_sc, ShowcaseApp = pcall(require, "ShowcaseApp")
if not ok_sc then
    print("[main] ERROR loading ShowcaseApp: " .. tostring(ShowcaseApp))
    ShowcaseApp = function() return ce("View", { style = { flex = 1 } },
        ce("Text", { style = { fontSize = 16, color = "#FF0000" } }, "Showcase failed to load"))
    end
end
local ok_ks, KitchenSinkApp = pcall(require, "KitchenSinkApp")
if not ok_ks then
    print("[main] ERROR loading KitchenSinkApp: " .. tostring(KitchenSinkApp))
    KitchenSinkApp = function() return ce("View", { style = { flex = 1 } },
        ce("Text", { style = { fontSize = 16, color = "#FF0000" } }, "KitchenSink failed to load"))
    end
end

-- Route: read .route file to jump directly to a specific demo
-- Usage: echo "quiz" > .route   then launch simulator
local ROUTE_MAP = { news = "News", quiz = "Quiz", tetris = "Game", sink = "Kitchen", showcase = "Showcase" }
local initialRoute = "News"

-- Test mode: read .test file to auto-run tests on startup
-- Usage: echo "pressable" > .test   then launch simulator
-- Or: echo "all" > .test   to run all tests
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
                name = "Kitchen",
                component = KitchenSinkApp,
                options = { tabBarLabel = "组件", tabBarIcon = "K" },
            }),
            ce(Tab.Screen, {
                name = "Showcase",
                component = ShowcaseApp,
                options = { tabBarLabel = "炫酷", tabBarIcon = "★" },
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
        local started = testServer.start(9876)

        -- App-specific routes (Kitchen Sink navigation)
        testServer.route("POST", "/navigate", function(params)
            local route = params.route
            if route then
                print("[TEST_SERVER] Navigate to: " .. route)
                Runtime:dispatchEvent({ name = "kitchensink_navigate", route = route })
                return testServer.ok({success=true, route=route})
            end
            return testServer.err("Missing route")
        end)

        testServer.route("POST", "/tap-category", function(params)
            local category = params.category
            if category then
                Runtime:dispatchEvent({ name = "kitchensink_navigate", category = category })
                return testServer.ok({success=true, category=category})
            end
            return testServer.err("Missing category")
        end)

        testServer.route("GET", "/pages", function()
            return testServer.ok({ pages = {
                {category="Basics",    pages={"View","Text","Image","Button","Pressable","Touchable","LinearGradient"}},
                {category="Forms",     pages={"TextInput","Switch","Modal","Indicator","KeyboardAV"}},
                {category="Lists",     pages={"ScrollView","FlatList","VirtualList","SectionList"}},
                {category="Nav",       pages={"StackNav","Headers","DrawerNav"}},
                {category="Animation", pages={"Timing","Spring","Sequence","Parallel","Loop"}},
                {category="Overlay",   pages={"Alert","ActionSheet","Toast","Popover"}},
                {category="Layout",    pages={"Flexbox","Responsive","SafeArea","SafeAreaView","Spacing"}},
                {category="Advanced",  pages={"Badge","Progress","Accordion","Dropdown","Card","Gesture Handler","useId","useImperativeHandle","useSyncExternalStore"}},
                {category="Interop",   pages={"ReactInSolar","Solar2DInReact","AsyncStorage","VectorIcons","Slider","DeviceInfo","DateTimePicker"}},
                {category="Canvas",   pages={"Canvas","Tetris"}},
            }})
        end)

        -- Test mode indicator overlay
        if started then
            local badge = display.newGroup()
            local badgeBg = display.newRoundedRect(badge, 0, 0, 62, 18, 4)
            badgeBg:setFillColor(1, 0.5, 0, 0.85) -- orange
            badgeBg.anchorX, badgeBg.anchorY = 0, 0
            local badgeText = display.newText({
                parent = badge,
                text = "TEST",
                x = 31, y = 9,
                font = native.systemFontBold,
                fontSize = 10,
            })
            badgeText:setFillColor(1, 1, 1)
            badge.x = display.contentWidth - 70
            badge.y = 4
            -- Keep on top
            timer.performWithDelay(2000, function()
                if badge.parent then
                    badge.parent:insert(badge)
                end
            end, 0)
        end
    else
        print("[TEST_SERVER] Not started: " .. tostring(testServer))
    end
end)
