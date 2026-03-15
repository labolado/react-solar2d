-- components/ActivityIndicator.lua
-- Simple loading indicator using three dots pattern.
-- Spinning animation requires the Animated API at the app level.

local React = require("react")
local createElement = React.createElement

local function ActivityIndicator(props)
    if props.animating == false then return nil end

    local size = props.size or "small"
    local actualSize = size == "large" and 72
        or (size == "small" and 40
        or (type(size) == "number" and size or 40))
    local color = props.color or "#999999"
    local dotSize = actualSize / 3
    local dotRadius = dotSize / 2

    return createElement("View", {
        style = {
            flexDirection = "row",
            justifyContent = "center",
            alignItems = "center",
            gap = actualSize / 4,
        },
    },
        createElement("View", {
            style = {
                width = dotSize,
                height = dotSize,
                borderRadius = dotRadius,
                backgroundColor = color,
                opacity = 0.4,
            },
        }),
        createElement("View", {
            style = {
                width = dotSize,
                height = dotSize,
                borderRadius = dotRadius,
                backgroundColor = color,
                opacity = 0.7,
            },
        }),
        createElement("View", {
            style = {
                width = dotSize,
                height = dotSize,
                borderRadius = dotRadius,
                backgroundColor = color,
            },
        })
    )
end

return ActivityIndicator
