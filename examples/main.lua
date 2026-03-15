-- examples/main.lua
-- Solar2D entry point for react-solar2d demos

-- Resolve parent directory path for require
local path = system.pathForFile("main.lua"):gsub("examples/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

local RN = require("react_solar2d")
local React = require("react")

-- Pick which demo to run
local demo = "hello" -- "hello" | "counter"

local container = display.newGroup()

if demo == "hello" then
    local HelloWorld = require("examples.HelloWorld")
    local rec = RN.render(React.createElement(HelloWorld), container)
    print("Rendered hello. Container children:", container.numChildren)
    -- Debug: print display tree
    local function debugTree(obj, indent)
        indent = indent or ""
        print(indent .. tostring(obj._type or "?") .. " x=" .. obj.x .. " y=" .. obj.y .. " w=" .. (obj.width or 0) .. " h=" .. (obj.height or 0) .. " children=" .. (obj.numChildren or 0))
        if obj._textObj then print(indent .. "  text: " .. tostring(obj._textObj.text)) end
        for i = 1, (obj.numChildren or 0) do
            debugTree(obj[i], indent .. "  ")
        end
    end
    debugTree(container)
elseif demo == "counter" then
    local Counter = require("examples.Counter")
    RN.render(React.createElement(Counter), container)
end

-- Auto-flush state updates on each frame
Runtime:addEventListener("enterFrame", function()
    RN.flushUpdates()
end)
