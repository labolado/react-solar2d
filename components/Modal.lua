-- components/Modal.lua
-- Function component: overlay backdrop + centered content
local React = require("react")
local createElement = React.createElement

local function Modal(props)
    if not props.visible then
        return nil
    end

    local transparent = props.transparent ~= false

    return createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = display.contentWidth,
            height = display.contentHeight,
            zIndex = 9999,
        },
    },
        -- Backdrop
        createElement("View", {
            style = {
                position = "absolute",
                top = 0, left = 0,
                width = display.contentWidth,
                height = display.contentHeight,
                backgroundColor = transparent and "rgba(0,0,0,128)" or "#FFFFFF",
            },
            onPress = function()
                if props.onRequestClose then
                    props.onRequestClose()
                end
            end,
        }),
        -- Content
        createElement("View", {
            style = {
                flex = 1,
                justifyContent = "center",
                alignItems = "center",
            },
        }, props.children)
    )
end

return Modal
