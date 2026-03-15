-- examples/main.lua
-- Solar2D entry point for react-solar2d demos
-- Resolve parent directory path for require
local path = system.pathForFile("main.lua"):gsub("examples/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local RN = require("react_solar2d")
local React = require("react")

-- Pick which demo to run
local demo = "counter" -- "hello" | "counter"

local container = display.newGroup()

if demo == "hello" then
    local HelloWorld = require("examples.HelloWorld")
    RN.render(React.createElement(HelloWorld), container)
elseif demo == "counter" then
    local Counter = require("examples.Counter")
    RN.render(React.createElement(Counter), container)
end
-- Auto-flush state updates on each frame
RN.startAutoFlush()
