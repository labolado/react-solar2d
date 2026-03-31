--- DrawingCanvas component.
-- Multi-finger drawing surface. Each finger draws an independent stroke.
-- Uses display.newLine + :append() for real-time rendering at 60fps.
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
--   clip boolean        Clip drawing to bounds via Container (default false)
-- @return table React element
local function DrawingCanvas(props)
    local viewRef = React.useRef(nil)
    local surfaceRef = React.useRef(nil)    -- display group holding all strokes
    local activeRef = React.useRef({})      -- activeRef.current[id] = {line, lastX, lastY}
    local strokesRef = React.useRef({})     -- ordered list of all stroke display objects

    local onRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    -- propsRef avoids stale closures in event handlers
    local propsRef = React.useRef({})
    propsRef.current = props

    React.useEffect(function()
        local view = viewRef.current
        if not view then return end

        local style = propsRef.current.style or {}
        local w = style.width or display.contentWidth
        local h = style.height or display.contentHeight

        -- Drawing surface group (inserted below any React children)
        local surface = display.newGroup()
        view:insert(surface)
        surface:toBack()
        if view._bg then view._bg:toBack() end
        surfaceRef.current = surface

        -- Transparent hit rect the size of the canvas
        local hitRect = display.newRect(surface, w / 2, h / 2, w, h)
        hitRect.anchorX, hitRect.anchorY = 0.5, 0.5
        hitRect:setFillColor(0, 0, 0, 0.001)
        hitRect.isHitTestable = true

        local function onTouch(event)
            local p = propsRef.current
            local phase = event.phase
            local id = event.id
            local ex, ey = event.x, event.y

            -- Convert screen coords to surface-local coords
            local lx, ly = surface:contentToLocal(ex, ey)

            if phase == "began" then
                -- Palm rejection: ignore additional fingers beyond maxFingers
                local maxFingers = p.maxFingers or 5
                local activeCount = 0
                for _ in pairs(activeRef.current) do activeCount = activeCount + 1 end
                if activeCount >= maxFingers then return true end
                -- canFocus: another component may already own this finger
                if not TouchRegistry.canFocus(id, hitRect) then return true end

                TouchRegistry.claim(id, hitRect)
                display.getCurrentStage():setFocus(hitRect, id)

                local color = p.brushColor or "#000000"
                local size = p.brushSize or 4

                -- Parse color string into r,g,b,a
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

                -- lx + 0.1: Solar2D requires two distinct points to create a line object;
                -- without this offset a single-tap produces no visible object.
                local line = display.newLine(surface, lx, ly, lx + 0.1, ly)
                line:setStrokeColor(r, g, b, a)
                line.strokeWidth = size

                activeRef.current[id] = { line = line, lastX = lx, lastY = ly }

                -- Track strokes; enforce maxStrokes limit
                local strokes = strokesRef.current
                strokes[#strokes + 1] = line
                local maxStrokes = p.maxStrokes or 200
                while #strokes > maxStrokes do
                    local old = table.remove(strokes, 1)
                    -- Only remove if the stroke is not still being drawn by an active finger
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

            elseif phase == "moved" then
                local state = activeRef.current[id]
                if not state then return true end
                state.line:append(lx, ly)
                state.lastX = lx
                state.lastY = ly
                return true

            elseif phase == "ended" or phase == "cancelled" then
                display.getCurrentStage():setFocus(nil, id)
                TouchRegistry.release(id, hitRect)
                if activeRef.current[id] then
                    activeRef.current[id] = nil
                end
                if propsRef.current.onStrokeEnd then
                    propsRef.current.onStrokeEnd({ id = id })
                end
                return true
            end
            return false
        end

        hitRect:addEventListener("touch", onTouch)

        return function()
            -- Cleanup sweep: release all finger focuses + registry
            for fid in pairs(activeRef.current) do
                display.getCurrentStage():setFocus(nil, fid)
                TouchRegistry.release(fid, hitRect)
            end
            hitRect:removeEventListener("touch", onTouch)
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
            activeRef.current = {}
        end
    end, {})

    return ce("View", {
        ref = onRef,
        style = props.style,
    }, props.children)
end

return DrawingCanvas
