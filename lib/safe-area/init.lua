-- lib/safe-area/init.lua
-- react-native-safe-area-context implementation for Solar2D

local M = {}

function M.getSafeAreaInsets()
    local insets = { top = 0, bottom = 0, left = 0, right = 0 }

    if not display then
        return insets
    end

    if display.safeScreenOriginY and display.screenOriginY then
        insets.top = math.abs(display.safeScreenOriginY - display.screenOriginY)
    end

    if display.safeActualContentHeight and display.safeScreenOriginY then
        local safeH = display.safeActualContentHeight
        local safeY = display.safeScreenOriginY
        local screenH = display.actualContentHeight or display.contentHeight
        local originY = display.screenOriginY or 0
        insets.bottom = math.max(0, (screenH + originY) - (safeH + safeY))
    end

    return insets
end

function M.useSafeAreaInsets()
    return M.getSafeAreaInsets()
end

return M
