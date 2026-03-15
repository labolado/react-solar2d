-- hooks/useTimer.lua
-- Timer/interval hooks for game loops
local React = require("react")

local M = {}

function M.useInterval(callback, delay)
    local callbackRef = React.useRef(callback)
    callbackRef.current = callback

    React.useEffect(function()
        if delay == nil or delay == false then return end

        local handle = timer.performWithDelay(delay, function()
            if callbackRef.current then
                callbackRef.current()
            end
        end, 0) -- 0 = infinite repeats

        return function()
            timer.cancel(handle)
        end
    end, {delay})
end

function M.useTimeout(callback, delay)
    local callbackRef = React.useRef(callback)
    callbackRef.current = callback

    React.useEffect(function()
        if delay == nil or delay == false then return end

        local handle = timer.performWithDelay(delay, function()
            if callbackRef.current then
                callbackRef.current()
            end
        end, 1) -- 1 = run once

        return function()
            timer.cancel(handle)
        end
    end, {delay})
end

return M
