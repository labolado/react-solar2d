-- react/Hooks.lua
local M = {}

local currentFiber = nil
local hookIndex = 0
local pendingEffects = {}

function M._setCurrentFiber(fiber)
    currentFiber = fiber
end

function M._resetHookIndex()
    hookIndex = 0
end

function M._finishHooks()
    currentFiber = nil
    hookIndex = 0
end

function M._getPendingEffects()
    local effects = pendingEffects
    pendingEffects = {}
    return effects
end

-- Internal: get or create hook state at current index
local function getHook()
    hookIndex = hookIndex + 1
    if not currentFiber._hooks then
        currentFiber._hooks = {}
    end
    return hookIndex
end

---@return value, setter
function M.useState(initialValue)
    local idx = getHook()
    local hooks = currentFiber._hooks

    -- Initialize on first render
    if hooks[idx] == nil then
        hooks[idx] = { state = initialValue, queue = {}, queueLen = 0 }
    end

    local hook = hooks[idx]

    -- Process queued updates (values wrapped in {v=...} to handle nil)
    for i = 1, hook.queueLen or 0 do
        local entry = hook.queue[i]
        if entry and type(entry.v) == "function" then
            hook.state = entry.v(hook.state)
        elseif entry then
            hook.state = entry.v
        end
    end
    hook.queue = {}
    hook.queueLen = 0

    local fiber = currentFiber
    local function setState(newValue)
        -- Wrap in table to support nil values (table.insert ignores nil)
        local len = (hook.queueLen or 0) + 1
        hook.queue[len] = { v = newValue }
        hook.queueLen = len
        -- Schedule re-render (reconciler will call this)
        if fiber._scheduleUpdate then
            fiber._scheduleUpdate(fiber)
        end
    end

    return hook.state, setState
end

function M.useReducer(reducer, initialState)
    local idx = getHook()
    local hooks = currentFiber._hooks

    if hooks[idx] == nil then
        hooks[idx] = { state = initialState, queue = {}, queueLen = 0 }
    end

    local hook = hooks[idx]

    for i = 1, hook.queueLen or 0 do
        local entry = hook.queue[i]
        if entry then
            hook.state = reducer(hook.state, entry.v)
        end
    end
    hook.queue = {}
    hook.queueLen = 0

    local fiber = currentFiber
    local function dispatch(action)
        local len = (hook.queueLen or 0) + 1
        hook.queue[len] = { v = action }
        hook.queueLen = len
        if fiber._scheduleUpdate then
            fiber._scheduleUpdate(fiber)
        end
    end

    return hook.state, dispatch
end

function M.useRef(initialValue)
    local idx = getHook()
    local hooks = currentFiber._hooks

    if hooks[idx] == nil then
        hooks[idx] = { current = initialValue }
    end

    return hooks[idx]
end

-- Deps comparison
local function depsChanged(prevDeps, nextDeps)
    if prevDeps == nil then return true end
    if #prevDeps ~= #nextDeps then return true end
    for i = 1, #nextDeps do
        if prevDeps[i] ~= nextDeps[i] then return true end
    end
    return false
end

function M.useMemo(factory, deps)
    local idx = getHook()
    local hooks = currentFiber._hooks

    if hooks[idx] == nil or depsChanged(hooks[idx].deps, deps) then
        local value = factory()
        hooks[idx] = { value = value, deps = deps }
    end

    return hooks[idx].value
end

function M.useCallback(callback, deps)
    return M.useMemo(function() return callback end, deps)
end

function M.useEffect(callback, deps)
    local idx = getHook()
    local hooks = currentFiber._hooks

    local shouldRun = hooks[idx] == nil or depsChanged(hooks[idx].deps, deps)

    if shouldRun then
        local prevCleanup = hooks[idx] and hooks[idx].cleanup
        hooks[idx] = { deps = deps, cleanup = nil }
        table.insert(pendingEffects, {
            callback = callback,
            hookRef = hooks[idx],
            prevCleanup = prevCleanup,
        })
    end
end

function M.useLayoutEffect(callback, deps)
    -- In Solar2D (single-threaded), same as useEffect but runs synchronously
    M.useEffect(callback, deps)
end

-- Context (basic implementation)
local contextCounter = 0

function M.createContext(defaultValue)
    contextCounter = contextCounter + 1
    local id = contextCounter
    local context = {
        _id = id,
        _defaultValue = defaultValue,
    }
    context.Provider = {
        _isProvider = true,
        _contextId = id,
    }
    return context
end

function M.useContext(context)
    -- Walk up fiber tree to find Provider
    local fiber = currentFiber
    while fiber do
        if fiber._contextValues and fiber._contextValues[context._id] ~= nil then
            return fiber._contextValues[context._id]
        end
        fiber = fiber.parent
    end
    return context._defaultValue
end

return M
