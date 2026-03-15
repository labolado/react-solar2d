-- examples/main.lua
-- Solar2D entry point for react-solar2d demos
-- Resolve parent directory path for require
local path = system.pathForFile("main.lua"):gsub("examples/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local RN = require("react_solar2d")
local React = require("react")

-- Pick which demo to run: "hello" | "counter" | "news" | "quiz" | "tetris"
local demo = "news" -- "hello" | "counter" | "news" | "quiz" | "tetris" | "scrolltest"

local container = display.newGroup()

if demo == "hello" then
    local HelloWorld = require("examples.HelloWorld")
    RN.render(React.createElement(HelloWorld), container)
elseif demo == "counter" then
    local Counter = require("examples.Counter")
    RN.render(React.createElement(Counter), container)
elseif demo == "news" then
    local NewsApp = require("examples.NewsApp")
    RN.render(React.createElement(NewsApp), container)
elseif demo == "quiz" then
    local QuizApp = require("examples.QuizApp")
    RN.render(React.createElement(QuizApp), container)
elseif demo == "tetris" then
    local TetrisApp = require("examples.TetrisApp")
    RN.render(React.createElement(TetrisApp), container)
elseif demo == "scrolltest" then
    local ce = React.createElement
    local function ScrollTest()
        local items = {}
        for i = 1, 5 do
            items[i] = ce("View", {
                key = "item" .. i,
                style = { backgroundColor = "#FFFFFF", borderRadius = 12, padding = 20, margin = 16 },
            },
                ce("Text", { style = { fontSize = 36, color = "#333333", fontWeight = "bold" } }, "Item " .. i),
                ce("Text", { style = { fontSize = 24, color = "#999999", marginTop = 8 } }, "Description for item " .. i)
            )
        end
        return ce("View", { style = { flex = 1, width = display.contentWidth, height = display.contentHeight, backgroundColor = "#EEEEEE" } },
            ce("Text", { style = { fontSize = 48, fontWeight = "bold", padding = 32 } }, "Scroll Test"),
            ce("ScrollView", { style = { flex = 1 } }, unpack(items))
        )
    end
    RN.render(React.createElement(ScrollTest), container)
end

-- Auto-flush state updates on each frame
RN.startAutoFlush()
