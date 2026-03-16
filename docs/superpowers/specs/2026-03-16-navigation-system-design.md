# Navigation System Design

## Problem

Each demo app implements its own screen routing with raw `useState`. No shared navigation pattern, no history stack, no parameter passing convention. The 55+ labo_* apps need a standardized, React Navigation-compatible system.

## Solution

Full navigation framework: Stack, Tab, Drawer navigators with Header, Deep Linking, nested navigation, and test route support.

## Prerequisites (Step 0)

### Context.Provider in Reconciler

The current reconciler (`react/Reconciler.lua`) has no support for Context. Navigation requires context to pass `navigation` and `route` objects to deeply nested screen components without prop drilling.

**Implementation needed in Reconciler:**

```lua
-- react/Context.lua
function createContext(defaultValue)
    return {
        _type = "context",
        _defaultValue = defaultValue,
        Provider = function(props)
            -- Provider is a special function component
            -- Sets context value on the fiber, children read it via useContext
        end,
    }
end

-- react/Hooks.lua — add useContext
function useContext(context)
    -- Walk up the fiber tree from currentFiber to find nearest Provider
    -- Return its value, or context._defaultValue if no Provider found
end
```

**Reconciler changes:**
- `performUnitOfWork`: when fiber.type is a Context Provider, store `props.value` on the fiber as `fiber._contextValue` and set `fiber._contextType = context`
- `useContext`: walk `currentFiber.parent` chain upward, find first fiber where `fiber._contextType == context`, return `fiber._contextValue`
- This is a minimal implementation — no consumer component, no subscription optimization. Just Provider + useContext.

### Screen Visibility Toggle

The renderer needs a way to hide/show screens without unmount/remount. Two approaches:

**Chosen approach: `style.display = "none"`** — already partially supported by the renderer. When a screen is hidden:
```lua
-- Set on the screen's root View:
style = { display = "none" }  -- sets isVisible = false on display object
```

The HostConfig `updateInstance` must handle `display` style changes:
```lua
if newStyle.display == "none" then
    instance.isVisible = false
elseif oldStyle.display == "none" and newStyle.display ~= "none" then
    instance.isVisible = true
end
```

This preserves the display object tree (no unmount), so scroll position and form state survive screen switches.

## API Overview

### NavigationContainer (root)

```lua
ce(NavigationContainer, {
    -- Deep Linking
    linking = {
        prefixes = { "myapp://" },
        config = {
            screens = {
                Home = "",
                Detail = "detail/:id",
                Settings = "settings",
            }
        }
    },
    -- Test support: jump directly to a screen
    initialState = {
        routes = {
            { name = "Home" },
            { name = "Detail", params = { id = 123 } },
        },
        index = 2,  -- 1-based: Detail is active (second route)
    },
},
    ce(Stack.Navigator, { ... })
)
```

### Stack Navigator

```lua
local Stack = createStackNavigator()

ce(Stack.Navigator, {
    initialRouteName = "Home",
    screenOptions = {
        headerStyle = { backgroundColor = "#1A1A2E" },
        headerTintColor = "#FFFFFF",
    },
},
    ce(Stack.Screen, {
        name = "Home",
        component = HomeScreen,
        options = {
            title = "首页",
            headerRight = function(props)
                return ce("View", { onPress = props.navigation.openDrawer },
                    ce("Text", {}, "Menu"))
            end,
        },
    }),
    ce(Stack.Screen, {
        name = "Detail",
        component = DetailScreen,
        options = function(props)
            return { title = props.route.params.title or "详情" }
        end,
    })
)
```

### Tab Navigator

```lua
local Tab = createBottomTabNavigator()

ce(Tab.Navigator, {
    initialRouteName = "News",
    tabBarOptions = {
        activeTintColor = "#2979FF",
        inactiveTintColor = "#888888",
        backgroundColor = "#1A1A2E",
        showLabel = true,
        tabBarPosition = "bottom",  -- "bottom" | "top"
    },
},
    ce(Tab.Screen, {
        name = "News",
        component = NewsStack,
        options = {
            tabBarLabel = "热点",
            tabBarIcon = "N",       -- text icon (Solar2D has no icon fonts)
            tabBarBadge = 3,        -- optional badge count
        },
    }),
    ce(Tab.Screen, { name = "Quiz", component = QuizScreen,
        options = { tabBarLabel = "问答", tabBarIcon = "Q" } }),
    ce(Tab.Screen, { name = "Game", component = TetrisScreen,
        options = { tabBarLabel = "游戏", tabBarIcon = "T" } })
)
```

### Drawer Navigator

```lua
local Drawer = createDrawerNavigator()

ce(Drawer.Navigator, {
    drawerWidth = 280,
    drawerPosition = "left",    -- "left" | "right"
    drawerType = "slide",       -- "slide" | "front" (overlay)
    drawerStyle = {
        backgroundColor = "#1A1A2E",
    },
    drawerContent = function(props)
        -- Custom drawer content
        return ce("View", {},
            ce(DrawerItemList, { state = props.state, navigation = props.navigation }),
            ce("View", { style = { marginTop = 20 } },
                ce("Text", { style = { color = "#888" } }, "v1.0.0")
            )
        )
    end,
},
    ce(Drawer.Screen, { name = "Main", component = MainTabs,
        options = { drawerLabel = "首页", drawerIcon = "H" } }),
    ce(Drawer.Screen, { name = "Settings", component = SettingsScreen,
        options = { drawerLabel = "设置", drawerIcon = "S" } })
)
```

### Navigation Object (passed to every screen)

```lua
-- props.navigation methods:
navigation.navigate(name, params)    -- smart: find in current or parent navigator
navigation.push(name, params)        -- Stack only: always push new
navigation.goBack()                  -- pop current screen
navigation.replace(name, params)     -- replace current screen
navigation.reset(state)              -- reset entire navigator state
navigation.setParams(params)         -- update current screen params
navigation.isFocused()               -- is this screen currently visible
navigation.getParent()               -- parent navigator's navigation object

-- Drawer specific:
navigation.openDrawer()
navigation.closeDrawer()
navigation.toggleDrawer()

-- props.route:
route.name                           -- screen name
route.params                         -- parameters passed
route.key                            -- unique key
```

### Header Component

Default header rendered by Stack Navigator. Fully customizable per screen.

```lua
-- Default header: [Back] [Title] [Right]
options = {
    title = "页面标题",
    headerShown = true,              -- false to hide
    headerStyle = {
        backgroundColor = "#1A1A2E",
        height = 56,
    },
    headerTintColor = "#FFFFFF",     -- back button + title color
    headerTitleStyle = {
        fontSize = 18,
        fontWeight = "bold",
    },
    headerTitleAlign = "center",     -- "center" | "left"
    headerLeft = function(props)     -- custom left component
        return ce("View", { onPress = props.onPress },
            ce("Text", {}, "< Back"))
    end,
    headerRight = function(props)    -- custom right component
        return ce("View", { onPress = ... },
            ce("Text", {}, "Save"))
    end,
    header = function(props)         -- fully custom header
        return ce("View", { ... })
    end,
}
```

### Navigation Events

```lua
ce(Stack.Screen, {
    name = "Home",
    component = HomeScreen,
    listeners = {
        focus = function(e) print("screen focused") end,
        blur = function(e) print("screen blurred") end,
        beforeRemove = function(e)
            -- Prevent leaving (e.g., unsaved changes)
            e.preventDefault()
        end,
    },
})

-- Or via hook inside screen component:
local function HomeScreen(props)
    React.useEffect(function()
        local unsub = props.navigation.addListener("focus", function()
            print("focused!")
        end)
        return unsub
    end, {})
end
```

### Deep Linking

```lua
-- Configuration
ce(NavigationContainer, {
    linking = {
        prefixes = { "myapp://", "https://myapp.com" },
        config = {
            screens = {
                Home = "",
                Detail = "detail/:id",
                Nested = {
                    screens = {
                        Profile = "user/:userId",
                        Settings = "settings",
                    }
                }
            }
        }
    }
})

-- Resolution: "myapp://detail/123" → navigate("Detail", { id = "123" })

-- Solar2D integration: reads from system.LaunchArgs or .route file
-- For testing: pass initialURL prop
ce(NavigationContainer, {
    linking = { ... },
    initialURL = "myapp://detail/123",  -- test override
})
```

## Architecture

```
navigation/
├── init.lua                    -- Exports: createStackNavigator, createBottomTabNavigator,
│                               --   createDrawerNavigator, NavigationContainer
├── NavigationContainer.lua     -- Root: manages state tree, provides context
├── NavigationContext.lua        -- React context for navigation/route
├── StackNavigator.lua          -- Stack: push/pop/replace with history
├── TabNavigator.lua            -- Tabs: parallel screens with tab bar
├── DrawerNavigator.lua         -- Drawer: slide-out side panel
├── Header.lua                  -- Default header component
├── DeepLinking.lua             -- URL → navigation state resolver
├── NavigationState.lua         -- State tree operations (push, pop, reset)
└── NavigationTestUtils.lua     -- Test helpers
```

### State Tree

Navigation state is a tree mirroring navigator nesting:

All indices are **1-based** (Lua convention). `index` points to the active route in the `routes` array.

```lua
{
    type = "drawer",
    index = 1,                          -- 1-based: first route "Main" is active
    routes = {
        {
            name = "Main",
            key = "main-1",
            state = {
                type = "tab",
                index = 1,              -- 1-based: first tab "News" is active
                routes = {
                    {
                        name = "News",
                        key = "news-1",
                        state = {
                            type = "stack",
                            index = 2,  -- 1-based: second route "NewsDetail" is on top
                            routes = {
                                { name = "NewsList", key = "list-1" },
                                { name = "NewsDetail", key = "detail-1",
                                  params = { id = 123 } },
                            }
                        }
                    },
                    { name = "Quiz", key = "quiz-1" },
                }
            }
        },
        { name = "Settings", key = "settings-1" },
    }
}
```

### Screen Lifecycle

| Event | Stack push | Stack pop | Tab switch | Drawer open |
|-------|-----------|----------|------------|-------------|
| Previous screen | blur → hide | remove | blur → hide | blur (stays) |
| New screen | create → focus | show → focus | show → focus | — |

**Screen preservation:**
- Tab: screens preserved (hidden via `isVisible = false`)
- Stack: screens preserved in stack (hidden), removed on pop
- Drawer: main content stays visible, drawer slides over

### Rendering Strategy

Each navigator renders only what's needed:

- **Stack**: render all screens in stack, only topmost visible. On `goBack`, hide top and show previous.
- **Tab**: render all tabs, only active tab visible. Tab bar always visible.
- **Drawer**: render main content + drawer panel. Drawer panel positioned offscreen, slides in on open.

Using `style.display = "none"` instead of unmount/remount avoids re-creating display objects and preserves scroll position, form state, etc.

## Container Nesting Constraint

Solar2D has a 3-level nesting limit for Container (clipping mask) objects. Nested navigators (e.g., Drawer > Tab > Stack) could easily exceed this.

**Rule: All navigator wrapper Views use Group (default), not Container.** Only individual screen content that explicitly sets `overflow: "hidden"` uses Container. This keeps the nesting budget available for app content, not navigation chrome.

## Transitions

### V1: Immediate Transitions (No Animation)

Screen transitions are instant — set `display = "none"` on hiding screen, remove it on showing screen. This is sufficient for functional correctness.

### V2: Animated Transitions (Future)

After V1 is working, transitions can be added using the existing `animated/` system:
- **Stack push**: new screen slides in from right (x: screenWidth → 0)
- **Stack pop**: current screen slides out to right (x: 0 → screenWidth)
- **Drawer open**: drawer panel slides in from left (x: -drawerWidth → 0)
- **Tab switch**: cross-fade or instant (configurable)

Transition config per navigator:
```lua
ce(Stack.Navigator, {
    screenOptions = {
        animation = "slide_from_right",  -- or "none", "fade"
        animationDuration = 250,
    },
})
```

V2 is explicitly out of scope for initial implementation.

## Drawer Gestures

### V1: Button-Only Control

Drawer opens/closes via `navigation.openDrawer()` / `closeDrawer()` / `toggleDrawer()` triggered by buttons. No swipe gesture.

### V2: Swipe Gesture (Future)

Edge swipe detection on the main content area:
- Touch begins within 20px of left edge
- Horizontal drag distance > vertical drag distance
- Drag exceeds threshold (40px) → open drawer

This reuses the same touch handling pattern as ScrollView. Deferred to V2 to keep initial implementation focused.

## Deep Linking Platform Scope

Deep linking in Solar2D is more limited than mobile native:

- **Simulator/Desktop**: reads from `.route` file or `initialURL` prop (test only)
- **Mobile (iOS/Android)**: reads from `system.LaunchArgs` (URL that launched the app)
- **No runtime URL handling**: Solar2D cannot listen for incoming URLs while running (unlike React Native's `Linking.addEventListener`). Deep linking only processes the launch URL.

The `DeepLinking.lua` module handles:
1. Parse URL against `linking.config.screens` mapping
2. Build corresponding navigation state
3. Pass as `initialState` to NavigationContainer

This is sufficient for test route support and basic app launch scenarios.

## beforeRemove Event

The `beforeRemove` event uses a two-phase approach:

```lua
-- Phase 1: Dispatch beforeRemove to listeners
-- Phase 2: If no listener called preventDefault(), proceed with removal

local function dispatchBeforeRemove(navigation, route)
    local event = {
        type = "beforeRemove",
        data = { action = { type = "GO_BACK" } },
        defaultPrevented = false,
        preventDefault = function(self)
            self.defaultPrevented = true
        end,
    }
    navigation._emit("beforeRemove", event)
    return not event.defaultPrevented
end

-- In goBack():
local canRemove = dispatchBeforeRemove(navigation, currentRoute)
if canRemove then
    -- proceed with pop
end
```

This is synchronous — no async confirmation dialogs in V1. The listener must decide immediately whether to prevent removal.

## Nesting Rules

1. Any navigator can be nested inside any other
2. `navigate()` bubbles up: if screen not found in current navigator, tries parent
3. Each navigator manages its own state independently
4. `getParent()` returns parent navigator's navigation object

## Testing

### Mock Tests

```lua
-- test_navigation_state.lua
-- Push, pop, replace, reset operations on state tree
-- Navigate across nested navigators
-- Deep link URL parsing

-- test_header.lua
-- Default header renders title
-- Custom headerLeft/headerRight
-- headerShown = false hides header
```

### Simulator Tests

```lua
-- test_navigation.lua
-- Mount app with Stack navigator
-- Verify initial screen renders
-- Navigate to detail → verify screen content
-- GoBack → verify return to previous screen
-- Tab switch → verify correct tab active
-- Drawer open/close → verify drawer visibility
```

### Test Route Direct Access

```lua
-- Jump directly to any screen in the app for testing
-- Method 1: initialState prop
ce(NavigationContainer, {
    initialState = {
        type = "stack",
        index = 3,  -- 1-based: third route "Detail" is on top
        routes = {
            { name = "Home" },
            { name = "List" },
            { name = "Detail", params = { id = 42 } },
        }
    }
})

-- Method 2: NavigationTestUtils helper
local utils = require("navigation.NavigationTestUtils")
utils.navigateTo(container, "Detail", { id = 42 })

-- Method 3: .route file integration (extends existing system)
-- echo "news/detail/123" > examples/.route
-- Router parses: app = "news", then initialState = navigate to Detail with id=123
```

### Integration with Existing Test System

The `.route` file system is extended to support deep paths:

```
# Current: app-level routing
quiz                    → launch QuizApp

# New: screen-level routing
quiz/result             → QuizApp, navigate to result screen
news/detail/123         → NewsApp, navigate to detail with id=123
```

Test files (`test_quiz.lua`, `test_all.lua`) can use `initialState` to start at specific screens without clicking through the entire flow.

## Files

| File | Purpose | Lines (est) |
|------|---------|-------------|
| `navigation/init.lua` | Public exports | 30 |
| `navigation/NavigationContainer.lua` | Root state management + context | 120 |
| `navigation/NavigationContext.lua` | React context definition | 20 |
| `navigation/NavigationState.lua` | State tree operations | 100 |
| `navigation/StackNavigator.lua` | Stack logic + transitions | 150 |
| `navigation/TabNavigator.lua` | Tab logic + tab bar rendering | 150 |
| `navigation/DrawerNavigator.lua` | Drawer logic + gesture | 130 |
| `navigation/Header.lua` | Default header component | 80 |
| `navigation/DeepLinking.lua` | URL → state resolution | 60 |
| `navigation/NavigationTestUtils.lua` | Test helpers | 40 |
| `tests/navigation/test_state.lua` | State operation tests | 100 |
| `tests/navigation/test_stack.lua` | Stack navigator tests | 80 |
| `tests/navigation/test_tab.lua` | Tab navigator tests | 80 |
| `tests/navigation/test_drawer.lua` | Drawer navigator tests | 80 |
| `tests/navigation/test_deeplink.lua` | Deep linking tests | 60 |
| `tests/solar2d/test_navigation.lua` | Simulator integration tests | 100 |

## Success Criteria

1. **Prerequisite**: Context.Provider + useContext work in reconciler
2. Stack: push/pop/replace/reset work, back button in header
3. Tab: switch tabs preserves screen state, badge displays
4. Drawer: open/close/toggle via navigation methods (swipe deferred to V2)
5. Header: default + custom + hidden all work
6. Deep linking: URL resolves to correct screen with params (launch-time only)
7. Nesting: Tab inside Drawer inside Stack works (all use Group, not Container)
8. Test route: can navigate to any screen via initialState or .route file
9. All indices 1-based throughout
10. Screen visibility via `style.display = "none"` (no unmount/remount)
11. Transitions: immediate in V1 (animated transitions deferred to V2)
12. beforeRemove: synchronous preventDefault works
13. All existing app tests still pass
14. Demo app (main.lua) refactored to use navigation system
