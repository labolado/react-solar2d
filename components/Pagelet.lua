-- components/Pagelet.lua
-- React-level scene manager with composer-compatible lifecycle.
-- Unlike SceneCanvas (imperative scenes in Canvas), Pagelet wraps
-- React components with create/show/hide/destroy lifecycle callbacks.
--
-- Usage:
--   ce(Pagelet.Container, { current = "game" },
--       ce(Pagelet, { name = "menu", onShow = function(e) ... end },
--           ce("View", {}, ce("Text", {}, "Menu"))
--       ),
--       ce(Pagelet, { name = "game", onShow = function(e) ... end },
--           ce(SceneCanvas, { scene = boardScene }),
--           ce("View", {}, ce("Text", {}, "Score"))
--       ),
--   )

local React = require("react")
local ce = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local ReactElement = require("react.ReactElement")

-- ============================================================
-- Pagelet: a page with composer-compatible lifecycle
-- ============================================================
local function Pagelet(props)
    local params = props.params
    local mountedRef = useRef(false)

    -- Fire lifecycle on mount/unmount
    useEffect(function()
        local event = { params = params }

        -- Mount: create → show(will) → show(did)
        if props.onCreate then
            event.name = "create"
            props.onCreate(event)
        end
        if props.onShow then
            event.name = "show"
            event.phase = "will"
            props.onShow(event)
            -- "did" after initial render
            event.phase = "did"
            props.onShow(event)
        end
        mountedRef.current = true

        -- Unmount: hide(will) → hide(did) → destroy
        return function()
            local ev = { params = params }
            if props.onHide then
                ev.name = "hide"
                ev.phase = "will"
                props.onHide(ev)
                ev.phase = "did"
                props.onHide(ev)
            end
            if props.onDestroy then
                ev.name = "destroy"
                props.onDestroy(ev)
            end
            mountedRef.current = false
        end
    end, {})

    -- Render children wrapped in a View
    local style = props.style or { flex = 1 }
    local children = props.children
    if children == nil then
        return ce("View", { style = style })
    elseif type(children) == "table" and children["$$typeof"] then
        -- single React element
        return ce("View", { style = style }, children)
    elseif type(children) == "table" then
        -- array of React elements
        return ce("View", { style = style }, unpack(children))
    else
        -- string or other primitive
        return ce("View", { style = style }, children)
    end
end

-- ============================================================
-- Container: manages which Pagelet is active
-- ============================================================
local function Container(props)
    local current = props.current
    local children = props.children
    local style = props.style or { flex = 1 }

    -- Normalize children to array
    local childList = {}
    if children then
        if type(children) == "table" and children["$$typeof"] then
            -- single child element
            childList = { children }
        elseif type(children) == "table" then
            childList = children
        end
    end

    -- Find the Pagelet matching `current`
    local activeChild = nil
    for _, child in ipairs(childList) do
        if type(child) == "table" and child.props and child.props.name == current then
            -- Clone with key to ensure proper mount/unmount on switch
            local clonedProps = {}
            for k, v in pairs(child.props) do
                clonedProps[k] = v
            end
            clonedProps.key = "pagelet:" .. current
            activeChild = ce(child.type, clonedProps)
            break
        end
    end

    if activeChild then
        return ce("View", { style = style }, activeChild)
    end
    return ce("View", { style = style })
end

-- ============================================================
-- Export
-- ============================================================
local M = setmetatable({}, {
    __call = function(_, props)
        return Pagelet(props)
    end,
})
M.Container = Container

return M
