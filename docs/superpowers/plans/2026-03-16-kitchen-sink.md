# Kitchen Sink Demo Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a comprehensive showcase app demonstrating all 14 components, hooks, navigation, animation, and Solar2D interop in a navigable 6-tab structure.

**Architecture:** KitchenSinkApp is a function component registered as a tab in main.lua. Internally it creates a BottomTabNavigator (6 tabs), each with a StackNavigator. A shared ListScreen component auto-generates category list pages from screen descriptor tables. Each `*Screens.lua` exports `{ name, component, description, icon }` entries.

**Tech Stack:** Pure Lua, React hooks, Solar2D display API, Navigation system, Animated API.

**Spec:** `docs/superpowers/specs/2026-03-16-kitchen-sink-design.md`

---

## File Structure

| File | Purpose | Action |
|------|---------|--------|
| `examples/kitchen_sink/theme.lua` | Shared color constants and spacing | Create |
| `examples/KitchenSinkApp.lua` | Root: 6-tab navigator + ListScreen | Create |
| `examples/kitchen_sink/BasicsScreens.lua` | 6 basic component demos | Create |
| `examples/kitchen_sink/FormsScreens.lua` | 4 form component demos | Create |
| `examples/kitchen_sink/ListsScreens.lua` | 3 list/scroll demos | Create |
| `examples/kitchen_sink/NavigationScreens.lua` | 3 navigation demos | Create |
| `examples/kitchen_sink/AnimationScreens.lua` | 5 animation demos | Create |
| `examples/kitchen_sink/InteropScreens.lua` | 2 interop demos | Create |
| `examples/main.lua` | Add KitchenSink as 4th tab | Modify |

**Dependency graph:** Task 1 (foundation) → Tasks 2-7 (parallel, no file overlap) → Task 8 (integration).

---

## Chunk 1: Foundation

### Task 1: Theme + KitchenSinkApp Root

**Files:**
- Create: `examples/kitchen_sink/theme.lua`
- Create: `examples/KitchenSinkApp.lua`

- [ ] **Step 1: Create theme.lua**

```lua
-- examples/kitchen_sink/theme.lua
local T = {}

T.bg = "#0D1117"
T.surface = "#161B22"
T.border = "#30363D"
T.textPrimary = "#E6EDF3"
T.textSecondary = "#8B949E"
T.accent = "#58A6FF"
T.tabActive = "#FF6600"
T.tabInactive = "#666688"

T.pad = 16
T.gap = 12
T.radius = 12
T.radiusSmall = 8

-- Shared helpers used by all *Screens.lua files
local React = require("react")
local ce = React.createElement

function T.Section(props)
    return ce("View", { style = { marginBottom = T.gap } },
        ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } }, props.title),
        ce("View", {}, props.children)
    )
end

function T.DemoPage(props)
    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    }, props.children)
end

return T
```

- [ ] **Step 2: Create KitchenSinkApp.lua**

This is the root component. It creates 6 tabs, each with a StackNavigator. The `ListScreen` is a shared component that renders a scrollable card list from a screen descriptor table.

```lua
-- examples/KitchenSinkApp.lua
-- Kitchen Sink: comprehensive component showcase
local React = require("react")
local ce = React.createElement
local Navigation = require("navigation")
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")

-- Shared ListScreen: renders a card list from screen descriptors
-- Note: KitchenSinkApp is rendered inside main.lua's NavigationContainer —
-- do NOT wrap in a second NavigationContainer.
local function ListScreen(props)
    local screens = props.route and props.route.params and props.route.params.screens or {}
    local navigation = props.navigation
    local items = {}
    for i, s in ipairs(screens) do
        items[#items + 1] = ce(RN.Pressable, {
            key = s.name,
            style = {
                flexDirection = "row", alignItems = "center",
                backgroundColor = T.surface,
                borderRadius = T.radius, padding = T.pad,
                marginBottom = T.gap,
                borderWidth = 1, borderColor = T.border,
            },
            onPress = function()
                navigation.navigate(s.name)
            end,
        },
            -- Icon circle
            ce("View", {
                style = {
                    width = 44, height = 44, borderRadius = 22,
                    backgroundColor = T.accent,
                    justifyContent = "center", alignItems = "center",
                    marginRight = T.pad,
                },
            }, ce("Text", {
                style = { fontSize = 18, color = "#FFFFFF", fontWeight = "bold" },
            }, s.icon or s.name:sub(1, 1))),
            -- Text
            ce("View", { style = { flex = 1 } },
                ce("Text", {
                    style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold" },
                }, s.name),
                ce("Text", {
                    style = { fontSize = 12, color = T.textSecondary },
                }, s.description or "")
            )
        )
    end
    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    }, items)
end

-- Tab definitions
local TAB_CONFIGS = {
    { key = "Basics",     label = "基础",   icon = "B", screens = require("examples.kitchen_sink.BasicsScreens") },
    { key = "Forms",      label = "表单",   icon = "F", screens = require("examples.kitchen_sink.FormsScreens") },
    { key = "Lists",      label = "列表",   icon = "L", screens = require("examples.kitchen_sink.ListsScreens") },
    { key = "Nav",        label = "导航",   icon = "N", screens = require("examples.kitchen_sink.NavigationScreens") },
    { key = "Animation",  label = "动画",   icon = "A", screens = require("examples.kitchen_sink.AnimationScreens") },
    { key = "Interop",    label = "互操",   icon = "I", screens = require("examples.kitchen_sink.InteropScreens") },
}

-- Build a StackNavigator for each tab category
local function createTabStack(tabConfig)
    local Stack = Navigation.createStackNavigator()
    return function(props)
        local screenElements = {
            ce(Stack.Screen, {
                name = tabConfig.key .. "List",
                component = ListScreen,
                options = { title = tabConfig.label, headerShown = false },
            }),
        }
        for _, s in ipairs(tabConfig.screens) do
            screenElements[#screenElements + 1] = ce(Stack.Screen, {
                name = s.name,
                component = s.component,
                options = { title = s.name },
            })
        end
        return ce(Stack.Navigator, {
            initialRouteName = tabConfig.key .. "List",
            initialState = {
                type = "stack",
                index = 1,
                routes = { { name = tabConfig.key .. "List", key = tabConfig.key .. "List-1", params = { screens = tabConfig.screens } } },
            },
            screenOptions = {
                headerStyle = { backgroundColor = T.surface },
                headerTintColor = T.textPrimary,
            },
        }, screenElements)
    end
end

-- Build tab screen components
local tabStacks = {}
for _, config in ipairs(TAB_CONFIGS) do
    tabStacks[config.key] = createTabStack(config)
end

local Tab = Navigation.createBottomTabNavigator()

local function KitchenSinkApp()
    local tabScreens = {}
    for _, config in ipairs(TAB_CONFIGS) do
        tabScreens[#tabScreens + 1] = ce(Tab.Screen, {
            name = config.key,
            component = tabStacks[config.key],
            options = { tabBarLabel = config.label, tabBarIcon = config.icon },
        })
    end
    return ce(Tab.Navigator, {
        tabBarOptions = {
            activeTintColor = T.tabActive,
            inactiveTintColor = T.tabInactive,
            backgroundColor = T.surface,
        },
    }, tabScreens)
end

return KitchenSinkApp
```

- [ ] **Step 3: Create placeholder screen files**

Each `*Screens.lua` needs to exist (even if empty) for the require to work. Create minimal placeholder versions that return an empty table `{}`. These will be replaced in Tasks 2-7.

```lua
-- Placeholder for each: examples/kitchen_sink/BasicsScreens.lua (and others)
return {}
```

Create all 6 placeholder files.

- [ ] **Step 4: Commit**

```bash
git add examples/kitchen_sink/theme.lua examples/KitchenSinkApp.lua examples/kitchen_sink/BasicsScreens.lua examples/kitchen_sink/FormsScreens.lua examples/kitchen_sink/ListsScreens.lua examples/kitchen_sink/NavigationScreens.lua examples/kitchen_sink/AnimationScreens.lua examples/kitchen_sink/InteropScreens.lua
git commit -m "feat: KitchenSink foundation — theme, root navigator, placeholders"
```

---

## Chunk 2: Basics + Forms Screens

### Task 2: BasicsScreens (6 demos)

**Files:**
- Rewrite: `examples/kitchen_sink/BasicsScreens.lua`

- [ ] **Step 1: Implement all 6 basic component demos**

```lua
-- examples/kitchen_sink/BasicsScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Section = T.Section
local DemoPage = T.DemoPage

-- 1. ViewDemo
local function ViewDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "Flex Direction" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce("View", { style = { width = 60, height = 60, backgroundColor = "#E74C3C", borderRadius = 4 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "#2ECC71", borderRadius = 4 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "#3498DB", borderRadius = 4 } })
            )
        ),
        ce(Section, { title = "Border Radius" },
            ce("View", { style = { flexDirection = "row", gap = 12, alignItems = "center" } },
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 0 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 16 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 25 } })
            )
        ),
        ce(Section, { title = "Opacity" },
            ce("View", { style = { flexDirection = "row", gap = 12 } },
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 1.0, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 0.7, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 0.4, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 0.1, borderRadius = 8 } })
            )
        ),
        ce(Section, { title = "Background Colors" },
            ce("View", { style = { flexDirection = "row", flexWrap = "wrap", gap = 8 } },
                ce("View", { style = { width = 44, height = 44, backgroundColor = "tomato", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "dodgerblue", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "gold", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "teal", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "coral", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "indigo", borderRadius = 8 } })
            )
        )
    )
end

-- 2. TextDemo
local function TextDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "Font Sizes" },
            ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "fontSize: 12"),
            ce("Text", { style = { fontSize = 18, color = T.textPrimary } }, "fontSize: 18"),
            ce("Text", { style = { fontSize = 24, color = T.textPrimary } }, "fontSize: 24"),
            ce("Text", { style = { fontSize = 36, color = T.textPrimary } }, "fontSize: 36")
        ),
        ce(Section, { title = "Font Weight" },
            ce("Text", { style = { fontSize = 18, color = T.textPrimary } }, "Normal weight"),
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, fontWeight = "bold" } }, "Bold weight")
        ),
        ce(Section, { title = "Colors" },
            ce("Text", { style = { fontSize = 16, color = "tomato" } }, "Tomato"),
            ce("Text", { style = { fontSize = 16, color = "dodgerblue" } }, "DodgerBlue"),
            ce("Text", { style = { fontSize = 16, color = "gold" } }, "Gold"),
            ce("Text", { style = { fontSize = 16, color = "#00C853" } }, "#00C853 Green")
        ),
        ce(Section, { title = "Number of Lines (truncation)" },
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary },
                numberOfLines = 1,
            }, "This is a very long text that should be truncated to a single line because numberOfLines is set to 1."),
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginTop = 8 },
                numberOfLines = 2,
            }, "This is another long text that can span up to two lines before being truncated. It has quite a lot of content to demonstrate the two-line limit clearly.")
        ),
        ce(Section, { title = "Nested Text" },
            ce("Text", { style = { fontSize = 14, color = T.textSecondary } },
                "Note: nested inline Text (bold/color within paragraph) is not yet supported in react-solar2d. Each Text is a separate display.newText object.")
        )
    )
end

-- 3. ImageDemo
local function ImageDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "resizeMode Comparison" },
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginBottom = 8 },
            }, "Image uses local file paths in Solar2D. resizeMode: cover / contain / stretch"),
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce("View", { style = { alignItems = "center" } },
                    ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 4 } }),
                    ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginTop = 4 } }, "cover")
                ),
                ce("View", { style = { alignItems = "center" } },
                    ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 4, opacity = 0.7 } }),
                    ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginTop = 4 } }, "contain")
                ),
                ce("View", { style = { alignItems = "center" } },
                    ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 4, opacity = 0.4 } }),
                    ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginTop = 4 } }, "stretch")
                )
            )
        ),
        ce(Section, { title = "Different Sizes" },
            ce("View", { style = { flexDirection = "row", gap = 12, alignItems = "flex-end" } },
                ce("View", { style = { width = 40, height = 40, backgroundColor = T.accent, borderRadius = 8 } }),
                ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 8 } }),
                ce("View", { style = { width = 120, height = 80, backgroundColor = T.accent, borderRadius = T.radius } })
            )
        ),
        ce(Section, { title = "Border Radius on Images" },
            ce("View", { style = { flexDirection = "row", gap = 12 } },
                ce("View", { style = { width = 60, height = 60, backgroundColor = "coral", borderRadius = 0 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "coral", borderRadius = 12 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "coral", borderRadius = 30 } })
            )
        )
    )
end

-- 4. ButtonDemo
local function ButtonDemo()
    local count, setCount = useState(0)
    return ce(DemoPage, {},
        ce(Section, { title = "Button Colors" },
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Default", onPress = function() end }),
                ce(RN.Button, { title = "Red", color = "#E74C3C", onPress = function() end }),
                ce(RN.Button, { title = "Blue", color = "#2979FF", onPress = function() end }),
                ce(RN.Button, { title = "Green", color = "#00C853", onPress = function() end })
            )
        ),
        ce(Section, { title = "onPress Counter" },
            ce("Text", {
                style = { fontSize = 24, color = T.textPrimary, marginBottom = 8 },
            }, "Count: " .. count),
            ce(RN.Button, {
                title = "Tap me (+1)",
                color = T.accent,
                onPress = function() setCount(function(c) return c + 1 end) end,
            })
        )
    )
end

-- 5. PressableDemo
local function PressableDemo()
    local pressMsg, setPressMsg = useState("Tap or long-press below")
    return ce(DemoPage, {},
        ce(Section, { title = "Press Feedback" },
            ce("Text", {
                style = { fontSize = 16, color = T.textPrimary, marginBottom = 12 },
            }, pressMsg),
            ce(RN.Pressable, {
                onPress = function() setPressMsg("Tapped!") end,
                style = {
                    backgroundColor = T.surface, padding = T.pad,
                    borderRadius = T.radiusSmall, borderWidth = 1, borderColor = T.border,
                    marginBottom = T.gap,
                },
            }, ce("Text", { style = { color = T.textPrimary, fontSize = 16 } }, "Tap me")),
            ce(RN.Pressable, {
                onLongPress = function() setPressMsg("Long pressed!") end,
                style = {
                    backgroundColor = T.surface, padding = T.pad,
                    borderRadius = T.radiusSmall, borderWidth = 1, borderColor = T.accent,
                },
            }, ce("Text", { style = { color = T.accent, fontSize = 16 } }, "Long press me"))
        ),
        ce(Section, { title = "Custom Styled (card-like)" },
            ce(RN.Pressable, {
                onPress = function() setPressMsg("Card pressed!") end,
                style = {
                    flexDirection = "row", alignItems = "center",
                    backgroundColor = T.surface, padding = T.pad,
                    borderRadius = T.radius, borderWidth = 1, borderColor = T.border,
                },
            },
                ce("View", { style = { width = 40, height = 40, borderRadius = 20, backgroundColor = T.accent, justifyContent = "center", alignItems = "center", marginRight = 12 } },
                    ce("Text", { style = { fontSize = 18, color = "#FFF" } }, "P")
                ),
                ce("View", { style = { flex = 1 } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold" } }, "Card Pressable"),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, "Tap this card-like layout")
                )
            )
        )
    )
end

-- 6. TouchableOpacityDemo
local function TouchableOpacityDemo()
    local tapped, setTapped = useState("")
    return ce(DemoPage, {},
        ce(Section, { title = "Active Opacity Comparison" },
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginBottom = 12 },
            }, tapped ~= "" and ("Tapped: " .. tapped) or "Tap the buttons below"),
            ce("View", { style = { flexDirection = "row", gap = 12 } },
                ce(RN.TouchableOpacity, {
                    activeOpacity = 0.2,
                    onPress = function() setTapped("opacity 0.2") end,
                    style = { flex = 1, backgroundColor = T.accent, padding = 16, borderRadius = T.radiusSmall, alignItems = "center" },
                }, ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, "0.2")),
                ce(RN.TouchableOpacity, {
                    activeOpacity = 0.5,
                    onPress = function() setTapped("opacity 0.5") end,
                    style = { flex = 1, backgroundColor = T.accent, padding = 16, borderRadius = T.radiusSmall, alignItems = "center" },
                }, ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, "0.5")),
                ce(RN.TouchableOpacity, {
                    activeOpacity = 0.8,
                    onPress = function() setTapped("opacity 0.8") end,
                    style = { flex = 1, backgroundColor = T.accent, padding = 16, borderRadius = T.radiusSmall, alignItems = "center" },
                }, ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, "0.8"))
            )
        )
    )
end

return {
    { name = "View",      component = ViewDemo,      description = "Layout, radius, opacity, colors", icon = "V" },
    { name = "Text",      component = TextDemo,      description = "Sizes, weight, color, truncation", icon = "T" },
    { name = "Image",     component = ImageDemo,     description = "Sizes, radius, placeholder",       icon = "I" },
    { name = "Button",    component = ButtonDemo,    description = "Colors, onPress counter",           icon = "B" },
    { name = "Pressable", component = PressableDemo, description = "Press and long-press feedback",     icon = "P" },
    { name = "Touchable", component = TouchableOpacityDemo, description = "ActiveOpacity comparison",   icon = "O" },
}
```

- [ ] **Step 2: Commit**

```bash
git add examples/kitchen_sink/BasicsScreens.lua
git commit -m "feat: KitchenSink basics — View, Text, Image, Button, Pressable, TouchableOpacity"
```

---

### Task 3: FormsScreens (4 demos)

**Files:**
- Rewrite: `examples/kitchen_sink/FormsScreens.lua`

- [ ] **Step 1: Implement all 4 form demos**

```lua
-- examples/kitchen_sink/FormsScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Hooks = require("hooks.useTimer")
local Section = T.Section
local DemoPage = T.DemoPage

-- 1. TextInputDemo
local function TextInputDemo()
    local text, setText = useState("")
    local multiText, setMultiText = useState("")
    return ce(DemoPage, {},
        ce(Section, { title = "Single Line Input" },
            ce(RN.TextInput, {
                placeholder = "Type something...",
                value = text,
                onChangeText = function(t) setText(t) end,
                style = {
                    backgroundColor = T.surface, color = T.textPrimary,
                    padding = 12, borderRadius = T.radiusSmall,
                    borderWidth = 1, borderColor = T.border, fontSize = 16,
                },
            }),
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginTop = 8 },
            }, "You typed: " .. text)
        ),
        ce(Section, { title = "Multi-line Input" },
            ce(RN.TextInput, {
                placeholder = "Write a paragraph...",
                value = multiText,
                onChangeText = function(t) setMultiText(t) end,
                multiline = true,
                style = {
                    backgroundColor = T.surface, color = T.textPrimary,
                    padding = 12, borderRadius = T.radiusSmall,
                    borderWidth = 1, borderColor = T.border,
                    fontSize = 16, height = 120,
                },
            })
        )
    )
end

-- 2. SwitchDemo
local function SwitchDemo()
    local wifi, setWifi = useState(true)
    local bluetooth, setBluetooth = useState(false)
    local darkMode, setDarkMode = useState(true)
    return ce(DemoPage, {},
        ce(Section, { title = "Switches" },
            ce("View", { style = { gap = 16 } },
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Wi-Fi: " .. (wifi and "ON" or "OFF")),
                    ce(RN.Switch, { value = wifi, onValueChange = setWifi })
                ),
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Bluetooth: " .. (bluetooth and "ON" or "OFF")),
                    ce(RN.Switch, {
                        value = bluetooth, onValueChange = setBluetooth,
                        trackColor = { ["true"] = "#2979FF", ["false"] = "#444" },
                    })
                ),
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Dark Mode: " .. (darkMode and "ON" or "OFF")),
                    ce(RN.Switch, {
                        value = darkMode, onValueChange = setDarkMode,
                        trackColor = { ["true"] = "#FF6600", ["false"] = "#444" },
                        thumbColor = "#FFF",
                    })
                )
            )
        )
    )
end

-- 3. ModalDemo
local function ModalDemo()
    local visible, setVisible = useState(false)
    return ce(DemoPage, {},
        ce(Section, { title = "Modal" },
            ce(RN.Button, {
                title = "Open Modal",
                color = T.accent,
                onPress = function() setVisible(true) end,
            }),
            ce(RN.Modal, {
                visible = visible,
                transparent = true,
                onRequestClose = function() setVisible(false) end,
            },
                ce("View", {
                    style = {
                        backgroundColor = T.surface, borderRadius = T.radius,
                        padding = 24, width = 280,
                        borderWidth = 1, borderColor = T.border,
                    },
                },
                    ce("Text", {
                        style = { fontSize = 20, color = T.textPrimary, fontWeight = "bold", marginBottom = 12 },
                    }, "Hello Modal!"),
                    ce("Text", {
                        style = { fontSize = 14, color = T.textSecondary, marginBottom = 20 },
                    }, "This is a modal dialog rendered as an overlay."),
                    ce(RN.Button, {
                        title = "Close",
                        color = T.accent,
                        onPress = function() setVisible(false) end,
                    })
                )
            )
        )
    )
end

-- 4. ActivityIndicatorDemo
local function ActivityIndicatorDemo()
    local animating, setAnimating = useState(true)
    local sizeLabel, setSizeLabel = useState("small")
    local colorIdx, setColorIdx = useState(1)
    local colors = { "#58A6FF", "#FF6600", "#00C853", "#E74C3C" }
    local colorNames = { "Blue", "Orange", "Green", "Red" }

    -- useTimeout: auto-hide after 3 seconds then re-show
    local autoHidden, setAutoHidden = useState(false)
    Hooks.useTimeout(function()
        if animating and not autoHidden then
            setAutoHidden(true)
            setAnimating(false)
        end
    end, animating and not autoHidden and 3000 or false)

    Hooks.useTimeout(function()
        if autoHidden then
            setAutoHidden(false)
            setAnimating(true)
        end
    end, autoHidden and 1500 or false)

    local sizeVal = sizeLabel
    if sizeLabel == "custom" then sizeVal = 60 end

    return ce(DemoPage, {},
        ce(Section, { title = "Activity Indicator" },
            ce("View", {
                style = { alignItems = "center", padding = 24, backgroundColor = T.surface, borderRadius = T.radius, marginBottom = T.gap },
            },
                ce(RN.ActivityIndicator, {
                    animating = animating,
                    size = sizeVal,
                    color = colors[colorIdx],
                }),
                ce("Text", {
                    style = { fontSize = 12, color = T.textSecondary, marginTop = 12 },
                }, animating and "Auto-hides in 3s, re-shows in 1.5s" or "Paused...")
            )
        ),
        ce(Section, { title = "Size" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce(RN.Button, { title = "Small", color = sizeLabel == "small" and T.accent or T.textSecondary, onPress = function() setSizeLabel("small") end }),
                ce(RN.Button, { title = "Large", color = sizeLabel == "large" and T.accent or T.textSecondary, onPress = function() setSizeLabel("large") end }),
                ce(RN.Button, { title = "60px", color = sizeLabel == "custom" and T.accent or T.textSecondary, onPress = function() setSizeLabel("custom") end })
            )
        ),
        ce(Section, { title = "Color: " .. colorNames[colorIdx] },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce(RN.Button, { title = "Next Color", color = colors[colorIdx], onPress = function()
                    setColorIdx(function(i) return (i % #colors) + 1 end)
                end })
            )
        ),
        ce(Section, { title = "Animating" },
            ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, animating and "ON" or "OFF"),
                ce(RN.Switch, { value = animating, onValueChange = function(v)
                    setAutoHidden(false)
                    setAnimating(v)
                end })
            )
        )
    )
end

return {
    { name = "TextInput",  component = TextInputDemo,  description = "Single/multi-line, controlled input", icon = "T" },
    { name = "Switch",     component = SwitchDemo,     description = "Toggle switches, custom colors",      icon = "S" },
    { name = "Modal",      component = ModalDemo,      description = "Overlay dialog, open/close",          icon = "M" },
    { name = "Indicator",  component = ActivityIndicatorDemo, description = "Loading spinner, size/color/useTimeout", icon = "A" },
}
```

- [ ] **Step 2: Commit**

```bash
git add examples/kitchen_sink/FormsScreens.lua
git commit -m "feat: KitchenSink forms — TextInput, Switch, Modal, ActivityIndicator"
```

---

## Chunk 3: Lists + Navigation Screens

### Task 4: ListsScreens (3 demos)

**Files:**
- Rewrite: `examples/kitchen_sink/ListsScreens.lua`

- [ ] **Step 1: Implement all 3 list demos**

```lua
-- examples/kitchen_sink/ListsScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Section = T.Section

-- 1. ScrollViewDemo
local function ScrollViewDemo()
    local scrollY, setScrollY = useState(0)
    -- Vertical cards
    local cards = {}
    local cardColors = { "#E74C3C", "#2979FF", "#00C853", "#FF6600", "#9C27B0", "#00BCD4" }
    for i = 1, 24 do
        local color = cardColors[((i - 1) % #cardColors) + 1]
        cards[#cards + 1] = ce("View", {
            key = "card" .. i,
            style = {
                height = 80, backgroundColor = color, borderRadius = T.radius,
                justifyContent = "center", alignItems = "center", marginBottom = T.gap,
            },
        }, ce("Text", { style = { fontSize = 20, color = "#FFFFFF", fontWeight = "bold" } }, "Card " .. i))
    end

    -- Horizontal thumbnails
    local thumbs = {}
    for i = 1, 12 do
        local color = cardColors[((i - 1) % #cardColors) + 1]
        thumbs[#thumbs + 1] = ce("View", {
            key = "thumb" .. i,
            style = {
                width = 100, height = 100, backgroundColor = color,
                borderRadius = T.radiusSmall, marginRight = T.gap,
                justifyContent = "center", alignItems = "center",
            },
        }, ce("Text", { style = { fontSize = 14, color = "#FFF" } }, "#" .. i))
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("View", {
            style = { padding = T.pad, backgroundColor = T.surface, borderBottomWidth = 1, borderColor = T.border },
        },
            ce("Text", { style = { fontSize = 12, color = T.textSecondary } },
                "Scroll Y: " .. math.floor(scrollY))
        ),
        ce("ScrollView", {
            style = { flex = 1 },
            contentContainerStyle = { padding = T.pad },
            onScroll = function(e)
                setScrollY(math.abs(e.contentOffset.y))
            end,
        },
            ce(Section, { title = "Vertical Scroll (24 cards)" }, cards),
            ce(Section, { title = "Horizontal Scroll" },
                ce("ScrollView", {
                    horizontal = true,
                    style = { height = 120 },
                    contentContainerStyle = { paddingVertical = 8 },
                }, thumbs)
            )
        )
    )
end

-- 2. FlatListBasicDemo
local function FlatListBasicDemo()
    local showData, setShowData = useState(true)
    local data = {}
    if showData then
        for i = 1, 30 do
            data[i] = { id = tostring(i), title = "Item " .. i, subtitle = "Description for item " .. i }
        end
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("View", { style = { padding = T.pad, flexDirection = "row", gap = 8 } },
            ce(RN.Button, {
                title = showData and "Clear Data" or "Load Data",
                color = T.accent,
                onPress = function() setShowData(function(v) return not v end) end,
            })
        ),
        ce(RN.FlatList, {
            data = data,
            keyExtractor = function(item) return item.id end,
            renderItem = function(info)
                return ce("View", {
                    key = info.item.id,
                    style = { padding = T.pad, backgroundColor = T.bg },
                },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, info.item.title),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, info.item.subtitle)
                )
            end,
            ItemSeparatorComponent = function()
                return ce("View", { style = { height = 1, backgroundColor = T.border } })
            end,
            ListHeaderComponent = function()
                return ce("View", { style = { padding = T.pad, backgroundColor = T.surface } },
                    ce("Text", { style = { fontSize = 18, color = T.accent, fontWeight = "bold" } }, "FlatList Header")
                )
            end,
            ListFooterComponent = function()
                return ce("View", { style = { padding = T.pad, backgroundColor = T.surface } },
                    ce("Text", { style = { fontSize = 14, color = T.textSecondary } }, "— End of list —")
                )
            end,
            ListEmptyComponent = function()
                return ce("View", { style = { padding = 40, alignItems = "center" } },
                    ce("Text", { style = { fontSize = 18, color = T.textSecondary } }, "No data"),
                    ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginTop = 8 } }, "Tap 'Load Data' above")
                )
            end,
        })
    )
end

-- 3. FlatListVirtualDemo
local function FlatListVirtualDemo()
    local count, setCount = useState(1000)
    local data = {}
    for i = 1, count do
        data[i] = { id = tostring(i), index = i }
    end
    local ITEM_HEIGHT = 60

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("View", {
            style = { padding = T.pad, backgroundColor = T.surface, borderBottomWidth = 1, borderColor = T.border },
        },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold" } },
                "Virtualized: " .. count .. " items (window renders ~" .. math.ceil(display.contentHeight / ITEM_HEIGHT) .. " at a time)"),
            ce("Text", { style = { fontSize = 12, color = T.textSecondary } },
                "Each item is " .. ITEM_HEIGHT .. "px tall")
        ),
        ce(RN.FlatList, {
            data = data,
            keyExtractor = function(item) return item.id end,
            getItemLayout = function(d, i)
                return { length = ITEM_HEIGHT, offset = ITEM_HEIGHT * (i - 1), index = i }
            end,
            renderItem = function(info)
                local bg = info.index % 2 == 0 and T.surface or T.bg
                return ce("View", {
                    key = info.item.id,
                    style = {
                        height = ITEM_HEIGHT, paddingHorizontal = T.pad,
                        justifyContent = "center", backgroundColor = bg,
                        borderBottomWidth = 1, borderColor = T.border,
                    },
                },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } },
                        "Item #" .. info.item.index),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary } },
                        "id: " .. info.item.id)
                )
            end,
            onEndReached = function()
                setCount(function(c) return c + 100 end)
            end,
            onEndReachedThreshold = 0.5,
        })
    )
end

return {
    { name = "ScrollView",     component = ScrollViewDemo,     description = "Vertical + horizontal, onScroll", icon = "S" },
    { name = "FlatList",       component = FlatListBasicDemo,  description = "Header, footer, separator, empty", icon = "F" },
    { name = "VirtualList",    component = FlatListVirtualDemo, description = "1000+ items, windowed rendering", icon = "V" },
}
```

- [ ] **Step 2: Commit**

```bash
git add examples/kitchen_sink/ListsScreens.lua
git commit -m "feat: KitchenSink lists — ScrollView, FlatList basic + virtualized"
```

---

### Task 5: NavigationScreens (3 demos)

**Files:**
- Rewrite: `examples/kitchen_sink/NavigationScreens.lua`

- [ ] **Step 1: Implement all 3 navigation demos**

```lua
-- examples/kitchen_sink/NavigationScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local Navigation = require("navigation")
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local DemoPage = T.DemoPage

-- 1. StackDemo — embedded mini stack navigator
local function StackDemo()
    local Stack = Navigation.createStackNavigator()

    local function ScreenA(props)
        return ce(DemoPage, {},
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = T.gap } }, "Screen A (root)"),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Push Screen B", color = T.accent, onPress = function()
                    props.navigation.push("ScreenB", { from = "A" })
                end }),
                ce(RN.Button, { title = "Navigate to C", color = "#FF6600", onPress = function()
                    props.navigation.navigate("ScreenC", { from = "A" })
                end })
            )
        )
    end

    local function ScreenB(props)
        local params = props.route and props.route.params or {}
        return ce(DemoPage, {},
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = 4 } }, "Screen B"),
            ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginBottom = T.gap } },
                "Param from: " .. (params.from or "none")),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Push Screen C", color = T.accent, onPress = function()
                    props.navigation.push("ScreenC", { from = "B" })
                end }),
                ce(RN.Button, { title = "Replace with C", color = "#E74C3C", onPress = function()
                    props.navigation.replace("ScreenC", { from = "B-replace" })
                end }),
                ce(RN.Button, { title = "Go Back", color = T.textSecondary, onPress = function()
                    props.navigation.goBack()
                end })
            )
        )
    end

    local function ScreenC(props)
        local params = props.route and props.route.params or {}
        return ce(DemoPage, {},
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = 4 } }, "Screen C"),
            ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginBottom = T.gap } },
                "Param from: " .. (params.from or "none")),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Reset to A", color = "#E74C3C", onPress = function()
                    props.navigation.reset({ routes = { { name = "ScreenA" } }, index = 1 })
                end }),
                ce(RN.Button, { title = "Go Back", color = T.textSecondary, onPress = function()
                    props.navigation.goBack()
                end })
            )
        )
    end

    return ce(Stack.Navigator, {
        screenOptions = {
            headerStyle = { backgroundColor = T.surface },
            headerTintColor = T.textPrimary,
        },
    },
        ce(Stack.Screen, { name = "ScreenA", component = ScreenA, options = { title = "Stack Demo: A" } }),
        ce(Stack.Screen, { name = "ScreenB", component = ScreenB, options = { title = "Stack Demo: B" } }),
        ce(Stack.Screen, { name = "ScreenC", component = ScreenC, options = { title = "Stack Demo: C" } })
    )
end

-- 2. HeaderDemo — embedded stack showing header options
local function HeaderDemo()
    local Stack = Navigation.createStackNavigator()

    local function HeaderList(props)
        local items = {
            { name = "CustomTitle", label = "Custom Title" },
            { name = "StyledHeader", label = "Styled Header" },
            { name = "TintColor", label = "Header Tint Color" },
            { name = "CustomButtons", label = "Left/Right Buttons" },
            { name = "NoHeader", label = "No Header" },
        }
        local elements = {}
        for _, item in ipairs(items) do
            elements[#elements + 1] = ce(RN.Pressable, {
                key = item.name,
                style = { padding = T.pad, backgroundColor = T.surface, borderRadius = T.radiusSmall, marginBottom = T.gap },
                onPress = function() props.navigation.navigate(item.name) end,
            }, ce("Text", { style = { fontSize = 16, color = T.accent } }, item.label))
        end
        return ce("ScrollView", {
            style = { flex = 1, backgroundColor = T.bg },
            contentContainerStyle = { padding = T.pad },
        }, elements)
    end

    local function SimpleScreen(props)
        return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
            ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Look at the header above!"),
            ce(RN.Button, { title = "Go Back", color = T.accent, onPress = function() props.navigation.goBack() end })
        )
    end

    return ce(Stack.Navigator, {
        screenOptions = {
            headerStyle = { backgroundColor = T.surface },
            headerTintColor = T.textPrimary,
        },
    },
        ce(Stack.Screen, { name = "HeaderList", component = HeaderList, options = { title = "Header Options" } }),
        ce(Stack.Screen, { name = "CustomTitle", component = SimpleScreen, options = { title = "My Custom Title" } }),
        ce(Stack.Screen, { name = "StyledHeader", component = SimpleScreen, options = {
            title = "Styled",
            headerStyle = { backgroundColor = "#E74C3C", height = 80 },
            headerTintColor = "#FFFFFF",
        } }),
        ce(Stack.Screen, { name = "TintColor", component = SimpleScreen, options = {
            title = "Tint Color",
            headerTintColor = "#00C853",
        } }),
        ce(Stack.Screen, { name = "CustomButtons", component = SimpleScreen, options = {
            title = "Buttons",
            headerLeft = function() return ce("Text", { style = { color = T.accent, fontSize = 14 } }, "[Menu]") end,
            headerRight = function() return ce("Text", { style = { color = "#FF6600", fontSize = 14 } }, "[Save]") end,
        } }),
        ce(Stack.Screen, { name = "NoHeader", component = SimpleScreen, options = { headerShown = false } })
    )
end

-- 3. DrawerDemo — embedded mini drawer navigator
local function DrawerDemo()
    local Drawer = Navigation.createDrawerNavigator()

    local function DrawerHome(props)
        return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = T.gap } }, "Drawer Home"),
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Open Drawer", color = T.accent, onPress = function()
                    props.navigation.openDrawer()
                end }),
                ce(RN.Button, { title = "Close Drawer", color = "#E74C3C", onPress = function()
                    props.navigation.closeDrawer()
                end }),
                ce(RN.Button, { title = "Toggle Drawer", color = "#FF6600", onPress = function()
                    props.navigation.toggleDrawer()
                end }),
                ce(RN.Button, { title = "Go to Settings", color = T.textSecondary, onPress = function()
                    props.navigation.navigate("DrawerSettings")
                end })
            )
        )
    end

    local function DrawerSettings(props)
        return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, marginBottom = T.gap } }, "Settings Screen"),
            ce(RN.Button, { title = "Open Drawer", color = T.accent, onPress = function()
                props.navigation.openDrawer()
            end })
        )
    end

    return ce(Drawer.Navigator, {
        drawerWidth = 220,
    },
        ce(Drawer.Screen, { name = "DrawerHome", component = DrawerHome }),
        ce(Drawer.Screen, { name = "DrawerSettings", component = DrawerSettings })
    )
end

return {
    { name = "StackNav",   component = StackDemo,  description = "Push, pop, replace, reset, params", icon = "S" },
    { name = "Headers",    component = HeaderDemo,  description = "Title, style, buttons, hidden",     icon = "H" },
    { name = "DrawerNav",  component = DrawerDemo,  description = "Open, close, toggle, navigate",     icon = "D" },
}
```

- [ ] **Step 2: Commit**

```bash
git add examples/kitchen_sink/NavigationScreens.lua
git commit -m "feat: KitchenSink navigation — Stack, Header, Drawer demos"
```

---

## Chunk 4: Animation + Interop + Integration

### Task 6: AnimationScreens (5 demos)

**Files:**
- Rewrite: `examples/kitchen_sink/AnimationScreens.lua`

- [ ] **Step 1: Implement all 5 animation demos**

```lua
-- examples/kitchen_sink/AnimationScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useRef = React.useRef
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Animated = require("animated")
local Hooks = require("hooks.useTimer")
local Section = T.Section
local DemoPage = T.DemoPage

-- 1. TimingDemo
local function TimingDemo()
    local posX = useRef(Animated.Value(0)).current
    local opacityVal = useRef(Animated.Value(1)).current
    local duration, setDuration = useState(500)

    local function slideRight()
        Animated.timing(posX, { toValue = 200, duration = duration }).start()
    end
    local function slideLeft()
        Animated.timing(posX, { toValue = 0, duration = duration }).start()
    end
    local function fadeOut()
        Animated.timing(opacityVal, { toValue = 0.1, duration = duration }).start()
    end
    local function fadeIn()
        Animated.timing(opacityVal, { toValue = 1, duration = duration }).start()
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Slide (translateX)" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = T.accent,
                    borderRadius = T.radius, translateX = posX,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 12 } },
                ce(RN.Button, { title = "Right →", color = T.accent, onPress = slideRight }),
                ce(RN.Button, { title = "← Left", color = T.textSecondary, onPress = slideLeft })
            )
        ),
        ce(Section, { title = "Opacity Fade" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = "#FF6600",
                    borderRadius = T.radius, opacity = opacityVal,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 12 } },
                ce(RN.Button, { title = "Fade Out", color = "#FF6600", onPress = fadeOut }),
                ce(RN.Button, { title = "Fade In", color = T.textSecondary, onPress = fadeIn })
            )
        ),
        ce(Section, { title = "Duration: " .. duration .. "ms" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce(RN.Button, { title = "200ms", color = duration == 200 and T.accent or T.textSecondary, onPress = function() setDuration(200) end }),
                ce(RN.Button, { title = "500ms", color = duration == 500 and T.accent or T.textSecondary, onPress = function() setDuration(500) end }),
                ce(RN.Button, { title = "1000ms", color = duration == 1000 and T.accent or T.textSecondary, onPress = function() setDuration(1000) end })
            )
        )
    )
end

-- 2. SpringDemo
local function SpringDemo()
    local scaleVal = useRef(Animated.Value(1)).current
    local function bounce()
        scaleVal:setValue(0.5)
        Animated.spring(scaleVal, { toValue = 1 }).start()
    end
    return ce(DemoPage, {},
        ce(Section, { title = "Spring Scale (tap the box)" },
            ce(Animated.View, {
                style = {
                    width = 120, height = 120, backgroundColor = "#E74C3C",
                    borderRadius = T.radius, scaleX = scaleVal, scaleY = scaleVal,
                    alignSelf = "center",
                },
                onPress = bounce,
            }),
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, textAlign = "center", marginTop = 12 },
            }, "Tap the red box for spring bounce")
        )
    )
end

-- 3. SequenceDemo
local function SequenceDemo()
    local posX = useRef(Animated.Value(0)).current
    local opacityVal = useRef(Animated.Value(1)).current
    local running, setRunning = useState(false)

    local function play()
        setRunning(true)
        posX:setValue(0)
        opacityVal:setValue(1)
        Animated.sequence({
            Animated.timing(posX, { toValue = 200, duration = 400 }),
            Animated.timing(opacityVal, { toValue = 0, duration = 300 }),
            Animated.parallel({
                Animated.timing(posX, { toValue = 0, duration = 400 }),
                Animated.timing(opacityVal, { toValue = 1, duration = 400 }),
            }),
        }).start(function() setRunning(false) end)
    end

    local function reset()
        posX:setValue(0)
        opacityVal:setValue(1)
        setRunning(false)
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Sequence: slide → fade → restore" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = "#00C853",
                    borderRadius = T.radius, translateX = posX, opacity = opacityVal,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 12 } },
                ce(RN.Button, { title = running and "Playing..." or "Play", color = T.accent, onPress = play }),
                ce(RN.Button, { title = "Reset", color = T.textSecondary, onPress = reset })
            )
        )
    )
end

-- 4. ParallelDemo
local function ParallelDemo()
    local scaleVal = useRef(Animated.Value(1)).current
    local rotateVal = useRef(Animated.Value(0)).current
    local opacityVal = useRef(Animated.Value(1)).current

    local function play()
        scaleVal:setValue(1)
        rotateVal:setValue(0)
        opacityVal:setValue(1)
        Animated.parallel({
            Animated.timing(scaleVal, { toValue = 1.5, duration = 600 }),
            Animated.timing(rotateVal, { toValue = 180, duration = 600 }),
            Animated.timing(opacityVal, { toValue = 0.3, duration = 600 }),
        }).start()
    end

    local function reset()
        scaleVal:setValue(1)
        rotateVal:setValue(0)
        opacityVal:setValue(1)
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Parallel: scale + rotate + opacity" },
            ce(Animated.View, {
                style = {
                    width = 100, height = 100, backgroundColor = "#9C27B0",
                    borderRadius = T.radius, alignSelf = "center",
                    scaleX = scaleVal, scaleY = scaleVal,
                    rotation = rotateVal, opacity = opacityVal,
                },
            }),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 16 } },
                ce(RN.Button, { title = "Play All", color = "#9C27B0", onPress = play }),
                ce(RN.Button, { title = "Reset", color = T.textSecondary, onPress = reset })
            )
        )
    )
end

-- 5. LoopDemo
local function LoopDemo()
    local spinVal = useRef(Animated.Value(0)).current
    local pulseVal = useRef(Animated.Value(1)).current
    local spinAnim = useRef(nil)
    local pulseAnim = useRef(nil)
    local running, setRunning = useState(false)
    local tickCount, setTickCount = useState(0)

    -- useInterval-driven counter alongside animation
    Hooks.useInterval(function()
        setTickCount(function(c) return c + 1 end)
    end, running and 1000 or false)

    local function startAll()
        setRunning(true)
        setTickCount(0)
        spinVal:setValue(0)
        pulseVal:setValue(1)
        spinAnim.current = Animated.loop(
            Animated.timing(spinVal, { toValue = 360, duration = 1500 })
        )
        spinAnim.current:start()
        pulseAnim.current = Animated.loop(
            Animated.sequence({
                Animated.timing(pulseVal, { toValue = 0.3, duration = 500 }),
                Animated.timing(pulseVal, { toValue = 1, duration = 500 }),
            }),
            { iterations = 3 }
        )
        pulseAnim.current:start()
    end

    local function stopAll()
        setRunning(false)
        if spinAnim.current then spinAnim.current:stop() end
        if pulseAnim.current then pulseAnim.current:stop() end
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Infinite Rotation" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = T.accent,
                    borderRadius = 8, rotation = spinVal, alignSelf = "center",
                },
            }, ce("Text", {
                style = { fontSize = 24, color = "#FFF", textAlign = "center" },
            }, "+"))
        ),
        ce(Section, { title = "Pulsing Opacity (3 iterations)" },
            ce(Animated.View, {
                style = {
                    width = 80, height = 80, backgroundColor = "#FF6600",
                    borderRadius = 40, opacity = pulseVal, alignSelf = "center",
                },
            })
        ),
        ce(Section, { title = "useInterval Counter" },
            ce("Text", {
                style = { fontSize = 24, color = T.textPrimary, textAlign = "center" },
            }, "Ticks: " .. tickCount)
        ),
        ce("View", { style = { flexDirection = "row", gap = 8 } },
            ce(RN.Button, { title = running and "Running..." or "Start", color = T.accent, onPress = startAll }),
            ce(RN.Button, { title = "Stop", color = T.textSecondary, onPress = stopAll })
        )
    )
end

return {
    { name = "Timing",   component = TimingDemo,   description = "Slide, fade, duration control",       icon = "T" },
    { name = "Spring",   component = SpringDemo,   description = "Elastic bounce on tap",               icon = "S" },
    { name = "Sequence", component = SequenceDemo, description = "Chained multi-step animation",        icon = "Q" },
    { name = "Parallel", component = ParallelDemo, description = "Scale + rotate + fade at once",       icon = "P" },
    { name = "Loop",     component = LoopDemo,     description = "Infinite spin, pulse, useInterval",   icon = "L" },
}
```

- [ ] **Step 2: Commit**

```bash
git add examples/kitchen_sink/AnimationScreens.lua
git commit -m "feat: KitchenSink animation — timing, spring, sequence, parallel, loop"
```

---

### Task 7: InteropScreens (2 demos)

**Files:**
- Rewrite: `examples/kitchen_sink/InteropScreens.lua`

- [ ] **Step 1: Implement both interop demos**

```lua
-- examples/kitchen_sink/InteropScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")

-- 1. ReactInSolar2DDemo
-- Demonstrates native Solar2D code hosting a React subtree via RN.render()
local function ReactInSolar2DDemo()
    local groupRef = useRef(nil)
    local rendererRef = useRef(nil)

    useEffect(function()
        -- Create the scene group that holds everything
        local sceneGroup = display.newGroup()
        groupRef.current = sceneGroup

        -- Section 1: Native Solar2D objects (top)
        local headerText = display.newText({
            parent = sceneGroup, text = "Native Solar2D Header",
            x = display.contentCenterX, y = 40,
            fontSize = 16,
        })
        headerText:setFillColor(1, 0.4, 0) -- orange

        local circle = display.newCircle(sceneGroup, 80, 90, 20)
        circle:setFillColor(1, 0.3, 0.3) -- tomato

        local rect = display.newRect(sceneGroup, 180, 90, 60, 30)
        rect:setFillColor(1, 0.84, 0) -- gold

        -- Section 2: React subtree rendered into a sub-group
        local reactGroup = display.newGroup()
        sceneGroup:insert(reactGroup)
        reactGroup.y = 130

        -- Counter component rendered via RN.render
        local function CounterCard()
            local count, setCount = useState(0)
            return ce("View", {
                style = {
                    backgroundColor = "#161B22", borderRadius = 12,
                    padding = 16, borderWidth = 2, borderColor = "#58A6FF",
                    width = 280, alignSelf = "center",
                },
            },
                ce("Text", { style = { fontSize = 18, color = "#E6EDF3", fontWeight = "bold" } },
                    "React Subtree (RN.render)"),
                ce("Text", { style = { fontSize = 32, color = "#58A6FF", textAlign = "center", marginVertical = 8 } },
                    tostring(count)),
                ce("View", { style = { flexDirection = "row", gap = 8 } },
                    ce(RN.Button, { title = "-1", color = "#E74C3C", onPress = function()
                        setCount(function(c) return c - 1 end)
                    end }),
                    ce(RN.Button, { title = "+1", color = "#00C853", onPress = function()
                        setCount(function(c) return c + 1 end)
                    end })
                )
            )
        end

        rendererRef.current = RN.render(ce(CounterCard), reactGroup, { width = 300, height = 200 })

        -- Section 3: Native footer
        local footerText = display.newText({
            parent = sceneGroup, text = "Native Solar2D Footer",
            x = display.contentCenterX, y = 370,
            fontSize = 14,
        })
        footerText:setFillColor(1, 0.4, 0) -- orange

        return function()
            -- Cleanup: unmount React tree and remove native objects
            if rendererRef.current then
                RN.unmount(reactGroup)
            end
            if sceneGroup and sceneGroup.removeSelf then
                sceneGroup:removeSelf()
            end
        end
    end, {})

    -- This component itself renders nothing via React — everything is in the useEffect
    return ce("View", { style = { flex = 1, backgroundColor = T.bg } })
end

-- 2. Solar2DInReactDemo
-- React layout with native Solar2D display objects created inside via useEffect
local function Solar2DInReactDemo()
    local canvasRef = useRef(nil)
    local running, setRunning = useState(true)
    local runningRef = useRef(true)
    runningRef.current = running

    useEffect(function()
        -- We need access to the View's underlying display group.
        -- The View component creates a display group; we access it after mount.
        -- For this demo, we create a separate group positioned in the canvas area.
        local nativeGroup = display.newGroup()
        local canvasY = 200 -- approximate position of the canvas area
        nativeGroup.y = canvasY

        -- Create native display objects
        local ball = display.newCircle(nativeGroup, 160, 50, 15)
        ball:setFillColor(1, 0.3, 0.3) -- tomato

        local particle1 = display.newCircle(nativeGroup, 40, 30, 4)
        particle1:setFillColor(1, 0.84, 0) -- gold
        particle1.alpha = 0.7

        local particle2 = display.newCircle(nativeGroup, 80, 60, 3)
        particle2:setFillColor(0.53, 0.81, 0.92) -- skyblue
        particle2.alpha = 0.5

        local particle3 = display.newCircle(nativeGroup, 250, 40, 5)
        particle3:setFillColor(0, 0.78, 0.33) -- green
        particle3.alpha = 0.6

        -- Bouncing ball via enterFrame listener
        local direction = 1
        local speed = 3
        local function onEnterFrame()
            if not runningRef.current then return end
            ball.y = ball.y + direction * speed
            if ball.y >= 140 then
                direction = -1
            elseif ball.y <= 10 then
                direction = 1
            end
        end
        Runtime:addEventListener("enterFrame", onEnterFrame)

        -- Cleanup on unmount
        return function()
            Runtime:removeEventListener("enterFrame", onEnterFrame)
            if nativeGroup and nativeGroup.removeSelf then
                nativeGroup:removeSelf()
            end
        end
    end, {})

    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        -- React header
        ce("View", { style = { marginBottom = T.gap } },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } },
                "React Header (managed by React)"),
            ce("View", {
                style = { backgroundColor = T.surface, borderRadius = T.radius, padding = T.pad },
            },
                ce("Text", { style = { fontSize = 16, color = T.textPrimary } },
                    "This header is a normal React View + Text component.")
            )
        ),

        -- Canvas area — the native Solar2D objects are positioned here via useEffect
        ce("View", { style = { marginBottom = T.gap } },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } },
                "Solar2D Canvas (useEffect + enterFrame)"),
            ce("View", {
                style = {
                    height = 180, backgroundColor = "#0A0A1A",
                    borderRadius = T.radius, borderWidth = 2, borderColor = "#FF6600",
                },
            },
                ce("Text", {
                    style = { fontSize = 10, color = "#FF6600", textAlign = "center", marginTop = 4 },
                }, "Native display objects rendered via useEffect + enterFrame listener")
            ),
            ce("View", { style = { flexDirection = "row", gap = 8, marginTop = 8 } },
                ce(RN.Button, {
                    title = running and "Pause" or "Resume",
                    color = T.accent,
                    onPress = function() setRunning(function(r) return not r end) end,
                })
            )
        ),

        -- React footer
        ce("View", { style = { marginBottom = T.gap } },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } },
                "React Footer (managed by React)"),
            ce("View", {
                style = { backgroundColor = T.surface, borderRadius = T.radius, padding = T.pad },
            },
                ce("Text", { style = { fontSize = 16, color = T.textPrimary } },
                    "React manages layout and state. Solar2D handles the bouncing ball with enterFrame. Cleanup runs on unmount.")
            )
        )
    )
end

return {
    { name = "ReactInSolar", component = ReactInSolar2DDemo, description = "Native code hosts React subtree",     icon = "R" },
    { name = "Solar2DInReact", component = Solar2DInReactDemo, description = "React layout with native canvas", icon = "S" },
}
```

- [ ] **Step 2: Commit**

```bash
git add examples/kitchen_sink/InteropScreens.lua
git commit -m "feat: KitchenSink interop — ReactInSolar2D + Solar2DInReact demos"
```

---

### Task 8: main.lua Integration

**Files:**
- Modify: `examples/main.lua`

- [ ] **Step 1: Add KitchenSink as 4th tab in main.lua**

Read current `examples/main.lua`. Add after TetrisApp require:

```lua
local KitchenSinkApp = require("examples.KitchenSinkApp")
```

Add a 4th `Tab.Screen` after the Game screen:

```lua
            ce(Tab.Screen, {
                name = "Showcase",
                component = KitchenSinkApp,
                options = { tabBarLabel = "展示", tabBarIcon = "K" },
            })
```

Also add to `ROUTE_MAP`:

```lua
local ROUTE_MAP = { news = "News", quiz = "Quiz", tetris = "Game", showcase = "Showcase" }
```

- [ ] **Step 2: Verify the app loads in simulator**

Open `examples/main.lua` in Corona Simulator. Verify:
- 4 tabs visible at bottom (热点, 问答, 游戏, 展示)
- "展示" tab shows the 6-tab Kitchen Sink navigator
- Can navigate through all 6 categories
- Demo screens load and interact correctly

- [ ] **Step 3: Commit**

```bash
git add examples/main.lua
git commit -m "feat: add KitchenSink showcase as 4th tab in main.lua"
```

- [ ] **Step 4: Push**

```bash
git push origin master
```
