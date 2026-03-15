-- examples/main.lua
-- Solar2D entry point for react-solar2d demos
-- Resolve parent directory path for require
local path = system.pathForFile("main.lua"):gsub("examples/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local RN = require("react_solar2d")
local React = require("react")

-- Pick which demo to run: "hello" | "counter" | "news" | "quiz" | "tetris"
local demo = "news" -- "hello" | "counter" | "news" | "quiz" | "tetris"

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
end

-- Auto-flush state updates on each frame
RN.startAutoFlush()
