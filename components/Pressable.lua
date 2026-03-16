-- components/Pressable.lua
-- Function component: generic pressable wrapper with press feedback
local React = require("react")
local createElement = React.createElement

local function Pressable(props)
    return createElement("View", {
        style = props.style,
        onPress = props.onPress,
        onLongPress = props.onLongPress,
        _touchFeedback = "opacity",
        _activeOpacity = props.activeOpacity or 0.6,
    }, props.children)
end

return Pressable
