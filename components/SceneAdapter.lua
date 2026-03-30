--- SceneAdapter module.
-- Composer-compatible scene shim for use with SceneCanvas.
-- @module components.SceneAdapter

local M = {}

--- Create a new composer-compatible scene.
-- @return table Scene object with addEventListener and dispatchEvent methods
function M.newScene()
    local scene = {}
    scene._listeners = {}

    function scene:addEventListener(name, obj)
        self._listeners[name] = obj
    end

    function scene:dispatchEvent(event)
        local listener = self._listeners[event.name]
        if not listener then return end
        if type(listener) == "table" and type(listener[event.name]) == "function" then
            listener[event.name](listener, event)
        elseif type(listener) == "function" then
            listener(event)
        end
    end

    return scene
end

return M
