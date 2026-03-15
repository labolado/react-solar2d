-- components/TouchableOpacity.lua
local React = require("react")

local function TouchableOpacity(props)
    local children = props.children
    if type(children) == "table" and children[1] then
        return React.createElement("View", {
            style = props.style,
            onPress = props.onPress,
            _touchFeedback = "opacity",
            _activeOpacity = props.activeOpacity or 0.2,
        }, unpack(children))
    else
        return React.createElement("View", {
            style = props.style,
            onPress = props.onPress,
            _touchFeedback = "opacity",
            _activeOpacity = props.activeOpacity or 0.2,
        }, children)
    end
end

return TouchableOpacity
