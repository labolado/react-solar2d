--- Safe area insets for Solar2D.
-- Drop-in replacement for react-native-safe-area-context.
-- Reads Solar2D's `display.safeScreenOriginY` / `display.safeActualContentHeight`
-- to compute insets for notches, status bars, and home indicators.
-- @module lib.safe-area

local M = {}

--- Get current safe area insets in content coordinates.
-- Returns zero insets when running outside Solar2D (e.g. headless tests).
-- @return table {top=number, bottom=number, left=number, right=number}
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

--- Hook-style accessor for safe area insets.
-- Currently returns the same as `getSafeAreaInsets()` (no reactive updates).
-- Provided for API compatibility with react-native-safe-area-context.
-- @return table {top, bottom, left, right}
function M.useSafeAreaInsets()
    return M.getSafeAreaInsets()
end

return M
