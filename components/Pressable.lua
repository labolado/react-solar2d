--- Pressable component.
-- Generic pressable wrapper with press feedback.
-- @module components.Pressable

local React = require("react")
local createElement = React.createElement

--- Pressable component.
-- @param props table {style, onPress, onLongPress, activeOpacity, children}
-- @return table React element
local function Pressable(props)
    local style = props.style or {}
    -- Ensure Pressable has a background so the group can receive taps.
    -- If the consumer didn't set a backgroundColor, use transparent.
    if style.backgroundColor == nil then
        style = {}
        for k, v in pairs(props.style or {}) do
            style[k] = v
        end
        style.backgroundColor = "transparent"
    end
    return createElement("View", {
        style = style,
        onPress = props.onPress,
        onLongPress = props.onLongPress,
        _touchFeedback = "opacity",
        _activeOpacity = props.activeOpacity or 0.6,
    }, props.children)
end

return Pressable
