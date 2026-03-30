--- Switch component.
-- Toggle switch function component.
-- @module components.Switch

local React = require("react")
local createElement = React.createElement

--- Switch component.
-- @param props table {value, onValueChange, trackColor={true=...,false=...}, thumbColor}
-- @return table React element
local function Switch(props)
    local value = props.value or false
    local onValueChange = props.onValueChange
    local trackColor = props.trackColor or {}
    local thumbColor = props.thumbColor or "#FFFFFF"

    local trackBg = value
        and (trackColor["true"] or "#4CD964")
        or (trackColor["false"] or "#E5E5EA")

    return createElement("View", {
        style = {
            width = 100, height = 62,
            borderRadius = 31,
            backgroundColor = trackBg,
            justifyContent = "center",
            padding = 4,
        },
        onPress = function()
            if onValueChange then
                onValueChange(not value)
            end
        end,
    },
        createElement("View", {
            style = {
                width = 54, height = 54,
                borderRadius = 27,
                backgroundColor = thumbColor,
                alignSelf = value and "flex-end" or "flex-start",
            },
        })
    )
end

return Switch
