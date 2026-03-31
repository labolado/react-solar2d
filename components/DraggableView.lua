--- DraggableView component.
-- A View that can be dragged by a single finger at 60fps.
-- Directly manipulates the display object position (no React state) for performance.
-- A second finger touching while dragging is ignored.
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
--   bounds table          {xMin, yMin, xMax, yMax} content bounds to clamp position
--   disabled boolean      When true, touch is ignored
-- @return table React element
local function DraggableView(props)
    local viewRef = React.useRef(nil)
    local touchIdRef = React.useRef(nil)    -- active finger id
    local startTouchRef = React.useRef(nil) -- {x, y} of touch began
    local startPosRef = React.useRef(nil)   -- {x, y} of object when drag began

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
        -- In that mode, the ScrollView overlay owns the touch lifecycle (setFocus),
        -- so we must NOT call setFocus ourselves to avoid stealing the touch.
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

        local function onTouch(event)
            local p = propsRef.current
            if p.disabled then return false end
            local phase = event.phase

            if phase == "began" then
                -- Only accept one finger at a time
                if touchIdRef.current ~= nil then return true end
                -- canFocus: another component may already own this finger
                if not TouchRegistry.canFocus(event.id, view) then return false end
                touchIdRef.current = event.id
                TouchRegistry.claim(event.id, view)
                startTouchRef.current = { x = event.x, y = event.y }
                startPosRef.current = { x = view.x, y = view.y }
                -- Only claim focus when handling touch directly (not via ScrollView)
                if not delegated then
                    display.getCurrentStage():setFocus(view, event.id)
                end
                if p.onDragStart then
                    p.onDragStart({ x = event.x, y = event.y, id = event.id })
                end
                return true

            elseif phase == "moved" then
                if event.id ~= touchIdRef.current then return true end
                local st = startTouchRef.current
                local sp = startPosRef.current
                if not st or not sp then return true end

                local dx = event.x - st.x
                local dy = event.y - st.y
                local newX = sp.x + dx
                local newY = sp.y + dy

                -- Apply bounds clamping
                if p.bounds then
                    local b = p.bounds
                    newX = clamp(newX, b.xMin, b.xMax)
                    newY = clamp(newY, b.yMin, b.yMax)
                end

                view.x = newX
                view.y = newY

                if p.onDrag then
                    p.onDrag({ x = event.x, y = event.y, dx = dx, dy = dy, id = event.id })
                end
                return true

            elseif phase == "ended" or phase == "cancelled" then
                if event.id ~= touchIdRef.current then return true end
                touchIdRef.current = nil
                TouchRegistry.release(event.id, view)
                if not delegated then
                    display.getCurrentStage():setFocus(nil, event.id)
                end

                -- Snap on release
                if p.snapToGrid then
                    view.x = snapVal(view.x, p.snapToGrid)
                    view.y = snapVal(view.y, p.snapToGrid)
                end

                if p.onDragEnd then
                    p.onDragEnd({ x = event.x, y = event.y, id = event.id })
                end
                return true
            end
            return false
        end

        view:addEventListener("touch", onTouch)
        -- Mark as draggable so ScrollView's findDragChild can delegate to us.
        -- _onDragHandler wraps onTouch with delegated=true so we don't steal
        -- the overlay's setFocus — the ScrollView manages the touch lifecycle.
        view._isDraggable = true
        view._onDragHandler = function(ev)
            delegated = true
            local r = onTouch(ev)
            delegated = false
            return r
        end

        return function()
            -- Cleanup sweep: release focus + registry
            if touchIdRef.current ~= nil then
                display.getCurrentStage():setFocus(nil, touchIdRef.current)
                TouchRegistry.release(touchIdRef.current, view)
                touchIdRef.current = nil
            end
            view:removeEventListener("touch", onTouch)
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
