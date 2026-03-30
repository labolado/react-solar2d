-- main.lua
-- React-Solar2D demo app entry point
-- Run from project root: framework modules are at ./react/, ./renderer/, etc.
-- Example apps are in ./examples/

-- Ensure ?/init.lua is in search path (Solar2D may not include it by default)
-- Also add examples/ so demo modules can be found
local resDir = system.pathForFile("main.lua"):gsub("main%.lua$", "")
package.path = resDir .. "?.lua;" .. resDir .. "?/init.lua;" .. resDir .. "examples/?.lua;" .. resDir .. "examples/?/init.lua;" .. package.path

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
local ok_ks, KitchenSinkApp = pcall(require, "KitchenSinkApp")
if not ok_ks then
    print("[main] ERROR loading KitchenSinkApp: " .. tostring(KitchenSinkApp))
    KitchenSinkApp = function() return ce("View", { style = { flex = 1 } },
        ce("Text", { style = { fontSize = 16, color = "#FF0000" } }, "KitchenSink failed to load"))
    end
end

-- Route: read .route file to jump directly to a specific demo
local ROUTE_MAP = { news = "News", quiz = "Quiz", tetris = "Game", sink = "Showcase" }
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

-- App
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
            ce(Tab.Screen, { name = "News", component = NewsApp, options = { tabBarLabel = "热点", tabBarIcon = "热" } }),
            ce(Tab.Screen, { name = "Quiz", component = QuizApp, options = { tabBarLabel = "问答", tabBarIcon = "Q" } }),
            ce(Tab.Screen, { name = "Game", component = TetrisApp, options = { tabBarLabel = "游戏", tabBarIcon = "T" } }),
            ce(Tab.Screen, { name = "Showcase", component = KitchenSinkApp, options = { tabBarLabel = "展示", tabBarIcon = "K" } })
        )
    )
end

-- Mount
local container = display.newGroup()
RN.render(ce(App), container)
RN.startAutoFlush()
