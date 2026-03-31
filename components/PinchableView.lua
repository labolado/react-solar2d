--- PinchableView component.
-- Supports 1-finger pan and 2-finger pinch-zoom + rotation.
-- Directly manipulates the display object (x, y, xScale, yScale, rotation) at 60fps.
-- Math adapted from labo_papercut_dinosaur multitouch patterns.
-- @module components.PinchableView

local React = require("react")
local ce = React.createElement

-- Distance between two points
local function dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Angle in degrees between two points
local function angleDeg(x1, y1, x2, y2)
    return math.deg(math.atan2(y2 - y1, x2 - x1))
end

--- PinchableView component.
-- @param props table
--   style table              Layout + visual style
--   children any             Child elements
--   minScale number          Minimum allowed scale (default 0.2)
--   maxScale number          Maximum allowed scale (default 5)
--   onTransformStart function  Called with {scale, rotation, x, y} on gesture begin
--   onTransform function       Called with {scale, rotation, x, y} each frame
--   onTransformEnd function    Called with {scale, rotation, x, y} on gesture end
--   disabled boolean           When true, touch is ignored
-- @return table React element
local function PinchableView(props)
    local viewRef = React.useRef(nil)

    local onRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    React.useEffect(function()
        local view = viewRef.current
        if not view then return end

        local minScale = props.minScale or 0.2
        local maxScale = props.maxScale or 5

        -- Active touches indexed by event.id
        local touches = {}
        local touchCount = 0

        -- Gesture state recorded at gesture start
        local baseScale = 1
        local baseRotation = 0
        local baseX = 0
        local baseY = 0
        local startDist = nil
        local startAngle = nil
        local startCX = nil
        local startCY = nil

        local function touchIds()
            local ids = {}
            for id in pairs(touches) do ids[#ids + 1] = id end
            return ids
        end

        local function fireCb(cb)
            if cb then
                cb({
                    scale = view.xScale,
                    rotation = view.rotation,
                    x = view.x,
                    y = view.y,
                })
            end
        end

        local function recordBase()
            baseScale = view.xScale
            baseRotation = view.rotation
            baseX = view.x
            baseY = view.y
        end

        local function onTouch(event)
            if props.disabled then return false end
            local phase = event.phase
            local id = event.id

            if phase == "began" then
                touches[id] = { x = event.x, y = event.y }
                touchCount = touchCount + 1
                display.getCurrentStage():setFocus(view, id)

                if touchCount == 1 then
                    recordBase()
                    fireCb(props.onTransformStart)
                elseif touchCount == 2 then
                    -- Record two-finger start state
                    local ids = touchIds()
                    local t1, t2 = touches[ids[1]], touches[ids[2]]
                    startDist = dist(t1.x, t1.y, t2.x, t2.y)
                    startAngle = angleDeg(t1.x, t1.y, t2.x, t2.y)
                    startCX = (t1.x + t2.x) * 0.5
                    startCY = (t1.y + t2.y) * 0.5
                    recordBase()
                end
                return true

            elseif phase == "moved" then
                if not touches[id] then return true end
                touches[id] = { x = event.x, y = event.y }

                if touchCount == 1 then
                    -- Single finger: pan
                    local ids = touchIds()
                    -- delta from when this finger began (we re-record base each time count changes)
                    -- use startCX/Y for 1-finger too
                    if startCX == nil then
                        startCX = event.x
                        startCY = event.y
                        recordBase()
                    end
                    local dx = event.x - startCX
                    local dy = event.y - startCY
                    view.x = baseX + dx
                    view.y = baseY + dy
                    fireCb(props.onTransform)

                elseif touchCount >= 2 then
                    local ids = touchIds()
                    local t1, t2 = touches[ids[1]], touches[ids[2]]
                    if not t1 or not t2 then return true end

                    -- Scale
                    local curDist = dist(t1.x, t1.y, t2.x, t2.y)
                    local scaleFactor = (startDist and startDist > 0)
                        and (curDist / startDist) or 1
                    local newScale = baseScale * scaleFactor
                    if newScale < minScale then newScale = minScale end
                    if newScale > maxScale then newScale = maxScale end
                    view.xScale = newScale
                    view.yScale = newScale

                    -- Rotation
                    local curAngle = angleDeg(t1.x, t1.y, t2.x, t2.y)
                    local dAngle = (startAngle) and (curAngle - startAngle) or 0
                    view.rotation = baseRotation + dAngle

                    -- Translate: midpoint of two fingers drives position
                    local curCX = (t1.x + t2.x) * 0.5
                    local curCY = (t1.y + t2.y) * 0.5
                    if startCX then
                        view.x = baseX + (curCX - startCX)
                        view.y = baseY + (curCY - startCY)
                    end

                    fireCb(props.onTransform)
                end
                return true

            elseif phase == "ended" or phase == "cancelled" then
                if not touches[id] then return true end
                touches[id] = nil
                touchCount = touchCount - 1
                display.getCurrentStage():setFocus(nil, id)

                if touchCount == 0 then
                    startDist = nil
                    startAngle = nil
                    startCX = nil
                    startCY = nil
                    fireCb(props.onTransformEnd)
                elseif touchCount == 1 then
                    -- Dropped to 1 finger: re-record base from current state
                    startDist = nil
                    startAngle = nil
                    startCX = nil
                    startCY = nil
                    recordBase()
                end
                return true
            end
            return false
        end

        view:addEventListener("touch", onTouch)

        return function()
            view:removeEventListener("touch", onTouch)
        end
    end, {props.disabled, props.minScale, props.maxScale})

    return ce("View", {
        ref = onRef,
        style = props.style,
    }, props.children)
end

return PinchableView
