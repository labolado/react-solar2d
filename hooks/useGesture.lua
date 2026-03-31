--- Gesture hooks for multitouch interactions.
-- Provides pan, pinch, rotation, and simultaneous gesture composition.
-- All hooks return a gesture config table consumed by DraggableView or PinchableView.
-- @module hooks.useGesture

local M = {}

-- Distance between two touch points
local function dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Angle in degrees between two touch points
local function angle(x1, y1, x2, y2)
    return math.deg(math.atan2(y2 - y1, x2 - x1))
end

-- Midpoint of two touch points
local function midpoint(x1, y1, x2, y2)
    return (x1 + x2) * 0.5, (y1 + y2) * 0.5
end

--- Single-finger pan gesture.
-- Returns a gesture config with onPanStart/onPan/onPanEnd callbacks.
-- @param config table Optional: { onStart, onMove, onEnd, minDistance }
-- @return table Gesture config for use with DraggableView
function M.pan(config)
    config = config or {}
    return {
        type = "pan",
        onStart = config.onStart,
        onMove = config.onMove,
        onEnd = config.onEnd,
        minDistance = config.minDistance or 0,
    }
end

--- Two-finger pinch gesture returning scale and focal point.
-- @param config table Optional: { onStart, onMove, onEnd, minScale, maxScale }
-- @return table Gesture config for use with PinchableView
function M.pinch(config)
    config = config or {}
    return {
        type = "pinch",
        onStart = config.onStart,
        onMove = config.onMove,
        onEnd = config.onEnd,
        minScale = config.minScale or 0.1,
        maxScale = config.maxScale or 10,
    }
end

--- Two-finger rotation gesture returning degrees.
-- @param config table Optional: { onStart, onMove, onEnd }
-- @return table Gesture config for use with PinchableView
function M.rotation(config)
    config = config or {}
    return {
        type = "rotation",
        onStart = config.onStart,
        onMove = config.onMove,
        onEnd = config.onEnd,
    }
end

--- Combine multiple gesture configs so they all fire simultaneously.
-- @param ... Gesture config tables from pan/pinch/rotation
-- @return table Combined gesture config
function M.simultaneous(...)
    local gestures = {...}
    return {
        type = "simultaneous",
        gestures = gestures,
    }
end

--- Utility: average center of an arbitrary set of active touches.
-- @param touches table Table of touch objects with x, y properties
-- @return number, number Center x, y coordinates
function M.avgCenter(touches)
    local sx, sy, n = 0, 0, 0
    for _, t in pairs(touches) do
        sx = sx + t.x
        sy = sy + t.y
        n = n + 1
    end
    if n == 0 then return 0, 0 end
    return sx / n, sy / n
end

--- Utility: average distance from center (scale proxy).
-- @param touches table Table of touch objects with x, y properties
-- @param cx number Center x coordinate
-- @param cy number Center y coordinate
-- @return number Average distance from center
function M.avgDist(touches, cx, cy)
    local sum, n = 0, 0
    for _, t in pairs(touches) do
        sum = sum + dist(t.x, t.y, cx, cy)
        n = n + 1
    end
    if n == 0 then return 0 end
    return sum / n
end

-- Export math utilities for component use
M.dist = dist
M.angle = angle
M.midpoint = midpoint

return M
