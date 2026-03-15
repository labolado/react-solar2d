# React-Solar2D Implementation Plan

> **Version:** 1.1 | **Date:** 2026-03-15 | **Status:** Active

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a React Native-compatible UI framework for Solar2D in pure Lua 5.1, enabling AI-generated RN code to run natively on 55+ labo_* children's apps.

**Architecture:** Simplified React core (createElement + synchronous reconciler + hooks) with Solar2D host renderer, **full CSS Flexbox engine** (ported from ReactJIT's layout.lua, 2500+ LOC), StyleSheet system, and RN-compatible component library. Uses react-lua's API surface but simplified internals (no Fiber time-slicing — unnecessary for UI overlays).

**Tech Stack:** Lua 5.1, Solar2D (Corona SDK), react-lua (API reference), ReactJIT layout.lua (Flexbox source)

---

## File Structure

```
react-solar2d/
├── react/
│   ├── init.lua                 -- Module entry: exports createElement, hooks, createContext
│   ├── ReactElement.lua         -- Element type, createElement, isValidElement
│   ├── Hooks.lua                -- useState, useEffect, useRef, useMemo, useCallback, useContext, useReducer
│   ├── Reconciler.lua           -- Synchronous tree diff + commit (simplified Fiber)
│   └── FiberNode.lua            -- Node structure: type, props, state, children, stateQueue
├── renderer/
│   ├── init.lua                 -- ReactSolar2D.render(element, container)
│   └── HostConfig.lua           -- createInstance, updateProps, appendChild, removeChild, commitUpdate
├── layout/
│   ├── init.lua                 -- Layout entry: exports calculateLayout, LayoutNode
│   ├── LayoutNode.lua           -- Node with full CSS style properties + measurement callback
│   ├── FlexAlgorithm.lua        -- Full CSS Flexbox engine (ported from ReactJIT layout.lua)
│   │                            -- 3-phase: intrinsic sizing → flex distribution → constraint clamping
│   │                            -- Supports: wrap, shrink, grow, min/max, aspect-ratio, auto margins
│   ├── FlexLine.lua             -- Line-based wrapping: collect items into lines, per-line layout
│   ├── Measurement.lua          -- Platform measurement callbacks (text size, image dimensions)
│   └── Enums.lua                -- FlexDirection, JustifyContent, AlignItems, AlignContent, etc.
├── style/
│   ├── init.lua                 -- Style module entry
│   ├── StyleSheet.lua           -- StyleSheet.create(), flatten, compose
│   └── processColor.lua         -- "#FF0000" → {1, 0, 0, 1}, "red" → {1, 0, 0, 1}
├── components/
│   ├── View.lua                 -- Group + Rect, overflow:hidden → Container
│   ├── Text.lua                 -- display.newText wrapper
│   ├── Image.lua                -- display.newImageRect wrapper
│   ├── Button.lua               -- Pressable + Text
│   ├── TouchableOpacity.lua     -- Touch with opacity feedback
│   ├── ScrollView.lua           -- Touch-based scrolling container
│   ├── FlatList.lua             -- Virtualized list with renderItem
│   ├── TextInput.lua            -- native.newTextField wrapper
│   └── Modal.lua                -- Overlay with touch blocker
├── animated/
│   ├── AnimatedValue.lua        -- Animated.Value with listeners
│   ├── AnimatedTiming.lua       -- Animated.timing() → transition.to
│   └── AnimatedView.lua         -- createAnimatedComponent wrapper
├── tests/
│   ├── helpers/
│   │   ├── mock_display.lua     -- Mock Solar2D display.* API
│   │   └── test_runner.lua      -- Minimal test harness (assert-based)
│   ├── react/
│   │   ├── test_createElement.lua
│   │   ├── test_hooks.lua
│   │   └── test_reconciler.lua
│   ├── layout/
│   │   └── test_flexbox.lua
│   ├── style/
│   │   ├── test_processColor.lua
│   │   └── test_stylesheet.lua
│   ├── renderer/
│   │   └── test_hostConfig.lua
│   └── components/
│       ├── test_view.lua
│       └── test_text.lua
└── examples/
    ├── main.lua                 -- Solar2D entry, scene picker
    ├── HelloWorld.lua           -- Minimal render test
    ├── Counter.lua              -- useState demo
    ├── TodoList.lua             -- List + state management
    └── FlexboxDemo.lua          -- Layout showcase
```

---

## Chunk 1: Test Infrastructure + React Core

### Task 1.1: Test Harness

**Files:**
- Create: `tests/helpers/test_runner.lua`
- Create: `tests/helpers/mock_display.lua`

- [ ] **Step 1: Create minimal test runner**

```lua
-- tests/helpers/test_runner.lua
local M = {}
M._tests = {}
M._passed = 0
M._failed = 0

function M.describe(name, fn)
    print("\n=== " .. name .. " ===")
    fn()
end

function M.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        M._passed = M._passed + 1
        print("  ✓ " .. name)
    else
        M._failed = M._failed + 1
        print("  ✗ " .. name .. "\n    " .. tostring(err))
    end
end

function M.expect(val)
    return {
        toBe = function(expected)
            if val ~= expected then
                error("Expected " .. tostring(expected) .. " but got " .. tostring(val), 2)
            end
        end,
        toEqual = function(expected)
            -- deep equality for tables
            local function deepEq(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end
                for k, v in pairs(a) do
                    if not deepEq(v, b[k]) then return false end
                end
                for k in pairs(b) do
                    if a[k] == nil then return false end
                end
                return true
            end
            if not deepEq(val, expected) then
                error("Deep equality failed", 2)
            end
        end,
        toBeTruthy = function()
            if not val then error("Expected truthy but got " .. tostring(val), 2) end
        end,
        toBeFalsy = function()
            if val then error("Expected falsy but got " .. tostring(val), 2) end
        end,
        toBeNil = function()
            if val ~= nil then error("Expected nil but got " .. tostring(val), 2) end
        end,
        toBeType = function(t)
            if type(val) ~= t then error("Expected type " .. t .. " but got " .. type(val), 2) end
        end,
    }
end

function M.summary()
    print("\n--- Results: " .. M._passed .. " passed, " .. M._failed .. " failed ---")
    return M._failed == 0
end

return M
```

- [ ] **Step 2: Create mock Solar2D display API**

```lua
-- tests/helpers/mock_display.lua
local M = {}

local nextId = 0
local function newId()
    nextId = nextId + 1
    return nextId
end

local function newDisplayObject(objType)
    local obj = {
        _type = objType,
        _id = newId(),
        _children = {},
        _parent = nil,
        _listeners = {},
        x = 0, y = 0,
        width = 0, height = 0,
        anchorX = 0.5, anchorY = 0.5,
        alpha = 1,
        isVisible = true,
        rotation = 0,
        xScale = 1, yScale = 1,
        _fillColor = {1, 1, 1, 1},
        _strokeColor = {0, 0, 0, 1},
        strokeWidth = 0,
        numChildren = 0,
    }

    function obj:setFillColor(r, g, b, a)
        self._fillColor = {r, g or r, b or r, a or 1}
    end
    function obj:setStrokeColor(r, g, b, a)
        self._strokeColor = {r, g or r, b or r, a or 1}
    end
    function obj:addEventListener(event, fn)
        self._listeners[event] = self._listeners[event] or {}
        table.insert(self._listeners[event], fn)
    end
    function obj:removeEventListener(event, fn)
        local list = self._listeners[event]
        if list then
            for i, f in ipairs(list) do
                if f == fn then table.remove(list, i); break end
            end
        end
    end
    function obj:toFront() end
    function obj:toBack() end
    function obj:removeSelf()
        if self._parent then
            for i, c in ipairs(self._parent._children) do
                if c == self then
                    table.remove(self._parent._children, i)
                    self._parent.numChildren = #self._parent._children
                    break
                end
            end
            self._parent = nil
        end
    end

    -- Group methods
    function obj:insert(indexOrChild, child)
        local c = child or indexOrChild
        if c._parent then c:removeSelf() end
        c._parent = self
        if child then
            table.insert(self._children, indexOrChild, c)
        else
            table.insert(self._children, c)
        end
        self.numChildren = #self._children
    end

    function obj:remove(indexOrChild)
        if type(indexOrChild) == "number" then
            local c = self._children[indexOrChild]
            if c then c._parent = nil end
            table.remove(self._children, indexOrChild)
        else
            indexOrChild:removeSelf()
        end
        self.numChildren = #self._children
    end

    setmetatable(obj, {
        __index = function(t, k)
            if type(k) == "number" then return t._children[k] end
        end
    })

    return obj
end

function M.newGroup()
    return newDisplayObject("group")
end

function M.newRect(parent, x, y, w, h)
    local r = newDisplayObject("rect")
    r.x, r.y, r.width, r.height = x, y, w, h
    r.path = { width = w, height = h }
    if parent then parent:insert(r) end
    return r
end

function M.newRoundedRect(parent, x, y, w, h, cornerRadius)
    local r = M.newRect(parent, x, y, w, h)
    r._type = "roundedRect"
    r._cornerRadius = cornerRadius
    return r
end

function M.newText(options)
    local t = newDisplayObject("text")
    t.text = options.text or ""
    t.size = options.fontSize or 14
    t.x = options.x or 0
    t.y = options.y or 0
    t.width = options.width or 100
    t.height = options.height or 20
    if options.parent then options.parent:insert(t) end
    return t
end

function M.newImage(parent, filename, x, y)
    local img = newDisplayObject("image")
    img._filename = filename
    img.x, img.y = x or 0, y or 0
    if parent then parent:insert(img) end
    return img
end

function M.newImageRect(parent, filename, w, h)
    local img = M.newImage(parent, filename)
    img.width, img.height = w, h
    img.path = { width = w, height = h }
    return img
end

function M.newContainer(parent, w, h)
    local c = newDisplayObject("container")
    c.width, c.height = w, h
    if parent then parent:insert(c) end
    return c
end

function M.resetIdCounter()
    nextId = 0
end

return M
```

- [ ] **Step 3: Verify test harness works**

Run: `cd /path/to/project && lua tests/helpers/test_runner.lua`
(Should load without error)

- [ ] **Step 4: Commit**

```bash
git add tests/
git commit -m "feat: add test harness and mock Solar2D display API"
```

---

### Task 1.2: ReactElement + createElement

**Files:**
- Create: `react/ReactElement.lua`
- Create: `tests/react/test_createElement.lua`

- [ ] **Step 1: Write failing tests for createElement**

```lua
-- tests/react/test_createElement.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local createElement = require("react.ReactElement").createElement

T.describe("createElement", function()
    T.it("creates element with type and props", function()
        local el = createElement("View", { style = { flex = 1 } })
        T.expect(el.type).toBe("View")
        T.expect(el.props.style.flex).toBe(1)
        T.expect(el.props.children).toBeNil()
    end)

    T.it("handles children as third+ args", function()
        local child1 = createElement("Text", nil, "Hello")
        local parent = createElement("View", nil, child1)
        T.expect(parent.props.children).toBe(child1)
    end)

    T.it("handles multiple children as table", function()
        local c1 = createElement("Text", nil, "A")
        local c2 = createElement("Text", nil, "B")
        local parent = createElement("View", nil, c1, c2)
        T.expect(#parent.props.children).toBe(2)
    end)

    T.it("handles string children", function()
        local el = createElement("Text", nil, "Hello World")
        T.expect(el.props.children).toBe("Hello World")
    end)

    T.it("merges children from props and args", function()
        local el = createElement("View", { key = "a" }, "child")
        T.expect(el.props.children).toBe("child")
        T.expect(el.props.key).toBeNil() -- key extracted
        T.expect(el.key).toBe("a")
    end)

    T.it("handles nil props", function()
        local el = createElement("View")
        T.expect(el.type).toBe("View")
        T.expect(type(el.props)).toBe("table")
    end)

    T.it("handles function components", function()
        local function MyComp(props)
            return createElement("View")
        end
        local el = createElement(MyComp, { title = "test" })
        T.expect(el.type).toBe(MyComp)
        T.expect(el.props.title).toBe("test")
    end)
end)

T.summary()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /path/to/project && lua tests/react/test_createElement.lua`
Expected: FAIL (module not found)

- [ ] **Step 3: Implement ReactElement**

```lua
-- react/ReactElement.lua
local M = {}

local REACT_ELEMENT_TYPE = "$$react.element"

function M.createElement(type, config, ...)
    local props = {}
    local key = nil
    local ref = nil

    if config then
        key = config.key
        ref = config.ref
        for k, v in pairs(config) do
            if k ~= "key" and k ~= "ref" and k ~= "__self" and k ~= "__source" then
                props[k] = v
            end
        end
    end

    local childCount = select("#", ...)
    if childCount == 1 then
        props.children = select(1, ...)
    elseif childCount > 1 then
        local children = {}
        for i = 1, childCount do
            children[i] = select(i, ...)
        end
        props.children = children
    end

    return {
        ["$$typeof"] = REACT_ELEMENT_TYPE,
        type = type,
        key = key,
        ref = ref,
        props = props,
    }
end

function M.isValidElement(object)
    return type(object) == "table" and object["$$typeof"] == REACT_ELEMENT_TYPE
end

M.REACT_ELEMENT_TYPE = REACT_ELEMENT_TYPE

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /path/to/project && lua tests/react/test_createElement.lua`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add react/ReactElement.lua tests/react/test_createElement.lua
git commit -m "feat: implement createElement and ReactElement"
```

---

### Task 1.3: FiberNode

**Files:**
- Create: `react/FiberNode.lua`

- [ ] **Step 1: Implement FiberNode**

```lua
-- react/FiberNode.lua
local M = {}

--[[
FiberNode represents a unit of work in the reconciler tree.
Simplified from React's full Fiber — no lanes, no double-buffering.

Fields:
  tag          : "host" | "function" | "class" | "root" | "text"
  type         : string (host) or function (component)
  key          : string or nil
  ref          : table or nil
  props        : table
  stateNode    : Solar2D display object (for host nodes) or nil
  child        : first child FiberNode
  sibling      : next sibling FiberNode
  parent       : parent FiberNode (called "return" in React)
  alternate    : previous fiber for diffing
  memoizedState: first hook in linked list (for function components)
  stateQueue   : pending state updates
  effectTag    : "PLACEMENT" | "UPDATE" | "DELETION" | nil
  effects      : list of effect callbacks to run
]]

function M.createFiber(tag, type, key, props)
    return {
        tag = tag,
        type = type,
        key = key,
        ref = nil,
        props = props or {},
        stateNode = nil,
        child = nil,
        sibling = nil,
        parent = nil,
        alternate = nil,
        memoizedState = nil,
        stateQueue = {},
        effectTag = nil,
        effects = {},
    }
end

function M.createHostRootFiber()
    return M.createFiber("root", nil, nil, {})
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add react/FiberNode.lua
git commit -m "feat: add FiberNode structure"
```

---

### Task 1.4: Hooks — useState, useRef, useMemo, useCallback

**Files:**
- Create: `react/Hooks.lua`
- Create: `tests/react/test_hooks.lua`

- [ ] **Step 1: Write failing tests for hooks**

```lua
-- tests/react/test_hooks.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local Hooks = require("react.Hooks")
local FiberNode = require("react.FiberNode")

-- Helper: simulate rendering a function component with hooks
local function renderWithHooks(fn, props, existingFiber)
    local fiber = existingFiber or FiberNode.createFiber("function", fn, nil, props or {})
    Hooks._setCurrentFiber(fiber)
    Hooks._resetHookIndex()
    local result = fn(props or {})
    Hooks._finishHooks()
    return result, fiber
end

T.describe("useState", function()
    T.it("returns initial value", function()
        local function Comp()
            local val, _ = Hooks.useState(42)
            return val
        end
        local result = renderWithHooks(Comp)
        T.expect(result).toBe(42)
    end)

    T.it("setter updates state on next render", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState(0)
            setSt = set
            return val
        end
        local _, fiber = renderWithHooks(Comp)
        T.expect(_).toBe(0)

        setSt(10)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(10)
    end)

    T.it("functional updater works", function()
        local setSt
        local function Comp()
            local val, set = Hooks.useState(5)
            setSt = set
            return val
        end
        local _, fiber = renderWithHooks(Comp)

        setSt(function(prev) return prev + 1 end)
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(6)
    end)

    T.it("multiple useState hooks work independently", function()
        local function Comp()
            local a, _ = Hooks.useState("hello")
            local b, _ = Hooks.useState(99)
            return a .. tostring(b)
        end
        local result = renderWithHooks(Comp)
        T.expect(result).toBe("hello99")
    end)
end)

T.describe("useRef", function()
    T.it("returns ref object with .current", function()
        local function Comp()
            local ref = Hooks.useRef(nil)
            return ref
        end
        local result = renderWithHooks(Comp)
        T.expect(result.current).toBeNil()
    end)

    T.it("persists across renders", function()
        local myRef
        local function Comp()
            myRef = Hooks.useRef(0)
            return myRef
        end
        local _, fiber = renderWithHooks(Comp)
        myRef.current = 42
        renderWithHooks(Comp, nil, fiber)
        T.expect(myRef.current).toBe(42)
    end)
end)

T.describe("useMemo", function()
    T.it("computes value", function()
        local function Comp()
            local val = Hooks.useMemo(function() return 2 + 3 end, {})
            return val
        end
        local result = renderWithHooks(Comp)
        T.expect(result).toBe(5)
    end)

    T.it("recomputes when deps change", function()
        local computeCount = 0
        local function Comp(props)
            local val = Hooks.useMemo(function()
                computeCount = computeCount + 1
                return props.x * 2
            end, { props.x })
            return val
        end
        local _, fiber = renderWithHooks(Comp, { x = 5 })
        T.expect(computeCount).toBe(1)

        -- Same deps, no recompute
        fiber.props = { x = 5 }
        renderWithHooks(Comp, { x = 5 }, fiber)
        T.expect(computeCount).toBe(1)

        -- Different deps, recompute
        fiber.props = { x = 10 }
        local result = renderWithHooks(Comp, { x = 10 }, fiber)
        T.expect(computeCount).toBe(2)
        T.expect(result).toBe(20)
    end)
end)

T.describe("useReducer", function()
    T.it("dispatches actions through reducer", function()
        local function reducer(state, action)
            if action.type == "increment" then return state + 1
            elseif action.type == "decrement" then return state - 1
            else return state end
        end
        local dispatchFn
        local function Comp()
            local count, dispatch = Hooks.useReducer(reducer, 0)
            dispatchFn = dispatch
            return count
        end
        local _, fiber = renderWithHooks(Comp)
        T.expect(_).toBe(0)

        dispatchFn({ type = "increment" })
        dispatchFn({ type = "increment" })
        local result = renderWithHooks(Comp, nil, fiber)
        T.expect(result).toBe(2)
    end)
end)

T.summary()
```

- [ ] **Step 2: Run test to verify failure**

Run: `cd /path/to/project && lua tests/react/test_hooks.lua`
Expected: FAIL

- [ ] **Step 3: Implement Hooks**

```lua
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
        hooks[idx] = { state = initialValue, queue = {} }
    end

    local hook = hooks[idx]

    -- Process queued updates
    for _, update in ipairs(hook.queue) do
        if type(update) == "function" then
            hook.state = update(hook.state)
        else
            hook.state = update
        end
    end
    hook.queue = {}

    local fiber = currentFiber
    local function setState(newValue)
        table.insert(hook.queue, newValue)
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
        hooks[idx] = { state = initialState, queue = {} }
    end

    local hook = hooks[idx]

    for _, action in ipairs(hook.queue) do
        hook.state = reducer(hook.state, action)
    end
    hook.queue = {}

    local fiber = currentFiber
    local function dispatch(action)
        table.insert(hook.queue, action)
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
    return {
        _id = contextCounter,
        _defaultValue = defaultValue,
        Provider = function() end, -- placeholder, reconciler handles
    }
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /path/to/project && lua tests/react/test_hooks.lua`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add react/Hooks.lua tests/react/test_hooks.lua
git commit -m "feat: implement hooks — useState, useRef, useMemo, useCallback, useEffect, useContext"
```

---

### Task 1.5: React module init

**Files:**
- Create: `react/init.lua`

- [ ] **Step 1: Create module entry**

```lua
-- react/init.lua
local ReactElement = require("react.ReactElement")
local Hooks = require("react.Hooks")

local React = {}

-- Core
React.createElement = ReactElement.createElement
React.isValidElement = ReactElement.isValidElement

-- Hooks
React.useState = Hooks.useState
React.useReducer = Hooks.useReducer
React.useEffect = Hooks.useEffect
React.useLayoutEffect = Hooks.useLayoutEffect
React.useRef = Hooks.useRef
React.useMemo = Hooks.useMemo
React.useCallback = Hooks.useCallback
React.useContext = Hooks.useContext
React.createContext = Hooks.createContext

-- Fragment (represented as special type)
React.Fragment = "$$react.fragment"

-- Internal (for reconciler)
React._Hooks = Hooks
React._ReactElement = ReactElement

return React
```

- [ ] **Step 2: Commit**

```bash
git add react/init.lua
git commit -m "feat: add React module entry point"
```

---

## Chunk 2: Reconciler + Solar2D Host Renderer

### Task 2.1: Reconciler — synchronous tree diff

**Files:**
- Create: `react/Reconciler.lua`
- Create: `tests/react/test_reconciler.lua`

- [ ] **Step 1: Write failing reconciler tests**

```lua
-- tests/react/test_reconciler.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local Reconciler = require("react.Reconciler")
local mockDisplay = require("tests.helpers.mock_display")

-- Minimal host config for testing
local testHostConfig = {
    createInstance = function(type, props)
        local obj = mockDisplay.newGroup()
        obj._type = type
        obj._props = props
        return obj
    end,
    createTextInstance = function(text)
        local obj = mockDisplay.newGroup()
        obj._type = "TEXT"
        obj._text = text
        return obj
    end,
    appendChild = function(parent, child)
        parent:insert(child)
    end,
    removeChild = function(parent, child)
        child:removeSelf()
    end,
    updateInstance = function(instance, oldProps, newProps)
        instance._props = newProps
    end,
    updateTextInstance = function(instance, oldText, newText)
        instance._text = newText
    end,
}

T.describe("Reconciler", function()
    T.it("renders a single host element", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", { testProp = "hello" }),
            container
        )

        T.expect(container.numChildren).toBe(1)
        T.expect(container[1]._type).toBe("View")
        T.expect(container[1]._props.testProp).toBe("hello")
    end)

    T.it("renders nested elements", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", nil,
                React.createElement("Text", { value = "hi" })
            ),
            container
        )

        T.expect(container.numChildren).toBe(1)
        T.expect(container[1].numChildren).toBe(1)
        T.expect(container[1][1]._type).toBe("Text")
    end)

    T.it("renders function components", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        local function MyComponent(props)
            return React.createElement("View", { id = props.name })
        end

        reconciler.render(
            React.createElement(MyComponent, { name = "test" }),
            container
        )

        T.expect(container.numChildren).toBe(1)
        T.expect(container[1]._props.id).toBe("test")
    end)

    T.it("updates props on re-render", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", { color = "red" }),
            container
        )
        T.expect(container[1]._props.color).toBe("red")

        reconciler.render(
            React.createElement("View", { color = "blue" }),
            container
        )
        T.expect(container.numChildren).toBe(1) -- reused, not recreated
        T.expect(container[1]._props.color).toBe("blue")
    end)

    T.it("removes children on re-render", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)

        reconciler.render(
            React.createElement("View", nil,
                React.createElement("Text"),
                React.createElement("Text")
            ),
            container
        )
        T.expect(container[1].numChildren).toBe(2)

        reconciler.render(
            React.createElement("View", nil,
                React.createElement("Text")
            ),
            container
        )
        T.expect(container[1].numChildren).toBe(1)
    end)

    T.it("handles useState triggering re-render", function()
        local container = mockDisplay.newGroup()
        local reconciler = Reconciler.create(testHostConfig)
        local setCount

        local function Counter()
            local count, set = React.useState(0)
            setCount = set
            return React.createElement("Text", { value = count })
        end

        reconciler.render(React.createElement(Counter), container)
        T.expect(container[1]._props.value).toBe(0)

        setCount(5)
        reconciler.flushUpdates()
        T.expect(container[1]._props.value).toBe(5)
    end)
end)

T.summary()
```

- [ ] **Step 2: Run test to verify failure**

Run: `cd /path/to/project && lua tests/react/test_reconciler.lua`
Expected: FAIL

- [ ] **Step 3: Implement Reconciler**

```lua
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
        -- Find root fiber
        local root = fiber
        while root.parent do
            root = root.parent
        end
        table.insert(pendingUpdateFibers, root)
    end

    -- Normalize children to a flat list
    local function normalizeChildren(children)
        if children == nil then return {} end
        if type(children) ~= "table" or children["$$typeof"] then
            return { children }
        end
        -- Check if it's an array of elements or a single element
        if #children > 0 then
            local result = {}
            for _, child in ipairs(children) do
                if type(child) == "table" and #child > 0 and not child["$$typeof"] then
                    -- Nested array
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

    -- Reconcile a fiber node and its children
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
                -- Text node
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
                    -- Same type: update
                    local tag = type(elementType) == "function" and "function" or "host"
                    newFiber = FiberNode.createFiber(tag, elementType, element.key, element.props)
                    newFiber.stateNode = old.stateNode
                    newFiber.alternate = old
                    newFiber._hooks = old._hooks
                    newFiber.effectTag = "UPDATE"
                    oldChildren[key] = nil
                else
                    -- Different type: new placement
                    local tag = type(elementType) == "function" and "function" or "host"
                    newFiber = FiberNode.createFiber(tag, elementType, element.key, element.props)
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

        -- Mark remaining old children for deletion
        for _, old in pairs(oldChildren) do
            old.effectTag = "DELETION"
            table.insert(fiber.effects, old)
        end
    end

    -- Process a single fiber: render function components, reconcile children
    local function performUnitOfWork(fiber)
        if fiber.tag == "function" then
            -- Function component
            Hooks._setCurrentFiber(fiber)
            Hooks._resetHookIndex()
            fiber._scheduleUpdate = scheduleUpdate
            local children = fiber.type(fiber.props)
            Hooks._finishHooks()
            reconcileChildren(fiber, children)
        elseif fiber.tag == "host" then
            -- Host element
            if not fiber.stateNode then
                fiber.stateNode = hostConfig.createInstance(fiber.type, fiber.props)
            end
            reconcileChildren(fiber, fiber.props.children)
        elseif fiber.tag == "text" then
            if not fiber.stateNode then
                fiber.stateNode = hostConfig.createTextInstance(fiber.props.text)
            end
        elseif fiber.tag == "root" then
            reconcileChildren(fiber, fiber.props.children)
        end
    end

    -- Walk the tree depth-first
    local function walkFiber(fiber)
        performUnitOfWork(fiber)
        -- Process children
        local child = fiber.child
        while child do
            walkFiber(child)
            child = child.sibling
        end
    end

    -- Commit phase: apply mutations to host tree
    local function commitDeletion(fiber, parentInstance)
        if fiber.tag == "host" or fiber.tag == "text" then
            if fiber.stateNode then
                hostConfig.removeChild(parentInstance, fiber.stateNode)
            end
        else
            -- Function component: find actual host child
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

        -- Process deletions first
        for _, deletion in ipairs(fiber.effects) do
            local parentInstance = getHostParent(deletion)
            if parentInstance then
                commitDeletion(deletion, parentInstance)
            end
        end
        fiber.effects = {}

        -- Apply this fiber's changes
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

        fiber.effectTag = nil

        -- Recurse
        local child = fiber.child
        while child do
            commitWork(child)
            child = child.sibling
        end
    end

    -- Run pending effects
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
        if #pendingUpdateFibers == 0 then return end
        pendingUpdateFibers = {}

        -- Re-render from root
        local element = rootFiber.props.children
        local container = rootFiber.stateNode
        local oldRoot = rootFiber

        rootFiber = FiberNode.createFiber("root", nil, nil, { children = element })
        rootFiber.stateNode = container
        rootFiber.alternate = oldRoot

        walkFiber(rootFiber)
        commitWork(rootFiber)
        flushEffects()
    end

    function reconciler.unmount(container)
        if rootFiber then
            -- Remove all children
            for i = container.numChildren, 1, -1 do
                local child = container[i]
                if child then child:removeSelf() end
            end
            rootFiber = nil
        end
    end

    return reconciler
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /path/to/project && lua tests/react/test_reconciler.lua`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add react/Reconciler.lua tests/react/test_reconciler.lua
git commit -m "feat: implement synchronous reconciler with tree diff and commit"
```

---

### Task 2.2: Solar2D Host Config

**Files:**
- Create: `renderer/HostConfig.lua`
- Create: `tests/renderer/test_hostConfig.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/renderer/test_hostConfig.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

-- Inject mock display globally (simulates Solar2D environment)
local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay

local HostConfig = require("renderer.HostConfig")

T.describe("HostConfig.createInstance", function()
    T.it("creates a group for View type", function()
        local inst = HostConfig.createInstance("View", {})
        T.expect(inst._type).toBe("group")
    end)

    T.it("creates rect background for View with backgroundColor", function()
        local inst = HostConfig.createInstance("View", {
            style = { backgroundColor = "#FF0000" }
        })
        T.expect(inst._bg).toBeTruthy()
    end)

    T.it("creates text instance for Text type", function()
        local inst = HostConfig.createInstance("Text", {
            children = "Hello"
        })
        T.expect(inst._textObj).toBeTruthy()
    end)

    T.it("creates image for Image type", function()
        local inst = HostConfig.createInstance("Image", {
            source = "icon.png"
        })
        T.expect(inst._imageObj).toBeTruthy()
    end)
end)

T.describe("HostConfig.appendChild", function()
    T.it("inserts child into parent group", function()
        local parent = HostConfig.createInstance("View", {})
        local child = HostConfig.createInstance("View", {})
        HostConfig.appendChild(parent, child)
        T.expect(parent.numChildren).toBe(1)
    end)
end)

T.describe("HostConfig.removeChild", function()
    T.it("removes child from parent", function()
        local parent = HostConfig.createInstance("View", {})
        local child = HostConfig.createInstance("View", {})
        HostConfig.appendChild(parent, child)
        HostConfig.removeChild(parent, child)
        T.expect(parent.numChildren).toBe(0)
    end)
end)

T.summary()
```

- [ ] **Step 2: Run test to verify failure**

Run: `cd /path/to/project && lua tests/renderer/test_hostConfig.lua`
Expected: FAIL

- [ ] **Step 3: Implement HostConfig**

```lua
-- renderer/HostConfig.lua
local M = {}

-- Color processing (basic — full version in style/processColor.lua)
local function parseColor(color)
    if type(color) == "table" then return color end
    if type(color) ~= "string" then return {1, 1, 1, 1} end

    -- #RRGGBB or #RRGGBBAA
    if color:sub(1, 1) == "#" then
        local hex = color:sub(2)
        local r = tonumber(hex:sub(1, 2), 16) / 255
        local g = tonumber(hex:sub(3, 4), 16) / 255
        local b = tonumber(hex:sub(5, 6), 16) / 255
        local a = #hex >= 8 and (tonumber(hex:sub(7, 8), 16) / 255) or 1
        return {r, g, b, a}
    end

    -- Named colors (common subset)
    local named = {
        red = {1, 0, 0, 1}, green = {0, 0.5, 0, 1}, blue = {0, 0, 1, 1},
        white = {1, 1, 1, 1}, black = {0, 0, 0, 1}, transparent = {0, 0, 0, 0},
        gray = {0.5, 0.5, 0.5, 1}, yellow = {1, 1, 0, 1}, orange = {1, 0.65, 0, 1},
    }
    return named[color:lower()] or {1, 1, 1, 1}
end

-- Helper: wire touch events (onPress, onLongPress) to Solar2D listeners
local function wireEvents(instance, props)
    if props.onPress then
        instance._onPress = props.onPress
        instance:addEventListener("tap", function(event)
            props.onPress(event)
            return true
        end)
    end
    if props.onLongPress then
        instance._onLongPress = props.onLongPress
        local longPressTimer = nil
        instance:addEventListener("touch", function(event)
            if event.phase == "began" then
                display.currentStage:setFocus(instance)
                longPressTimer = timer.performWithDelay(500, function()
                    props.onLongPress(event)
                end)
            elseif event.phase == "ended" or event.phase == "cancelled" then
                display.currentStage:setFocus(nil)
                if longPressTimer then timer.cancel(longPressTimer); longPressTimer = nil end
            end
            return true
        end)
    end

    -- Touch feedback: opacity
    if props._touchFeedback == "opacity" then
        local activeOpacity = props._activeOpacity or 0.2
        instance:addEventListener("touch", function(event)
            if event.phase == "began" then
                instance._origAlpha = instance.alpha
                instance.alpha = activeOpacity
            elseif event.phase == "ended" or event.phase == "cancelled" then
                instance.alpha = instance._origAlpha or 1
            end
            return true
        end)
    end
end

function M.createInstance(elementType, props)
    local style = props.style or {}

    if elementType == "View" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0
        group.anchorChildren = true

        -- Background rect (only if visual styling needed)
        if style.backgroundColor or style.borderWidth or style.borderColor then
            local bg
            if style.borderRadius and style.borderRadius > 0 then
                bg = display.newRoundedRect(group, 0, 0, style.width or 0, style.height or 0, style.borderRadius)
            else
                bg = display.newRect(group, 0, 0, style.width or 0, style.height or 0)
            end
            bg.anchorX, bg.anchorY = 0, 0

            if style.backgroundColor then
                local c = parseColor(style.backgroundColor)
                bg:setFillColor(c[1], c[2], c[3], c[4])
            else
                bg:setFillColor(0, 0, 0, 0) -- transparent
            end

            if style.borderWidth then
                bg.strokeWidth = style.borderWidth
                if style.borderColor then
                    local c = parseColor(style.borderColor)
                    bg:setStrokeColor(c[1], c[2], c[3], c[4])
                end
            end

            group._bg = bg
        end

        if style.opacity then group.alpha = style.opacity end
        if style.display == "none" then group.isVisible = false end

        wireEvents(group, props)
        return group

    elseif elementType == "Text" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0

        local text = tostring(props.children or "")
        local textObj = display.newText({
            parent = group,
            text = text,
            x = 0, y = 0,
            fontSize = style.fontSize or 14,
            width = style.width,
        })
        textObj.anchorX, textObj.anchorY = 0, 0

        if style.color then
            local c = parseColor(style.color)
            textObj:setFillColor(c[1], c[2], c[3], c[4])
        end

        group._textObj = textObj
        wireEvents(group, props)
        return group

    elseif elementType == "Image" then
        local group = display.newGroup()
        group.anchorX, group.anchorY = 0, 0

        local source = props.source
        local filename = (type(source) == "table") and source.uri or source or ""
        local w = style.width or 100
        local h = style.height or 100

        local img = display.newImageRect(group, filename, w, h)
        if img then
            img.anchorX, img.anchorY = 0, 0
        end

        group._imageObj = img
        wireEvents(group, props)
        return group
    end

    -- Fallback: generic group
    local group = display.newGroup()
    group.anchorX, group.anchorY = 0, 0
    wireEvents(group, props)
    return group
end

function M.createTextInstance(text)
    local group = display.newGroup()
    local textObj = display.newText({
        parent = group,
        text = tostring(text),
        x = 0, y = 0,
        fontSize = 14,
    })
    textObj.anchorX, textObj.anchorY = 0, 0
    group._textObj = textObj
    return group
end

function M.appendChild(parent, child)
    parent:insert(child)
end

function M.removeChild(parent, child)
    child:removeSelf()
end

function M.insertBefore(parent, child, beforeChild)
    -- Find index of beforeChild
    for i = 1, parent.numChildren do
        if parent[i] == beforeChild then
            parent:insert(i, child)
            return
        end
    end
    parent:insert(child)
end

function M.updateInstance(instance, oldProps, newProps)
    local oldStyle = oldProps.style or {}
    local newStyle = newProps.style or {}

    -- Update background
    if instance._bg then
        if newStyle.backgroundColor then
            local c = parseColor(newStyle.backgroundColor)
            instance._bg:setFillColor(c[1], c[2], c[3], c[4])
        end
        if newStyle.width then instance._bg.path.width = newStyle.width end
        if newStyle.height then instance._bg.path.height = newStyle.height end
    end

    -- Update touch events
    -- TODO: diff old/new onPress handlers (for now, re-wire is handled by reconciler recreation)

    -- Update text
    if instance._textObj then
        local newText = newProps.children
        local textType = type(newText)
        if textType == "string" or textType == "number" then
            instance._textObj.text = tostring(newText)
        end
        if newStyle.color then
            local c = parseColor(newStyle.color)
            instance._textObj:setFillColor(c[1], c[2], c[3], c[4])
        end
        if newStyle.fontSize then
            instance._textObj.size = newStyle.fontSize
        end
    end

    -- Update common props
    if newStyle.opacity then instance.alpha = newStyle.opacity end
    if newStyle.display == "none" then
        instance.isVisible = false
    elseif oldStyle.display == "none" and newStyle.display ~= "none" then
        instance.isVisible = true
    end
end

function M.updateTextInstance(instance, oldText, newText)
    if instance._textObj then
        instance._textObj.text = tostring(newText)
    end
end

return M
```

- [ ] **Step 4: Run tests**

Run: `cd /path/to/project && lua tests/renderer/test_hostConfig.lua`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add renderer/HostConfig.lua tests/renderer/test_hostConfig.lua
git commit -m "feat: implement Solar2D host config — View, Text, Image creation and updates"
```

---

### Task 2.3: Renderer entry point

**Files:**
- Create: `renderer/init.lua`

- [ ] **Step 1: Implement renderer entry**

```lua
-- renderer/init.lua
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")

local ReactSolar2D = {}

local reconcilerInstance = nil

function ReactSolar2D.render(element, container)
    if not reconcilerInstance then
        reconcilerInstance = Reconciler.create(HostConfig)
    end
    reconcilerInstance.render(element, container)
    return reconcilerInstance
end

function ReactSolar2D.unmount(container)
    if reconcilerInstance then
        reconcilerInstance.unmount(container)
        reconcilerInstance = nil
    end
end

-- Expose for state update flushing (called by timer or enterFrame)
function ReactSolar2D.flushUpdates()
    if reconcilerInstance then
        reconcilerInstance.flushUpdates()
    end
end

-- Auto-flush: hook into Solar2D's enterFrame for automatic re-renders
function ReactSolar2D.startAutoFlush()
    Runtime:addEventListener("enterFrame", function()
        ReactSolar2D.flushUpdates()
    end)
end

return ReactSolar2D
```

- [ ] **Step 2: Commit**

```bash
git add renderer/init.lua
git commit -m "feat: add ReactSolar2D.render entry point"
```

---

## Chunk 3: StyleSheet + processColor

### Task 3.1: processColor

**Files:**
- Create: `style/processColor.lua`
- Create: `tests/style/test_processColor.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/style/test_processColor.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local processColor = require("style.processColor")

T.describe("processColor", function()
    T.it("converts #RRGGBB", function()
        local c = processColor("#FF0000")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
        T.expect(c[4]).toBe(1)
    end)

    T.it("converts #RRGGBBAA", function()
        local c = processColor("#FF000080")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
        -- 0x80 = 128, 128/255 ≈ 0.502
        T.expect(math.abs(c[4] - 0.502) < 0.01).toBeTruthy()
    end)

    T.it("converts #RGB shorthand", function()
        local c = processColor("#F00")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
    end)

    T.it("converts named colors", function()
        local c = processColor("red")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
    end)

    T.it("converts rgba(r,g,b,a)", function()
        local c = processColor("rgba(255, 0, 0, 0.5)")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
        T.expect(c[4]).toBe(0.5)
    end)

    T.it("passes through table {r,g,b,a}", function()
        local c = processColor({0.5, 0.5, 0.5, 1})
        T.expect(c[1]).toBe(0.5)
    end)
end)

T.summary()
```

- [ ] **Step 2: Implement processColor**

```lua
-- style/processColor.lua
local namedColors = {
    transparent = {0, 0, 0, 0},
    black = {0, 0, 0, 1}, white = {1, 1, 1, 1},
    red = {1, 0, 0, 1}, green = {0, 0.502, 0, 1}, blue = {0, 0, 1, 1},
    yellow = {1, 1, 0, 1}, cyan = {0, 1, 1, 1}, magenta = {1, 0, 1, 1},
    orange = {1, 0.647, 0, 1}, purple = {0.502, 0, 0.502, 1},
    pink = {1, 0.753, 0.796, 1}, brown = {0.647, 0.165, 0.165, 1},
    gray = {0.502, 0.502, 0.502, 1}, grey = {0.502, 0.502, 0.502, 1},
    lightgray = {0.827, 0.827, 0.827, 1}, darkgray = {0.663, 0.663, 0.663, 1},
    tomato = {1, 0.388, 0.278, 1}, coral = {1, 0.498, 0.314, 1},
    salmon = {0.980, 0.502, 0.447, 1}, gold = {1, 0.843, 0, 1},
    skyblue = {0.529, 0.808, 0.922, 1}, steelblue = {0.275, 0.510, 0.706, 1},
    dodgerblue = {0.118, 0.565, 1, 1}, navy = {0, 0, 0.502, 1},
    teal = {0, 0.502, 0.502, 1}, indigo = {0.294, 0, 0.510, 1},
}

local function processColor(color)
    if color == nil then return nil end
    if type(color) == "table" then return color end
    if type(color) == "number" then return {color, color, color, 1} end
    if type(color) ~= "string" then return {1, 1, 1, 1} end

    -- Named color
    local named = namedColors[color:lower()]
    if named then return {named[1], named[2], named[3], named[4]} end

    -- #RGB
    if color:match("^#%x%x%x$") then
        local r = tonumber(color:sub(2, 2), 16) / 15
        local g = tonumber(color:sub(3, 3), 16) / 15
        local b = tonumber(color:sub(4, 4), 16) / 15
        return {r, g, b, 1}
    end

    -- #RRGGBB
    if color:match("^#%x%x%x%x%x%x$") then
        local r = tonumber(color:sub(2, 3), 16) / 255
        local g = tonumber(color:sub(4, 5), 16) / 255
        local b = tonumber(color:sub(6, 7), 16) / 255
        return {r, g, b, 1}
    end

    -- #RRGGBBAA
    if color:match("^#%x%x%x%x%x%x%x%x$") then
        local r = tonumber(color:sub(2, 3), 16) / 255
        local g = tonumber(color:sub(4, 5), 16) / 255
        local b = tonumber(color:sub(6, 7), 16) / 255
        local a = tonumber(color:sub(8, 9), 16) / 255
        return {r, g, b, a}
    end

    -- rgba(r, g, b, a)
    local r, g, b, a = color:match("rgba%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*([%d%.]+)%s*%)")
    if r then
        return {tonumber(r) / 255, tonumber(g) / 255, tonumber(b) / 255, tonumber(a)}
    end

    -- rgb(r, g, b)
    r, g, b = color:match("rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
    if r then
        return {tonumber(r) / 255, tonumber(g) / 255, tonumber(b) / 255, 1}
    end

    return {1, 1, 1, 1}
end

return processColor
```

- [ ] **Step 3: Run tests**

Run: `cd /path/to/project && lua tests/style/test_processColor.lua`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add style/processColor.lua tests/style/test_processColor.lua
git commit -m "feat: implement processColor — hex, rgba, named color conversion"
```

---

### Task 3.2: StyleSheet

**Files:**
- Create: `style/StyleSheet.lua`
- Create: `tests/style/test_stylesheet.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/style/test_stylesheet.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local StyleSheet = require("style.StyleSheet")

T.describe("StyleSheet.create", function()
    T.it("returns style objects unchanged", function()
        local styles = StyleSheet.create({
            container = { flex = 1, backgroundColor = "red" },
            text = { fontSize = 16 },
        })
        T.expect(styles.container.flex).toBe(1)
        T.expect(styles.text.fontSize).toBe(16)
    end)

    T.it("freezes styles (read-only id assigned)", function()
        local styles = StyleSheet.create({
            box = { width = 100 },
        })
        T.expect(styles.box._id).toBeTruthy()
    end)
end)

T.describe("StyleSheet.flatten", function()
    T.it("merges array of styles", function()
        local result = StyleSheet.flatten({
            { flex = 1, padding = 10 },
            { padding = 20, margin = 5 },
        })
        T.expect(result.flex).toBe(1)
        T.expect(result.padding).toBe(20)
        T.expect(result.margin).toBe(5)
    end)

    T.it("handles nil in array", function()
        local result = StyleSheet.flatten({
            { flex = 1 },
            nil,
            { margin = 5 },
        })
        T.expect(result.flex).toBe(1)
        T.expect(result.margin).toBe(5)
    end)

    T.it("handles single style (not array)", function()
        local result = StyleSheet.flatten({ flex = 1 })
        T.expect(result.flex).toBe(1)
    end)

    T.it("handles false/nil input", function()
        local result = StyleSheet.flatten(nil)
        T.expect(type(result)).toBe("table")
    end)
end)

T.describe("StyleSheet.compose", function()
    T.it("composes two styles", function()
        local result = StyleSheet.compose(
            { flex = 1 },
            { margin = 5 }
        )
        T.expect(type(result)).toBe("table")
    end)
end)

T.summary()
```

- [ ] **Step 2: Implement StyleSheet**

```lua
-- style/StyleSheet.lua
local M = {}

local nextId = 0

function M.create(styles)
    local result = {}
    for name, style in pairs(styles) do
        nextId = nextId + 1
        style._id = nextId
        result[name] = style
    end
    return result
end

function M.flatten(style)
    if style == nil or style == false then return {} end
    if type(style) ~= "table" then return {} end

    -- Check if it's an array (has numeric keys starting at 1)
    if style[1] ~= nil or #style > 0 then
        -- Could be an array of styles OR a single style with numeric keys
        -- Heuristic: if first element is a table, it's an array of styles
        if type(style[1]) == "table" then
            local result = {}
            for _, s in ipairs(style) do
                if s then
                    local flat = M.flatten(s)
                    for k, v in pairs(flat) do
                        result[k] = v
                    end
                end
            end
            return result
        end
    end

    -- Single style object
    local result = {}
    for k, v in pairs(style) do
        result[k] = v
    end
    return result
end

function M.compose(style1, style2)
    if style1 and style2 then
        return {style1, style2}
    end
    return style1 or style2 or {}
end

-- RN compatibility constants
M.hairlineWidth = 1
M.absoluteFill = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0 }
M.absoluteFillObject = M.absoluteFill

return M
```

- [ ] **Step 3: Run tests**

Run: `cd /path/to/project && lua tests/style/test_stylesheet.lua`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add style/StyleSheet.lua tests/style/test_stylesheet.lua
git commit -m "feat: implement StyleSheet.create, flatten, compose"
```

---

### Task 3.3: Style module init

**Files:**
- Create: `style/init.lua`

- [ ] **Step 1: Create style init**

```lua
-- style/init.lua
local StyleSheet = require("style.StyleSheet")
local processColor = require("style.processColor")

return {
    StyleSheet = StyleSheet,
    processColor = processColor,
}
```

- [ ] **Step 2: Commit**

```bash
git add style/init.lua
git commit -m "feat: add style module entry point"
```

---

## Chunk 4: Full CSS Flexbox Layout Engine (Port from ReactJIT)

> **Source:** ReactJIT layout.lua (2500+ LOC, Lua 5.1 compatible)
> **Strategy:** Port ReactJIT's 3-phase flexbox algorithm, adapt measurement callbacks for Solar2D
> **Scope:** Full CSS Flexbox spec — wrap, shrink, grow, min/max constraints, aspect-ratio, auto margins, alignContent, baseline alignment, percentage values, iterative constraint clamping (max 10 passes)

### Task 4.1: Layout Enums + Measurement Interface

**Files:**
- Create: `layout/Enums.lua`
- Create: `layout/Measurement.lua`

- [ ] **Step 1: Implement comprehensive enums (all CSS Flexbox values)**

```lua
-- layout/Enums.lua
return {
    FlexDirection = {
        ROW = "row",
        COLUMN = "column",
        ROW_REVERSE = "row-reverse",
        COLUMN_REVERSE = "column-reverse",
    },
    JustifyContent = {
        FLEX_START = "flex-start",
        CENTER = "center",
        FLEX_END = "flex-end",
        SPACE_BETWEEN = "space-between",
        SPACE_AROUND = "space-around",
        SPACE_EVENLY = "space-evenly",
    },
    AlignItems = {
        FLEX_START = "flex-start",
        CENTER = "center",
        FLEX_END = "flex-end",
        STRETCH = "stretch",
        BASELINE = "baseline",
    },
    AlignContent = {
        FLEX_START = "flex-start",
        CENTER = "center",
        FLEX_END = "flex-end",
        STRETCH = "stretch",
        SPACE_BETWEEN = "space-between",
        SPACE_AROUND = "space-around",
    },
    AlignSelf = {
        AUTO = "auto",
        FLEX_START = "flex-start",
        CENTER = "center",
        FLEX_END = "flex-end",
        STRETCH = "stretch",
        BASELINE = "baseline",
    },
    Position = {
        RELATIVE = "relative",
        ABSOLUTE = "absolute",
    },
    FlexWrap = {
        NO_WRAP = "nowrap",
        WRAP = "wrap",
        WRAP_REVERSE = "wrap-reverse",
    },
    Overflow = {
        VISIBLE = "visible",
        HIDDEN = "hidden",
        SCROLL = "scroll",
    },
    Display = {
        FLEX = "flex",
        NONE = "none",
    },
}
```

- [ ] **Step 2: Implement measurement callback interface**

```lua
-- layout/Measurement.lua
-- Platform-specific measurement callbacks for intrinsic sizing
-- Solar2D adapter provides text/image measurement functions
local M = {}

-- Default measurement context (overridden by Solar2D adapter)
local measureText = nil
local measureImage = nil

-- Register Solar2D measurement functions
-- textMeasureFn(text, style, maxWidth) → { width, height }
-- imageMeasureFn(source) → { width, height }
function M.setTextMeasure(fn)
    measureText = fn
end

function M.setImageMeasure(fn)
    measureImage = fn
end

-- Measure a text node's intrinsic size given max width constraint
-- Returns { width, height }
function M.getTextSize(text, style, maxWidth)
    if measureText then
        return measureText(text, style, maxWidth)
    end
    -- Fallback: estimate based on character count
    local fontSize = style.fontSize or 14
    local charWidth = fontSize * 0.6
    local totalWidth = #text * charWidth
    if maxWidth and totalWidth > maxWidth then
        local lines = math.ceil(totalWidth / maxWidth)
        return { width = maxWidth, height = lines * fontSize * 1.2 }
    end
    return { width = totalWidth, height = fontSize * 1.2 }
end

-- Measure an image's natural dimensions
-- Returns { width, height }
function M.getImageSize(source)
    if measureImage then
        return measureImage(source)
    end
    return { width = 0, height = 0 }
end

return M
```

- [ ] **Step 3: Commit**

```bash
git add layout/Enums.lua layout/Measurement.lua
git commit -m "feat: add layout enums (full CSS Flexbox) and measurement interface"
```

---

### Task 4.2: LayoutNode with Full Style Properties

**Files:**
- Create: `layout/LayoutNode.lua`

- [ ] **Step 1: Implement LayoutNode with complete CSS Flexbox style properties**

```lua
-- layout/LayoutNode.lua
local M = {}

function M.new(style, measureFn)
    style = style or {}
    local node = {
        -- Node type for measurement dispatch
        nodeType = style.nodeType or "container", -- "container" | "text" | "image"

        -- Measurement callback for leaf nodes (text, image)
        -- measureFn(node, maxWidth, maxHeight) → { width, height }
        measure = measureFn,

        -- Input style (full CSS Flexbox properties)
        style = {
            -- Display
            display = style.display or "flex",  -- "flex" | "none"

            -- Flex container
            flexDirection = style.flexDirection or "column",
            flexWrap = style.flexWrap or "nowrap",
            justifyContent = style.justifyContent or "flex-start",
            alignItems = style.alignItems or "stretch",
            alignContent = style.alignContent or "stretch",

            -- Flex item
            alignSelf = style.alignSelf,  -- nil = inherit from parent alignItems
            flex = style.flex,
            flexGrow = style.flexGrow or 0,
            flexShrink = style.flexShrink or 1,  -- CSS default is 1
            flexBasis = style.flexBasis,  -- nil = auto

            -- Dimensions
            width = style.width,
            height = style.height,
            minWidth = style.minWidth or 0,
            maxWidth = style.maxWidth,  -- nil = unlimited
            minHeight = style.minHeight or 0,
            maxHeight = style.maxHeight,
            aspectRatio = style.aspectRatio,  -- number, e.g. 16/9

            -- Padding (supports shorthand and per-side)
            padding = style.padding or 0,
            paddingTop = style.paddingTop,
            paddingRight = style.paddingRight,
            paddingBottom = style.paddingBottom,
            paddingLeft = style.paddingLeft,
            paddingHorizontal = style.paddingHorizontal,
            paddingVertical = style.paddingVertical,

            -- Margin (supports shorthand, per-side, and "auto")
            margin = style.margin or 0,
            marginTop = style.marginTop,
            marginRight = style.marginRight,
            marginBottom = style.marginBottom,
            marginLeft = style.marginLeft,
            marginHorizontal = style.marginHorizontal,
            marginVertical = style.marginVertical,

            -- Gap
            gap = style.gap or 0,
            rowGap = style.rowGap,
            columnGap = style.columnGap,

            -- Position
            position = style.position or "relative",
            top = style.top,
            right = style.right,
            bottom = style.bottom,
            left = style.left,

            -- Border (affects layout box size)
            borderWidth = style.borderWidth or 0,
            borderTopWidth = style.borderTopWidth,
            borderRightWidth = style.borderRightWidth,
            borderBottomWidth = style.borderBottomWidth,
            borderLeftWidth = style.borderLeftWidth,

            -- Overflow
            overflow = style.overflow or "visible",
        },

        -- Computed layout (output)
        layout = {
            x = 0, y = 0,
            width = 0, height = 0,
            -- Content size (for scroll containers)
            contentWidth = 0,
            contentHeight = 0,
        },

        -- Tree
        children = {},
        parent = nil,

        -- Dirty tracking
        isDirty = true,
    }

    -- Resolve padding with shorthand hierarchy:
    -- paddingTop > paddingVertical > padding
    function node:getPadding(side)
        local s = self.style
        if side == "top" then return s.paddingTop or s.paddingVertical or s.padding or 0 end
        if side == "right" then return s.paddingRight or s.paddingHorizontal or s.padding or 0 end
        if side == "bottom" then return s.paddingBottom or s.paddingVertical or s.padding or 0 end
        if side == "left" then return s.paddingLeft or s.paddingHorizontal or s.padding or 0 end
        return 0
    end

    -- Resolve margin with shorthand hierarchy (returns 0 for "auto", caller checks isAutoMargin)
    function node:getMargin(side)
        local s = self.style
        local val
        if side == "top" then val = s.marginTop or s.marginVertical or s.margin
        elseif side == "right" then val = s.marginRight or s.marginHorizontal or s.margin
        elseif side == "bottom" then val = s.marginBottom or s.marginVertical or s.margin
        elseif side == "left" then val = s.marginLeft or s.marginHorizontal or s.margin
        end
        if val == "auto" then return 0 end
        return val or 0
    end

    -- Check if margin is set to "auto" (for centering)
    function node:isAutoMargin(side)
        local s = self.style
        if side == "top" then return (s.marginTop or s.marginVertical) == "auto" end
        if side == "right" then return (s.marginRight or s.marginHorizontal) == "auto" end
        if side == "bottom" then return (s.marginBottom or s.marginVertical) == "auto" end
        if side == "left" then return (s.marginLeft or s.marginHorizontal) == "auto" end
        return false
    end

    -- Resolve border width
    function node:getBorder(side)
        local s = self.style
        if side == "top" then return s.borderTopWidth or s.borderWidth or 0 end
        if side == "right" then return s.borderRightWidth or s.borderWidth or 0 end
        if side == "bottom" then return s.borderBottomWidth or s.borderWidth or 0 end
        if side == "left" then return s.borderLeftWidth or s.borderWidth or 0 end
        return 0
    end

    function node:getGap(axis)
        local s = self.style
        if axis == "row" then return s.columnGap or s.gap or 0 end
        if axis == "column" then return s.rowGap or s.gap or 0 end
        return 0
    end

    function node:addChild(child)
        child.parent = self
        self.children[#self.children + 1] = child
        self:markDirty()
        return child
    end

    function node:removeChild(child)
        for i, c in ipairs(self.children) do
            if c == child then
                table.remove(self.children, i)
                child.parent = nil
                self:markDirty()
                return
            end
        end
    end

    function node:markDirty()
        self.isDirty = true
        if self.parent then self.parent:markDirty() end
    end

    -- Resolve percentage values relative to parent dimension
    function node:resolvePercent(value, parentDim)
        if type(value) == "string" then
            local num = tonumber(value:match("^(.+)%%$"))
            if num and parentDim then
                return num / 100 * parentDim
            end
            return 0
        end
        return value
    end

    return node
end

return M
```

- [ ] **Step 2: Write tests for LayoutNode**

```lua
-- tests/layout/test_layout_node.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local LayoutNode = require("layout.LayoutNode")

T.describe("LayoutNode", function()
    T.it("creates with defaults", function()
        local node = LayoutNode.new()
        T.expect(node.style.flexDirection).toBe("column")
        T.expect(node.style.flexShrink).toBe(1)
        T.expect(node.style.alignItems).toBe("stretch")
        T.expect(node.isDirty).toBe(true)
    end)

    T.it("resolves padding shorthand hierarchy", function()
        local node = LayoutNode.new({ padding = 5, paddingVertical = 10, paddingTop = 20 })
        T.expect(node:getPadding("top")).toBe(20)     -- most specific wins
        T.expect(node:getPadding("bottom")).toBe(10)   -- paddingVertical
        T.expect(node:getPadding("left")).toBe(5)      -- fallback to padding
    end)

    T.it("resolves auto margins", function()
        local node = LayoutNode.new({ marginLeft = "auto", marginRight = "auto" })
        T.expect(node:isAutoMargin("left")).toBe(true)
        T.expect(node:isAutoMargin("right")).toBe(true)
        T.expect(node:getMargin("left")).toBe(0)  -- auto returns 0 for calculation
    end)

    T.it("resolves percentage values", function()
        local node = LayoutNode.new()
        T.expect(node:resolvePercent("50%", 200)).toBe(100)
        T.expect(node:resolvePercent(30, 200)).toBe(30)
    end)

    T.it("marks dirty on child add/remove", function()
        local parent = LayoutNode.new()
        parent.isDirty = false
        local child = LayoutNode.new({ height = 50 })
        parent:addChild(child)
        T.expect(parent.isDirty).toBe(true)
    end)

    T.it("supports border width", function()
        local node = LayoutNode.new({ borderWidth = 2, borderTopWidth = 4 })
        T.expect(node:getBorder("top")).toBe(4)
        T.expect(node:getBorder("left")).toBe(2)
    end)
end)

T.run()
```

- [ ] **Step 3: Run tests**

Run: `cd /path/to/project && lua tests/layout/test_layout_node.lua`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add layout/LayoutNode.lua tests/layout/test_layout_node.lua
git commit -m "feat: add LayoutNode with full CSS Flexbox style properties, dirty tracking, measurement"
```

---

### Task 4.3: FlexLine — Line-based Wrapping

**Files:**
- Create: `layout/FlexLine.lua`
- Create: `tests/layout/test_flex_line.lua`

- [ ] **Step 1: Implement line collection algorithm**

Port from ReactJIT's line-based wrapping logic. Collects flex items into lines based on:
- Available main axis space
- `flexWrap` setting (nowrap = single line, wrap = multi-line)
- Item flex-basis + margins + min-content size

```lua
-- layout/FlexLine.lua
-- Line-based flex item collection and per-line layout
-- Ported from ReactJIT layout.lua
local M = {}

-- Collect children into flex lines
-- Returns array of lines, each line = { items = {}, mainSize = 0, crossSize = 0 }
function M.collectLines(children, mainAvailable, isRow, gap, wrap)
    local lines = {}
    local currentLine = { items = {}, totalBasis = 0, totalGrow = 0, totalShrink = 0 }

    for _, child in ipairs(children) do
        if child.style.display == "none" then goto continue end
        if child.style.position == "absolute" then goto continue end

        local cs = child.style
        local grow = cs.flexGrow or 0
        local shrink = cs.flexShrink or 1

        -- flex shorthand
        if cs.flex then
            if cs.flex > 0 then grow = cs.flex; shrink = 1
            elseif cs.flex == 0 then grow = 0; shrink = 0
            elseif cs.flex == -1 then grow = 0; shrink = 1
            end
        end

        -- Resolve flex basis
        local basis
        if cs.flexBasis then
            basis = cs.flexBasis
        elseif isRow then
            basis = cs.width or 0
        else
            basis = cs.height or 0
        end

        -- Margins on main axis
        local mainMarginStart, mainMarginEnd
        if isRow then
            mainMarginStart = child:getMargin("left")
            mainMarginEnd = child:getMargin("right")
        else
            mainMarginStart = child:getMargin("top")
            mainMarginEnd = child:getMargin("bottom")
        end
        local mainMargin = mainMarginStart + mainMarginEnd

        local itemMainSize = basis + mainMargin
        local gapBefore = #currentLine.items > 0 and gap or 0

        -- Check if item fits on current line
        if wrap ~= "nowrap" and #currentLine.items > 0 then
            if currentLine.totalBasis + gapBefore + itemMainSize > mainAvailable then
                -- Start new line
                lines[#lines + 1] = currentLine
                currentLine = { items = {}, totalBasis = 0, totalGrow = 0, totalShrink = 0 }
                gapBefore = 0
            end
        end

        currentLine.items[#currentLine.items + 1] = {
            child = child,
            basis = basis,
            grow = grow,
            shrink = shrink,
            mainMargin = mainMargin,
            mainMarginStart = mainMarginStart,
            mainMarginEnd = mainMarginEnd,
        }
        currentLine.totalBasis = currentLine.totalBasis + gapBefore + itemMainSize
        currentLine.totalGrow = currentLine.totalGrow + grow
        currentLine.totalShrink = currentLine.totalShrink + shrink

        ::continue::
    end

    if #currentLine.items > 0 then
        lines[#lines + 1] = currentLine
    end

    return lines
end

-- Resolve main axis sizes for a single line
-- Distributes free space via grow/shrink with iterative constraint clamping
function M.resolveLineSizes(line, mainAvailable, gap, isRow)
    local totalGaps = (#line.items - 1) * gap
    local freeSpace = mainAvailable - line.totalBasis

    -- Iterative resolution: items may hit min/max constraints
    -- Frozen items stop growing/shrinking, excess redistributes
    local MAX_ITERATIONS = 10
    local frozen = {}

    for iter = 1, MAX_ITERATIONS do
        local changed = false
        local activeFreeSpace = freeSpace
        local activeGrow = 0
        local activeShrink = 0

        -- Sum active grow/shrink (non-frozen items)
        for i, item in ipairs(line.items) do
            if not frozen[i] then
                if freeSpace > 0 then
                    activeGrow = activeGrow + item.grow
                else
                    activeShrink = activeShrink + (item.shrink * item.basis)
                end
            end
        end

        for i, item in ipairs(line.items) do
            if frozen[i] then goto nextItem end

            local resolved = item.basis
            if freeSpace > 0 and activeGrow > 0 then
                resolved = resolved + (freeSpace * item.grow / activeGrow)
            elseif freeSpace < 0 and activeShrink > 0 then
                local shrinkRatio = (item.shrink * item.basis) / activeShrink
                resolved = resolved + (freeSpace * shrinkRatio)
            end

            -- Clamp to min/max
            local cs = item.child.style
            local minMain = isRow and (cs.minWidth or 0) or (cs.minHeight or 0)
            local maxMain = isRow and cs.maxWidth or cs.maxHeight

            if resolved < minMain then
                resolved = minMain
                frozen[i] = true
                freeSpace = freeSpace - (resolved - item.basis)
                changed = true
            elseif maxMain and resolved > maxMain then
                resolved = maxMain
                frozen[i] = true
                freeSpace = freeSpace - (resolved - item.basis)
                changed = true
            end

            item.resolvedMain = math.max(0, resolved)
            ::nextItem::
        end

        if not changed then break end
    end

    -- Final pass: resolve any remaining non-frozen items
    for i, item in ipairs(line.items) do
        if not item.resolvedMain then
            item.resolvedMain = math.max(0, item.basis)
        end
    end
end

return M
```

- [ ] **Step 2: Write tests for line collection and size resolution**

```lua
-- tests/layout/test_flex_line.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local LayoutNode = require("layout.LayoutNode")
local FlexLine = require("layout.FlexLine")

T.describe("FlexLine: collectLines", function()
    T.it("single line when nowrap", function()
        local children = {
            LayoutNode.new({ width = 100 }),
            LayoutNode.new({ width = 100 }),
            LayoutNode.new({ width = 100 }),
        }
        local lines = FlexLine.collectLines(children, 200, true, 0, "nowrap")
        T.expect(#lines).toBe(1)
        T.expect(#lines[1].items).toBe(3)
    end)

    T.it("wraps to multiple lines", function()
        local children = {
            LayoutNode.new({ width = 100 }),
            LayoutNode.new({ width = 100 }),
            LayoutNode.new({ width = 100 }),
        }
        local lines = FlexLine.collectLines(children, 200, true, 0, "wrap")
        T.expect(#lines).toBe(2)
        T.expect(#lines[1].items).toBe(2)
        T.expect(#lines[2].items).toBe(1)
    end)

    T.it("respects gap in wrap calculation", function()
        local children = {
            LayoutNode.new({ width = 90 }),
            LayoutNode.new({ width = 90 }),
            LayoutNode.new({ width = 90 }),
        }
        local lines = FlexLine.collectLines(children, 200, true, 20, "wrap")
        -- 90 + 20 + 90 = 200 fits, 90 + 20 + 90 + 20 + 90 = 310 doesn't
        T.expect(#lines).toBe(2)
    end)

    T.it("skips display:none children", function()
        local children = {
            LayoutNode.new({ width = 100 }),
            LayoutNode.new({ width = 100, display = "none" }),
            LayoutNode.new({ width = 100 }),
        }
        local lines = FlexLine.collectLines(children, 300, true, 0, "nowrap")
        T.expect(#lines[1].items).toBe(2)
    end)

    T.it("skips absolute children", function()
        local children = {
            LayoutNode.new({ width = 100 }),
            LayoutNode.new({ width = 100, position = "absolute" }),
        }
        local lines = FlexLine.collectLines(children, 300, true, 0, "nowrap")
        T.expect(#lines[1].items).toBe(1)
    end)
end)

T.describe("FlexLine: resolveLineSizes", function()
    T.it("distributes grow space", function()
        local child1 = LayoutNode.new({ width = 50, flexGrow = 1 })
        local child2 = LayoutNode.new({ width = 50, flexGrow = 2 })
        local lines = FlexLine.collectLines({ child1, child2 }, 300, true, 0, "nowrap")
        FlexLine.resolveLineSizes(lines[1], 300, 0, true)
        -- 200 free space: child1 gets 50+66.67, child2 gets 50+133.33
        T.expect(math.floor(lines[1].items[1].resolvedMain)).toBe(116)
        T.expect(math.floor(lines[1].items[2].resolvedMain)).toBe(183)
    end)

    T.it("shrinks proportionally", function()
        local child1 = LayoutNode.new({ width = 200, flexShrink = 1 })
        local child2 = LayoutNode.new({ width = 200, flexShrink = 1 })
        local lines = FlexLine.collectLines({ child1, child2 }, 300, true, 0, "nowrap")
        FlexLine.resolveLineSizes(lines[1], 300, 0, true)
        T.expect(lines[1].items[1].resolvedMain).toBe(150)
        T.expect(lines[1].items[2].resolvedMain).toBe(150)
    end)

    T.it("clamps to minWidth during shrink", function()
        local child1 = LayoutNode.new({ width = 200, flexShrink = 1, minWidth = 180 })
        local child2 = LayoutNode.new({ width = 200, flexShrink = 1 })
        local lines = FlexLine.collectLines({ child1, child2 }, 300, true, 0, "nowrap")
        FlexLine.resolveLineSizes(lines[1], 300, 0, true)
        T.expect(lines[1].items[1].resolvedMain).toBe(180)  -- clamped
        -- child2 absorbs remaining shrink
    end)

    T.it("clamps to maxWidth during grow", function()
        local child1 = LayoutNode.new({ width = 50, flexGrow = 1, maxWidth = 80 })
        local child2 = LayoutNode.new({ width = 50, flexGrow = 1 })
        local lines = FlexLine.collectLines({ child1, child2 }, 300, true, 0, "nowrap")
        FlexLine.resolveLineSizes(lines[1], 300, 0, true)
        T.expect(lines[1].items[1].resolvedMain).toBe(80)  -- clamped
    end)
end)

T.run()
```

- [ ] **Step 3: Run tests**

Run: `cd /path/to/project && lua tests/layout/test_flex_line.lua`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add layout/FlexLine.lua tests/layout/test_flex_line.lua
git commit -m "feat: add FlexLine with line collection and iterative constraint clamping"
```

---

### Task 4.4: FlexAlgorithm — Full 3-Phase Layout Engine

**Files:**
- Create: `layout/FlexAlgorithm.lua`
- Create: `layout/init.lua`
- Create: `tests/layout/test_flexbox.lua`

> **This is the core port from ReactJIT's layout.lua.** The algorithm has 3 phases:
> 1. **Intrinsic sizing** — bottom-up measurement of leaf nodes (text, images)
> 2. **Flex distribution** — per-line grow/shrink with iterative constraint clamping
> 3. **Position assignment** — justify, align, reverse, auto margins

- [ ] **Step 1: Implement FlexAlgorithm (port from ReactJIT)**

The implementation should follow ReactJIT's architecture:
- Use `FlexLine.collectLines()` for wrapping
- Use `FlexLine.resolveLineSizes()` for per-line flex distribution
- Handle `alignContent` for multi-line cross axis distribution
- Support `aspectRatio` (resolve width from height or vice versa)
- Support percentage values via `node:resolvePercent()`
- Support auto margins (center remaining space)
- Recurse into children for nested flex containers
- Handle `display: "none"` (skip entirely)
- Handle absolute positioning separately

**Key reference:** Read ReactJIT's layout.lua during implementation for exact algorithm details. The subagent research report documents the 3-phase architecture in detail.

```lua
-- layout/FlexAlgorithm.lua
-- Full CSS Flexbox layout engine
-- Ported from ReactJIT layout.lua (2500+ LOC), adapted for Solar2D
local FlexLine = require("layout.FlexLine")
local M = {}

function M.calculateLayout(node, parentWidth, parentHeight)
    if node.style.display == "none" then
        node.layout.width = 0
        node.layout.height = 0
        return
    end

    local s = node.style
    local isRow = s.flexDirection == "row" or s.flexDirection == "row-reverse"
    local isReverse = s.flexDirection == "row-reverse" or s.flexDirection == "column-reverse"
    local isWrap = s.flexWrap ~= "nowrap"
    local isWrapReverse = s.flexWrap == "wrap-reverse"

    -- Resolve node dimensions (may be percentage, number, or nil=auto)
    local nodeWidth = node:resolvePercent(s.width, parentWidth) or parentWidth or 0
    local nodeHeight = node:resolvePercent(s.height, parentHeight) or parentHeight or 0

    -- Apply aspect ratio
    if s.aspectRatio then
        if s.width and not s.height then
            nodeHeight = nodeWidth / s.aspectRatio
        elseif s.height and not s.width then
            nodeWidth = nodeHeight * s.aspectRatio
        end
    end

    -- Apply min/max constraints
    if s.minWidth then nodeWidth = math.max(nodeWidth, s.minWidth) end
    if s.maxWidth then nodeWidth = math.min(nodeWidth, s.maxWidth) end
    if s.minHeight then nodeHeight = math.max(nodeHeight, s.minHeight) end
    if s.maxHeight then nodeHeight = math.min(nodeHeight, s.maxHeight) end

    node.layout.width = nodeWidth
    node.layout.height = nodeHeight

    -- If this is a leaf node with measurement function, measure it
    if node.measure and #node.children == 0 then
        local measured = node.measure(node, nodeWidth, nodeHeight)
        if not s.width then node.layout.width = math.max(measured.width, s.minWidth or 0) end
        if not s.height then node.layout.height = math.max(measured.height, s.minHeight or 0) end
        if s.maxWidth then node.layout.width = math.min(node.layout.width, s.maxWidth) end
        if s.maxHeight then node.layout.height = math.min(node.layout.height, s.maxHeight) end
        return
    end

    -- Box model: padding + border
    local pt = node:getPadding("top") + node:getBorder("top")
    local pr = node:getPadding("right") + node:getBorder("right")
    local pb = node:getPadding("bottom") + node:getBorder("bottom")
    local pl = node:getPadding("left") + node:getBorder("left")

    local contentWidth = nodeWidth - pl - pr
    local contentHeight = nodeHeight - pt - pb
    local mainSize = isRow and contentWidth or contentHeight
    local crossSize = isRow and contentHeight or contentWidth
    local gap = node:getGap(isRow and "row" or "column")
    local crossGap = node:getGap(isRow and "column" or "row")

    -- Separate absolute and flow children
    local absChildren = {}
    local flowChildren = {}
    for _, child in ipairs(node.children) do
        if child.style.position == "absolute" then
            absChildren[#absChildren + 1] = child
        else
            flowChildren[#flowChildren + 1] = child
        end
    end

    -- Handle absolute children
    for _, child in ipairs(absChildren) do
        local cw = child:resolvePercent(child.style.width, contentWidth) or 0
        local ch = child:resolvePercent(child.style.height, contentHeight) or 0
        M.calculateLayout(child, cw, ch)
        child.layout.x = (child.style.left or 0) + pl
        child.layout.y = (child.style.top or 0) + pt
        if child.style.right and not child.style.left then
            child.layout.x = nodeWidth - pr - child.layout.width - child.style.right
        end
        if child.style.bottom and not child.style.top then
            child.layout.y = nodeHeight - pb - child.layout.height - child.style.bottom
        end
    end

    if #flowChildren == 0 then return end

    -- Phase 1: Collect items into lines
    local lines = FlexLine.collectLines(flowChildren, mainSize, isRow, gap, s.flexWrap)

    -- Phase 2: Resolve sizes per line
    for _, line in ipairs(lines) do
        FlexLine.resolveLineSizes(line, mainSize, gap, isRow)

        -- Resolve cross sizes and recurse into children
        line.crossSize = 0
        for _, item in ipairs(line.items) do
            local child = item.child
            local cw, ch
            if isRow then
                cw = item.resolvedMain
                local alignSelf = child.style.alignSelf or s.alignItems
                if alignSelf == "stretch" and not child.style.height then
                    ch = crossSize  -- will be adjusted after all lines measured
                else
                    ch = child:resolvePercent(child.style.height, contentHeight) or 0
                end
            else
                ch = item.resolvedMain
                local alignSelf = child.style.alignSelf or s.alignItems
                if alignSelf == "stretch" and not child.style.width then
                    cw = crossSize
                else
                    cw = child:resolvePercent(child.style.width, contentWidth) or 0
                end
            end

            M.calculateLayout(child, cw, ch)

            local crossMarginStart = isRow and child:getMargin("top") or child:getMargin("left")
            local crossMarginEnd = isRow and child:getMargin("bottom") or child:getMargin("right")
            local childCross = (isRow and child.layout.height or child.layout.width) + crossMarginStart + crossMarginEnd

            if childCross > line.crossSize then
                line.crossSize = childCross
            end
        end
    end

    -- Phase 3a: Distribute cross space among lines (alignContent)
    local totalLineCross = 0
    for _, line in ipairs(lines) do
        totalLineCross = totalLineCross + line.crossSize
    end
    totalLineCross = totalLineCross + (#lines - 1) * crossGap

    local freeCrossSpace = crossSize - totalLineCross
    local lineOffsets = {}
    local lineCrossOffset = 0

    if #lines == 1 or s.alignContent == "flex-start" then
        lineCrossOffset = 0
    elseif s.alignContent == "flex-end" then
        lineCrossOffset = freeCrossSpace
    elseif s.alignContent == "center" then
        lineCrossOffset = freeCrossSpace / 2
    elseif s.alignContent == "stretch" then
        local extra = freeCrossSpace / #lines
        for _, line in ipairs(lines) do
            line.crossSize = line.crossSize + extra
        end
    elseif s.alignContent == "space-between" and #lines > 1 then
        crossGap = crossGap + freeCrossSpace / (#lines - 1)
    elseif s.alignContent == "space-around" and #lines > 0 then
        local space = freeCrossSpace / #lines
        lineCrossOffset = space / 2
        crossGap = crossGap + space
    end

    local crossCursor = lineCrossOffset
    for _, line in ipairs(lines) do
        line.crossOffset = crossCursor
        crossCursor = crossCursor + line.crossSize + crossGap
    end

    -- Phase 3b: Position items along main and cross axes
    for _, line in ipairs(lines) do
        local totalFinalMain = 0
        for _, item in ipairs(line.items) do
            local finalMain = isRow and item.child.layout.width or item.child.layout.height
            totalFinalMain = totalFinalMain + finalMain + item.mainMargin
        end
        totalFinalMain = totalFinalMain + (#line.items - 1) * gap

        local mainFreeSpace = mainSize - totalFinalMain
        local mainOffset = 0
        local mainGap = gap

        -- Auto margins consume free space first
        local autoMarginCount = 0
        for _, item in ipairs(line.items) do
            if isRow then
                if item.child:isAutoMargin("left") then autoMarginCount = autoMarginCount + 1 end
                if item.child:isAutoMargin("right") then autoMarginCount = autoMarginCount + 1 end
            else
                if item.child:isAutoMargin("top") then autoMarginCount = autoMarginCount + 1 end
                if item.child:isAutoMargin("bottom") then autoMarginCount = autoMarginCount + 1 end
            end
        end

        local autoMarginSize = 0
        if autoMarginCount > 0 then
            autoMarginSize = math.max(0, mainFreeSpace) / autoMarginCount
            mainFreeSpace = 0  -- auto margins consume all free space
        end

        -- justifyContent (only if no auto margins)
        if autoMarginCount == 0 then
            if s.justifyContent == "flex-start" then
                mainOffset = 0
            elseif s.justifyContent == "flex-end" then
                mainOffset = mainFreeSpace
            elseif s.justifyContent == "center" then
                mainOffset = mainFreeSpace / 2
            elseif s.justifyContent == "space-between" and #line.items > 1 then
                mainGap = gap + mainFreeSpace / (#line.items - 1)
            elseif s.justifyContent == "space-around" and #line.items > 0 then
                local space = mainFreeSpace / #line.items
                mainOffset = space / 2
                mainGap = gap + space
            elseif s.justifyContent == "space-evenly" and #line.items > 0 then
                local space = mainFreeSpace / (#line.items + 1)
                mainOffset = space
                mainGap = gap + space
            end
        end

        local cursor = mainOffset
        for i, item in ipairs(line.items) do
            local child = item.child

            -- Resolve auto margins for this item
            local autoStart = 0
            local autoEnd = 0
            if isRow then
                if child:isAutoMargin("left") then autoStart = autoMarginSize end
                if child:isAutoMargin("right") then autoEnd = autoMarginSize end
            else
                if child:isAutoMargin("top") then autoStart = autoMarginSize end
                if child:isAutoMargin("bottom") then autoEnd = autoMarginSize end
            end

            local mainPos = cursor + item.mainMarginStart + autoStart
            local finalMain = isRow and child.layout.width or child.layout.height
            local finalCross = isRow and child.layout.height or child.layout.width

            -- Cross axis alignment within line
            local crossMarginStart = isRow and child:getMargin("top") or child:getMargin("left")
            local crossMarginEnd = isRow and child:getMargin("bottom") or child:getMargin("right")

            local crossPos = line.crossOffset
            local alignSelf = child.style.alignSelf or s.alignItems

            if alignSelf == "flex-start" or alignSelf == "stretch" then
                crossPos = crossPos + crossMarginStart
            elseif alignSelf == "flex-end" then
                crossPos = crossPos + line.crossSize - finalCross - crossMarginEnd
            elseif alignSelf == "center" then
                crossPos = crossPos + (line.crossSize - finalCross) / 2
            end

            if isRow then
                child.layout.x = pl + mainPos
                child.layout.y = pt + crossPos
            else
                child.layout.x = pl + crossPos
                child.layout.y = pt + mainPos
            end

            cursor = mainPos + finalMain + item.mainMarginEnd + autoEnd
            if i < #line.items then
                cursor = cursor + mainGap
            end
        end
    end

    -- Handle reverse
    if isReverse then
        for _, child in ipairs(flowChildren) do
            if isRow then
                child.layout.x = nodeWidth - child.layout.x - child.layout.width
            else
                child.layout.y = nodeHeight - child.layout.y - child.layout.height
            end
        end
    end

    if isWrapReverse then
        for _, child in ipairs(flowChildren) do
            if isRow then
                child.layout.y = nodeHeight - child.layout.y - child.layout.height
            else
                child.layout.x = nodeWidth - child.layout.x - child.layout.width
            end
        end
    end

    -- Track content size for scroll containers
    local maxContentMain = 0
    local maxContentCross = 0
    for _, child in ipairs(flowChildren) do
        local mainEnd, crossEnd
        if isRow then
            mainEnd = child.layout.x + child.layout.width - pl
            crossEnd = child.layout.y + child.layout.height - pt
        else
            mainEnd = child.layout.y + child.layout.height - pt
            crossEnd = child.layout.x + child.layout.width - pl
        end
        if mainEnd > maxContentMain then maxContentMain = mainEnd end
        if crossEnd > maxContentCross then maxContentCross = crossEnd end
    end

    if isRow then
        node.layout.contentWidth = maxContentMain
        node.layout.contentHeight = maxContentCross
    else
        node.layout.contentWidth = maxContentCross
        node.layout.contentHeight = maxContentMain
    end

    node.isDirty = false
end

return M
```

- [ ] **Step 2: Create layout init**

```lua
-- layout/init.lua
local FlexAlgorithm = require("layout.FlexAlgorithm")
local LayoutNode = require("layout.LayoutNode")
local Measurement = require("layout.Measurement")

return {
    calculateLayout = FlexAlgorithm.calculateLayout,
    LayoutNode = LayoutNode,
    Measurement = Measurement,
}
```

- [ ] **Step 3: Write comprehensive flexbox tests**

```lua
-- tests/layout/test_flexbox.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local LayoutNode = require("layout.LayoutNode")
local Layout = require("layout")

-- === Basic Direction ===

T.describe("Flexbox: column direction", function()
    T.it("stacks children vertically", function()
        local root = LayoutNode.new({ width = 200, height = 400 })
        root:addChild(LayoutNode.new({ height = 50 }))
        root:addChild(LayoutNode.new({ height = 80 }))

        Layout.calculateLayout(root, 200, 400)

        T.expect(root.children[1].layout.y).toBe(0)
        T.expect(root.children[1].layout.width).toBe(200) -- stretch
        T.expect(root.children[1].layout.height).toBe(50)
        T.expect(root.children[2].layout.y).toBe(50)
    end)

    T.it("respects padding", function()
        local root = LayoutNode.new({ width = 200, height = 400, padding = 10 })
        root:addChild(LayoutNode.new({ height = 50 }))

        Layout.calculateLayout(root, 200, 400)

        T.expect(root.children[1].layout.x).toBe(10)
        T.expect(root.children[1].layout.y).toBe(10)
        T.expect(root.children[1].layout.width).toBe(180) -- 200 - 10 - 10
    end)
end)

T.describe("Flexbox: row direction", function()
    T.it("lays out children horizontally", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ width = 80 }))
        root:addChild(LayoutNode.new({ width = 120 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(0)
        T.expect(root.children[2].layout.x).toBe(80)
        T.expect(root.children[1].layout.height).toBe(100) -- stretch
    end)
end)

-- === Flex Grow / Shrink ===

T.describe("Flexbox: flex grow", function()
    T.it("distributes free space proportionally", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ width = 50, flexGrow = 1 }))
        root:addChild(LayoutNode.new({ width = 50, flexGrow = 2 }))

        Layout.calculateLayout(root, 300, 100)

        -- 200 free: child1 gets 50+66.67≈116, child2 gets 50+133.33≈183
        local w1 = root.children[1].layout.width
        local w2 = root.children[2].layout.width
        T.expect(math.abs(w1 - 116.67) < 1).toBe(true)
        T.expect(math.abs(w2 - 183.33) < 1).toBe(true)
    end)

    T.it("flex shorthand works", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ flex = 1 }))
        root:addChild(LayoutNode.new({ flex = 1 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.width).toBe(150)
        T.expect(root.children[2].layout.width).toBe(150)
    end)
end)

T.describe("Flexbox: flex shrink", function()
    T.it("shrinks proportionally", function()
        local root = LayoutNode.new({ width = 200, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ width = 150, flexShrink = 1 }))
        root:addChild(LayoutNode.new({ width = 150, flexShrink = 1 }))

        Layout.calculateLayout(root, 200, 100)

        T.expect(root.children[1].layout.width).toBe(100)
        T.expect(root.children[2].layout.width).toBe(100)
    end)
end)

-- === Justify Content ===

T.describe("Flexbox: justifyContent", function()
    T.it("center", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", justifyContent = "center" })
        root:addChild(LayoutNode.new({ width = 50 }))
        root:addChild(LayoutNode.new({ width = 50 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(100) -- (300-100)/2
        T.expect(root.children[2].layout.x).toBe(150)
    end)

    T.it("space-between", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", justifyContent = "space-between" })
        root:addChild(LayoutNode.new({ width = 50 }))
        root:addChild(LayoutNode.new({ width = 50 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(0)
        T.expect(root.children[2].layout.x).toBe(250)
    end)

    T.it("space-evenly", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", justifyContent = "space-evenly" })
        root:addChild(LayoutNode.new({ width = 50 }))
        root:addChild(LayoutNode.new({ width = 50 }))

        Layout.calculateLayout(root, 300, 100)

        -- 200 free / 3 = 66.67
        local x1 = root.children[1].layout.x
        local x2 = root.children[2].layout.x
        T.expect(math.abs(x1 - 66.67) < 1).toBe(true)
        T.expect(math.abs(x2 - 183.33) < 1).toBe(true)
    end)
end)

-- === Align Items ===

T.describe("Flexbox: alignItems", function()
    T.it("center on cross axis", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", alignItems = "center" })
        root:addChild(LayoutNode.new({ width = 50, height = 30 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.y).toBe(35) -- (100-30)/2
    end)

    T.it("flex-end on cross axis", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", alignItems = "flex-end" })
        root:addChild(LayoutNode.new({ width = 50, height = 30 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.y).toBe(70) -- 100-30
    end)
end)

-- === Wrap ===

T.describe("Flexbox: wrap", function()
    T.it("wraps items to next line", function()
        local root = LayoutNode.new({ width = 200, height = 400, flexDirection = "row", flexWrap = "wrap" })
        root:addChild(LayoutNode.new({ width = 120, height = 50 }))
        root:addChild(LayoutNode.new({ width = 120, height = 50 }))

        Layout.calculateLayout(root, 200, 400)

        T.expect(root.children[1].layout.x).toBe(0)
        T.expect(root.children[1].layout.y).toBe(0)
        T.expect(root.children[2].layout.x).toBe(0)
        T.expect(root.children[2].layout.y).toBe(50)  -- second line
    end)
end)

-- === Gap ===

T.describe("Flexbox: gap", function()
    T.it("adds gap between items", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", gap = 10 })
        root:addChild(LayoutNode.new({ width = 50 }))
        root:addChild(LayoutNode.new({ width = 50 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(0)
        T.expect(root.children[2].layout.x).toBe(60) -- 50 + 10 gap
    end)
end)

-- === Absolute Positioning ===

T.describe("Flexbox: absolute", function()
    T.it("positions absolutely within parent", function()
        local root = LayoutNode.new({ width = 200, height = 200, padding = 10 })
        root:addChild(LayoutNode.new({ position = "absolute", top = 5, left = 5, width = 50, height = 50 }))

        Layout.calculateLayout(root, 200, 200)

        T.expect(root.children[1].layout.x).toBe(15) -- left + padding
        T.expect(root.children[1].layout.y).toBe(15) -- top + padding
    end)

    T.it("supports right/bottom anchoring", function()
        local root = LayoutNode.new({ width = 200, height = 200 })
        root:addChild(LayoutNode.new({ position = "absolute", right = 10, bottom = 10, width = 50, height = 50 }))

        Layout.calculateLayout(root, 200, 200)

        T.expect(root.children[1].layout.x).toBe(140) -- 200 - 50 - 10
        T.expect(root.children[1].layout.y).toBe(140)
    end)
end)

-- === Auto Margins ===

T.describe("Flexbox: auto margins", function()
    T.it("centers item with marginLeft/Right auto", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ width = 100, marginLeft = "auto", marginRight = "auto" }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(100) -- (300-100)/2
    end)
end)

-- === Aspect Ratio ===

T.describe("Flexbox: aspect ratio", function()
    T.it("resolves height from width and ratio", function()
        local root = LayoutNode.new({ width = 300, height = 400 })
        root:addChild(LayoutNode.new({ width = 200, aspectRatio = 2 })) -- w/h = 2, so h = 100

        Layout.calculateLayout(root, 300, 400)

        T.expect(root.children[1].layout.width).toBe(200)
        T.expect(root.children[1].layout.height).toBe(100)
    end)
end)

-- === Reverse ===

T.describe("Flexbox: reverse", function()
    T.it("reverses row direction", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row-reverse" })
        root:addChild(LayoutNode.new({ width = 50 }))
        root:addChild(LayoutNode.new({ width = 50 }))

        Layout.calculateLayout(root, 300, 100)

        -- First child should be on the right
        T.expect(root.children[1].layout.x > root.children[2].layout.x).toBe(true)
    end)
end)

-- === Display None ===

T.describe("Flexbox: display none", function()
    T.it("skips display:none children", function()
        local root = LayoutNode.new({ width = 200, height = 400 })
        root:addChild(LayoutNode.new({ height = 50 }))
        root:addChild(LayoutNode.new({ height = 50, display = "none" }))
        root:addChild(LayoutNode.new({ height = 50 }))

        Layout.calculateLayout(root, 200, 400)

        T.expect(root.children[1].layout.y).toBe(0)
        T.expect(root.children[3].layout.y).toBe(50)  -- skips hidden child
    end)
end)

-- === Measurement Callback ===

T.describe("Flexbox: measurement", function()
    T.it("uses measure function for leaf nodes", function()
        local root = LayoutNode.new({ width = 200, height = 400 })
        local textNode = LayoutNode.new({}, function(node, maxW, maxH)
            return { width = 120, height = 20 }
        end)
        root:addChild(textNode)

        Layout.calculateLayout(root, 200, 400)

        T.expect(root.children[1].layout.width).toBe(120)
        T.expect(root.children[1].layout.height).toBe(20)
    end)
end)

-- === Border Width ===

T.describe("Flexbox: border width", function()
    T.it("subtracts border from content area", function()
        local root = LayoutNode.new({ width = 200, height = 200, borderWidth = 5 })
        root:addChild(LayoutNode.new({ height = 50 }))

        Layout.calculateLayout(root, 200, 200)

        T.expect(root.children[1].layout.x).toBe(5)
        T.expect(root.children[1].layout.y).toBe(5)
        T.expect(root.children[1].layout.width).toBe(190) -- 200 - 5 - 5
    end)
end)

T.run()
```

- [ ] **Step 4: Run tests**

Run: `cd /path/to/project && lua tests/layout/test_flexbox.lua`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add layout/ tests/layout/
git commit -m "feat: implement full CSS Flexbox layout engine — wrap, grow, shrink, min/max clamping, auto margins, aspect-ratio, alignContent, measurement callbacks"
        T.expect(root.children[1].layout.y).toBe(10)
        T.expect(root.children[1].layout.width).toBe(180) -- 200 - 10 - 10
    end)
end)

T.describe("Flexbox: row direction", function()
    T.it("places children horizontally", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ width = 80 }))
        root:addChild(LayoutNode.new({ width = 120 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(0)
        T.expect(root.children[1].layout.width).toBe(80)
        T.expect(root.children[2].layout.x).toBe(80)
        T.expect(root.children[2].layout.width).toBe(120)
    end)
end)

T.describe("Flexbox: flex grow", function()
    T.it("distributes remaining space", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ width = 100, flexGrow = 0 }))
        root:addChild(LayoutNode.new({ flexGrow = 1 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.width).toBe(100)
        T.expect(root.children[2].layout.width).toBe(200)
    end)

    T.it("splits flex grow proportionally", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row" })
        root:addChild(LayoutNode.new({ flexGrow = 1 }))
        root:addChild(LayoutNode.new({ flexGrow = 2 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.width).toBe(100)
        T.expect(root.children[2].layout.width).toBe(200)
    end)
end)

T.describe("Flexbox: justifyContent", function()
    T.it("center", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", justifyContent = "center" })
        root:addChild(LayoutNode.new({ width = 60, height = 40 }))
        root:addChild(LayoutNode.new({ width = 40, height = 40 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(100) -- (300 - 100) / 2
        T.expect(root.children[2].layout.x).toBe(160)
    end)

    T.it("space-between", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", justifyContent = "space-between" })
        root:addChild(LayoutNode.new({ width = 50, height = 40 }))
        root:addChild(LayoutNode.new({ width = 50, height = 40 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(0)
        T.expect(root.children[2].layout.x).toBe(250) -- 300 - 50
    end)
end)

T.describe("Flexbox: alignItems", function()
    T.it("center cross-axis", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", alignItems = "center" })
        root:addChild(LayoutNode.new({ width = 50, height = 40 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.y).toBe(30) -- (100 - 40) / 2
    end)
end)

T.describe("Flexbox: margin", function()
    T.it("applies margin to children", function()
        local root = LayoutNode.new({ width = 200, height = 400 })
        root:addChild(LayoutNode.new({ height = 50, margin = 10 }))
        root:addChild(LayoutNode.new({ height = 50 }))

        Layout.calculateLayout(root, 200, 400)

        T.expect(root.children[1].layout.x).toBe(10)
        T.expect(root.children[1].layout.y).toBe(10)
        T.expect(root.children[1].layout.width).toBe(180) -- 200 - 10 - 10
        T.expect(root.children[2].layout.y).toBe(70) -- 10 + 50 + 10
    end)
end)

T.describe("Flexbox: gap", function()
    T.it("adds gap between children", function()
        local root = LayoutNode.new({ width = 300, height = 100, flexDirection = "row", gap = 10 })
        root:addChild(LayoutNode.new({ width = 50, height = 40 }))
        root:addChild(LayoutNode.new({ width = 50, height = 40 }))
        root:addChild(LayoutNode.new({ width = 50, height = 40 }))

        Layout.calculateLayout(root, 300, 100)

        T.expect(root.children[1].layout.x).toBe(0)
        T.expect(root.children[2].layout.x).toBe(60)  -- 50 + 10
        T.expect(root.children[3].layout.x).toBe(120) -- 50 + 10 + 50 + 10
    end)
end)

T.describe("Flexbox: absolute positioning", function()
    T.it("positions absolutely relative to parent", function()
        local root = LayoutNode.new({ width = 300, height = 300 })
        root:addChild(LayoutNode.new({ position = "absolute", top = 20, left = 30, width = 50, height = 50 }))
        root:addChild(LayoutNode.new({ height = 100 }))

        Layout.calculateLayout(root, 300, 300)

        T.expect(root.children[1].layout.x).toBe(30)
        T.expect(root.children[1].layout.y).toBe(20)
        -- Absolute children don't affect flow
        T.expect(root.children[2].layout.y).toBe(0)
    end)
end)

T.summary()
```

- [ ] **Step 2: Implement FlexAlgorithm**

```lua
-- layout/FlexAlgorithm.lua
local M = {}

function M.calculateLayout(node, parentWidth, parentHeight)
    local s = node.style
    local isRow = s.flexDirection == "row" or s.flexDirection == "row-reverse"
    local isReverse = s.flexDirection == "row-reverse" or s.flexDirection == "column-reverse"

    -- Resolve node size
    local nodeWidth = s.width or parentWidth or 0
    local nodeHeight = s.height or parentHeight or 0

    -- Apply min/max constraints
    if s.minWidth then nodeWidth = math.max(nodeWidth, s.minWidth) end
    if s.maxWidth then nodeWidth = math.min(nodeWidth, s.maxWidth) end
    if s.minHeight then nodeHeight = math.max(nodeHeight, s.minHeight) end
    if s.maxHeight then nodeHeight = math.min(nodeHeight, s.maxHeight) end

    node.layout.width = nodeWidth
    node.layout.height = nodeHeight

    -- Padding
    local pt = node:getPadding("top")
    local pr = node:getPadding("right")
    local pb = node:getPadding("bottom")
    local pl = node:getPadding("left")

    local contentWidth = nodeWidth - pl - pr
    local contentHeight = nodeHeight - pt - pb

    -- Separate absolute and relative children
    local relChildren = {}
    local absChildren = {}
    for _, child in ipairs(node.children) do
        if child.style.position == "absolute" then
            absChildren[#absChildren + 1] = child
        else
            relChildren[#relChildren + 1] = child
        end
    end

    -- Handle absolute children
    for _, child in ipairs(absChildren) do
        local cw = child.style.width or 0
        local ch = child.style.height or 0
        M.calculateLayout(child, cw, ch)
        child.layout.x = (child.style.left or 0) + pl
        child.layout.y = (child.style.top or 0) + pt
    end

    if #relChildren == 0 then return end

    -- Main axis = row → width, column → height
    local mainSize = isRow and contentWidth or contentHeight
    local crossSize = isRow and contentHeight or contentWidth
    local gap = node:getGap(isRow and "row" or "column")

    -- First pass: measure children base sizes
    local childInfos = {}
    local totalBaseMain = 0
    local totalGrow = 0
    local totalShrink = 0

    for i, child in ipairs(relChildren) do
        local cs = child.style
        local grow = cs.flexGrow or 0
        local shrink = cs.flexShrink or 0

        -- flex shorthand
        if cs.flex then
            if cs.flex > 0 then grow = cs.flex; shrink = 1
            elseif cs.flex == 0 then grow = 0; shrink = 0
            end
        end

        local baseMain
        if isRow then
            baseMain = cs.flexBasis or cs.width or 0
        else
            baseMain = cs.flexBasis or cs.height or 0
        end

        local mt = child:getMargin("top")
        local mr = child:getMargin("right")
        local mb = child:getMargin("bottom")
        local ml = child:getMargin("left")

        local mainMargin = isRow and (ml + mr) or (mt + mb)
        local crossMargin = isRow and (mt + mb) or (ml + mr)

        childInfos[i] = {
            child = child,
            baseMain = baseMain,
            grow = grow,
            shrink = shrink,
            mainMargin = mainMargin,
            crossMargin = crossMargin,
            mt = mt, mr = mr, mb = mb, ml = ml,
        }

        totalBaseMain = totalBaseMain + baseMain + mainMargin
        totalGrow = totalGrow + grow
        totalShrink = totalShrink + shrink
    end

    -- Add gaps
    local totalGaps = (#relChildren - 1) * gap
    totalBaseMain = totalBaseMain + totalGaps

    -- Second pass: resolve flex grow/shrink
    local freeSpace = mainSize - totalBaseMain

    for _, info in ipairs(childInfos) do
        local mainDim = info.baseMain
        if freeSpace > 0 and totalGrow > 0 then
            mainDim = mainDim + (freeSpace * info.grow / totalGrow)
        elseif freeSpace < 0 and totalShrink > 0 then
            mainDim = mainDim + (freeSpace * info.shrink / totalShrink)
        end
        mainDim = math.max(0, mainDim)
        info.resolvedMain = mainDim
    end

    -- Third pass: calculate cross sizes and recursively layout children
    for _, info in ipairs(childInfos) do
        local child = info.child
        local cw, ch
        if isRow then
            cw = info.resolvedMain
            -- alignItems: stretch → full cross, else use child's height
            local alignSelf = child.style.alignSelf or s.alignItems
            if alignSelf == "stretch" and not child.style.height then
                ch = crossSize - info.crossMargin
            else
                ch = child.style.height or 0
            end
        else
            ch = info.resolvedMain
            local alignSelf = child.style.alignSelf or s.alignItems
            if alignSelf == "stretch" and not child.style.width then
                cw = crossSize - info.crossMargin
            else
                cw = child.style.width or 0
            end
        end

        -- Apply min/max
        if child.style.minWidth then cw = math.max(cw, child.style.minWidth) end
        if child.style.maxWidth then cw = math.min(cw, child.style.maxWidth) end
        if child.style.minHeight then ch = math.max(ch, child.style.minHeight) end
        if child.style.maxHeight then ch = math.min(ch, child.style.maxHeight) end

        M.calculateLayout(child, cw, ch)
        info.finalMain = isRow and child.layout.width or child.layout.height
        info.finalCross = isRow and child.layout.height or child.layout.width
    end

    -- Fourth pass: position along main axis
    local totalFinalMain = 0
    for _, info in ipairs(childInfos) do
        totalFinalMain = totalFinalMain + info.finalMain + info.mainMargin
    end
    totalFinalMain = totalFinalMain + totalGaps

    local mainFreeSpace = mainSize - totalFinalMain
    local mainOffset
    local mainGap = gap

    if s.justifyContent == "flex-start" then
        mainOffset = 0
    elseif s.justifyContent == "flex-end" then
        mainOffset = mainFreeSpace
    elseif s.justifyContent == "center" then
        mainOffset = mainFreeSpace / 2
    elseif s.justifyContent == "space-between" then
        mainOffset = 0
        if #relChildren > 1 then
            mainGap = gap + mainFreeSpace / (#relChildren - 1)
        end
    elseif s.justifyContent == "space-around" then
        local space = mainFreeSpace / #relChildren
        mainOffset = space / 2
        mainGap = gap + space
    elseif s.justifyContent == "space-evenly" then
        local space = mainFreeSpace / (#relChildren + 1)
        mainOffset = space
        mainGap = gap + space
    else
        mainOffset = 0
    end

    local cursor = mainOffset
    for i, info in ipairs(childInfos) do
        local child = info.child
        local mainMarginBefore = isRow and info.ml or info.mt
        local crossMarginBefore = isRow and info.mt or info.ml

        local mainPos = cursor + mainMarginBefore
        local crossPos = 0

        -- Cross axis alignment
        local alignSelf = child.style.alignSelf or s.alignItems
        if alignSelf == "flex-start" or alignSelf == "stretch" then
            crossPos = crossMarginBefore
        elseif alignSelf == "flex-end" then
            local crossMarginAfter = isRow and info.mb or info.mr
            crossPos = crossSize - info.finalCross - crossMarginAfter
        elseif alignSelf == "center" then
            crossPos = (crossSize - info.finalCross) / 2
        end

        if isRow then
            child.layout.x = pl + mainPos
            child.layout.y = pt + crossPos
        else
            child.layout.x = pl + crossPos
            child.layout.y = pt + mainPos
        end

        cursor = mainPos + info.finalMain + (isRow and info.mr or info.mb)
        if i < #relChildren then
            cursor = cursor + mainGap
        end
    end

    -- Handle reverse
    if isReverse then
        for _, info in ipairs(childInfos) do
            local child = info.child
            if isRow then
                child.layout.x = nodeWidth - child.layout.x - child.layout.width
            else
                child.layout.y = nodeHeight - child.layout.y - child.layout.height
            end
        end
    end
end

return M
```

- [ ] **Step 3: Create layout init**

```lua
-- layout/init.lua
local FlexAlgorithm = require("layout.FlexAlgorithm")
local LayoutNode = require("layout.LayoutNode")
local Enums = require("layout.Enums")

return {
    calculateLayout = FlexAlgorithm.calculateLayout,
    Node = LayoutNode,
    Enums = Enums,
}
```

- [ ] **Step 4: Run tests**

Run: `cd /path/to/project && lua tests/layout/test_flexbox.lua`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add layout/ tests/layout/
git commit -m "feat: implement flexbox layout engine — direction, grow, justify, align, gap, absolute"
```

---

## Chunk 5: Core Components

### Task 5.1: View Component

**Files:**
- Create: `components/View.lua`
- Create: `tests/components/test_view.lua`

- [ ] **Step 1: Write failing test**

```lua
-- tests/components/test_view.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local View = require("components.View")

T.describe("View component", function()
    T.it("returns a host element of type View", function()
        local el = React.createElement(View, { style = { flex = 1 } })
        T.expect(el.type).toBe("View")
    end)

    T.it("passes through style and children", function()
        local child = React.createElement("Text", nil, "hi")
        local el = React.createElement(View, {
            style = { backgroundColor = "red" },
        }, child)
        T.expect(el.props.style.backgroundColor).toBe("red")
        T.expect(el.props.children).toBe(child)
    end)
end)

T.summary()
```

- [ ] **Step 2: Implement View**

```lua
-- components/View.lua
-- View is a direct host component — the reconciler handles "View" type via HostConfig.
-- This module provides the component name constant and optional forwarding.
return "View"
```

- [ ] **Step 3: Run test, verify pass, commit**

```bash
git add components/View.lua tests/components/test_view.lua
git commit -m "feat: add View component"
```

---

### Task 5.2: Text Component

**Files:**
- Create: `components/Text.lua`
- Create: `tests/components/test_text.lua`

- [ ] **Step 1: Write test**

```lua
-- tests/components/test_text.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local Text = require("components.Text")

T.describe("Text component", function()
    T.it("is a host element type", function()
        local el = React.createElement(Text, { style = { fontSize = 16 } }, "Hello")
        T.expect(el.type).toBe("Text")
        T.expect(el.props.children).toBe("Hello")
    end)
end)

T.summary()
```

- [ ] **Step 2: Implement and commit**

```lua
-- components/Text.lua
return "Text"
```

```bash
git add components/Text.lua tests/components/test_text.lua
git commit -m "feat: add Text component"
```

---

### Task 5.3: Image, Button, TouchableOpacity

**Files:**
- Create: `components/Image.lua`
- Create: `components/Button.lua`
- Create: `components/TouchableOpacity.lua`

- [ ] **Step 1: Implement Image**

```lua
-- components/Image.lua
return "Image"
```

- [ ] **Step 2: Implement Button as function component**

```lua
-- components/Button.lua
local React = require("react")

local function Button(props)
    return React.createElement("View", {
        style = {
            backgroundColor = props.color or "#2196F3",
            borderRadius = 4,
            padding = 10,
            alignItems = "center",
        },
        onPress = props.onPress,
    },
        React.createElement("Text", {
            style = {
                color = "#FFFFFF",
                fontSize = 16,
                fontWeight = "bold",
            },
        }, props.title or "")
    )
end

return Button
```

- [ ] **Step 3: Implement TouchableOpacity**

```lua
-- components/TouchableOpacity.lua
local React = require("react")

local function TouchableOpacity(props)
    -- Unpack children from props and pass as varargs, consistent with Button
    local children = props.children
    if type(children) == "table" and children[1] then
        return React.createElement("View", {
            style = props.style,
            onPress = props.onPress,
            _touchFeedback = "opacity",
            _activeOpacity = props.activeOpacity or 0.2,
        }, unpack(children))
    else
        return React.createElement("View", {
            style = props.style,
            onPress = props.onPress,
            _touchFeedback = "opacity",
            _activeOpacity = props.activeOpacity or 0.2,
        }, children)
    end
end

return TouchableOpacity
```

- [ ] **Step 4: Commit**

```bash
git add components/Image.lua components/Button.lua components/TouchableOpacity.lua
git commit -m "feat: add Image, Button, TouchableOpacity components"
```

---

### Task 5.4: Components init + full module init

**Files:**
- Create: `components/init.lua`
- Create: `init.lua` (root module entry)

- [ ] **Step 1: Components init**

```lua
-- components/init.lua
return {
    View = require("components.View"),
    Text = require("components.Text"),
    Image = require("components.Image"),
    Button = require("components.Button"),
    TouchableOpacity = require("components.TouchableOpacity"),
}
```

- [ ] **Step 2: Root init.lua**

```lua
-- init.lua (react-solar2d root)
local React = require("react")
local ReactSolar2D = require("renderer")
local StyleSheet = require("style.StyleSheet")
local processColor = require("style.processColor")
local Components = require("components")

local RN = {}

-- React core
RN.createElement = React.createElement
RN.useState = React.useState
RN.useEffect = React.useEffect
RN.useLayoutEffect = React.useLayoutEffect
RN.useRef = React.useRef
RN.useMemo = React.useMemo
RN.useCallback = React.useCallback
RN.useContext = React.useContext
RN.useReducer = React.useReducer
RN.createContext = React.createContext
RN.Fragment = React.Fragment

-- Renderer
RN.render = ReactSolar2D.render
RN.unmount = ReactSolar2D.unmount

-- Style
RN.StyleSheet = StyleSheet

-- Components (also available as direct exports, RN-style)
RN.View = Components.View
RN.Text = Components.Text
RN.Image = Components.Image
RN.Button = Components.Button
RN.TouchableOpacity = Components.TouchableOpacity

return RN
```

- [ ] **Step 3: Commit**

```bash
git add components/init.lua init.lua
git commit -m "feat: add module entry points — components init and root init"
```

---

## Chunk 6: Layout ↔ Renderer Integration

### Task 6.1: Connect Flexbox to Reconciler commit phase

**Files:**
- Modify: `renderer/init.lua`
- Modify: `renderer/HostConfig.lua`

The reconciler currently positions elements based on explicit style.x/y, but never runs the flexbox engine. This task integrates `layout.calculateLayout` into the render pipeline so that flexbox properties actually position display objects.

- [ ] **Step 1: Add layout pass to renderer**

Update `renderer/init.lua` to run layout after reconciliation:

```lua
-- renderer/init.lua (updated)
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")
local Layout = require("layout")
local LayoutNode = require("layout.LayoutNode")

local ReactSolar2D = {}
local reconcilerInstance = nil

-- Build a LayoutNode tree mirroring the fiber tree
local function buildLayoutTree(fiber)
    if not fiber then return nil end
    if fiber.tag ~= "host" and fiber.tag ~= "root" then
        -- Function components: pass through to child
        return buildLayoutTree(fiber.child)
    end

    local style = (fiber.props and fiber.props.style) or {}
    local node = LayoutNode.new(style)
    node._fiber = fiber

    local child = fiber.child
    while child do
        local childNode = buildLayoutTree(child)
        if childNode then
            node:addChild(childNode)
        end
        child = child.sibling
    end

    return node
end

-- Apply computed layout positions to display objects
local function applyLayout(layoutNode)
    if not layoutNode then return end
    local fiber = layoutNode._fiber
    if fiber and fiber.stateNode then
        fiber.stateNode.x = layoutNode.layout.x
        fiber.stateNode.y = layoutNode.layout.y
        -- Update size for bg rect if present
        if fiber.stateNode._bg then
            fiber.stateNode._bg.path.width = layoutNode.layout.width
            fiber.stateNode._bg.path.height = layoutNode.layout.height
        end
    end

    for _, child in ipairs(layoutNode.children) do
        applyLayout(child)
    end
end

function ReactSolar2D.render(element, container, options)
    if not reconcilerInstance then
        reconcilerInstance = Reconciler.create(HostConfig)
    end
    reconcilerInstance.render(element, container)

    -- Run layout pass
    local width = (options and options.width) or (container.width > 0 and container.width) or display.contentWidth
    local height = (options and options.height) or (container.height > 0 and container.height) or display.contentHeight

    -- Build layout tree from fiber tree and calculate
    local rootFiber = reconcilerInstance._getRootFiber()
    if rootFiber then
        local layoutRoot = buildLayoutTree(rootFiber)
        if layoutRoot then
            Layout.calculateLayout(layoutRoot, width, height)
            applyLayout(layoutRoot)
        end
    end

    return reconcilerInstance
end

function ReactSolar2D.unmount(container)
    if reconcilerInstance then
        reconcilerInstance.unmount(container)
        reconcilerInstance = nil
    end
end

function ReactSolar2D.flushUpdates()
    if reconcilerInstance then
        reconcilerInstance.flushUpdates()
        -- Re-run layout after state updates (uses same approach)
        local rootFiber = reconcilerInstance._getRootFiber()
        if rootFiber and rootFiber.stateNode then
            local width = rootFiber.stateNode.width or display.contentWidth
            local height = rootFiber.stateNode.height or display.contentHeight
            local layoutRoot = buildLayoutTree(rootFiber)
            if layoutRoot then
                Layout.calculateLayout(layoutRoot, width, height)
                applyLayout(layoutRoot)
            end
        end
    end
end

function ReactSolar2D.startAutoFlush()
    Runtime:addEventListener("enterFrame", function()
        ReactSolar2D.flushUpdates()
    end)
end

return ReactSolar2D
```

- [ ] **Step 2: Expose `_getRootFiber` in Reconciler**

Add to the end of `reconciler` table in `react/Reconciler.lua`:

```lua
    function reconciler._getRootFiber()
        return rootFiber
    end
```

- [ ] **Step 3: Commit**

```bash
git add renderer/init.lua react/Reconciler.lua
git commit -m "feat: integrate flexbox layout engine with renderer pipeline"
```

---

## Chunk 7: Examples

### Task 7.1: HelloWorld example for Solar2D Simulator

**Files:**
- Create: `examples/main.lua`
- Create: `examples/HelloWorld.lua`
- Create: `examples/Counter.lua`

- [ ] **Step 1: Create main.lua (Solar2D entry)**

```lua
-- examples/main.lua
-- Solar2D entry point for react-solar2d demos
-- Add parent directory to package path
package.path = "../?.lua;../?/init.lua;" .. package.path

local RN = require("init")
local React = require("react")

-- Pick which demo to run
local demo = "counter" -- "hello" | "counter"

local container = display.newGroup()

if demo == "hello" then
    local HelloWorld = require("examples.HelloWorld")
    RN.render(React.createElement(HelloWorld), container)
elseif demo == "counter" then
    local Counter = require("examples.Counter")
    RN.render(React.createElement(Counter), container)
end

-- Auto-flush state updates on each frame
Runtime:addEventListener("enterFrame", function()
    RN.flushUpdates()
end)
```

- [ ] **Step 2: Create HelloWorld**

```lua
-- examples/HelloWorld.lua
local React = require("react")
local createElement = React.createElement

local function HelloWorld()
    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#F5F5F5",
            justifyContent = "center",
            alignItems = "center",
            width = display.contentWidth,
            height = display.contentHeight,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 32,
                color = "#333333",
                fontWeight = "bold",
            },
        }, "Hello, React-Solar2D!"),

        createElement("Text", {
            style = {
                fontSize = 18,
                color = "#666666",
                marginTop = 12,
            },
        }, "React Native API on Solar2D")
    )
end

return HelloWorld
```

- [ ] **Step 3: Create Counter (useState demo)**

```lua
-- examples/Counter.lua
local React = require("react")
local createElement = React.createElement

local function Counter()
    local count, setCount = React.useState(0)

    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#FFFFFF",
            justifyContent = "center",
            alignItems = "center",
            width = display.contentWidth,
            height = display.contentHeight,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 48,
                color = "#2196F3",
                fontWeight = "bold",
            },
        }, tostring(count)),

        createElement("View", {
            style = {
                flexDirection = "row",
                marginTop = 24,
                gap = 16,
            },
        },
            createElement("View", {
                style = {
                    backgroundColor = "#4CAF50",
                    borderRadius = 8,
                    padding = 16,
                    paddingLeft = 24,
                    paddingRight = 24,
                },
                onPress = function()
                    setCount(function(c) return c + 1 end)
                end,
            },
                createElement("Text", {
                    style = { color = "#FFFFFF", fontSize = 20 },
                }, "+1")
            ),

            createElement("View", {
                style = {
                    backgroundColor = "#F44336",
                    borderRadius = 8,
                    padding = 16,
                    paddingLeft = 24,
                    paddingRight = 24,
                },
                onPress = function()
                    setCount(0)
                end,
            },
                createElement("Text", {
                    style = { color = "#FFFFFF", fontSize = 20 },
                }, "Reset")
            )
        )
    )
end

return Counter
```

- [ ] **Step 4: Commit**

```bash
git add examples/
git commit -m "feat: add HelloWorld and Counter examples for Solar2D Simulator"
```

---

## Future Work (not in this plan)

The following are planned for subsequent implementation plans:

1. **ScrollView / FlatList** — touch-based scrolling with momentum physics, virtualized list
2. **Animated API** — Animated.Value, Animated.timing wrapping transition.to
3. **TextInput** — native.newTextField wrapper
4. **Modal** — overlay with touch blocker and transitions
5. **Context + Theme system** — Provider/Consumer for labo_* theme integration
6. ~~luaYoga C bindings~~ → **已独立成计划**: `docs/superpowers/plans/2026-03-15-yoga-c-binding.md` — Yoga v3.2.1 C 插件，替代 Chunk 4 的纯 Lua Flexbox
7. **Migration guide** — how to incrementally adopt in existing labo_* projects

> **Note:** View/Text/Image are host-type string constants, not actual function components. This means HOC wrapping and ref forwarding won't work on them directly. This is acceptable for MVP — can be upgraded to function components later if needed.
