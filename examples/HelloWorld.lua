-- examples/HelloWorld.lua
local React = require("react")
local createElement = React.createElement

local function HelloWorld()
    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#F5F5F5",
            justifyContent = "center",
            alignItems = "center",
            width = display.contentWidth,
            height = display.contentHeight,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 32,
                color = "#333333",
                fontWeight = "bold",
            },
        }, "Hello, React-Solar2D!"),

        createElement("Text", {
            style = {
                fontSize = 18,
                color = "#666666",
                marginTop = 12,
            },
        }, "React Native API on Solar2D")
    )
end

return HelloWorld
