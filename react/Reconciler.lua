--- Fiber reconciler.
-- Creates and updates the component tree, schedules effects, and commits changes to the host.
-- @module react.Reconciler

local ReactElement = require("react.ReactElement")
local FiberNode = require("react.FiberNode")
local Hooks = require("react.Hooks")

local M = {}

local FRAGMENT_TYPE = "$$react.fragment"

-- Shallow equality check for memo props comparison
local function shallowEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if k ~= "children" and b[k] ~= v then return false end
    end
    for k in pairs(b) do
        if k ~= "children" and a[k] == nil then return false end
    end
    return true
end

-- Check if a value is callable (function or table with __call metamethod)
local function isCallable(v)
    if type(v) == "function" then return true end
    if type(v) == "table" then
        local mt = getmetatable(v)
        return mt and type(mt.__call) == "function"
    end
    return false
end

--- Create a reconciler instance bound to a host config.
-- @param hostConfig table Host config with createInstance, updateInstance, appendChild, etc.
-- @return table Reconciler instance with render, flushUpdates, and unmount methods
function M.create(hostConfig)
    local reconciler = {}
    local rootFiber = nil
    local pendingUpdateFibers = {}

    local function scheduleUpdate(fiber)
        local root = fiber
        while root.parent do
            root = root.parent
        end
        table.insert(pendingUpdateFibers, root)
    end

    local function normalizeChildren(children)
        if children == nil then return {} end
        if type(children) ~= "table" or children["$$typeof"] then
            return { children }
        end
        -- Use raw length check that handles nil holes in arrays
        -- (Lua's # operator is unreliable with nil holes, so check rawget)
        local len = rawget(children, 1) ~= nil and #children or 0
        if len == 0 then
            -- Check if it's a sparse array (nil holes, e.g. {nil, elem, elem})
            for i = 1, 64 do
                if rawget(children, i) ~= nil then len = i end
            end
        end
        if len > 0 then
            local result = {}
            for i = 1, len do
                local child = rawget(children, i)
                if child ~= nil then
                    if type(child) == "table" and not child["$$typeof"] and rawget(child, 1) ~= nil then
                        for j = 1, #child do
                            if child[j] ~= nil then
                                result[#result + 1] = child[j]
                            end
                        end
                    else
                        result[#result + 1] = child
                    end
                end
            end
            return result
        end
        return { children }
    end

    local function reconcileChildren(fiber, children)
        local elements = normalizeChildren(children)
        local oldChild = fiber.alternate and fiber.alternate.child
        local prevSibling = nil

        local oldChildren = {}
        local node = oldChild
        while node do
            local key = node.key or (#oldChildren + 1)
            oldChildren[key] = node
            node = node.sibling
        end

        for i, element in ipairs(elements) do
            local newFiber = nil

            if type(element) == "string" or type(element) == "number" then
                local key = i
                local old = oldChildren[key]
                if old and old.tag == "text" then
                    newFiber = FiberNode.createFiber("text", nil, nil, { text = tostring(element) })
                    newFiber.stateNode = old.stateNode
                    newFiber.alternate = old
                    newFiber.effectTag = "UPDATE"
                    oldChildren[key] = nil
                else
                    newFiber = FiberNode.createFiber("text", nil, nil, { text = tostring(element) })
                    newFiber.effectTag = "PLACEMENT"
                end
            elseif type(element) == "table" and element["$$typeof"] then
                local key = element.key or i
                local old = oldChildren[key]
                local elementType = element.type

                if old and old.type == elementType then
                    local tag
                    if isCallable(elementType) then
                        tag = "function"
                    elseif type(elementType) == "table" and elementType._isProvider then
                        tag = "function"  -- Provider handled in performUnitOfWork
                    elseif type(elementType) == "table" and elementType._isForwardRef then
                        tag = "function"  -- forwardRef handled in performUnitOfWork
                    elseif elementType == FRAGMENT_TYPE then
                        tag = "function"  -- Fragment: pass children through
                    elseif type(elementType) == "table" and elementType._isMemo then
                        tag = "function"  -- memo component
                    else
                        tag = "host"
                    end
                    newFiber = FiberNode.createFiber(tag, elementType, element.key, element.props)
                    newFiber.ref = element.ref
                    newFiber.stateNode = old.stateNode
                    newFiber.alternate = old
                    newFiber._hooks = old._hooks
                    newFiber.effectTag = "UPDATE"
                    oldChildren[key] = nil
                else
                    local tag
                    if isCallable(elementType) then
                        tag = "function"
                    elseif type(elementType) == "table" and elementType._isProvider then
                        tag = "function"  -- Provider handled in performUnitOfWork
                    elseif type(elementType) == "table" and elementType._isForwardRef then
                        tag = "function"  -- forwardRef handled in performUnitOfWork
                    elseif elementType == FRAGMENT_TYPE then
                        tag = "function"  -- Fragment: pass children through
                    elseif type(elementType) == "table" and elementType._isMemo then
                        tag = "function"  -- memo component
                    else
                        tag = "host"
                    end
                    newFiber = FiberNode.createFiber(tag, elementType, element.key, element.props)
                    newFiber.ref = element.ref
                    newFiber.effectTag = "PLACEMENT"
                    if old then
                        old.effectTag = "DELETION"
                        table.insert(fiber.effects, old)
                        oldChildren[key] = nil
                    end
                end
            end

            if newFiber then
                newFiber.parent = fiber
                newFiber._scheduleUpdate = scheduleUpdate

                if i == 1 then
                    fiber.child = newFiber
                else
                    if prevSibling then
                        prevSibling.sibling = newFiber
                    end
                end
                prevSibling = newFiber
            end
        end

        for _, old in pairs(oldChildren) do
            old.effectTag = "DELETION"
            table.insert(fiber.effects, old)
        end
    end

    local function performUnitOfWork(fiber)
        if fiber.tag == "function" then
            Hooks._setCurrentFiber(fiber)
            Hooks._resetHookIndex()
            fiber._scheduleUpdate = scheduleUpdate

            local elementType = fiber.type
            if type(elementType) == "table" and elementType._isProvider then
                -- Context.Provider — store value on fiber for useContext
                local contextId = elementType._contextId
                local parentCtx = {}
                local p = fiber.parent
                while p do
                    if p._contextValues then
                        for k, v in pairs(p._contextValues) do
                            if parentCtx[k] == nil then parentCtx[k] = v end
                        end
                    end
                    p = p.parent
                end
                parentCtx[contextId] = fiber.props.value
                fiber._contextValues = parentCtx
                Hooks._finishHooks()
                reconcileChildren(fiber, fiber.props.children)
            elseif type(elementType) == "table" and elementType._isForwardRef then
                -- forwardRef component — pass ref to render function
                local children = elementType.render(fiber.props, fiber.ref)
                Hooks._finishHooks()
                reconcileChildren(fiber, children)
            elseif elementType == FRAGMENT_TYPE then
                -- Fragment — just pass children through, no host node created
                Hooks._finishHooks()
                reconcileChildren(fiber, fiber.props.children)
            elseif type(elementType) == "table" and elementType._isMemo then
                -- React.memo — skip re-render if props haven't changed
                local oldProps = fiber.alternate and fiber.alternate.props
                local equal = false
                if oldProps then
                    if elementType.areEqual then
                        equal = elementType.areEqual(oldProps, fiber.props)
                    else
                        equal = shallowEqual(oldProps, fiber.props)
                    end
                end
                if equal and fiber.alternate then
                    -- Props unchanged — reuse old children
                    Hooks._finishHooks()
                    fiber.child = fiber.alternate.child
                    -- Re-parent old children to new fiber
                    local c = fiber.child
                    while c do
                        c.parent = fiber
                        c = c.sibling
                    end
                else
                    -- Props changed — re-render the wrapped component
                    local children = elementType.component(fiber.props)
                    Hooks._finishHooks()
                    reconcileChildren(fiber, children)
                end
            else
                local children = fiber.type(fiber.props)
                Hooks._finishHooks()
                reconcileChildren(fiber, children)
            end
        elseif fiber.tag == "host" then
            if not fiber.stateNode then
                fiber.stateNode = hostConfig.createInstance(fiber.type, fiber.props)
            end
            -- Text elements are leaf nodes: content handled via props.children in createInstance
            if fiber.type ~= "Text" then
                reconcileChildren(fiber, fiber.props.children)
            end
        elseif fiber.tag == "text" then
            if not fiber.stateNode then
                fiber.stateNode = hostConfig.createTextInstance(fiber.props.text)
            end
        elseif fiber.tag == "root" then
            reconcileChildren(fiber, fiber.props.children)
        end
    end

    local function walkFiber(fiber)
        performUnitOfWork(fiber)
        local child = fiber.child
        while child do
            walkFiber(child)
            child = child.sibling
        end
    end

    -- Clean up a single fiber's hooks (useEffect cleanup) and subscriptions
    local function cleanupFiber(fiber)
        -- useEffect / useLayoutEffect cleanup
        if fiber._hooks then
            for _, hook in ipairs(fiber._hooks) do
                if type(hook) == "table" and type(hook.cleanup) == "function" then
                    hook.cleanup()
                    hook.cleanup = nil
                end
            end
        end
        -- useSyncExternalStore cleanup
        if fiber._storeCleanups then
            for _, cleanup in pairs(fiber._storeCleanups) do
                if type(cleanup) == "function" then cleanup() end
            end
            fiber._storeCleanups = nil
        end
        -- ref cleanup
        if fiber.ref then
            if type(fiber.ref) == "function" then
                fiber.ref(nil)
            elseif type(fiber.ref) == "table" then
                fiber.ref.current = nil
            end
        end
    end

    local function commitDeletion(fiber, parentInstance)
        -- Clean up this fiber's hooks, subscriptions, and refs
        cleanupFiber(fiber)

        if fiber.tag == "host" or fiber.tag == "text" then
            -- Before removing, recursively clean up all descendant fibers
            local function cleanupDescendants(f)
                local child = f.child
                while child do
                    cleanupFiber(child)
                    cleanupDescendants(child)
                    child = child.sibling
                end
            end
            cleanupDescendants(fiber)

            if fiber.stateNode then
                hostConfig.removeChild(parentInstance, fiber.stateNode)
            end
        else
            local child = fiber.child
            while child do
                commitDeletion(child, parentInstance)
                child = child.sibling
            end
        end
    end

    local function getHostParent(fiber)
        local parent = fiber.parent
        while parent do
            if parent.tag == "host" or parent.tag == "root" then
                return parent.stateNode
            end
            parent = parent.parent
        end
        return nil
    end

    local function commitWork(fiber)
        if not fiber then return end

        for _, deletion in ipairs(fiber.effects) do
            local parentInstance = getHostParent(deletion)
            if parentInstance then
                commitDeletion(deletion, parentInstance)
            end
        end
        fiber.effects = {}

        local parentInstance = getHostParent(fiber)

        if fiber.effectTag == "PLACEMENT" and fiber.stateNode then
            if parentInstance then
                hostConfig.appendChild(parentInstance, fiber.stateNode)
            end
        elseif fiber.effectTag == "UPDATE" then
            if fiber.tag == "host" and fiber.stateNode then
                local oldProps = fiber.alternate and fiber.alternate.props or {}
                hostConfig.updateInstance(fiber.stateNode, oldProps, fiber.props)
            elseif fiber.tag == "text" and fiber.stateNode then
                local oldText = fiber.alternate and fiber.alternate.props.text or ""
                hostConfig.updateTextInstance(fiber.stateNode, oldText, fiber.props.text)
            end
        end

        -- Invoke ref callback or set ref.current (after create or update)
        if fiber.ref and fiber.stateNode then
            if type(fiber.ref) == "function" then
                fiber.ref(fiber.stateNode)
            elseif type(fiber.ref) == "table" then
                fiber.ref.current = fiber.stateNode
            end
        end

        fiber.effectTag = nil

        local child = fiber.child
        while child do
            commitWork(child)
            child = child.sibling
        end
    end

    local function flushEffects()
        local effects = Hooks._getPendingEffects()
        for _, effect in ipairs(effects) do
            if effect.prevCleanup then
                effect.prevCleanup()
            end
            local cleanup = effect.callback()
            if type(cleanup) == "function" then
                effect.hookRef.cleanup = cleanup
            end
        end
    end

    --- Render an element into a container.
    -- @param element table React element tree
    -- @param container table Solar2D display group
    function reconciler.render(element, container)
        local oldRoot = rootFiber

        rootFiber = FiberNode.createFiber("root", nil, nil, { children = element })
        rootFiber.stateNode = container
        rootFiber.alternate = oldRoot

        walkFiber(rootFiber)
        commitWork(rootFiber)
        flushEffects()
    end

    --- Flush pending state updates and re-render.
    -- @return boolean True if updates were processed
    function reconciler.flushUpdates()
        if #pendingUpdateFibers == 0 then return false end
        pendingUpdateFibers = {}

        local element = rootFiber.props.children
        local container = rootFiber.stateNode
        local oldRoot = rootFiber

        rootFiber = FiberNode.createFiber("root", nil, nil, { children = element })
        rootFiber.stateNode = container
        rootFiber.alternate = oldRoot

        walkFiber(rootFiber)
        commitWork(rootFiber)
        flushEffects()
        return true
    end

    --- Unmount the tree and clean up all resources.
    -- @param container table Solar2D display group
    function reconciler.unmount(container)
        if rootFiber then
            -- Walk the entire fiber tree and clean up hooks, refs, subscriptions
            local function unmountFiber(fiber)
                if not fiber then return end
                cleanupFiber(fiber)
                unmountFiber(fiber.child)
                unmountFiber(fiber.sibling)
            end
            unmountFiber(rootFiber)

            -- Remove display objects
            for i = container.numChildren, 1, -1 do
                local child = container[i]
                if child then child:removeSelf() end
            end
            rootFiber = nil
        end
    end

    --- Get the current root fiber (for testing/debugging).
    -- @return table Root fiber node
    function reconciler._getRootFiber()
        return rootFiber
    end

    return reconciler
end

return M
