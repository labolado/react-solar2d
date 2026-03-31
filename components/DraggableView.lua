--- DraggableView component.
-- A View that can be dragged by a single finger at 60fps.
-- Directly manipulates the display object position (no React state) for performance.
-- Uses TrackDot pattern for reliable touch on real devices.
-- Works both standalone and inside a ScrollView (ScrollView delegates via _onDragHandler).
-- @module components.DraggableView

local React = require("react")
local ce = React.createElement
local TouchRegistry = require("lib.TouchRegistry")

--- DraggableView component.
-- @param props table
--   style table           Layout + visual style
--   children any          Child elements
--   onDragStart function  Called with {x, y, id} when drag begins
--   onDrag function       Called with {x, y, dx, dy, id} each moved event
--   onDragEnd function    Called with {x, y, id} when drag ends
--   snapToGrid number     If set, snaps position to this grid size on release
--   snapBack boolean      If true, returns to rest position on release (joystick mode)
--   bounds table          {xMin, yMin, xMax, yMax} offset limits from rest position
--   disabled boolean      When true, touch is ignored
-- @return table React element
local function DraggableView(props)
    local viewRef = React.useRef(nil)
    local touchIdRef = React.useRef(nil)    -- active finger id
    local startTouchRef = React.useRef(nil) -- {x, y} of touch began
    local startPosRef = React.useRef(nil)   -- {x, y} of object when drag began
    local dotRef = React.useRef(nil)        -- TrackDot for active drag

    -- propsRef: always holds latest props, avoids stale closures in touch handler
    local propsRef = React.useRef({})
    propsRef.current = props

    local onRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    React.useEffect(function()
        local view = viewRef.current
        if not view then return end

        -- When true, the touch came through ScrollView's _onDragHandler delegation.
        local delegated = false

        local function clamp(val, lo, hi)
            if lo and val < lo then return lo end
            if hi and val > hi then return hi end
            return val
        end

        local function snapVal(val, grid)
            if not grid or grid <= 0 then return val end
            return math.floor(val / grid + 0.5) * grid
        end

        local function cleanupDot()
            local dot = dotRef.current
            if dot then
                dot:removeEventListener("touch", dot._listener)
                dot:removeSelf()
                dotRef.current = nil
            end
        end

        local function handleEnd(event)
            local p = propsRef.current
            touchIdRef.current = nil
            TouchRegistry.release(event.id, view)
            if not delegated then
                display.getCurrentStage():setFocus(nil, event.id)
                cleanupDot()
            end

            -- Re-enable layout override now that drag is done
            view._directManipulation = false

            -- Snap on release
            if p.snapBack then
                local sp = startPosRef.current
                if sp then
                    view.x = sp.x
                    view.y = sp.y
                end
            elseif p.snapToGrid then
                view.x = snapVal(view.x, p.snapToGrid)
                view.y = snapVal(view.y, p.snapToGrid)
            end

            if p.onDragEnd then
                p.onDragEnd({ x = event.x, y = event.y, id = event.id })
            end
        end

        local function handleMove(event)
            local p = propsRef.current
            local st = startTouchRef.current
            local sp = startPosRef.current
            if not st or not sp then return end

            local dx = event.x - st.x
            local dy = event.y - st.y

            if p.bounds then
                local b = p.bounds
                dx = clamp(dx, b.xMin, b.xMax)
                dy = clamp(dy, b.yMin, b.yMax)
            end

            view.x = sp.x + dx
            view.y = sp.y + dy

            if p.onDrag then
                p.onDrag({ x = event.x, y = event.y, dx = dx, dy = dy, id = event.id })
            end
        end

        -- TrackDot touch listener (handles moved/ended after began)
        local function dotTouchHandler(event)
            if event.id ~= touchIdRef.current then return true end
            if event.phase == "moved" then
                handleMove(event)
            elseif event.phase == "ended" or event.phase == "cancelled" then
                handleEnd(event)
            end
            return true
        end

        -- Core began handler (called from both direct touch and _onDragHandler)
        local function handleBegan(event)
            local p = propsRef.current
            if p.disabled then return false end
            if touchIdRef.current ~= nil then return true end
            if not TouchRegistry.canFocus(event.id, view) then return false end

            touchIdRef.current = event.id
            TouchRegistry.claim(event.id, view)
            startTouchRef.current = { x = event.x, y = event.y }
            startPosRef.current = { x = view.x, y = view.y }
            -- Prevent applyLayout from overriding our position during drag
            view._directManipulation = true

            if not delegated then
                -- TrackDot: invisible proxy for reliable per-finger focus
                local dot = display.newCircle(event.x, event.y, 1)
                dot.isVisible = false
                dot.isHitTestable = true
                dot._listener = dotTouchHandler
                dot:addEventListener("touch", dotTouchHandler)
                display.getCurrentStage():setFocus(dot, event.id)
                dotRef.current = dot
            end

            if p.onDragStart then
                p.onDragStart({ x = event.x, y = event.y, id = event.id })
            end
            return true
        end

        -- Direct touch on the view's _bg rect.
        -- Handles began always; moved/ended as fallback when TrackDot focus doesn't
        -- deliver (programmatic dispatchEvent, some device edge cases).
        local bgListener
        if view._bg then
            bgListener = function(event)
                if event.phase == "began" then
                    return handleBegan(event)
                elseif touchIdRef.current and event.id == touchIdRef.current then
                    if event.phase == "moved" then
                        handleMove(event)
                        return true
                    elseif event.phase == "ended" or event.phase == "cancelled" then
                        handleEnd(event)
                        return true
                    end
                end
                return false
            end
            view._bg:addEventListener("touch", bgListener)
        end

        -- Mark as draggable so ScrollView's findDragChild can delegate to us.
        view._isDraggable = true
        view._onDragHandler = function(ev)
            delegated = true
            local r
            if ev.phase == "began" then
                r = handleBegan(ev)
            elseif ev.phase == "moved" then
                if ev.id == touchIdRef.current then handleMove(ev) end
                r = true
            elseif ev.phase == "ended" or ev.phase == "cancelled" then
                if ev.id == touchIdRef.current then handleEnd(ev) end
                r = true
            end
            delegated = false
            return r
        end

        return function()
            -- Cleanup sweep
            if touchIdRef.current ~= nil then
                display.getCurrentStage():setFocus(nil, touchIdRef.current)
                TouchRegistry.release(touchIdRef.current, view)
                touchIdRef.current = nil
            end
            cleanupDot()
            if bgListener and view._bg then
                view._bg:removeEventListener("touch", bgListener)
            end
            view._isDraggable = nil
            view._onDragHandler = nil
        end
    end, {})

    return ce("View", {
        ref = onRef,
        style = props.style,
    }, props.children)
end

return DraggableView
