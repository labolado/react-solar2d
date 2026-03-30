-- components/Button.lua
local React = require("react")

local function Button(props)
    local style = {
        backgroundColor = props.color or "#2196F3",
        borderRadius = 4,
        padding = 10,
        alignItems = "center",
    }
    if props.width then
        style.width = props.width
    end
    return React.createElement("View", {
        style = style,
        onPress = props.onPress,
        _touchFeedback = "opacity",
        _activeOpacity = 0.4,
    },
        React.createElement("Text", {
            style = {
                color = "#FFFFFF",
                fontSize = 16,
                fontWeight = "bold",
            },
        }, props.title or "")
    )
end

return Button
