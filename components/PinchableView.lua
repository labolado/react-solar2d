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

    -- propsRef: always holds latest props, avoids stale closures in touch handler
    local propsRef = React.useRef({})
    propsRef.current = props

    local onRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    React.useEffect(function()
        local view = viewRef.current
        if not view then return end

        local minScale = props.minScale or 0.2
        local maxScale = props.maxScale or 5

        -- Active touches: hash for O(1) lookup + ordered list for stable t1/t2 pairing
        local touches = {}      -- [id] = {x, y}
        local touchOrder = {}   -- ordered array of ids (insertion order)

        local function touchCount()
            return #touchOrder
        end

        -- Gesture base state (snapshot at gesture-change boundaries)
        local baseScale = 1
        local baseRotation = 0
        local baseX = 0
        local baseY = 0
        local startDist = nil
        local startAngle = nil
        local startCX = nil
        local startCY = nil

        local function recordBase()
            baseScale = view.xScale
            baseRotation = view.rotation
            baseX = view.x
            baseY = view.y
        end

        local function fireCb(cb)
            local p = propsRef.current
            if p[cb] then
                p[cb]({
                    scale = view.xScale,
                    rotation = view.rotation,
                    x = view.x,
                    y = view.y,
                })
            end
        end

        local function onTouch(event)
            local p = propsRef.current
            if p.disabled then return false end
            local phase = event.phase
            local id = event.id

            if phase == "began" then
                -- Guard duplicate began for the same id
                if touches[id] then return true end
                touches[id] = { x = event.x, y = event.y }
                touchOrder[#touchOrder + 1] = id
                display.getCurrentStage():setFocus(view, id)

                if touchCount() == 1 then
                    -- Record 1-finger pan origin immediately on began (not lazily on moved)
                    startCX = event.x
                    startCY = event.y
                    recordBase()
                    fireCb("onTransformStart")
                elseif touchCount() == 2 then
                    -- Record two-finger start state using stable ordered ids
                    local t1 = touches[touchOrder[1]]
                    local t2 = touches[touchOrder[2]]
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

                if touchCount() == 1 then
                    -- Single finger: pan relative to startCX/CY recorded in began
                    local dx = event.x - startCX
                    local dy = event.y - startCY
                    view.x = baseX + dx
                    view.y = baseY + dy
                    fireCb("onTransform")

                elseif touchCount() >= 2 then
                    local t1 = touches[touchOrder[1]]
                    local t2 = touches[touchOrder[2]]
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
                    local dAngle = startAngle and (curAngle - startAngle) or 0
                    view.rotation = baseRotation + dAngle

                    -- Translate: midpoint of two fingers drives position
                    local curCX = (t1.x + t2.x) * 0.5
                    local curCY = (t1.y + t2.y) * 0.5
                    if startCX then
                        view.x = baseX + (curCX - startCX)
                        view.y = baseY + (curCY - startCY)
                    end

                    fireCb("onTransform")
                end
                return true

            elseif phase == "ended" or phase == "cancelled" then
                if not touches[id] then return true end
                touches[id] = nil
                -- Remove from ordered list
                for i = #touchOrder, 1, -1 do
                    if touchOrder[i] == id then
                        table.remove(touchOrder, i)
                        break
                    end
                end
                display.getCurrentStage():setFocus(nil, id)

                if touchCount() == 0 then
                    startDist = nil
                    startAngle = nil
                    startCX = nil
                    startCY = nil
                    fireCb("onTransformEnd")
                elseif touchCount() == 1 then
                    -- Dropped to 1 finger: re-anchor pan from the remaining finger's
                    -- current position so the next moved event produces zero jump
                    local remainId = touchOrder[1]
                    local rem = touches[remainId]
                    startDist = nil
                    startAngle = nil
                    startCX = rem and rem.x or event.x
                    startCY = rem and rem.y or event.y
                    recordBase()
                end
                return true
            end
            return false
        end

        view:addEventListener("touch", onTouch)

        return function()
            -- Release all active finger focuses on unmount
            for _, tid in ipairs(touchOrder) do
                display.getCurrentStage():setFocus(nil, tid)
            end
            view:removeEventListener("touch", onTouch)
        end
    end, {props.minScale, props.maxScale})

    return ce("View", {
        ref = onRef,
        style = props.style,
    }, props.children)
end

return PinchableView
