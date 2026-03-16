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

-- Route: read .route file to jump directly to a specific demo
-- Usage: echo "quiz" > examples/.route   then launch simulator
local ROUTE_MAP = { news = "News", quiz = "Quiz", tetris = "Game" }
local initialRoute = "News"
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
            })
        )
    )
end

-- Mount
local container = display.newGroup()
RN.render(ce(App), container)
RN.startAutoFlush()
