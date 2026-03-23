-- react/Reconciler.lua
local ReactElement = require("react.ReactElement")
local FiberNode = require("react.FiberNode")
local Hooks = require("react.Hooks")

local M = {}

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
        if #children > 0 then
            local result = {}
            for _, child in ipairs(children) do
                if type(child) == "table" and #child > 0 and not child["$$typeof"] then
                    for _, c in ipairs(child) do
                        result[#result + 1] = c
                    end
                else
                    result[#result + 1] = child
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
                    if type(elementType) == "function" then
                        tag = "function"
                    elseif type(elementType) == "table" and elementType._isProvider then
                        tag = "function"  -- Provider handled in performUnitOfWork
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
                    if type(elementType) == "function" then
                        tag = "function"
                    elseif type(elementType) == "table" and elementType._isProvider then
                        tag = "function"  -- Provider handled in performUnitOfWork
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

    local function commitDeletion(fiber, parentInstance)
        if fiber.tag == "host" or fiber.tag == "text" then
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

        -- Invoke ref callback with the host instance (after create or update)
        if fiber.ref and type(fiber.ref) == "function" and fiber.stateNode then
            fiber.ref(fiber.stateNode)
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

    function reconciler.render(element, container)
        local oldRoot = rootFiber

        rootFiber = FiberNode.createFiber("root", nil, nil, { children = element })
        rootFiber.stateNode = container
        rootFiber.alternate = oldRoot

        walkFiber(rootFiber)
        commitWork(rootFiber)
        flushEffects()
    end

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

    function reconciler.unmount(container)
        if rootFiber then
            for i = container.numChildren, 1, -1 do
                local child = container[i]
                if child then child:removeSelf() end
            end
            rootFiber = nil
        end
    end

    function reconciler._getRootFiber()
        return rootFiber
    end

    return reconciler
end

return M
