# React-Solar2D

Pure Lua React framework for Solar2D (Corona SDK). Write UI with React API + Flexbox layout, runs on iOS/Android/Mac/Windows.

## Install

### Option A: Plugin (recommended)

Add to your `build.settings`:

```lua
local rs2d = "https://github.com/labolado/react-solar2d/releases/download/v8/"
local yoga_url = "https://github.com/labolado/solar2d-plugin-yoga/releases/download/v7/"

settings = {
    plugins = {
        ["plugin.react-solar2d"] = {
            publisherId = "com.labolado",
            supportedPlatforms = {
                ["mac-sim"]    = { url = rs2d .. "plugin.react-solar2d.tgz" },
                android        = { url = rs2d .. "plugin.react-solar2d.tgz" },
                iphone         = { url = rs2d .. "plugin.react-solar2d.tgz" },
                ["iphone-sim"] = { url = rs2d .. "plugin.react-solar2d.tgz" },
                ["win32-sim"]  = { url = rs2d .. "plugin.react-solar2d.tgz" },
            },
        },
        ["plugin.yoga"] = {
            publisherId = "com.labolado",
            supportedPlatforms = {
                ["mac-sim"]    = { url = yoga_url .. "plugin.yoga-mac-sim.tgz" },
                android        = { url = yoga_url .. "plugin.yoga-android.tgz" },
                iphone         = { url = yoga_url .. "plugin.yoga-iphone.tgz" },
                ["iphone-sim"] = { url = yoga_url .. "plugin.yoga-iphone-sim.tgz" },
                ["win32-sim"]  = { url = yoga_url .. "plugin.yoga-win32-sim.tgz" },
            },
        },
    },
}
```

### Option B: Local install

```bash
git clone https://github.com/labolado/react-solar2d.git
cd react-solar2d
./scripts/install-local.sh /path/to/your/project
```

This copies framework files directly into your project. No `build.settings` plugin config needed, but Yoga plugin still requires Option A's `plugin.yoga` entry.

## Hello World

```lua
-- main.lua
local RN = require("react_solar2d")
local ce = RN.createElement

local function App()
    return ce("View", {
        style = { flex = 1, backgroundColor = "#1a1a2e", justifyContent = "center", alignItems = "center" },
    },
        ce("Text", {
            style = { color = "#ffffff", fontSize = 24 },
        }, "Hello React-Solar2D!")
    )
end

local container = display.newGroup()
RN.render(ce(App), container)
RN.startAutoFlush()
```

## Components

### View

```lua
ce("View", {
    style = {
        flex = 1,
        flexDirection = "row",       -- "column" (default) | "row"
        justifyContent = "center",   -- "flex-start" | "center" | "flex-end" | "space-between" | "space-around"
        alignItems = "center",       -- "stretch" (default) | "center" | "flex-start" | "flex-end"
        padding = 16,
        margin = 8,
        backgroundColor = "#333",
        borderRadius = 12,
        borderWidth = 1,
        borderColor = "#666",
    },
}, children)
```

### Text

```lua
ce("Text", {
    style = {
        fontSize = 18,
        fontWeight = "bold",         -- "normal" | "bold"
        color = "#ffffff",
        textAlign = "center",        -- "left" | "center" | "right"
    },
}, "Hello")
```

### Image

```lua
-- Network image
ce("Image", {
    source = { uri = "https://example.com/photo.jpg" },
    style = { width = 200, height = 150, borderRadius = 8 },
    resizeMode = "cover",            -- "stretch" | "contain" | "cover" | "center"
})

-- Local image
ce("Image", {
    source = require("assets/icon.png"),
    style = { width = 48, height = 48 },
})
```

### Button

```lua
ce(RN.Button, {
    title = "Press Me",
    color = "#2196F3",
    onPress = function() print("pressed!") end,
})
```

### Pressable

```lua
ce(RN.Pressable, {
    style = { padding = 12, backgroundColor = "#333", borderRadius = 8 },
    onPress = function() print("pressed!") end,
},
    ce("Text", { style = { color = "#fff" } }, "Custom Button")
)
```

### ScrollView

```lua
ce(RN.ScrollView, {
    style = { flex = 1 },
    horizontal = false,              -- true for horizontal scroll
    onScroll = function(e) end,
    contentInset = { bottom = 50 },  -- extra scroll space
}, children)
```

### TextInput

```lua
ce(RN.TextInput, {
    style = { height = 40, borderWidth = 1, borderColor = "#ccc", padding = 8 },
    placeholder = "Type here...",
    value = text,
    onChangeText = function(t) setText(t) end,
})
```

### FlatList

```lua
ce(RN.FlatList, {
    data = items,
    keyExtractor = function(item) return item.id end,
    renderItem = function(info)
        return ce("Text", { style = { padding = 12 } }, info.item.title)
    end,
})
```

### Modal

```lua
ce(RN.Modal, {
    visible = showModal,
    transparent = true,
    onRequestClose = function() setShowModal(false) end,
}, modalContent)
```

### Switch

```lua
ce(RN.Switch, {
    value = isOn,
    onValueChange = function(v) setIsOn(v) end,
})
```

## Hooks

```lua
local RN = require("react_solar2d")
local React = require("react")

-- State (Lua multiple returns, not array)
local count, setCount = React.useState(0)

-- Effect
React.useEffect(function()
    print("mounted")
    return function() print("cleanup") end
end, {})

-- Ref
local ref = React.useRef(nil)

-- Memo / Callback
local doubled = React.useMemo(function() return count * 2 end, {count})
local onPress = React.useCallback(function() setCount(count + 1) end, {count})

-- Context
local ThemeCtx = React.createContext("dark")
local theme = React.useContext(ThemeCtx)
```

## Navigation

```lua
local Navigation = require("navigation")

-- Stack Navigator
local Stack = Navigation.createStackNavigator()

ce(Navigation.NavigationContainer, {},
    ce(Stack.Navigator, {},
        ce(Stack.Screen, { name = "Home", component = HomeScreen }),
        ce(Stack.Screen, { name = "Detail", component = DetailScreen })
    )
)

-- Navigate
props.navigation.navigate("Detail", { id = 123 })
props.navigation.goBack()

-- Tab Navigator
local Tab = Navigation.createBottomTabNavigator()

ce(Tab.Navigator, {},
    ce(Tab.Screen, { name = "Feed", component = FeedScreen,
        options = { tabBarLabel = "Feed", tabBarIcon = "F" } }),
    ce(Tab.Screen, { name = "Profile", component = ProfileScreen,
        options = { tabBarLabel = "Me", tabBarIcon = "P" } })
)
```

## Animation

```lua
local Animated = require("animated")

local opacity = React.useRef(Animated.Value(0)).current

-- Fade in
Animated.timing(opacity, { toValue = 1, duration = 300 }).start()

-- Use in element
ce(Animated.View, {
    style = { opacity = opacity, translateY = slideY },
}, children)
```

## Style

```lua
local StyleSheet = require("style.StyleSheet")

local styles = StyleSheet.create({
    container = { flex = 1, padding = 16, backgroundColor = "#fff" },
    title = { fontSize = 24, fontWeight = "bold", color = "#333" },
})

ce("View", { style = styles.container },
    ce("Text", { style = styles.title }, "Hello")
)
```

Supports standard Flexbox properties: `flex`, `flexDirection`, `justifyContent`, `alignItems`, `alignSelf`, `flexWrap`, `gap`, `padding*`, `margin*`, `width`, `height`, `minWidth`, `maxWidth`, `position` ("relative" | "absolute"), `top`, `left`, `right`, `bottom`.

Colors: `"#RGB"`, `"#RRGGBB"`, `"#RRGGBBAA"`, `"rgba(r,g,b,a)"`, named colors.

## ImperativeCanvas

Bridge between React layout and imperative Solar2D rendering (display objects, physics, etc.):

```lua
local ImperativeCanvas = require("components.ImperativeCanvas")

ce(ImperativeCanvas, {
    style = { width = 400, height = 300 },
    clip = true,
    onDraw = function(surface, w, h)
        local bg = display.newRect(surface, w/2, h/2, w, h)
        bg:setFillColor(0.1, 0.1, 0.3)
    end,
    onFrame = function(surface, dt)
        -- called every frame
    end,
})
```

## Examples

See the `examples/` directory for complete demo apps (News reader, Quiz, Tetris, KitchenSink component showcase).

## Tests

```bash
lua run_tests.lua              # all tests
lua run_tests.lua scrollview   # pattern match
```

See [docs/TESTING.md](docs/TESTING.md) for UI automation and device testing.

## License

MIT
