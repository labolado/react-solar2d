-- examples/HelloWorld.lua
local React = require("react")
local createElement = React.createElement

local function HelloWorld()
    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#E8F5E9",
            justifyContent = "center",
            alignItems = "center",
            width = display.contentWidth,
            height = display.contentHeight,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 80,
                color = "#1B5E20",
            },
        }, "Hello, React-Solar2D!"),

        createElement("Text", {
            style = {
                fontSize = 48,
                color = "#388E3C",
                marginTop = 30,
            },
        }, "React Native API on Solar2D"),

        createElement("Text", {
            style = {
                fontSize = 36,
                color = "#666666",
                marginTop = 60,
            },
        }, "Yoga C + Reconciler + Hooks")
    )
end

return HelloWorld
