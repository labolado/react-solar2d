-- components/WindowCalculator.lua
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
