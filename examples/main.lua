-- examples/main.lua
-- Solar2D entry point for react-solar2d demos
-- App launcher with runtime switching between demos

local path = system.pathForFile("main.lua"):gsub("examples/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local RN = require("react_solar2d")
local React = require("react")
local ce = React.createElement
local useState = React.useState

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

-- Demo registry
local DEMOS = {
    { key = "news",   name = "热点资讯",   desc = "百度热搜 + V2EX",   color = "#E74C3C", icon = "热" },
    { key = "quiz",   name = "Quiz Game",   desc = "Knowledge Quiz",   color = "#2979FF", icon = "Q" },
    { key = "tetris", name = "Tetris",      desc = "Classic Block Game", color = "#00C853", icon = "T" },
}

local DEMO_COMPONENTS = {
    news = NewsApp,
    quiz = QuizApp,
    tetris = TetrisApp,
}

-- ============================================================
-- Floating Menu Button (rendered in each app)
-- ============================================================
local function FloatingMenuButton(props)
    return ce("View", {
        style = {
            position = "absolute",
            top = SAFE_TOP + s(76),
            right = s(12),
            width = s(48), height = s(48),
            borderRadius = s(24),
            backgroundColor = "#FF6600",
            justifyContent = "center", alignItems = "center",
            borderWidth = 2, borderColor = "#FFFFFF",
        },
        onPress = props.onPress,
    },
        ce("Text", {
            style = { fontSize = s(24), color = "#FFFFFF", fontWeight = "bold" },
        }, "=")
    )
end

-- ============================================================
-- App Picker Dialog
-- ============================================================
local function AppPickerDialog(props)
    local items = {}
    for i, demo in ipairs(DEMOS) do
        local isActive = demo.key == props.current
        items[#items + 1] = ce("View", {
            key = demo.key,
            style = {
                flexDirection = "row", alignItems = "center",
                marginBottom = s(12),
                padding = s(18),
                backgroundColor = isActive and "#2A2A4E" or "#1E1E3A",
                borderRadius = s(14),
                borderWidth = isActive and 2 or 1,
                borderColor = isActive and demo.color or "#333355",
            },
            onPress = function()
                if not isActive then
                    props.onSelect(demo.key)
                end
                props.onClose()
            end,
        },
            -- Icon circle
            ce("View", {
                style = {
                    width = s(52), height = s(52),
                    borderRadius = s(26),
                    backgroundColor = demo.color,
                    justifyContent = "center", alignItems = "center",
                    marginRight = s(16),
                },
            },
                ce("Text", {
                    style = { fontSize = s(26), color = "#FFFFFF", fontWeight = "bold" },
                }, demo.icon)
            ),
            -- Text
            ce("View", { style = { flex = 1 } },
                ce("Text", {
                    style = { fontSize = s(26), color = "#FFFFFF", fontWeight = "bold" },
                }, demo.name),
                ce("Text", {
                    style = { fontSize = s(18), color = "#8888AA" },
                }, demo.desc)
            ),
            -- Active indicator
            isActive and ce("View", {
                style = {
                    width = s(12), height = s(12),
                    borderRadius = s(6),
                    backgroundColor = demo.color,
                },
            }) or nil
        )
    end

    return ce("View", {
        style = {
            position = "absolute", top = 0, left = 0,
            width = W, height = H,
            backgroundColor = "rgba(0,0,0,0.6)",
        },
        onPress = props.onClose,
    },
        -- Dialog card
        ce("View", {
            style = {
                position = "absolute",
                top = H * 0.2,
                left = s(20),
                width = W - s(40),
                backgroundColor = "#151530",
                borderRadius = s(20),
                padding = s(24),
                borderWidth = 1, borderColor = "#333355",
            },
        },
            -- Title
            ce("View", {
                style = { flexDirection = "row", alignItems = "center", marginBottom = s(20) },
            },
                ce("View", {
                    style = {
                        width = s(6), height = s(28),
                        backgroundColor = "#FF6600", borderRadius = s(3),
                        marginRight = s(12),
                    },
                }),
                ce("Text", {
                    style = { fontSize = s(28), color = "#FFFFFF", fontWeight = "bold" },
                }, "React-Solar2D Demos"),
                ce("View", { style = { flex = 1 } }),
                ce("View", {
                    style = {
                        paddingHorizontal = s(14), paddingVertical = s(6),
                        backgroundColor = "#2A2A4E", borderRadius = s(8),
                    },
                    onPress = props.onClose,
                },
                    ce("Text", {
                        style = { fontSize = s(20), color = "#8888AA" },
                    }, "Close")
                )
            ),
            -- Demo list
            unpack(items)
        )
    )
end

-- Route: read .route file to jump directly to a specific demo
-- Usage: echo "quiz" > examples/.route   then launch simulator
local INITIAL_DEMO = "news"
local routePath = system.pathForFile(".route", system.ResourceDirectory)
if routePath then
    local f = io.open(routePath, "r")
    if f then
        local route = f:read("*l")
        f:close()
        if route and route ~= "" and DEMO_COMPONENTS[route] then
            INITIAL_DEMO = route
            print("[ROUTE] Jumping to: " .. route)
        end
    end
end

-- ============================================================
-- Root App (manages demo switching)
-- ============================================================
local function RootApp()
    local currentDemo, setCurrentDemo = useState(INITIAL_DEMO)
    local showPicker, setShowPicker = useState(false)

    local DemoComponent = DEMO_COMPONENTS[currentDemo]

    return ce("View", {
        style = { width = W, height = H },
    },
        -- Current demo app
        DemoComponent and ce(DemoComponent) or nil,
        -- Floating menu button
        ce(FloatingMenuButton, {
            onPress = function() setShowPicker(true) end,
        }),
        -- Picker dialog overlay
        showPicker and ce(AppPickerDialog, {
            current = currentDemo,
            onSelect = function(key) setCurrentDemo(key) end,
            onClose = function() setShowPicker(false) end,
        }) or nil
    )
end

-- Mount
local container = display.newGroup()
RN.render(ce(RootApp), container)
RN.startAutoFlush()
