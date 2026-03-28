-- components/ImperativeCanvas.lua
-- Bridge component to embed imperative Solar2D rendering within React tree
local React = require("react")
local ce = React.createElement

local function ImperativeCanvas(props)
    local surfaceRef = React.useRef(nil)
    local viewRef = React.useRef(nil)
    local cleanupRef = React.useRef(nil)

    -- propsRef: always holds latest props, avoids stale closures in onFrame
    local propsRef = React.useRef({})
    propsRef.current = props

    local onViewRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    -- Create surface on mount
    React.useEffect(function()
        local view = viewRef.current
        if not view then return end

        local style = propsRef.current.style or {}
        local w = style.width or 0
        local h = style.height or 0
        local clip = propsRef.current.clip
        local overlay = propsRef.current.overlay

        local surface, drawTarget
        if clip then
            -- Container clips children to bounds; uses center-origin internally
            surface = display.newContainer(w, h)
            surface.anchorX, surface.anchorY = 0, 0
            surface.anchorChildren = false
            -- Offset group for top-left coordinate system
            local inner = display.newGroup()
            inner.x = -w / 2
            inner.y = -h / 2
            surface:insert(inner)
            drawTarget = inner
        else
            surface = display.newGroup()
            drawTarget = surface
        end

        view:insert(surface)
        if not overlay then
            surface:toBack()
            if view._bg then view._bg:toBack() end
        end
        surfaceRef.current = surface

        -- Call onDraw with drawTarget (top-left coords) and propsRef
        if propsRef.current.onDraw then
            cleanupRef.current = propsRef.current.onDraw(drawTarget, w, h, propsRef)
        end

        -- enterFrame for onFrame — reads from propsRef to avoid stale closures
        local onFrameListener
        if propsRef.current.onFrame then
            local lastTime = nil
            onFrameListener = function(event)
                local now = event.time
                local dt = lastTime and (now - lastTime) / 1000 or 0
                lastTime = now
                if dt > 0 and dt < 0.5 then
                    local currentOnFrame = propsRef.current.onFrame
                    if currentOnFrame then
                        currentOnFrame(drawTarget, dt)
                    end
                end
            end
            Runtime:addEventListener("enterFrame", onFrameListener)
        end

        return function()
            if cleanupRef.current then cleanupRef.current() end
            if onFrameListener then Runtime:removeEventListener("enterFrame", onFrameListener) end
            if surface and surface.removeSelf then surface:removeSelf() end
            surfaceRef.current = nil
        end
    end, {})

    -- Handle resize
    React.useEffect(function()
        if not props.onResize then return end
        local surface = surfaceRef.current
        if not surface then return end
        local style = props.style or {}
        local w = style.width or 0
        local h = style.height or 0
        props.onResize(surface, w, h)
    end, { props.style and props.style.width, props.style and props.style.height })

    -- Pass children through
    local children = props.children
    if children and type(children) == "table" and #children > 0 then
        return ce("View", {
            style = props.style,
            ref = onViewRef,
        }, unpack(children))
    else
        return ce("View", {
            style = props.style,
            ref = onViewRef,
        })
    end
end

return ImperativeCanvas
