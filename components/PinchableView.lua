--- PinchableView component.
-- 1-finger pan + 2-finger pinch-zoom + rotation with correct transform math.
-- Uses TrackDot pattern (one invisible proxy object per finger) for reliable
-- multi-finger focus. Incremental per-frame deltas avoid snapshot-based jumps.
-- Scale/rotation applied around the pinch center point, not object center.
-- Adapted from labo_papercut_dinosaur PinchZoomRotate.
-- @module components.PinchableView

local React = require("react")
local ce = React.createElement
local TouchRegistry = require("lib.TouchRegistry")

local function dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function angleDeg(x1, y1, x2, y2)
    return math.deg(math.atan2(y2 - y1, x2 - x1))
end

--- PinchableView component.
-- @param props table
--   style table              Layout + visual style
--   children any             Child elements
--   minScale number          Minimum allowed scale (default 0.2)
--   maxScale number          Maximum allowed scale (default 5)
--   scaleJitterThreshold number  Max per-frame scale change ratio before filtering (default 0.15)
--   onTransformStart function  Called with {scale, rotation, x, y}
--   onTransform function       Called with {scale, rotation, x, y}
--   onTransformEnd function    Called with {scale, rotation, x, y}
--   disabled boolean
-- @return table React element
local function PinchableView(props)
    local viewRef = React.useRef(nil)
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
        local jitterThreshold = props.scaleJitterThreshold or 0.15

        -- TrackDots: one invisible display object per finger.
        -- Solar2D setFocus routes that finger's events exclusively to the dot.
        -- This avoids multi-finger focus reliability issues on the same view.
        local dots = {}        -- [event.id] = {dot, listener}
        local touches = {}     -- [event.id] = {x, y}  (content/screen coords)
        local touchOrder = {}  -- ordered array of ids (insertion order, stable pairing)

        -- Previous-frame state for incremental delta computation
        local prevCX, prevCY = nil, nil  -- previous pinch center (content coords)
        local prevDist = nil             -- previous finger distance
        local prevAngle = nil            -- previous finger angle

        local function touchCount() return #touchOrder end

        local function fireCb(name)
            local p = propsRef.current
            if p[name] then
                p[name]({
                    scale = view.xScale,
                    rotation = view.rotation,
                    x = view.x,
                    y = view.y,
                })
            end
        end

        -- Snapshot current finger positions for next frame's delta calculation
        local function savePrev()
            if touchCount() >= 2 then
                local t1 = touches[touchOrder[1]]
                local t2 = touches[touchOrder[2]]
                if t1 and t2 then
                    prevDist = dist(t1.x, t1.y, t2.x, t2.y)
                    prevAngle = angleDeg(t1.x, t1.y, t2.x, t2.y)
                    prevCX = (t1.x + t2.x) * 0.5
                    prevCY = (t1.y + t2.y) * 0.5
                end
            elseif touchCount() == 1 then
                local t = touches[touchOrder[1]]
                if t then
                    prevCX = t.x
                    prevCY = t.y
                end
                prevDist = nil
                prevAngle = nil
            else
                prevCX, prevCY = nil, nil
                prevDist, prevAngle = nil, nil
            end
        end

        -- Convert content-space point to view's parent local space
        -- so view.x/y manipulation is in the correct coordinate system.
        local function toLocal(cx, cy)
            if view.parent and view.parent.contentToLocal then
                return view.parent:contentToLocal(cx, cy)
            end
            return cx, cy
        end

        -- Core: process a finger event (called by TrackDot listeners)
        local function handleFinger(id, phase, x, y)
            if phase == "moved" then
                if not touches[id] then return end
                touches[id] = { x = x, y = y }

                if touchCount() == 1 and prevCX then
                    -- Single finger: incremental pan
                    local plx, ply = toLocal(prevCX, prevCY)
                    local clx, cly = toLocal(x, y)
                    view.x = view.x + (clx - plx)
                    view.y = view.y + (cly - ply)
                    savePrev()
                    fireCb("onTransform")

                elseif touchCount() >= 2 and prevDist then
                    local t1 = touches[touchOrder[1]]
                    local t2 = touches[touchOrder[2]]
                    if not t1 or not t2 then return end

                    local curDist = dist(t1.x, t1.y, t2.x, t2.y)
                    local curAngle = angleDeg(t1.x, t1.y, t2.x, t2.y)
                    local curCX = (t1.x + t2.x) * 0.5
                    local curCY = (t1.y + t2.y) * 0.5

                    -- Delta scale with jitter filter (labo: filter noisy frames)
                    local dScale = (prevDist > 1) and (curDist / prevDist) or 1
                    if math.abs(dScale - 1) > jitterThreshold then dScale = 1 end
                    -- Clamp to scale limits
                    local projected = view.xScale * dScale
                    if projected < minScale then dScale = minScale / view.xScale end
                    if projected > maxScale then dScale = maxScale / view.xScale end

                    -- Delta rotation with wrap-around handling
                    local dRot = curAngle - prevAngle
                    if dRot > 180 then dRot = dRot - 360 end
                    if dRot < -180 then dRot = dRot + 360 end

                    -- Pinch center in parent-local coords
                    local lcx, lcy = toLocal(prevCX, prevCY)

                    -- 1) Rotate around pinch center (labo order: rotate first)
                    if dRot ~= 0 then
                        local rad = math.rad(dRot)
                        local cos_r = math.cos(rad)
                        local sin_r = math.sin(rad)
                        local ox = view.x - lcx
                        local oy = view.y - lcy
                        view.x = lcx + ox * cos_r - oy * sin_r
                        view.y = lcy + ox * sin_r + oy * cos_r
                        view.rotation = view.rotation + dRot
                    end

                    -- 2) Scale around pinch center
                    if dScale ~= 1 then
                        view.x = lcx + (view.x - lcx) * dScale
                        view.y = lcy + (view.y - lcy) * dScale
                        view.xScale = view.xScale * dScale
                        view.yScale = view.yScale * dScale
                    end

                    -- 3) Translate by center point movement
                    local newLcx, newLcy = toLocal(curCX, curCY)
                    view.x = view.x + (newLcx - lcx)
                    view.y = view.y + (newLcy - lcy)

                    savePrev()
                    fireCb("onTransform")
                end

            elseif phase == "ended" or phase == "cancelled" then
                if not touches[id] then return end
                touches[id] = nil
                for i = #touchOrder, 1, -1 do
                    if touchOrder[i] == id then
                        table.remove(touchOrder, i)
                        break
                    end
                end
                -- Remove TrackDot
                local entry = dots[id]
                if entry then
                    display.getCurrentStage():setFocus(nil, id)
                    entry.dot:removeEventListener("touch", entry.listener)
                    entry.dot:removeSelf()
                    dots[id] = nil
                end
                TouchRegistry.release(id, view)

                if touchCount() == 0 then
                    prevCX, prevCY = nil, nil
                    prevDist, prevAngle = nil, nil
                    fireCb("onTransformEnd")
                else
                    -- Re-anchor for next frame's delta
                    savePrev()
                end
            end
        end

        -- View's own touch listener: handles "began" events only.
        -- TrackDot listeners handle moved/ended.
        local function onViewTouch(event)
            if event.phase ~= "began" then return false end
            local p = propsRef.current
            if p.disabled then return false end

            local id = event.id
            -- Guard: duplicate began / palm rejection (max 2 fingers)
            if touches[id] then return true end
            if touchCount() >= 2 then return true end
            -- canFocus: another component may already own this finger
            if not TouchRegistry.canFocus(id, view) then return false end

            -- Register touch
            touches[id] = { x = event.x, y = event.y }
            touchOrder[#touchOrder + 1] = id
            TouchRegistry.claim(id, view)

            -- Create TrackDot: invisible proxy for this finger.
            -- setFocus routes subsequent events to the dot, not the view.
            local dot = display.newCircle(event.x, event.y, 1)
            dot.isVisible = false
            dot.isHitTestable = true

            local function dotListener(e)
                -- Update dot position (keeps Solar2D hit-test correct if focus is lost)
                if e.phase == "moved" then
                    dot.x = e.x
                    dot.y = e.y
                end
                handleFinger(e.id, e.phase, e.x, e.y)
                return true
            end

            dot:addEventListener("touch", dotListener)
            display.getCurrentStage():setFocus(dot, id)
            dots[id] = { dot = dot, listener = dotListener }

            -- First finger: begin gesture; second finger: transition to pinch
            savePrev()
            if touchCount() == 1 then
                fireCb("onTransformStart")
            end
            return true
        end

        view:addEventListener("touch", onViewTouch)

        return function()
            -- Cleanup sweep: remove all TrackDots, release all focus, reset state
            for fid, entry in pairs(dots) do
                display.getCurrentStage():setFocus(nil, fid)
                entry.dot:removeEventListener("touch", entry.listener)
                entry.dot:removeSelf()
            end
            TouchRegistry.releaseAll(view)
            dots = {}
            touches = {}
            touchOrder = {}
            prevCX, prevCY = nil, nil
            prevDist, prevAngle = nil, nil
            view:removeEventListener("touch", onViewTouch)
        end
    end, {props.minScale, props.maxScale})

    return ce("View", {
        ref = onRef,
        style = props.style,
    }, props.children)
end

return PinchableView
