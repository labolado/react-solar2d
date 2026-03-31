# React-Solar2D Development Notes

Internal notes for framework contributors. For user-facing docs see README.md.

## Architecture

```
react-solar2d/
├── react/              -- React core (createElement, hooks, reconciler)
├── renderer/           -- Solar2D host renderer (display object operations)
├── components/         -- RN-compatible components + ImperativeCanvas/SceneCanvas
├── layout/             -- Yoga C plugin bridge
├── lib/                -- Additional libraries (slider, datetime-picker, etc.)
├── style/              -- StyleSheet system
├── animated/           -- Animation system
├── navigation/         -- Navigation system (Stack, Tab, Drawer)
├── tests/              -- Unit + integration tests
├── plugins/            -- Yoga C plugin source + build
└── docs/               -- User-facing documentation
```

## Key Design Decisions

1. **API aligned with React Native** — RN pure-JS plugins work with minimal import changes
2. **Pure Lua** — no native plugins or source modifications needed
3. **View = Group + Rect**, only uses Container when `overflow: "hidden"` / `clip = true`
4. **Hooks use Lua multiple returns**: `local val, setVal = useState(initial)`

## Solar2D Constraints

- Container mask nesting limit: 3 levels — use Group when clipping not needed
- Color values: 0.0-1.0, framework handles #hex conversion
- Anchor default: center (0.5, 0.5) — framework sets to top-left (0, 0)
- `native.*` objects render on top of everything, ignore display hierarchy
- `display.newRoundedRect` path.width resize unreliable — use key-based recreation

## Framework Constraints

- **ScrollView uses Group** (not Container) — Container causes coordinate issues
- **`overflow: "hidden"`** only works on ImperativeCanvas with `clip=true`
- **Sparse arrays break children** — filter nil/false in varargs
- **`pointerEvents: "none"`** not supported
- **Root fiber position preserved** — `applyLayout` skips x/y for tag=="root" to preserve screenOriginY

## Position Channels (Yoga vs Direct Manipulation)

Yoga's `applyLayout` writes `view.x/y` every frame. Three modes coexist:

1. **Yoga layout** (default): `x = layoutLeft + _translateX`. All static elements.
2. **Animated offset**: `_translateX/_translateY` added on top of Yoga base position. Used by `Animated.Value` driving `translateX/translateY`.
3. **Direct manipulation**: set `instance._directManipulation = true` to bypass Yoga entirely. Component takes full control of x/y. **Must clear the flag when done**, or the element will never return to layout position.

DraggableView and PinchableView set this flag automatically during active gestures. If you write a custom component that directly modifies `instance.x/y` (e.g. a physics-driven element), set this flag or your changes will be overwritten next frame.

## Multitouch (TrackDot Pattern)

Solar2D `setFocus(target, event.id)` is unreliable when called multiple times on the same display object for different fingers. The framework uses the **TrackDot pattern** (from labo_papercut_dinosaur): each finger gets its own invisible `display.newCircle` proxy, and `setFocus` is called per-dot.

- `TouchRegistry` (`lib/TouchRegistry.lua`): global finger ownership — prevents two components from grabbing the same finger. All touch components use `canFocus/claim/release`.
- Touch listeners go on `view._bg` (the background rect), not the group — groups don't reliably receive touch events on all devices.
- `ScrollView` uses `primaryTouchId` to ignore extra fingers during scroll.

## ImperativeCanvas / SceneCanvas

- `clip=true` uses Container — consumes 1 mask level
- `overlay=true` renders surface above React children
- `propsRef` pattern avoids stale closures in onFrame/onDraw
- SceneCanvas dispatches composer lifecycle: create → show(will/did) → hide(will/did) → destroy
- See docs/ImperativeCanvas.md for usage guide

## Screenshot (test_server)

- `display.save(stage)` misses Container children — use Container→Group swap before save
- Crop formula: `pixel = content_coord * (img_pixels / contentWidth)`
- DO NOT resize screenshots — keep full resolution

## Commands

```bash
lua run_tests.lua                    # all tests
lua run_tests.lua scrollview         # pattern match

# Examples (separate repo)
# See https://github.com/labolado/react-solar2d-examples
```
