--- Portal component.
-- Portal system for rendering content outside the parent tree.
-- Used by Modal to render above navigation bars.
-- @module components.Portal

local React = require("react")
local useState = React.useState
local useEffect = React.useEffect
local createContext = React.createContext

-- Global registry for portals
local portalRegistry = {}
local listeners = {}

local function notifyListeners()
    for _, fn in ipairs(listeners) do
        fn()
    end
end

--- Portal context.
-- @field register function(id, content)
-- @field unregister function(id)
-- @field getAll function() -> table
-- @field subscribe function(fn) -> unsubscribe function
local PortalContext = createContext({
    register = function(id, content)
        portalRegistry[id] = content
        notifyListeners()
    end,
    unregister = function(id)
        portalRegistry[id] = nil
        notifyListeners()
    end,
    getAll = function()
        return portalRegistry
    end,
    subscribe = function(fn)
        table.insert(listeners, fn)
        return function()
            for i, f in ipairs(listeners) do
                if f == fn then
                    table.remove(listeners, i)
                    break
                end
            end
        end
    end
})

--- PortalHost renders all registered portals at root level.
-- @param props table
-- @return table React element
local function PortalHost(props)
    local portals, setPortals = useState({})

    useEffect(function()
        local unsubscribe = PortalContext._currentValue.subscribe(function()
            local all = PortalContext._currentValue.getAll()
            local list = {}
            for id, content in pairs(all) do
                table.insert(list, { id = id, content = content })
            end
            setPortals(list)
        end)
        return unsubscribe
    end, {})

    local children = {}
    for _, p in ipairs(portals) do
        table.insert(children, React.createElement("View", {
            key = p.id,
            style = { position = "absolute", top = 0, left = 0, width = display.contentWidth, height = display.contentHeight }
        }, p.content))
    end

    return React.createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = display.contentWidth,
            height = display.contentHeight,
            zIndex = 99999,
        }
    }, children)
end

--- Portal sends content to PortalHost.
-- @param props table {id, children}
-- @return nil
local function Portal(props)
    local id = props.id or "default"

    useEffect(function()
        PortalContext._currentValue.register(id, props.children)
        return function()
            PortalContext._currentValue.unregister(id)
        end
    end, { props.children })

    return nil
end

return {
    Portal = Portal,
    PortalHost = PortalHost,
    PortalContext = PortalContext
}
