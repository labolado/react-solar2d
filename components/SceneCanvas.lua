-- components/SceneCanvas.lua
-- Wraps ImperativeCanvas to load composer-style scenes
local React = require("react")
local ce = React.createElement
local ImperativeCanvas = require("components.ImperativeCanvas")

local function SceneCanvas(props)
    local scene = props.scene
    local params = props.params

    local onDraw = React.useCallback(function(surface, w, h)
        if not scene then return end

        -- Dispatch create
        scene:dispatchEvent({
            name = "create",
            view = surface,
            params = params,
            width = w,
            height = h,
        })

        -- Dispatch show will
        scene:dispatchEvent({
            name = "show",
            phase = "will",
            view = surface,
            params = params,
            width = w,
            height = h,
        })

        -- Dispatch show did (next frame equivalent — immediate in this context)
        scene:dispatchEvent({
            name = "show",
            phase = "did",
            view = surface,
            params = params,
            width = w,
            height = h,
        })

        -- Cleanup: hide + destroy
        return function()
            scene:dispatchEvent({
                name = "hide",
                phase = "will",
                view = surface,
                params = params,
            })
            scene:dispatchEvent({
                name = "hide",
                phase = "did",
                view = surface,
                params = params,
            })
            scene:dispatchEvent({
                name = "destroy",
                view = surface,
                params = params,
            })
        end
    end, { scene, params })

    return ce(ImperativeCanvas, {
        style = props.style,
        onDraw = onDraw,
        onFrame = props.onFrame,
        clip = props.clip,
        overlay = props.overlay,
    })
end

return SceneCanvas
