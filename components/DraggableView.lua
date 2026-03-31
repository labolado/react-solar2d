--- DraggableView component.
-- A View that can be dragged by a single finger at 60fps.
-- Directly manipulates the display object position (no React state) for performance.
-- A second finger touching while dragging is ignored.
-- @module components.DraggableView

local React = require("react")
local ce = React.createElement

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

    local onRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    React.useEffect(function()
        local view = viewRef.current
        if not view then return end

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
            if props.disabled then return false end
            local phase = event.phase

            if phase == "began" then
                -- Only accept one finger at a time
                if touchIdRef.current ~= nil then return true end
                touchIdRef.current = event.id
                startTouchRef.current = { x = event.x, y = event.y }
                startPosRef.current = { x = view.x, y = view.y }
                -- Lock this finger to the view
                display.getCurrentStage():setFocus(view, event.id)
                if props.onDragStart then
                    props.onDragStart({ x = event.x, y = event.y, id = event.id })
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
                if props.bounds then
                    local b = props.bounds
                    newX = clamp(newX, b.xMin, b.xMax)
                    newY = clamp(newY, b.yMin, b.yMax)
                end

                view.x = newX
                view.y = newY

                if props.onDrag then
                    props.onDrag({ x = event.x, y = event.y, dx = dx, dy = dy, id = event.id })
                end
                return true

            elseif phase == "ended" or phase == "cancelled" then
                if event.id ~= touchIdRef.current then return true end
                touchIdRef.current = nil
                display.getCurrentStage():setFocus(nil, event.id)

                -- Snap on release
                if props.snapToGrid then
                    view.x = snapVal(view.x, props.snapToGrid)
                    view.y = snapVal(view.y, props.snapToGrid)
                end

                if props.onDragEnd then
                    props.onDragEnd({ x = event.x, y = event.y, id = event.id })
                end
                return true
            end
            return false
        end

        view:addEventListener("touch", onTouch)
        -- Mark as draggable so ScrollView's findDragChild can delegate to us
        view._isDraggable = true
        view._onDragHandler = function(ev) return onTouch(ev) end

        return function()
            view:removeEventListener("touch", onTouch)
            view._isDraggable = nil
            view._onDragHandler = nil
        end
    end, {props.disabled})

    return ce("View", {
        ref = onRef,
        style = props.style,
    }, props.children)
end

return DraggableView
