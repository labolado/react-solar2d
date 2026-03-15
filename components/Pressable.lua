-- components/Pressable.lua
-- Function component: generic pressable wrapper
local React = require("react")
local createElement = React.createElement

local function Pressable(props)
    return createElement("View", {
        style = props.style,
        onPress = props.onPress,
        onLongPress = props.onLongPress,
    }, props.children)
end

return Pressable
