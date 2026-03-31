--- Joystick component.
-- Virtual joystick with circular bounds and snap-back.
-- Reports normalized [-1, 1] values for both axes.
-- Uses TrackDot pattern for reliable touch on real devices.
-- @module components.Joystick

local React = require("react")
local ce = React.createElement
local TouchRegistry = require("lib.TouchRegistry")

--- Joystick component.
-- @param props table
--   size number             Outer ring diameter (default 120)
--   thumbSize number        Inner thumb diameter (default 40)
--   onMove function         Called with {x, y} normalized to [-1, 1]
--   onRelease function      Called when thumb returns to center
--   style table             Additional style for outer ring
--   thumbStyle table        Additional style for thumb
--   ringColor string        Outer ring color (default "rgba(255,255,255,0.15)")
--   thumbColor string       Thumb color (default "#58A6FF")
--   disabled boolean
-- @return table React element
local function Joystick(props)
    local viewRef = React.useRef(nil)
    local thumbRef = React.useRef(nil)
    local propsRef = React.useRef({})
    propsRef.current = props

    local size = props.size or 120
    local thumbSize = props.thumbSize or 40
    local radius = (size - thumbSize) / 2

    local onViewRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    local onThumbRef = React.useCallback(function(instance)
        thumbRef.current = instance
    end, {})

    React.useEffect(function()
        local view = viewRef.current
        local thumb = thumbRef.current
        if not view or not thumb then return end

        local touchId = nil
        local startX, startY = nil, nil  -- touch began position (content coords)
        local restX, restY = nil, nil    -- thumb rest position (local coords)
        local dot = nil

        -- Thumb position is always under our control (not Yoga).
        -- Capture Yoga's initial center position, then take over.
        restX = thumb.x
        restY = thumb.y
        thumb._directManipulation = true

        local function cleanupDot()
            if dot then
                dot:removeEventListener("touch", dot._listener)
                dot:removeSelf()
                dot = nil
            end
        end

        local function handleEnd(id)
            if touchId ~= id then return end
            TouchRegistry.release(id, view)
            display.getCurrentStage():setFocus(nil, id)
            cleanupDot()
            touchId = nil

            -- Snap back to center
            if restX and restY then
                transition.to(thumb, {
                    time = 120,
                    x = restX,
                    y = restY,
                    transition = easing.outQuad,
                })
            end

            local p = propsRef.current
            if p.onRelease then p.onRelease() end
            if p.onMove then p.onMove({ x = 0, y = 0 }) end
        end

        local function handleMove(event)
            if touchId ~= event.id then return end
            if not startX or not restX then return end

            local dx = event.x - startX
            local dy = event.y - startY

            -- Circular clamp
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > radius then
                dx = dx * radius / dist
                dy = dy * radius / dist
                dist = radius
            end

            -- Move thumb (direct manipulation, thumb is inside a flex layout
            -- but we override its position)
            thumb.x = restX + dx
            thumb.y = restY + dy

            -- Report normalized values
            local p = propsRef.current
            if p.onMove then
                local nx = radius > 0 and (dx / radius) or 0
                local ny = radius > 0 and (dy / radius) or 0
                p.onMove({ x = nx, y = ny })
            end
        end

        local function dotListener(e)
            if e.id ~= touchId then return true end
            if e.phase == "moved" then
                dot.x = e.x
                dot.y = e.y
                handleMove(e)
            elseif e.phase == "ended" or e.phase == "cancelled" then
                handleEnd(e.id)
            end
            return true
        end

        local function onTouch(event)
            if event.phase ~= "began" then return false end
            local p = propsRef.current
            if p.disabled then return false end
            if touchId ~= nil then return true end
            if not TouchRegistry.canFocus(event.id, view) then return false end

            touchId = event.id
            TouchRegistry.claim(event.id, view)
            startX = event.x
            startY = event.y

            -- Cancel any snap-back animation in progress
            transition.cancel(thumb)
            thumb.x = restX
            thumb.y = restY

            -- TrackDot for reliable per-finger focus
            dot = display.newCircle(event.x, event.y, 1)
            dot.isVisible = false
            dot.isHitTestable = true
            dot._listener = dotListener
            dot:addEventListener("touch", dotListener)
            display.getCurrentStage():setFocus(dot, event.id)

            return true
        end

        -- Listen on the background rect of the outer view
        if view._bg then
            view._bg:addEventListener("touch", onTouch)
        end

        return function()
            if touchId then
                display.getCurrentStage():setFocus(nil, touchId)
                TouchRegistry.release(touchId, view)
                touchId = nil
            end
            cleanupDot()
            transition.cancel(thumb)
            if view._bg then
                view._bg:removeEventListener("touch", onTouch)
            end
        end
    end, {})

    local ringColor = props.ringColor or "rgba(255,255,255,0.15)"
    local thumbColor = props.thumbColor or "#58A6FF"

    -- Merge outer style
    local outerStyle = {
        width = size,
        height = size,
        borderRadius = size / 2,
        backgroundColor = ringColor,
        borderWidth = 2,
        borderColor = "rgba(255,255,255,0.3)",
        justifyContent = "center",
        alignItems = "center",
    }
    if props.style then
        for k, v in pairs(props.style) do outerStyle[k] = v end
    end

    -- Thumb style
    local tStyle = {
        width = thumbSize,
        height = thumbSize,
        borderRadius = thumbSize / 2,
        backgroundColor = thumbColor,
        borderWidth = 2,
        borderColor = "#FFF",
    }
    if props.thumbStyle then
        for k, v in pairs(props.thumbStyle) do tStyle[k] = v end
    end

    return ce("View", {
        ref = onViewRef,
        style = outerStyle,
    },
        ce("View", {
            ref = onThumbRef,
            style = tStyle,
        })
    )
end

return Joystick
