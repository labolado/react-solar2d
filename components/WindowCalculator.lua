--- WindowCalculator module.
-- Calculates the visible item window for VirtualizedList based on scroll offset.
-- @module components.WindowCalculator

--- Calculate visible window.
-- @param scrollOffset number Current scroll offset
-- @param viewportHeight number Height of the viewport
-- @param itemHeight number Height of each item
-- @param totalCount number Total number of items
-- @param windowSize number Buffer multiplier (default 5)
-- @return table {first, last} 1-based indices
local function calculateWindow(scrollOffset, viewportHeight, itemHeight, totalCount, windowSize)
    if totalCount == 0 or itemHeight == 0 then
        return { first = 1, last = 0 }
    end

    local visibleStart = math.floor(scrollOffset / itemHeight) + 1
    local visibleEnd = math.ceil((scrollOffset + viewportHeight) / itemHeight)
    local visibleCount = math.max(1, visibleEnd - visibleStart + 1)
    local buffer = math.floor((windowSize - 1) / 2 * visibleCount)

    return {
        first = math.max(1, visibleStart - buffer),
        last = math.min(totalCount, visibleEnd + buffer),
    }
end

return calculateWindow
