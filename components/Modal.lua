--- Modal component.
-- Function component: overlay backdrop + centered content.
-- Renders at screen level to cover all content including navigation bars.
-- @module components.Modal

local React = require("react")
local createElement = React.createElement

--- Modal component.
-- @param props table {visible, transparent=true|false, onRequestClose, children}
-- @return table React element
local function Modal(props)
    if not props.visible then
        return nil
    end

    local transparent = props.transparent ~= false
    -- Support test environment where display may not be available
    local screenW = display and display.contentWidth or 320
    local screenH = display and display.contentHeight or 480

    -- Modal renders a full-screen overlay that blocks all interaction below
    return createElement("View", {
        style = {
            position = "absolute",
            left = 0, top = 0,
            width = screenW,
            height = screenH,
            zIndex = 10000,
        },
    },
        -- Backdrop: full screen, intercepts all taps
        createElement("View", {
            style = {
                position = "absolute",
                left = 0, top = 0,
                width = screenW,
                height = screenH,
                backgroundColor = transparent and "rgba(0,0,0,0.6)" or "#FFFFFF",
            },
            onPress = props.onRequestClose,
        }),
        -- Content container: centered
        createElement("View", {
            style = {
                position = "absolute",
                left = 0, top = 0,
                width = screenW,
                height = screenH,
                justifyContent = "center",
                alignItems = "center",
            },
        }, props.children)
    )
end

return Modal
