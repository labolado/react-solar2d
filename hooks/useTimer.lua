--- useTimer hooks module.
-- Timer/interval hooks for game loops.
-- @module hooks.useTimer

local React = require("react")

local M = {}

--- useInterval hook — run a callback on an interval.
-- @param callback function Callback to run
-- @param delay number|boolean Delay in ms, or false/nil to pause
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

--- useTimeout hook — run a callback once after a delay.
-- @param callback function Callback to run
-- @param delay number|boolean Delay in ms, or false/nil to cancel
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
