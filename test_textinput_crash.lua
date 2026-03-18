-- Minimal TextInput crash test
package.path = "./?.lua;./?/init.lua;" .. package.path

local React = require("react")
local RN = require("react_solar2d")
local Renderer = require("renderer")

local ce = React.createElement
local useState = React.useState

local function TestScreen()
    local text, setText = useState("")
    return ce("View", { style = { width = 300, height = 200, backgroundColor = "#FFFFFF" } },
        ce(RN.TextInput, {
            placeholder = "Type here...",
            value = text,
            onChangeText = function(t) setText(t) end,
            style = {
                width = 280,
                height = 40,
                backgroundColor = "#F0F0F0",
                borderWidth = 1,
                borderColor = "#CCCCCC",
            },
        })
    )
end

print("Creating element...")
local element = ce(TestScreen)
print("Element created")

if display then
    print("Rendering in Solar2D...")
    local container = display.newGroup()
    local ok, err = pcall(function()
        Renderer.render(element, container)
    end)
    if ok then
        print("SUCCESS: TextInput rendered without crash")
    else
        print("FAILED: " .. tostring(err))
    end
else
    print("No display available (not in Solar2D)")
end
