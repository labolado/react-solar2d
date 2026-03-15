-- examples/main.lua
-- Solar2D entry point for react-solar2d demos
-- Add parent directory to package path
package.path = "../?.lua;../?/init.lua;" .. package.path

local RN = require("init")
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
Runtime:addEventListener("enterFrame", function()
    RN.flushUpdates()
end)
