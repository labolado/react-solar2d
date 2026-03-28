-- examples/Counter.lua
local React = require("react")
local createElement = React.createElement

local function Counter()
    local count, setCount = React.useState(0)

    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#FFFFFF",
            justifyContent = "center",
            alignItems = "center",
            width = display.contentWidth,
            height = display.contentHeight,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 144,
                color = "#2196F3",
                fontWeight = "bold",
            },
        }, tostring(count)),

        createElement("View", {
            style = {
                flexDirection = "row",
                marginTop = 60,
                gap = 40,
            },
        },
            createElement("View", {
                style = {
                    backgroundColor = "#4CAF50",
                    borderRadius = 20,
                    padding = 40,
                    paddingLeft = 80,
                    paddingRight = 80,
                },
                onPress = function()
                    setCount(function(c) return c + 1 end)
                end,
            },
                createElement("Text", {
                    style = { color = "#FFFFFF", fontSize = 64 },
                }, "+1")
            ),

            createElement("View", {
                style = {
                    backgroundColor = "#F44336",
                    borderRadius = 20,
                    padding = 40,
                    paddingLeft = 80,
                    paddingRight = 80,
                },
                onPress = function()
                    setCount(0)
                end,
            },
                createElement("Text", {
                    style = { color = "#FFFFFF", fontSize = 64 },
                }, "Reset")
            )
        )
    )
end

return Counter
