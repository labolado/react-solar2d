# React-Solar2D

React-like UI framework for Solar2D (Corona SDK), written in pure Lua.

## Features

- React API (createElement, hooks, reconciler, context)
- Flexbox layout via Yoga C plugin
- React Native compatible components (View, Text, ScrollView, TextInput, Modal, etc.)
- Navigation system (Stack, Tab, Drawer)
- Animation system (transition.to wrapper)
- ImperativeCanvas for mixing React UI with imperative Solar2D rendering
- SceneCanvas for loading existing composer scenes into React layout

## Quick Start

### 1. Run the examples

```bash
git clone --recursive https://github.com/labolado/react-solar2d-examples.git
```

Open `main.lua` in the Solar2D Simulator.

See [react-solar2d-examples](https://github.com/labolado/react-solar2d-examples) for demos.

### 2. Use in your own project

Add as a submodule:

```bash
cd your_project/
git submodule add https://github.com/labolado/react-solar2d.git react-solar2d
```

In your `main.lua`:

```lua
local base = system.pathForFile("main.lua"):match("(.+/)") or ""
package.path = base .. "react-solar2d/?.lua;"
            .. base .. "react-solar2d/?/init.lua;"
            .. package.path

local RN = require("react_solar2d")
local React = require("react")
local ce = React.createElement

local function App()
    return ce("View", {
        style = { width = 320, height = 480, backgroundColor = "#1a1a2e" },
    },
        ce("Text", {
            style = { color = "#ffffff", fontSize = 24, textAlign = "center", marginTop = 100 },
        }, "Hello React-Solar2D!")
    )
end

local container = display.newGroup()
RN.render(ce(App), container)
RN.startAutoFlush()
```

### 3. With Yoga layout (optional)

Build the Yoga C plugin for flexbox layout:

```bash
cd plugins/yoga && make solar2d
```

Then add to your package.cpath:

```lua
local YOGA = base .. "react-solar2d/plugins/yoga/build-solar2d/"
package.cpath = YOGA .. "?.dylib;" .. YOGA .. "?.so;" .. package.cpath
```

## Components

| Component | Description |
|-----------|-------------|
| View | Container with flexbox layout |
| Text | Text display |
| Image | Image display |
| ScrollView | Scrollable container with touch/mouse wheel |
| TextInput | Native text input field |
| Button | Simple button with title |
| Pressable | Touchable wrapper with press feedback |
| FlatList | Virtualized list |
| SectionList | Grouped list with section headers |
| Modal | Full-screen overlay |
| Switch | Toggle switch |
| Slider | Value slider (lib/slider) |
| ImperativeCanvas | Bridge for imperative Solar2D rendering |
| SceneCanvas | Load composer scenes into React layout |

## Hooks

```lua
local val, setVal = React.useState(initialValue)
local ref = React.useRef(nil)
React.useEffect(function() ... end, {deps})
local memoized = React.useMemo(function() ... end, {deps})
local callback = React.useCallback(function() ... end, {deps})
local val = React.useContext(MyContext)
```

## ImperativeCanvas

Embed Solar2D imperative rendering (display objects, physics, animations) inside React layout:

```lua
local ImperativeCanvas = require("components.ImperativeCanvas")

ce(ImperativeCanvas, {
    style = { width = 400, height = 300 },
    clip = true,    -- clip content to bounds
    onDraw = function(surface, w, h)
        local bg = display.newRect(surface, w/2, h/2, w, h)
        bg:setFillColor(0.1, 0.1, 0.3)
    end,
    onFrame = function(surface, dt)
        -- called every frame
    end,
})
```

See [docs/ImperativeCanvas.md](docs/ImperativeCanvas.md) for full guide.

## Tests

```bash
lua run_tests.lua              # all tests
lua run_tests.lua scrollview   # pattern match
```

## License

MIT
