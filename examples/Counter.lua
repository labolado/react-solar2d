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
                fontSize = 48,
                color = "#2196F3",
                fontWeight = "bold",
            },
        }, tostring(count)),

        createElement("View", {
            style = {
                flexDirection = "row",
                marginTop = 24,
                gap = 16,
            },
        },
            createElement("View", {
                style = {
                    backgroundColor = "#4CAF50",
                    borderRadius = 8,
                    padding = 16,
                    paddingLeft = 24,
                    paddingRight = 24,
                },
                onPress = function()
                    setCount(function(c) return c + 1 end)
                end,
            },
                createElement("Text", {
                    style = { color = "#FFFFFF", fontSize = 20 },
                }, "+1")
            ),

            createElement("View", {
                style = {
                    backgroundColor = "#F44336",
                    borderRadius = 8,
                    padding = 16,
                    paddingLeft = 24,
                    paddingRight = 24,
                },
                onPress = function()
                    setCount(0)
                end,
            },
                createElement("Text", {
                    style = { color = "#FFFFFF", fontSize = 20 },
                }, "Reset")
            )
        )
    )
end

return Counter
