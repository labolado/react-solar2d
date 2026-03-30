--- React hooks implementation.
-- Provides useState, useEffect, useRef, useMemo, useCallback, useContext, useReducer, useId,
-- useImperativeHandle, useDebugValue, and useSyncExternalStore.
-- @module react.Hooks

local M = {}

local currentFiber = nil
local hookIndex = 0
local pendingEffects = {}

--- Set the current fiber for hook execution.
-- @param fiber table Fiber node
function M._setCurrentFiber(fiber)
    currentFiber = fiber
end

--- Reset the hook index for a new render.
function M._resetHookIndex()
    hookIndex = 0
end

--- Finish hook execution and clear current fiber.
function M._finishHooks()
    currentFiber = nil
    hookIndex = 0
end

--- Get and clear pending effect callbacks.
-- @return table List of pending effects
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

--- useState hook — manage component state.
-- @param initialValue any Initial state value
-- @return any Current state value
-- @return function Setter function (accepts value or updater function)
-- @usage
-- local count, setCount = React.useState(0)
-- setCount(count + 1)
-- setCount(function(prev) return prev + 1 end)
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

--- useReducer hook — state management with reducer function.
-- @param reducer function Reducer function (state, action) -> newState
-- @param initialState any Initial state value
-- @return any Current state value
-- @return function Dispatch function
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

--- useRef hook — mutable reference that persists across renders.
-- @param initialValue any Initial ref value
-- @return table Ref object with `current` field
-- @usage
-- local inputRef = React.useRef(nil)
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

--- useMemo hook — cache expensive computation.
-- @param factory function Computation function
-- @param deps table Dependency array
-- @return any Memoized value
function M.useMemo(factory, deps)
    local idx = getHook()
    local hooks = currentFiber._hooks

    if hooks[idx] == nil or depsChanged(hooks[idx].deps, deps) then
        local value = factory()
        hooks[idx] = { value = value, deps = deps }
    end

    return hooks[idx].value
end

--- useCallback hook — cache callback reference.
-- @param callback function Callback to memoize
-- @param deps table Dependency array
-- @return function Memoized callback
function M.useCallback(callback, deps)
    return M.useMemo(function() return callback end, deps)
end

--- useEffect hook — run side effects after render.
-- @param callback function Effect function, may return cleanup function
-- @param[opt] deps table Dependency array (empty = mount only, nil = every render)
-- @usage
-- React.useEffect(function()
--     print("mounted")
--     return function() print("cleanup") end
-- end, {})
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

--- useLayoutEffect hook — run side effects synchronously after render.
-- In Solar2D (single-threaded), same as useEffect but runs synchronously.
-- @param callback function Effect function
-- @param[opt] deps table Dependency array
function M.useLayoutEffect(callback, deps)
    -- In Solar2D (single-threaded), same as useEffect but runs synchronously
    M.useEffect(callback, deps)
end

-- useId: generate unique IDs for accessibility and form associations
local idCounter = 0

--- useId hook — generate stable unique IDs.
-- @return string Unique ID
function M.useId()
    local idx = getHook()
    local hooks = currentFiber._hooks
    
    if hooks[idx] == nil then
        idCounter = idCounter + 1
        -- Generate stable ID per component mount (global counter)
        -- Format: "r:id-{counter}"
        hooks[idx] = "r:id-" .. tostring(idCounter)
    end
    
    return hooks[idx]
end

--- useImperativeHandle hook — customize the instance value exposed via ref.
-- @param ref table Ref object from useRef or forwardRef
-- @param createHandle function Factory returning the handle
-- @param[opt] deps table Dependency array
function M.useImperativeHandle(ref, createHandle, deps)
    local idx = getHook()
    local hooks = currentFiber._hooks
    
    local shouldUpdate = hooks[idx] == nil or depsChanged(hooks[idx].deps, deps)
    
    if shouldUpdate then
        local handle = createHandle()
        hooks[idx] = { handle = handle, deps = deps }
        
        -- Attach to ref.current if provided (standard React ref behavior)
        if ref and type(ref) == "table" then
            ref.current = handle
        end
    end
end

--- useDebugValue hook — display a label for custom hooks in debugging.
-- @param value any Value to display
-- @param[opt] formatFn function Optional formatter function
function M.useDebugValue(value, formatFn)
    -- In Solar2D environment, print for debugging
    -- In production, this could be a no-op
    local displayValue = value
    if formatFn and type(formatFn) == "function" then
        displayValue = formatFn(value)
    end
    -- Only print in debug mode (check for global DEBUG flag)
    if _G.DEBUG then
        print("[useDebugValue] " .. tostring(displayValue))
    end
end

--- useSyncExternalStore hook — subscribe to an external store.
-- @param subscribe function Subscribe function returning unsubscribe
-- @param getSnapshot function Get current snapshot
-- @param[opt] getServerSnapshot function Server snapshot getter
-- @return any Current snapshot
function M.useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)
    local idx = getHook()
    local hooks = currentFiber._hooks
    local fiber = currentFiber
    
    -- Initialize hook state on first render
    if hooks[idx] == nil then
        local snapshot = getSnapshot()
        hooks[idx] = {
            snapshot = snapshot,
            unsubscribe = nil,
            subscribe = nil, -- Track subscribe function reference
        }
    end
    
    local hook = hooks[idx]
    
    -- Only resubscribe if subscribe function changed (not on every render)
    if hooks[idx] == nil or hook.subscribe ~= subscribe then
        -- Unsubscribe from previous subscription if any
        if hook.unsubscribe then
            hook.unsubscribe()
        end
        
        -- Create wrapper that schedules update when store changes
        local function handleStoreChange()
            local newSnapshot = getSnapshot()
            if newSnapshot ~= hook.snapshot then
                hook.snapshot = newSnapshot
                if fiber._scheduleUpdate then
                    fiber._scheduleUpdate(fiber)
                end
            end
        end
        
        hook.subscribe = subscribe
        hook.unsubscribe = subscribe(handleStoreChange)
    end
    
    -- Get current snapshot
    hook.snapshot = getSnapshot()
    
    -- Cleanup subscription when component unmounts
    -- This is handled via a special cleanup mechanism in the reconciler
    if not fiber._storeCleanups then
        fiber._storeCleanups = {}
    end
    fiber._storeCleanups[idx] = hook.unsubscribe
    
    return hook.snapshot
end

-- Context (basic implementation)
local contextCounter = 0

--- createContext — create a React context.
-- @param defaultValue any Default value when no Provider is found
-- @return table Context object with Provider
-- @usage
-- local ThemeContext = React.createContext("light")
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

--- useContext — read value from nearest Provider.
-- @param context table Context created by createContext
-- @return any Current context value
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
