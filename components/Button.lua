-- components/Button.lua
local React = require("react")

local function Button(props)
    return React.createElement("View", {
        style = {
            backgroundColor = props.color or "#2196F3",
            borderRadius = 4,
            padding = 10,
            alignItems = "center",
        },
        onPress = props.onPress,
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
