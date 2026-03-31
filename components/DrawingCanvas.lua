--- DrawingCanvas component.
-- Multi-finger drawing surface. Each finger draws an independent stroke.
-- Uses TrackDot pattern (one invisible proxy per finger) for reliable
-- multi-finger focus, and display.newLine + :append() for 60fps rendering.
-- @module components.DrawingCanvas

local React = require("react")
local ce = React.createElement
local TouchRegistry = require("lib.TouchRegistry")

--- DrawingCanvas component.
-- @param props table
--   style table         Layout + visual style (must include width and height)
--   brushSize number    Stroke width in content units (default 4)
--   brushColor string   Stroke color (default "#000000")
--   onStrokeStart function  Called with {id, x, y} when a finger begins a stroke
--   onStrokeEnd function    Called with {id} when a finger lifts
--   maxStrokes number   Maximum strokes to keep (oldest removed, default 200)
--   maxFingers number   Maximum simultaneous fingers (palm rejection, default 5)
-- @return table React element
local DrawingCanvas = React.forwardRef(function(props, ref)
    local viewRef = React.useRef(nil)
    local surfaceRef = React.useRef(nil)    -- display group holding all strokes
    local activeRef = React.useRef({})      -- activeRef.current[id] = {line, dot, dotListener}
    local strokesRef = React.useRef({})     -- ordered list of all stroke display objects

    local onRef = React.useCallback(function(instance)
        viewRef.current = instance
        -- Forward to external ref so parent can access clearStrokes
        if ref then
            if type(ref) == "function" then
                ref(instance)
            elseif type(ref) == "table" then
                ref.current = instance
            end
        end
    end, {})

    -- propsRef avoids stale closures in event handlers
    local propsRef = React.useRef({})
    propsRef.current = props

    React.useEffect(function()
        local view = viewRef.current
        if not view then return end

        -- Use the view's actual layout size (from Yoga) rather than style props,
        -- because flex=1 etc. won't have width/height in the style table.
        local style = propsRef.current.style or {}
        local w = view.contentWidth or style.width or display.contentWidth
        local h = view.contentHeight or style.height or display.contentHeight
        -- Fallback: if view has a _bg rect (created by HostConfig), use its size
        if (w <= 0 or h <= 0) and view._bg then
            w = view._bg.contentWidth or w
            h = view._bg.contentHeight or h
        end

        -- Drawing surface group (inserted below any React children)
        local surface = display.newGroup()
        view:insert(surface)
        surface:toBack()
        if view._bg then view._bg:toBack() end
        surfaceRef.current = surface

        -- Transparent hit rect for initial touch detection (began only).
        -- After began, a TrackDot per finger handles moved/ended.
        -- Position at (0,0) with top-left anchor to match the view's coordinate system.
        local hitRect = display.newRect(surface, 0, 0, w, h)
        hitRect.anchorX, hitRect.anchorY = 0, 0
        hitRect:setFillColor(0, 0, 0, 0.001)
        hitRect.isHitTestable = true

        -- Remove a TrackDot and release its focus
        local function removeDot(id)
            local state = activeRef.current[id]
            if not state then return end
            display.getCurrentStage():setFocus(nil, id)
            TouchRegistry.release(id, view)
            if state.dot then
                state.dot:removeEventListener("touch", state.dotListener)
                state.dot:removeSelf()
            end
        end

        -- Handle moved/ended events from a TrackDot
        local function handleDotEvent(event)
            local id = event.id
            local phase = event.phase
            local state = activeRef.current[id]
            if not state then return true end

            local lx, ly = surface:contentToLocal(event.x, event.y)
            -- Clamp to canvas bounds so strokes don't escape the drawing area
            if lx < 0 then lx = 0 end
            if ly < 0 then ly = 0 end
            if lx > w then lx = w end
            if ly > h then ly = h end

            if phase == "moved" then
                state.line:append(lx, ly)
                state.lastX = lx
                state.lastY = ly
                -- Keep dot position in sync
                if state.dot then
                    state.dot.x = event.x
                    state.dot.y = event.y
                end

            elseif phase == "ended" or phase == "cancelled" then
                removeDot(id)
                activeRef.current[id] = nil
                if propsRef.current.onStrokeEnd then
                    propsRef.current.onStrokeEnd({ id = id })
                end
            end
            return true
        end

        -- hitRect only handles "began": creates a TrackDot per finger
        local function onHitTouch(event)
            if event.phase ~= "began" then return false end

            local p = propsRef.current
            local id = event.id

            -- Palm rejection
            local maxFingers = p.maxFingers or 5
            local activeCount = 0
            for _ in pairs(activeRef.current) do activeCount = activeCount + 1 end
            if activeCount >= maxFingers then return true end
            -- canFocus check
            if not TouchRegistry.canFocus(id, view) then return true end

            TouchRegistry.claim(id, view)

            local lx, ly = surface:contentToLocal(event.x, event.y)

            -- Parse brush color
            local color = p.brushColor or "#000000"
            local size = p.brushSize or 4
            local r, g, b, a = 0, 0, 0, 1
            if type(color) == "string" and color:sub(1, 1) == "#" then
                local hex = color:sub(2)
                r = (tonumber(hex:sub(1, 2), 16) or 0) / 255
                g = (tonumber(hex:sub(3, 4), 16) or 0) / 255
                b = (tonumber(hex:sub(5, 6), 16) or 0) / 255
                a = #hex >= 8 and ((tonumber(hex:sub(7, 8), 16) or 255) / 255) or 1
            elseif type(color) == "table" then
                r, g, b, a = color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1
            end

            -- lx + 0.1: Solar2D requires two distinct points to create a line;
            -- without this offset a single-tap produces no visible object.
            local line = display.newLine(surface, lx, ly, lx + 0.1, ly)
            line:setStrokeColor(r, g, b, a)
            line.strokeWidth = size

            -- TrackDot: invisible proxy so setFocus is per-dot (not shared hitRect).
            -- This is critical for multi-finger: setFocus(hitRect, id) for multiple
            -- ids on the same object is unreliable in Solar2D.
            local dot = display.newCircle(event.x, event.y, 1)
            dot.isVisible = false
            dot.isHitTestable = true
            dot:addEventListener("touch", handleDotEvent)
            display.getCurrentStage():setFocus(dot, id)

            activeRef.current[id] = {
                line = line,
                lastX = lx,
                lastY = ly,
                dot = dot,
                dotListener = handleDotEvent,
            }

            -- Enforce maxStrokes limit
            local strokes = strokesRef.current
            strokes[#strokes + 1] = line
            local maxStrokes = p.maxStrokes or 200
            while #strokes > maxStrokes do
                local old = table.remove(strokes, 1)
                local inUse = false
                for _, state in pairs(activeRef.current) do
                    if state.line == old then inUse = true; break end
                end
                if not inUse and old and old.removeSelf then old:removeSelf() end
            end

            if p.onStrokeStart then
                p.onStrokeStart({ id = id, x = lx, y = ly })
            end
            return true
        end

        hitRect:addEventListener("touch", onHitTouch)

        return function()
            -- Cleanup sweep: remove all TrackDots + release focus + registry
            for fid in pairs(activeRef.current) do
                removeDot(fid)
            end
            hitRect:removeEventListener("touch", onHitTouch)
            if surface and surface.removeSelf then
                surface:removeSelf()
            end
            surfaceRef.current = nil
            activeRef.current = {}
            strokesRef.current = {}
        end
    end, {})

    -- Expose clear() via imperative handle pattern on the view ref
    React.useEffect(function()
        local view = viewRef.current
        if not view then return end
        view.clearStrokes = function()
            local strokes = strokesRef.current
            for i = #strokes, 1, -1 do
                local s = strokes[i]
                if s and s.removeSelf then s:removeSelf() end
            end
            strokesRef.current = {}
            -- Also clean up any active dots
            for fid in pairs(activeRef.current) do
                local state = activeRef.current[fid]
                if state and state.dot then
                    display.getCurrentStage():setFocus(nil, fid)
                    TouchRegistry.release(fid, viewRef.current)
                    state.dot:removeEventListener("touch", state.dotListener)
                    state.dot:removeSelf()
                end
            end
            activeRef.current = {}
        end
    end, {})

    return ce("View", {
        ref = onRef,
        style = props.style,
    }, props.children)
end)

return DrawingCanvas
