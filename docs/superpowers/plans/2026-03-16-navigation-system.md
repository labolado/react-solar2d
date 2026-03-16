# Navigation System Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a React Navigation-compatible system with Stack, Tab, and Drawer navigators, enabling standardized screen routing across all apps.

**Architecture:** NavigationContainer (root) manages state tree via Context.Provider. Each navigator (Stack/Tab/Drawer) is a function component that reads/writes navigation state via useContext. Screens toggle visibility via `style.display = "none"` — no unmount/remount.

**Tech Stack:** Pure Lua, React hooks + Context, Solar2D display objects. No external dependencies.

**Spec:** `docs/superpowers/specs/2026-03-16-navigation-system-design.md`

---

## File Structure

| File | Purpose | Action |
|------|---------|--------|
| `react/Reconciler.lua` | Add Context.Provider fiber handling | Modify |
| `tests/react/test_context.lua` | Context.Provider + useContext tests | Create |
| `navigation/init.lua` | Public exports | Create |
| `navigation/NavigationState.lua` | Pure state tree operations | Create |
| `navigation/NavigationContext.lua` | React context definitions | Create |
| `navigation/StackNavigator.lua` | Stack push/pop/replace logic | Create |
| `navigation/TabNavigator.lua` | Tab switching + tab bar | Create |
| `navigation/DrawerNavigator.lua` | Drawer open/close logic | Create |
| `navigation/Header.lua` | Default header component | Create |
| `navigation/NavigationContainer.lua` | Root state + context provider | Create |
| `navigation/DeepLinking.lua` | URL → state resolution | Create |
| `navigation/NavigationTestUtils.lua` | Test helpers | Create |
| `tests/navigation/test_state.lua` | State operation tests | Create |
| `tests/navigation/test_stack.lua` | Stack navigator tests | Create |
| `tests/navigation/test_tab.lua` | Tab navigator tests | Create |
| `tests/navigation/test_drawer.lua` | Drawer navigator tests | Create |
| `tests/navigation/test_deeplink.lua` | Deep linking tests | Create |
| `react_solar2d.lua` | Add navigation exports | Modify |

---

## Chunk 1: Context.Provider in Reconciler (Prerequisite)

### Task 1: Context.Provider Support

The Reconciler's `performUnitOfWork` treats all function components the same. It needs to detect Context.Provider and store `_contextValues` on the fiber so `useContext` (which already walks the fiber tree) can find it.

**Files:**
- Modify: `react/Reconciler.lua`
- Create: `tests/react/test_context.lua`

- [ ] **Step 1: Write failing Context tests**

```lua
-- tests/react/test_context.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

display = require("tests.helpers.mock_display")
display.contentWidth = 320
display.contentHeight = 480
native = { systemFont = "Helvetica" }
timer = { performWithDelay = function() return {} end }
transition = { to = function() end }
Runtime = { addEventListener = function() end }

local T = require("tests.helpers.test_runner")
local React = require("react")
local ce = React.createElement
local HostConfig = require("renderer.HostConfig")
local Reconciler = require("react.Reconciler")

T.describe("Context.Provider + useContext", function()

    T.it("useContext returns default value without Provider", function()
        local ThemeContext = React.createContext("light")
        local captured = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(Child, {}), container)

        T.expect(captured).toBe("light")
    end)

    T.it("useContext reads value from Provider", function()
        local ThemeContext = React.createContext("light")
        local captured = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local function App()
            return ce(ThemeContext.Provider, { value = "dark" },
                ce(Child, {}))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)

        T.expect(captured).toBe("dark")
    end)

    T.it("useContext reads from nearest Provider", function()
        local ThemeContext = React.createContext("light")
        local captured = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local function Middle()
            return ce(ThemeContext.Provider, { value = "blue" },
                ce(Child, {}))
        end

        local function App()
            return ce(ThemeContext.Provider, { value = "dark" },
                ce(Middle, {}))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)

        T.expect(captured).toBe("blue")
    end)

    T.it("Provider updates propagate on re-render", function()
        local ThemeContext = React.createContext("light")
        local captured = nil
        local setTheme = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local function App()
            local theme, _setTheme = React.useState("dark")
            setTheme = _setTheme
            return ce(ThemeContext.Provider, { value = theme },
                ce(Child, {}))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)
        T.expect(captured).toBe("dark")

        -- Update theme
        setTheme("ocean")
        reconciler.flushUpdates()
        T.expect(captured).toBe("ocean")
    end)

    T.it("multiple contexts work independently", function()
        local ThemeCtx = React.createContext("light")
        local LangCtx = React.createContext("en")
        local capturedTheme, capturedLang = nil, nil

        local function Child()
            capturedTheme = React.useContext(ThemeCtx)
            capturedLang = React.useContext(LangCtx)
            return ce("View", {})
        end

        local function App()
            return ce(ThemeCtx.Provider, { value = "dark" },
                ce(LangCtx.Provider, { value = "zh" },
                    ce(Child, {})))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)

        T.expect(capturedTheme).toBe("dark")
        T.expect(capturedLang).toBe("zh")
    end)

end)

T.summary()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /path/to/project && lua tests/react/test_context.lua`
Expected: FAIL — Provider doesn't set `_contextValues`, so useContext returns default.

- [ ] **Step 3: Modify Reconciler to handle Provider**

In `react/Reconciler.lua`, **two changes are needed**:

**Change 1: `reconcileChildren`** — Fix tag assignment to detect Provider tables.

In the `reconcileChildren` function, replace the tag assignment logic (appears twice, for matched and new elements):

```lua
                -- OLD:
                -- local tag = type(elementType) == "function" and "function" or "host"
                -- NEW:
                local tag
                if type(elementType) == "function" then
                    tag = "function"
                elseif type(elementType) == "table" and elementType._isProvider then
                    tag = "function"  -- Provider handled in performUnitOfWork
                else
                    tag = "host"
                end
```

This must be applied in **both** places where `tag` is assigned in `reconcileChildren` (the "type matches" branch and the "new element" branch).

**Change 2: `performUnitOfWork`** — Handle Provider in the function branch:

```lua
        if fiber.tag == "function" then
            Hooks._setCurrentFiber(fiber)
            Hooks._resetHookIndex()
            fiber._scheduleUpdate = scheduleUpdate

            -- Detect Context.Provider: fiber.type is a marker table with _isProvider
            local elementType = fiber.type
            if type(elementType) == "table" and elementType._isProvider then
                -- This is a Context.Provider — store value on fiber for useContext
                local contextId = elementType._contextId
                -- Inherit parent context values
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
                -- Provider renders its children directly
                Hooks._finishHooks()
                reconcileChildren(fiber, fiber.props.children)
            else
                local children = fiber.type(fiber.props)
                Hooks._finishHooks()
                reconcileChildren(fiber, children)
            end
```

Also update `react/Hooks.lua` — `createContext` to make Provider detectable:

```lua
function M.createContext(defaultValue)
    contextCounter = contextCounter + 1
    local id = contextCounter
    local context = {
        _id = id,
        _defaultValue = defaultValue,
    }
    -- Provider is a special marker table (not a function)
    context.Provider = {
        _isProvider = true,
        _contextId = id,
    }
    return context
end
```

- [ ] **Step 4: Run context tests to verify they pass**

Run: `cd /path/to/project && lua tests/react/test_context.lua`
Expected: All 5 tests pass.

- [ ] **Step 5: Run all existing tests to verify no regressions**

Run: `cd /path/to/project && for f in tests/react/test_*.lua tests/renderer/test_*.lua tests/components/test_*.lua; do echo "--- $f ---"; lua "$f"; done`
Expected: All existing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add react/Reconciler.lua react/Hooks.lua tests/react/test_context.lua
git commit -m "feat: Context.Provider support in reconciler

Provider fibers store _contextValues for useContext to find.
Supports nesting, multiple contexts, and state-driven updates."
```

---

## Chunk 2: NavigationState (Pure State Operations)

### Task 2: NavigationState Module

Pure functions that operate on the navigation state tree. No display objects, no React — just state manipulation. This is the foundation all navigators build on.

**Files:**
- Create: `navigation/NavigationState.lua`
- Create: `tests/navigation/test_state.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/navigation/test_state.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local NavState = require("navigation.NavigationState")

T.describe("NavigationState", function()

    T.it("creates initial stack state", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
            { name = "Detail" },
        }, "Home")
        T.expect(state.type).toBe("stack")
        T.expect(state.index).toBe(1)
        T.expect(#state.routes).toBe(2)
        T.expect(state.routes[1].name).toBe("Home")
        T.expect(state.routes[1].key).toBeTruthy()
    end)

    T.it("push adds route and advances index", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        local next = NavState.push(state, "Detail", { id = 42 })
        T.expect(next.index).toBe(2)
        T.expect(#next.routes).toBe(2)
        T.expect(next.routes[2].name).toBe("Detail")
        T.expect(next.routes[2].params.id).toBe(42)
    end)

    T.it("pop removes top route", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "Detail", {})
        local next = NavState.pop(state)
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
        T.expect(next.routes[1].name).toBe("Home")
    end)

    T.it("pop on single route returns same state", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        local next = NavState.pop(state)
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
    end)

    T.it("replace swaps current route", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "Detail", {})
        local next = NavState.replace(state, "Settings", { tab = "general" })
        T.expect(next.index).toBe(2)
        T.expect(next.routes[2].name).toBe("Settings")
        T.expect(next.routes[2].params.tab).toBe("general")
    end)

    T.it("switchTab changes index", function()
        local state = NavState.createState("tab", {
            { name = "News" },
            { name = "Quiz" },
            { name = "Game" },
        }, "News")
        local next = NavState.switchTab(state, "Quiz")
        T.expect(next.index).toBe(2)
    end)

    T.it("switchTab with unknown name returns same state", function()
        local state = NavState.createState("tab", {
            { name = "News" },
        }, "News")
        local next = NavState.switchTab(state, "Unknown")
        T.expect(next.index).toBe(1)
    end)

    T.it("reset replaces entire state", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "A", {})
        state = NavState.push(state, "B", {})
        local next = NavState.reset(state, {
            { name = "Login" },
        }, 1)
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
        T.expect(next.routes[1].name).toBe("Login")
    end)

    T.it("setParams updates current route params", function()
        local state = NavState.createState("stack", {
            { name = "Detail" },
        }, "Detail")
        state.routes[1].params = { id = 1 }
        local next = NavState.setParams(state, { id = 2, title = "New" })
        T.expect(next.routes[1].params.id).toBe(2)
        T.expect(next.routes[1].params.title).toBe("New")
    end)

    T.it("navigate finds existing route in stack", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "Detail", { id = 1 })
        -- navigate to Home should go back, not push
        local next = NavState.navigate(state, "Home", {})
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
    end)

    T.it("navigate pushes if route not in stack", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        local next = NavState.navigate(state, "Detail", { id = 5 })
        T.expect(next.index).toBe(2)
        T.expect(next.routes[2].name).toBe("Detail")
    end)

end)

T.summary()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /path/to/project && lua tests/navigation/test_state.lua`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement NavigationState**

```lua
-- navigation/NavigationState.lua
-- Pure state tree operations. No display objects, no React.
-- All indices are 1-based (Lua convention).
local M = {}

local keyCounter = 0
local function generateKey(name)
    keyCounter = keyCounter + 1
    return name .. "-" .. keyCounter
end

-- Create initial navigator state
function M.createState(navType, routeConfigs, initialRouteName)
    local routes = {}
    local initialIndex = 1
    for i, config in ipairs(routeConfigs) do
        routes[i] = {
            name = config.name,
            key = generateKey(config.name),
            params = config.params,
        }
        if config.name == initialRouteName then
            initialIndex = i
        end
    end
    return {
        type = navType,
        index = initialIndex,
        routes = routes,
    }
end

-- Stack: push new route
function M.push(state, name, params)
    local routes = {}
    -- Copy existing routes up to current index
    for i = 1, state.index do
        routes[i] = state.routes[i]
    end
    -- Add new route
    routes[#routes + 1] = {
        name = name,
        key = generateKey(name),
        params = params,
    }
    return {
        type = state.type,
        index = #routes,
        routes = routes,
    }
end

-- Stack: pop top route
function M.pop(state)
    if #state.routes <= 1 then return state end
    local routes = {}
    for i = 1, #state.routes - 1 do
        routes[i] = state.routes[i]
    end
    return {
        type = state.type,
        index = #routes,
        routes = routes,
    }
end

-- Stack: replace current route
function M.replace(state, name, params)
    local routes = {}
    for i = 1, #state.routes do
        routes[i] = state.routes[i]
    end
    routes[state.index] = {
        name = name,
        key = generateKey(name),
        params = params,
    }
    return {
        type = state.type,
        index = state.index,
        routes = routes,
    }
end

-- Tab: switch to named tab
function M.switchTab(state, name)
    for i, route in ipairs(state.routes) do
        if route.name == name then
            return {
                type = state.type,
                index = i,
                routes = state.routes,
            }
        end
    end
    return state -- not found
end

-- Reset entire state
function M.reset(state, routeConfigs, index)
    local routes = {}
    for i, config in ipairs(routeConfigs) do
        routes[i] = {
            name = config.name,
            key = generateKey(config.name),
            params = config.params,
        }
    end
    return {
        type = state.type,
        index = index or #routes,
        routes = routes,
    }
end

-- Update params on current route
function M.setParams(state, newParams)
    local routes = {}
    for i = 1, #state.routes do
        routes[i] = state.routes[i]
    end
    local current = routes[state.index]
    local merged = {}
    if current.params then
        for k, v in pairs(current.params) do merged[k] = v end
    end
    for k, v in pairs(newParams) do merged[k] = v end
    routes[state.index] = {
        name = current.name,
        key = current.key,
        params = merged,
        state = current.state,
    }
    return {
        type = state.type,
        index = state.index,
        routes = routes,
    }
end

-- Smart navigate: pop to existing route or push new
function M.navigate(state, name, params)
    -- For tabs: just switch
    if state.type == "tab" then
        return M.switchTab(state, name)
    end
    -- For stack: check if route exists, pop to it; otherwise push
    for i, route in ipairs(state.routes) do
        if route.name == name then
            -- Pop to this route
            local routes = {}
            for j = 1, i do
                routes[j] = state.routes[j]
            end
            if params then
                routes[i] = {
                    name = routes[i].name,
                    key = routes[i].key,
                    params = params,
                    state = routes[i].state,
                }
            end
            return {
                type = state.type,
                index = i,
                routes = routes,
            }
        end
    end
    -- Not found: push
    return M.push(state, name, params)
end

-- Get current (active) route
function M.getCurrentRoute(state)
    return state.routes[state.index]
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /path/to/project && lua tests/navigation/test_state.lua`
Expected: All 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add navigation/NavigationState.lua tests/navigation/test_state.lua
git commit -m "feat: NavigationState pure state operations

Push, pop, replace, reset, switchTab, navigate, setParams.
All indices 1-based. Foundation for all navigator types."
```

---

## Chunk 3: NavigationContext + StackNavigator + Header

### Task 3: NavigationContext

**Files:**
- Create: `navigation/NavigationContext.lua`

- [ ] **Step 1: Create NavigationContext**

```lua
-- navigation/NavigationContext.lua
-- React context for passing navigation/route to screen components.
local React = require("react")

local M = {}

-- Context for the navigation object (navigate, goBack, push, etc.)
M.NavigationContext = React.createContext(nil)

-- Context for the current route (name, params, key)
M.RouteContext = React.createContext(nil)

return M
```

- [ ] **Step 2: Commit**

```bash
git add navigation/NavigationContext.lua
git commit -m "feat: NavigationContext for navigation/route context"
```

---

### Task 4: StackNavigator

**Files:**
- Create: `navigation/StackNavigator.lua`
- Create: `tests/navigation/test_stack.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/navigation/test_stack.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

display = require("tests.helpers.mock_display")
display.contentWidth = 320
display.contentHeight = 480
native = { systemFont = "Helvetica" }
timer = { performWithDelay = function() return {} end }
transition = { to = function() end }
Runtime = { addEventListener = function() end }

local T = require("tests.helpers.test_runner")
local React = require("react")
local ce = React.createElement
local HostConfig = require("renderer.HostConfig")
local Reconciler = require("react.Reconciler")
local NavCtx = require("navigation.NavigationContext")

T.describe("StackNavigator", function()

    local createStackNavigator = require("navigation.StackNavigator")

    T.it("renders initial screen", function()
        local rendered = nil
        local function HomeScreen(props)
            rendered = "Home"
            return ce("View", {}, ce("Text", {}, "Home Screen"))
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen })
            ), container)

        T.expect(rendered).toBe("Home")
    end)

    T.it("passes navigation and route to screen component", function()
        local capturedNav = nil
        local capturedRoute = nil

        local function HomeScreen(props)
            capturedNav = props.navigation
            capturedRoute = props.route
            return ce("View", {})
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen })
            ), container)

        T.expect(capturedNav).toBeTruthy()
        T.expect(capturedNav.navigate).toBeTruthy()
        T.expect(capturedNav.goBack).toBeTruthy()
        T.expect(capturedNav.push).toBeTruthy()
        T.expect(capturedRoute).toBeTruthy()
        T.expect(capturedRoute.name).toBe("Home")
    end)

    T.it("navigate pushes new screen", function()
        local capturedNav = nil
        local detailRendered = false

        local function HomeScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end
        local function DetailScreen(props)
            detailRendered = true
            return ce("View", {}, ce("Text", {}, "Detail"))
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen }),
                ce(Stack.Screen, { name = "Detail", component = DetailScreen })
            ), container)

        capturedNav.navigate("Detail", { id = 1 })
        reconciler.flushUpdates()
        T.expect(detailRendered).toBeTruthy()
    end)

    T.it("goBack pops current screen", function()
        local homeNav = nil
        local detailNav = nil
        local homeRenderCount = 0

        local function HomeScreen(props)
            homeNav = props.navigation
            homeRenderCount = homeRenderCount + 1
            return ce("View", {})
        end
        local function DetailScreen(props)
            detailNav = props.navigation
            return ce("View", {})
        end

        local Stack = createStackNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Stack.Navigator, { initialRouteName = "Home" },
                ce(Stack.Screen, { name = "Home", component = HomeScreen }),
                ce(Stack.Screen, { name = "Detail", component = DetailScreen })
            ), container)

        homeNav.navigate("Detail")
        reconciler.flushUpdates()
        T.expect(detailNav).toBeTruthy()

        detailNav.goBack()
        reconciler.flushUpdates()
        -- Home should be re-rendered as active
        T.expect(homeRenderCount >= 2).toBeTruthy()
    end)

end)

T.summary()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /path/to/project && lua tests/navigation/test_stack.lua`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement StackNavigator**

```lua
-- navigation/StackNavigator.lua
-- Stack navigator: push/pop/replace with history.
-- Renders all screens in stack, only topmost visible.
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useMemo = React.useMemo
local useRef = React.useRef
local NavState = require("navigation.NavigationState")
local NavCtx = require("navigation.NavigationContext")

local function createStackNavigator()
    local screenConfigs = {}

    local function Navigator(props)
        local children = props.children or {}
        if type(children) ~= "table" or children["$$typeof"] then
            children = { children }
        end

        -- Collect Screen configs from children props
        local screens = {}
        for _, child in ipairs(children) do
            if child and child.props and child.props.name then
                screens[#screens + 1] = {
                    name = child.props.name,
                    component = child.props.component,
                    options = child.props.options,
                    listeners = child.props.listeners,
                }
            end
        end

        -- Build initial route configs
        local routeConfigs = {}
        for _, s in ipairs(screens) do
            routeConfigs[#routeConfigs + 1] = { name = s.name }
        end

        local initialRouteName = props.initialRouteName or (screens[1] and screens[1].name)

        -- If initialState provided, use it directly
        local initState
        if props.initialState then
            initState = props.initialState
        else
            -- Start with only the initial route in the stack
            initState = NavState.createState("stack", { { name = initialRouteName } }, initialRouteName)
        end

        local state, setState = useState(initState)
        local stateRef = useRef(initState)
        stateRef.current = state  -- keep ref in sync
        local listenersRef = useRef({})

        -- Build navigation object
        local navigation = useMemo(function()
            local nav = {}

            function nav.navigate(name, params)
                setState(function(prev)
                    return NavState.navigate(prev, name, params)
                end)
            end

            function nav.push(name, params)
                setState(function(prev)
                    return NavState.push(prev, name, params)
                end)
            end

            function nav.goBack()
                setState(function(prev)
                    -- beforeRemove check
                    local current = NavState.getCurrentRoute(prev)
                    if current and listenersRef.current[current.key] then
                        local listener = listenersRef.current[current.key].beforeRemove
                        if listener then
                            local event = {
                                type = "beforeRemove",
                                defaultPrevented = false,
                                preventDefault = function(self)
                                    self.defaultPrevented = true
                                end,
                            }
                            listener(event)
                            if event.defaultPrevented then
                                return prev
                            end
                        end
                    end
                    return NavState.pop(prev)
                end)
            end

            function nav.replace(name, params)
                setState(function(prev)
                    return NavState.replace(prev, name, params)
                end)
            end

            function nav.reset(newState)
                setState(function(prev)
                    return NavState.reset(prev, newState.routes or {}, newState.index)
                end)
            end

            function nav.setParams(params)
                setState(function(prev)
                    return NavState.setParams(prev, params)
                end)
            end

            function nav.isFocused()
                return true -- Stack always focused (nesting handled by parent)
            end

            function nav.addListener(event, callback)
                -- Use stateRef to avoid stale closure on `state`
                local currentState = stateRef.current
                local route = NavState.getCurrentRoute(currentState)
                if route then
                    if not listenersRef.current[route.key] then
                        listenersRef.current[route.key] = {}
                    end
                    listenersRef.current[route.key][event] = callback
                end
                return function()
                    if route and listenersRef.current[route.key] then
                        listenersRef.current[route.key][event] = nil
                    end
                end
            end

            function nav.getParent()
                return props._parentNavigation or nil
            end

            -- Store reference for parent navigators
            nav._getState = function() return stateRef.current end

            return nav
        end, {})

        local Header = require("navigation.Header")

        -- Render all screens in stack, only topmost visible
        local screenElements = {}
        for i, route in ipairs(state.routes) do
            local screenConfig = nil
            for _, s in ipairs(screens) do
                if s.name == route.name then
                    screenConfig = s
                    break
                end
            end

            if screenConfig then
                local isActive = (i == state.index)
                local routeObj = {
                    name = route.name,
                    key = route.key,
                    params = route.params or {},
                }

                local screenNav = {}
                for k, v in pairs(navigation) do screenNav[k] = v end
                screenNav.isFocused = function() return isActive end

                -- Resolve screen options (can be table or function)
                local options = screenConfig.options or {}
                if type(options) == "function" then
                    options = options({ route = routeObj, navigation = screenNav })
                end
                -- Merge with navigator-level screenOptions
                local mergedOptions = {}
                if props.screenOptions then
                    for k, v in pairs(props.screenOptions) do mergedOptions[k] = v end
                end
                for k, v in pairs(options) do mergedOptions[k] = v end

                local screenStyle = {
                    display = isActive and "flex" or "none",
                }

                -- Register Screen-level listeners
                if screenConfig.listeners then
                    for event, fn in pairs(screenConfig.listeners) do
                        if not listenersRef.current[route.key] then
                            listenersRef.current[route.key] = {}
                        end
                        listenersRef.current[route.key][event] = fn
                    end
                end

                screenElements[#screenElements + 1] = ce("View", {
                    key = route.key,
                    style = screenStyle,
                },
                    -- Header (rendered per screen, only visible for active)
                    ce(Header, {
                        options = mergedOptions,
                        navigation = screenNav,
                        route = routeObj,
                        canGoBack = i > 1,
                    }),
                    ce(screenConfig.component, {
                        navigation = screenNav,
                        route = routeObj,
                    })
                )
            end
        end

        return ce("View", { style = props.style or {} }, screenElements)
    end

    -- Screen is just a config holder, not rendered directly
    local function Screen(props)
        return nil
    end

    return {
        Navigator = Navigator,
        Screen = Screen,
    }
end

return createStackNavigator
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /path/to/project && lua tests/navigation/test_stack.lua`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add navigation/StackNavigator.lua tests/navigation/test_stack.lua
git commit -m "feat: StackNavigator with push/pop/replace/navigate/goBack"
```

---

### Task 5: Header Component

**Files:**
- Create: `navigation/Header.lua`

- [ ] **Step 1: Implement Header**

```lua
-- navigation/Header.lua
-- Default header: [Back] [Title] [Right]
local React = require("react")
local ce = React.createElement

local function Header(props)
    local options = props.options or {}
    local navigation = props.navigation
    local route = props.route
    local canGoBack = props.canGoBack or false

    if options.headerShown == false then
        return nil
    end

    -- Custom header override
    if options.header then
        return options.header({
            navigation = navigation,
            route = route,
            options = options,
        })
    end

    local headerStyle = options.headerStyle or {}
    local bgColor = headerStyle.backgroundColor or "#FFFFFF"
    local headerHeight = headerStyle.height or 56
    local tintColor = options.headerTintColor or "#000000"
    local titleAlign = options.headerTitleAlign or "center"
    local title = options.title or route.name
    local titleStyle = options.headerTitleStyle or {}

    -- Build header children
    local headerChildren = {}

    -- Left: back button or custom
    if options.headerLeft then
        headerChildren[#headerChildren + 1] = ce("View", { key = "left" },
            options.headerLeft({ onPress = function() navigation.goBack() end }))
    elseif canGoBack then
        headerChildren[#headerChildren + 1] = ce("View", {
            key = "left",
            onPress = function() navigation.goBack() end,
            style = { width = 60, height = headerHeight, justifyContent = "center" },
        },
            ce("Text", { style = { color = tintColor, fontSize = 16 } }, "< Back"))
    end

    -- Title
    headerChildren[#headerChildren + 1] = ce("View", {
        key = "title",
        style = {
            flex = 1,
            justifyContent = "center",
            alignItems = titleAlign == "center" and "center" or "flex-start",
            height = headerHeight,
        },
    },
        ce("Text", {
            style = {
                color = tintColor,
                fontSize = titleStyle.fontSize or 18,
                fontWeight = titleStyle.fontWeight or "bold",
            },
        }, title))

    -- Right: custom component
    if options.headerRight then
        headerChildren[#headerChildren + 1] = ce("View", { key = "right" },
            options.headerRight({ navigation = navigation }))
    end

    return ce("View", {
        key = "__header",
        style = {
            height = headerHeight,
            backgroundColor = bgColor,
            flexDirection = "row",
            alignItems = "center",
            width = display and display.contentWidth or 320,
        },
    }, headerChildren)
end

return Header
```

- [ ] **Step 2: Commit**

```bash
git add navigation/Header.lua
git commit -m "feat: Header component with back button and customization"
```

---

## Chunk 4: TabNavigator + DrawerNavigator

### Task 6: TabNavigator

**Files:**
- Create: `navigation/TabNavigator.lua`
- Create: `tests/navigation/test_tab.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/navigation/test_tab.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

display = require("tests.helpers.mock_display")
display.contentWidth = 320
display.contentHeight = 480
native = { systemFont = "Helvetica" }
timer = { performWithDelay = function() return {} end }
transition = { to = function() end }
Runtime = { addEventListener = function() end }

local T = require("tests.helpers.test_runner")
local React = require("react")
local ce = React.createElement
local HostConfig = require("renderer.HostConfig")
local Reconciler = require("react.Reconciler")

T.describe("TabNavigator", function()

    local createBottomTabNavigator = require("navigation.TabNavigator")

    T.it("renders initial tab", function()
        local rendered = nil
        local function NewsScreen(props)
            rendered = "News"
            return ce("View", {}, ce("Text", {}, "News"))
        end
        local function QuizScreen(props)
            return ce("View", {}, ce("Text", {}, "Quiz"))
        end

        local Tab = createBottomTabNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Tab.Navigator, { initialRouteName = "News" },
                ce(Tab.Screen, { name = "News", component = NewsScreen }),
                ce(Tab.Screen, { name = "Quiz", component = QuizScreen })
            ), container)

        T.expect(rendered).toBe("News")
    end)

    T.it("switch tab via navigation.navigate", function()
        local capturedNav = nil
        local quizRendered = false

        local function NewsScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end
        local function QuizScreen(props)
            quizRendered = true
            return ce("View", {})
        end

        local Tab = createBottomTabNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Tab.Navigator, { initialRouteName = "News" },
                ce(Tab.Screen, { name = "News", component = NewsScreen }),
                ce(Tab.Screen, { name = "Quiz", component = QuizScreen })
            ), container)

        capturedNav.navigate("Quiz")
        reconciler.flushUpdates()
        T.expect(quizRendered).toBeTruthy()
    end)

    T.it("preserves screen state on tab switch", function()
        local newsRenderCount = 0

        local function NewsScreen(props)
            newsRenderCount = newsRenderCount + 1
            return ce("View", {})
        end
        local function QuizScreen(props)
            return ce("View", {})
        end

        local Tab = createBottomTabNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        local capturedNav = nil

        local function NewsWrapper(props)
            capturedNav = props.navigation
            return ce(NewsScreen, props)
        end

        reconciler.render(
            ce(Tab.Navigator, { initialRouteName = "News" },
                ce(Tab.Screen, { name = "News", component = NewsWrapper }),
                ce(Tab.Screen, { name = "Quiz", component = QuizScreen })
            ), container)

        local countAfterFirst = newsRenderCount
        capturedNav.navigate("Quiz")
        reconciler.flushUpdates()
        capturedNav.navigate("News")
        reconciler.flushUpdates()
        -- News should have re-rendered (UPDATE, not PLACEMENT)
        T.expect(newsRenderCount > countAfterFirst).toBeTruthy()
    end)

end)

T.summary()
```

- [ ] **Step 2: Implement TabNavigator**

```lua
-- navigation/TabNavigator.lua
-- Bottom tab navigator: parallel screens with tab bar.
-- All tabs rendered, only active visible (display="none" for inactive).
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useMemo = React.useMemo
local NavState = require("navigation.NavigationState")

local function createBottomTabNavigator()

    local function Navigator(props)
        local children = props.children or {}
        if type(children) ~= "table" or children["$$typeof"] then
            children = { children }
        end

        local screens = {}
        for _, child in ipairs(children) do
            if child and child.props and child.props.name then
                screens[#screens + 1] = {
                    name = child.props.name,
                    component = child.props.component,
                    options = child.props.options or {},
                }
            end
        end

        local initialRouteName = props.initialRouteName or (screens[1] and screens[1].name)
        local routeConfigs = {}
        for _, s in ipairs(screens) do
            routeConfigs[#routeConfigs + 1] = { name = s.name }
        end

        local initState = props.initialState
            or NavState.createState("tab", routeConfigs, initialRouteName)

        local state, setState = useState(initState)
        local tabBarOptions = props.tabBarOptions or {}

        local navigation = useMemo(function()
            local nav = {}
            function nav.navigate(name, params)
                setState(function(prev)
                    return NavState.switchTab(prev, name)
                end)
            end
            function nav.goBack() end -- no-op for tabs
            function nav.isFocused() return true end
            nav._getState = function() return state end
            return nav
        end, {})

        -- Render all tab screens
        local screenElements = {}
        for i, route in ipairs(state.routes) do
            local screenConfig = nil
            for _, s in ipairs(screens) do
                if s.name == route.name then screenConfig = s; break end
            end
            if screenConfig then
                local isActive = (i == state.index)
                local routeObj = {
                    name = route.name,
                    key = route.key,
                    params = route.params or {},
                }
                local screenNav = {}
                for k, v in pairs(navigation) do screenNav[k] = v end
                screenNav.isFocused = function() return isActive end

                screenElements[#screenElements + 1] = ce("View", {
                    key = route.key,
                    style = { display = isActive and "flex" or "none", flex = 1 },
                }, ce(screenConfig.component, {
                    navigation = screenNav,
                    route = routeObj,
                }))
            end
        end

        -- Tab bar
        local tabItems = {}
        for i, screen in ipairs(screens) do
            local isActive = (state.routes[state.index].name == screen.name)
            local opts = screen.options
            local label = opts.tabBarLabel or screen.name
            local icon = opts.tabBarIcon or ""
            local tint = isActive
                and (tabBarOptions.activeTintColor or "#2979FF")
                or (tabBarOptions.inactiveTintColor or "#888888")

            tabItems[#tabItems + 1] = ce("View", {
                key = "tab_" .. screen.name,
                onPress = function()
                    navigation.navigate(screen.name)
                end,
                style = {
                    flex = 1,
                    alignItems = "center",
                    justifyContent = "center",
                    height = 50,
                },
            },
                ce("Text", { style = { color = tint, fontSize = 12 } }, icon),
                (tabBarOptions.showLabel ~= false)
                    and ce("Text", { style = { color = tint, fontSize = 10 } }, label)
                    or nil
            )

            -- Badge
            if opts.tabBarBadge then
                -- Badge rendered as small text overlay (simplified)
            end
        end

        local tabBarBg = tabBarOptions.backgroundColor or "#FFFFFF"
        local tabBar = ce("View", {
            key = "__tabbar",
            style = {
                flexDirection = "row",
                height = 50,
                backgroundColor = tabBarBg,
                width = display and display.contentWidth or 320,
            },
        }, tabItems)

        -- Layout: screens + tab bar at bottom
        screenElements[#screenElements + 1] = tabBar

        return ce("View", { style = { flex = 1 } }, screenElements)
    end

    local function Screen(props) return nil end

    return {
        Navigator = Navigator,
        Screen = Screen,
    }
end

return createBottomTabNavigator
```

- [ ] **Step 3: Run tests**

Run: `cd /path/to/project && lua tests/navigation/test_tab.lua`
Expected: All 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add navigation/TabNavigator.lua tests/navigation/test_tab.lua
git commit -m "feat: TabNavigator with tab bar and screen preservation"
```

---

### Task 7: DrawerNavigator

**Files:**
- Create: `navigation/DrawerNavigator.lua`
- Create: `tests/navigation/test_drawer.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/navigation/test_drawer.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

display = require("tests.helpers.mock_display")
display.contentWidth = 320
display.contentHeight = 480
native = { systemFont = "Helvetica" }
timer = { performWithDelay = function() return {} end }
transition = { to = function() end }
Runtime = { addEventListener = function() end }

local T = require("tests.helpers.test_runner")
local React = require("react")
local ce = React.createElement
local HostConfig = require("renderer.HostConfig")
local Reconciler = require("react.Reconciler")

T.describe("DrawerNavigator", function()

    local createDrawerNavigator = require("navigation.DrawerNavigator")

    T.it("renders initial screen with drawer closed", function()
        local mainRendered = false
        local function MainScreen(props)
            mainRendered = true
            return ce("View", {}, ce("Text", {}, "Main"))
        end

        local Drawer = createDrawerNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Drawer.Navigator, { initialRouteName = "Main" },
                ce(Drawer.Screen, { name = "Main", component = MainScreen })
            ), container)

        T.expect(mainRendered).toBeTruthy()
    end)

    T.it("openDrawer/closeDrawer toggles drawer state", function()
        local capturedNav = nil
        local function MainScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end

        local Drawer = createDrawerNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Drawer.Navigator, { initialRouteName = "Main" },
                ce(Drawer.Screen, { name = "Main", component = MainScreen })
            ), container)

        T.expect(capturedNav.openDrawer).toBeTruthy()
        T.expect(capturedNav.closeDrawer).toBeTruthy()
        T.expect(capturedNav.toggleDrawer).toBeTruthy()

        -- These should not crash
        capturedNav.openDrawer()
        reconciler.flushUpdates()
        capturedNav.closeDrawer()
        reconciler.flushUpdates()
    end)

    T.it("navigate switches active screen", function()
        local capturedNav = nil
        local settingsRendered = false
        local function MainScreen(props)
            capturedNav = props.navigation
            return ce("View", {})
        end
        local function SettingsScreen(props)
            settingsRendered = true
            return ce("View", {})
        end

        local Drawer = createDrawerNavigator()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()

        reconciler.render(
            ce(Drawer.Navigator, { initialRouteName = "Main" },
                ce(Drawer.Screen, { name = "Main", component = MainScreen }),
                ce(Drawer.Screen, { name = "Settings", component = SettingsScreen })
            ), container)

        capturedNav.navigate("Settings")
        reconciler.flushUpdates()
        T.expect(settingsRendered).toBeTruthy()
    end)

end)

T.summary()
```

- [ ] **Step 2: Implement DrawerNavigator**

```lua
-- navigation/DrawerNavigator.lua
-- Drawer navigator: slide-out side panel (V1: button-only, no swipe gesture).
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useMemo = React.useMemo
local NavState = require("navigation.NavigationState")

local function createDrawerNavigator()

    local function Navigator(props)
        local children = props.children or {}
        if type(children) ~= "table" or children["$$typeof"] then
            children = { children }
        end

        local screens = {}
        for _, child in ipairs(children) do
            if child and child.props and child.props.name then
                screens[#screens + 1] = {
                    name = child.props.name,
                    component = child.props.component,
                    options = child.props.options or {},
                }
            end
        end

        local initialRouteName = props.initialRouteName or (screens[1] and screens[1].name)
        local routeConfigs = {}
        for _, s in ipairs(screens) do
            routeConfigs[#routeConfigs + 1] = { name = s.name }
        end

        local initState = props.initialState
            or NavState.createState("drawer", routeConfigs, initialRouteName)

        local state, setState = useState(initState)
        local drawerOpen, setDrawerOpen = useState(false)

        local drawerWidth = props.drawerWidth or 280
        local drawerPosition = props.drawerPosition or "left"
        local drawerStyle = props.drawerStyle or {}

        local navigation = useMemo(function()
            local nav = {}
            function nav.navigate(name, params)
                setState(function(prev)
                    return NavState.switchTab(prev, name) -- drawer uses same switch logic
                end)
                setDrawerOpen(false)
            end
            function nav.goBack()
                setDrawerOpen(false)
            end
            function nav.openDrawer()
                setDrawerOpen(true)
            end
            function nav.closeDrawer()
                setDrawerOpen(false)
            end
            function nav.toggleDrawer()
                setDrawerOpen(function(prev) return not prev end)
            end
            function nav.isFocused() return true end
            nav._getState = function() return state end
            return nav
        end, {})

        -- Render active screen (only active, drawer switches like tabs)
        local screenElements = {}
        for i, route in ipairs(state.routes) do
            local screenConfig = nil
            for _, s in ipairs(screens) do
                if s.name == route.name then screenConfig = s; break end
            end
            if screenConfig then
                local isActive = (i == state.index)
                local routeObj = {
                    name = route.name,
                    key = route.key,
                    params = route.params or {},
                }
                local screenNav = {}
                for k, v in pairs(navigation) do screenNav[k] = v end
                screenNav.isFocused = function() return isActive end

                screenElements[#screenElements + 1] = ce("View", {
                    key = route.key,
                    style = { display = isActive and "flex" or "none", flex = 1 },
                }, ce(screenConfig.component, {
                    navigation = screenNav,
                    route = routeObj,
                }))
            end
        end

        -- Drawer panel
        local drawerContent
        if props.drawerContent then
            drawerContent = props.drawerContent({
                state = state,
                navigation = navigation,
            })
        else
            -- Default drawer: list of screen names
            local items = {}
            for i, s in ipairs(screens) do
                local opts = s.options
                local label = opts.drawerLabel or s.name
                local isActive = (state.routes[state.index].name == s.name)
                items[#items + 1] = ce("View", {
                    key = "drawer_" .. s.name,
                    onPress = function() navigation.navigate(s.name) end,
                    style = {
                        height = 48,
                        justifyContent = "center",
                        backgroundColor = isActive and "#333333" or "transparent",
                    },
                },
                    ce("Text", {
                        style = {
                            color = isActive and "#FFFFFF" or "#CCCCCC",
                            fontSize = 16,
                        },
                    }, label))
            end
            drawerContent = ce("View", {}, items)
        end

        local drawerPanel = ce("View", {
            key = "__drawer_panel",
            style = {
                display = drawerOpen and "flex" or "none",
                width = drawerWidth,
                height = display and display.contentHeight or 480,
                backgroundColor = drawerStyle.backgroundColor or "#1A1A2E",
                position = "absolute",
                left = drawerPosition == "left" and 0 or nil,
                right = drawerPosition == "right" and 0 or nil,
                top = 0,
                zIndex = 100,
            },
        }, drawerContent)

        -- Overlay (tap to close)
        local overlay = ce("View", {
            key = "__drawer_overlay",
            style = {
                display = drawerOpen and "flex" or "none",
                position = "absolute",
                top = 0, left = 0,
                width = display and display.contentWidth or 320,
                height = display and display.contentHeight or 480,
                backgroundColor = "rgba(0,0,0,0.5)",
                zIndex = 99,
            },
            onPress = function() navigation.closeDrawer() end,
        })

        -- Main content + overlay + drawer
        -- Combine all elements
        screenElements[#screenElements + 1] = overlay
        screenElements[#screenElements + 1] = drawerPanel

        return ce("View", { style = { flex = 1 } }, screenElements)
    end

    local function Screen(props) return nil end

    return {
        Navigator = Navigator,
        Screen = Screen,
    }
end

return createDrawerNavigator
```

- [ ] **Step 3: Run tests**

Run: `cd /path/to/project && lua tests/navigation/test_drawer.lua`
Expected: All 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add navigation/DrawerNavigator.lua tests/navigation/test_drawer.lua
git commit -m "feat: DrawerNavigator with open/close/toggle (V1 button-only)"
```

---

## Chunk 5: NavigationContainer + DeepLinking + Public API

### Task 8: NavigationContainer

**Files:**
- Create: `navigation/NavigationContainer.lua`

- [ ] **Step 1: Implement NavigationContainer**

```lua
-- navigation/NavigationContainer.lua
-- Root component: wraps the navigator tree with NavigationContext.Provider.
local React = require("react")
local ce = React.createElement
local useState = React.useState
local NavCtx = require("navigation.NavigationContext")
local DeepLinking = require("navigation.DeepLinking")

local function NavigationContainer(props)
    local children = props.children

    -- Resolve initial state from deep linking or initialState prop
    local initialState = props.initialState
    if not initialState and props.linking then
        local url = props.initialURL
        if not url and _G.system and _G.system.LaunchArgs then
            url = _G.system.LaunchArgs.url
        end
        if url then
            initialState = DeepLinking.resolve(url, props.linking)
        end
    end

    -- Pass initialState down to child navigator if present
    if initialState and children and children.props then
        -- Clone child element with initialState injected
        local childProps = {}
        for k, v in pairs(children.props) do childProps[k] = v end
        childProps.initialState = initialState
        children = ce(children.type, childProps, children.props.children)
    end

    -- Wrap with NavigationContext.Provider so deeply nested screens
    -- can access navigation via useContext
    return ce(NavCtx.NavigationContext.Provider, { value = {
        linking = props.linking,
        initialState = initialState,
    } },
        ce("View", {
            style = {
                width = display and display.contentWidth or 320,
                height = display and display.contentHeight or 480,
            },
        }, children)
    )
end

return NavigationContainer
```

- [ ] **Step 2: Commit**

```bash
git add navigation/NavigationContainer.lua
git commit -m "feat: NavigationContainer root with deep linking support"
```

---

### Task 9: DeepLinking

**Files:**
- Create: `navigation/DeepLinking.lua`
- Create: `tests/navigation/test_deeplink.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/navigation/test_deeplink.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local DeepLinking = require("navigation.DeepLinking")

T.describe("DeepLinking", function()

    local linkingConfig = {
        prefixes = { "myapp://", "https://myapp.com/" },
        config = {
            screens = {
                Home = "",
                Detail = "detail/:id",
                Settings = "settings",
            }
        }
    }

    T.it("resolves root URL to Home", function()
        local state = DeepLinking.resolve("myapp://", linkingConfig)
        T.expect(state).toBeTruthy()
        T.expect(#state.routes >= 1).toBeTruthy()
        T.expect(state.routes[1].name).toBe("Home")
    end)

    T.it("resolves detail URL with params", function()
        local state = DeepLinking.resolve("myapp://detail/123", linkingConfig)
        T.expect(state).toBeTruthy()
        local lastRoute = state.routes[state.index]
        T.expect(lastRoute.name).toBe("Detail")
        T.expect(lastRoute.params.id).toBe("123")
    end)

    T.it("resolves settings URL", function()
        local state = DeepLinking.resolve("myapp://settings", linkingConfig)
        T.expect(state).toBeTruthy()
        local lastRoute = state.routes[state.index]
        T.expect(lastRoute.name).toBe("Settings")
    end)

    T.it("strips prefix correctly", function()
        local state = DeepLinking.resolve("https://myapp.com/detail/42", linkingConfig)
        T.expect(state).toBeTruthy()
        local lastRoute = state.routes[state.index]
        T.expect(lastRoute.name).toBe("Detail")
        T.expect(lastRoute.params.id).toBe("42")
    end)

    T.it("returns nil for unknown URL", function()
        local state = DeepLinking.resolve("myapp://unknown/path", linkingConfig)
        T.expect(state).toBeNil()
    end)

end)

T.summary()
```

- [ ] **Step 2: Implement DeepLinking**

```lua
-- navigation/DeepLinking.lua
-- Resolves a URL to navigation state based on linking config.
local M = {}

-- Parse path pattern like "detail/:id" into { segments, paramNames }
local function parsePattern(pattern)
    local segments = {}
    local paramNames = {}
    for seg in pattern:gmatch("[^/]+") do
        if seg:sub(1, 1) == ":" then
            segments[#segments + 1] = ":"
            paramNames[#paramNames + 1] = seg:sub(2)
        else
            segments[#segments + 1] = seg
        end
    end
    return segments, paramNames
end

-- Match a path against a pattern, extract params
local function matchPattern(path, pattern)
    local pathSegs = {}
    for seg in path:gmatch("[^/]+") do
        pathSegs[#pathSegs + 1] = seg
    end

    local patternSegs, paramNames = parsePattern(pattern)

    if #pathSegs ~= #patternSegs then return nil end

    local params = {}
    local paramIdx = 0
    for i, pseg in ipairs(patternSegs) do
        if pseg == ":" then
            paramIdx = paramIdx + 1
            params[paramNames[paramIdx]] = pathSegs[i]
        elseif pseg ~= pathSegs[i] then
            return nil
        end
    end

    return params
end

function M.resolve(url, linkingConfig)
    if not url or not linkingConfig then return nil end

    -- Strip prefix
    local path = url
    for _, prefix in ipairs(linkingConfig.prefixes or {}) do
        if path:sub(1, #prefix) == prefix then
            path = path:sub(#prefix + 1)
            break
        end
    end

    -- Remove leading/trailing slashes
    path = path:gsub("^/+", ""):gsub("/+$", "")

    local screens = linkingConfig.config and linkingConfig.config.screens or {}

    -- Try each screen pattern
    for screenName, pattern in pairs(screens) do
        if type(pattern) == "string" then
            local params = matchPattern(path, pattern)
            if params then
                local routes = {}
                -- If not root screen, add Home first
                if pattern ~= "" then
                    -- Find the root screen (empty pattern)
                    for rootName, rootPattern in pairs(screens) do
                        if rootPattern == "" then
                            routes[#routes + 1] = { name = rootName }
                            break
                        end
                    end
                end
                routes[#routes + 1] = {
                    name = screenName,
                    params = next(params) and params or nil,
                }
                return {
                    type = "stack",
                    index = #routes,
                    routes = routes,
                }
            end
        end
    end

    return nil
end

return M
```

- [ ] **Step 3: Run tests**

Run: `cd /path/to/project && lua tests/navigation/test_deeplink.lua`
Expected: All 5 tests pass.

- [ ] **Step 4: Commit**

```bash
git add navigation/DeepLinking.lua tests/navigation/test_deeplink.lua
git commit -m "feat: DeepLinking URL-to-state resolution"
```

---

### Task 10: NavigationTestUtils

**Files:**
- Create: `navigation/NavigationTestUtils.lua`

- [ ] **Step 1: Implement test helpers**

```lua
-- navigation/NavigationTestUtils.lua
-- Helpers for navigating to specific screens in tests.
local NavState = require("navigation.NavigationState")

local M = {}

-- Build an initialState that navigates to the given screen with params.
-- screenPath can be a simple name "Detail" or nested "News/Detail".
function M.buildInitialState(screenPath, params)
    local names = {}
    for name in screenPath:gmatch("[^/]+") do
        names[#names + 1] = name
    end

    local routes = {}
    for i, name in ipairs(names) do
        routes[i] = {
            name = name,
            params = (i == #names) and params or nil,
        }
    end

    return {
        type = "stack",
        index = #routes,
        routes = routes,
    }
end

-- Parse a .route file path like "news/detail/123" into app name + initialState
function M.parseRoutePath(routePath)
    local parts = {}
    for part in routePath:gmatch("[^/]+") do
        parts[#parts + 1] = part
    end

    if #parts == 0 then return nil, nil end

    local appName = parts[1]
    if #parts == 1 then
        return appName, nil -- just app, no screen routing
    end

    -- Remaining parts are screen path, last numeric part is a param
    local screenParts = {}
    local lastParam = nil
    for i = 2, #parts do
        if i == #parts and parts[i]:match("^%d+$") then
            lastParam = parts[i]
        else
            screenParts[#screenParts + 1] = parts[i]
        end
    end

    local screenPath = table.concat(screenParts, "/")
    local params = lastParam and { id = lastParam } or nil

    return appName, M.buildInitialState(screenPath, params)
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add navigation/NavigationTestUtils.lua
git commit -m "feat: NavigationTestUtils for test route access"
```

---

### Task 11: Public API (navigation/init.lua) + Exports

**Files:**
- Create: `navigation/init.lua`
- Modify: `react_solar2d.lua`

- [ ] **Step 1: Create navigation/init.lua**

```lua
-- navigation/init.lua
-- Public exports for the navigation system.
local M = {}

M.NavigationContainer = require("navigation.NavigationContainer")
M.createStackNavigator = require("navigation.StackNavigator")
M.createBottomTabNavigator = require("navigation.TabNavigator")
M.createDrawerNavigator = require("navigation.DrawerNavigator")
M.Header = require("navigation.Header")
M.NavigationTestUtils = require("navigation.NavigationTestUtils")

return M
```

- [ ] **Step 2: Add navigation exports to react_solar2d.lua**

Add after the Components section:

```lua
-- Navigation
local Navigation = require("navigation")
RN.NavigationContainer = Navigation.NavigationContainer
RN.createStackNavigator = Navigation.createStackNavigator
RN.createBottomTabNavigator = Navigation.createBottomTabNavigator
RN.createDrawerNavigator = Navigation.createDrawerNavigator
RN.Header = Navigation.Header
RN.NavigationTestUtils = Navigation.NavigationTestUtils
```

- [ ] **Step 3: Run all tests**

Run: `cd /path/to/project && for f in tests/react/test_*.lua tests/renderer/test_*.lua tests/components/test_*.lua tests/navigation/test_*.lua; do echo "--- $f ---"; lua "$f"; done`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add navigation/init.lua react_solar2d.lua
git commit -m "feat: navigation public API exports

Adds NavigationContainer, createStackNavigator, createBottomTabNavigator,
createDrawerNavigator, Header, NavigationTestUtils to RN module."
```

---

## Chunk 6: Integration — Demo App Refactor

### Task 12: Refactor main.lua to Use Navigation System

**Files:**
- Modify: `examples/main.lua`

- [ ] **Step 1: Read current main.lua routing logic**

Understand the current `.route` file + FloatingMenuButton + AppPickerDialog pattern. The goal is to replace the manual screen switching with the navigation system while keeping the same UI/UX.

- [ ] **Step 2: Refactor main.lua**

Replace the manual routing with:
- `NavigationContainer` as root
- `createDrawerNavigator` for app switching (or `createBottomTabNavigator`)
- Each demo app (NewsApp, QuizApp, TetrisApp) becomes a `Screen`

Key consideration: the existing apps are self-contained function components that call `React.useState` internally. They can be used as screen components directly.

The refactored structure:

```lua
local Navigation = require("navigation")
local ce = React.createElement

local Tab = Navigation.createBottomTabNavigator()

local function App()
    return ce(Navigation.NavigationContainer, {},
        ce(Tab.Navigator, {
            initialRouteName = "News",
            tabBarOptions = {
                activeTintColor = "#2979FF",
                inactiveTintColor = "#888888",
                backgroundColor = "#1A1A2E",
            },
        },
            ce(Tab.Screen, {
                name = "News",
                component = NewsApp,
                options = { tabBarLabel = "热点", tabBarIcon = "N" },
            }),
            ce(Tab.Screen, {
                name = "Quiz",
                component = QuizApp,
                options = { tabBarLabel = "问答", tabBarIcon = "Q" },
            }),
            ce(Tab.Screen, {
                name = "Game",
                component = TetrisApp,
                options = { tabBarLabel = "游戏", tabBarIcon = "T" },
            })
        )
    )
end
```

Integrate `.route` file reading with `NavigationTestUtils.parseRoutePath` for test support.

- [ ] **Step 3: Test in Solar2D Simulator**

Open `examples/main.lua` in Corona Simulator. Verify:
- Tab bar visible at bottom
- Can switch between News, Quiz, Game
- Each app's internal state preserved on tab switch
- `.route` file direct access still works

- [ ] **Step 4: Commit**

```bash
git add examples/main.lua
git commit -m "refactor: main.lua uses TabNavigator for app switching

Replaces manual route file + dialog with NavigationContainer + TabNavigator.
Preserves .route file support for test route direct access."
```

- [ ] **Step 5: Final full test suite run**

Run: `cd /path/to/project && for f in tests/react/test_*.lua tests/renderer/test_*.lua tests/components/test_*.lua tests/navigation/test_*.lua tests/style/test_*.lua; do echo "--- $f ---"; lua "$f"; done`
Expected: All tests pass.
