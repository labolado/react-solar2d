--- SafeAreaView component.
-- Automatically applies insets for safe areas (notch, island, status bar).
-- @module components.SafeAreaView

local React = require("react")
local createElement = React.createElement

--- SafeAreaView component.
-- @param props table {style, children}
-- @return table React element
local function SafeAreaView(props)
    local style = props.style or {}
    local children = props.children

    -- Calculate safe area insets on each render (handles orientation changes)
    local safeInsets = { top = 0, bottom = 0, left = 0, right = 0 }

    if display then
        -- Get safe area dimensions
        local safeX = display.safeScreenOriginX or display.screenOriginX or 0
        local safeY = display.safeScreenOriginY or display.screenOriginY or 0
        local safeW = display.safeActualContentWidth or display.actualContentWidth or display.contentWidth
        local safeH = display.safeActualContentHeight or display.actualContentHeight or display.contentHeight
        local screenW = display.actualContentWidth or display.contentWidth
        local screenH = display.actualContentHeight or display.contentHeight
        local originX = display.screenOriginX or 0
        local originY = display.screenOriginY or 0

        -- Calculate insets
        safeInsets.top = math.abs(safeY - originY)
        safeInsets.bottom = math.max(0, (screenH + originY) - (safeH + safeY))
        safeInsets.left = math.abs(safeX - originX)
        safeInsets.right = math.max(0, (screenW + originX) - (safeW + safeX))
    end

    -- Merge safe area padding with user-provided style
    local safeStyle = {}
    for k, v in pairs(style) do
        safeStyle[k] = v
    end

    -- Apply safe area insets as padding (can be overridden by explicit padding)
    safeStyle.paddingTop = (style.paddingTop or 0) + safeInsets.top
    safeStyle.paddingBottom = (style.paddingBottom or 0) + safeInsets.bottom
    safeStyle.paddingLeft = (style.paddingLeft or 0) + safeInsets.left
    safeStyle.paddingRight = (style.paddingRight or 0) + safeInsets.right

    return createElement("View", {
        style = safeStyle,
    }, children)
end

return SafeAreaView
