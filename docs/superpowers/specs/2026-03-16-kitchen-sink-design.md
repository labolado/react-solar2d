# Kitchen Sink Demo Design

## Goal

A comprehensive showcase app demonstrating every component, hook, navigation pattern, animation, and interop capability of react-solar2d. Serves as both developer reference and framework capability demo.

## Structure

NavigationContainer → BottomTabNavigator (6 tabs) → each tab has a StackNavigator (list page → demo page).

**Entry:** `examples/KitchenSinkApp.lua`, registered as a Screen in `examples/main.lua` TabNavigator.

**Container nesting constraint:** Solar2D limits Container (clipping) nesting to 3 levels. All navigators (Tab, Stack) use Group-based rendering (no clipping), so the nesting depth Tab → Stack → embedded Stack/Drawer is safe. Only Views with `overflow: "hidden"` use Containers — demo content should avoid deep clipping nesting.

## Tab Layout

| Tab | Icon | Label | Screens |
|-----|------|-------|---------|
| 1. Basics | B | 基础 | 6 screens |
| 2. Forms | F | 表单 | 4 screens |
| 3. Lists | L | 列表 | 3 screens |
| 4. Navigation | N | 导航 | 3 screens |
| 5. Animation | A | 动画 | 5 screens |
| 6. Interop | I | 互操作 | 2 screens |

Total: 23 demo screens + 6 list screens = 29 screens.

## Screen Specifications

### Tab 1: Basics (基础)

**ListScreen:** Grid/list of 6 items, each with icon + name + one-line description. Tap → push to demo.

**1. ViewDemo**
- Nested Views with different flexDirection (row/column)
- borderRadius showcase (sharp → rounded → circle)
- opacity levels (1.0, 0.7, 0.4, 0.1)
- backgroundColor palette (6+ colors)
- Demonstrates: View, flexbox layout, styling

**2. TextDemo**
- fontSize range (12→36)
- fontWeight variations (normal/bold)
- color showcase
- numberOfLines truncation (1, 2, unlimited)
- Nested Text (inline bold/color within paragraph — if supported, else note limitation)
- Demonstrates: Text, text styling

**3. ImageDemo**
- Local image with 3 resizeMode options (cover/contain/stretch) side by side
- Different sizes and borderRadius on images
- Demonstrates: Image, resizeMode, image styling

**4. ButtonDemo**
- Buttons with different colors (red/blue/green/default)
- Button onPress counter (tap count display)
- Demonstrates: Button, onPress, useState

**5. PressableDemo**
- Pressable with onPress feedback (color change on tap)
- Pressable with onLongPress (shows "Long pressed!" text)
- Custom styled pressable (card-like, icon-like)
- Demonstrates: Pressable, onPress, onLongPress

**6. TouchableOpacityDemo**
- Three TouchableOpacity with activeOpacity 0.2 / 0.5 / 0.8 side by side
- Tap feedback comparison
- Demonstrates: TouchableOpacity, activeOpacity

### Tab 2: Forms (表单)

**1. TextInputDemo**
- Single-line input with placeholder
- Multi-line input (textarea-like)
- Controlled input: typed text mirrors in a Text below
- Demonstrates: TextInput, onChangeText, useState, controlled components

**2. SwitchDemo**
- Switch with default colors
- Switch with custom trackColor and thumbColor
- Switch value displayed as text ("ON" / "OFF")
- Multiple switches controlling different states
- Demonstrates: Switch, onValueChange, useState

**3. ModalDemo**
- Button to open modal
- Modal with transparent backdrop
- Modal content: title + message + close button
- Demonstrates: Modal, visible, onRequestClose, useState

**4. ActivityIndicatorDemo**
- Size toggle: "small" / "large" / custom number
- Color picker (3-4 color options)
- animating toggle (on/off switch)
- Auto-hide after 3 seconds using useTimeout, then re-show
- Demonstrates: ActivityIndicator, size, color, animating, Switch, useTimeout

### Tab 3: Lists (列表)

**1. ScrollViewDemo**
- Vertical scroll with 20+ colored cards
- Horizontal scroll with thumbnail strip
- contentContainerStyle demo (padding, gap)
- onScroll callback showing scroll position in header
- Demonstrates: ScrollView, horizontal, contentContainerStyle, onScroll

**2. FlatListBasicDemo**
- Simple list with 30 items
- ListHeaderComponent (title bar)
- ListFooterComponent (footer text)
- ItemSeparatorComponent (line between items)
- ListEmptyComponent (shown when data=[])
- Toggle between populated and empty data
- Demonstrates: FlatList (fallback path), header/footer/separator/empty

**3. FlatListVirtualDemo**
- 1000-item list with getItemLayout (fixed 80px height)
- Item shows index number to verify correct items in view
- onEndReached trigger: appends more items (infinite scroll simulation)
- Performance indicator: shows rendered item count vs total
- Demonstrates: FlatList virtualization, getItemLayout, onEndReached, WindowCalculator

### Tab 4: Navigation (导航)

**1. StackDemo**
- Embedded mini StackNavigator inside the demo screen
- Screen A → push Screen B → push Screen C
- goBack, replace, reset demonstrations
- Route params passing and display
- Demonstrates: createStackNavigator, push, pop, replace, reset, navigate, route.params

**2. HeaderDemo**
- Embedded stack with screens showing different header configs:
  - Custom title
  - Custom headerStyle (background color, height)
  - Custom headerLeft (icon button)
  - Custom headerRight (action button)
  - headerShown = false (no header)
  - headerTintColor
- Demonstrates: Header, all header options

**3. DrawerDemo**
- Embedded mini DrawerNavigator
- openDrawer / closeDrawer / toggleDrawer buttons
- Navigate between drawer screens
- Default drawer content visible
- Demonstrates: createDrawerNavigator, drawer navigation methods

### Tab 5: Animation (动画)

**1. TimingDemo**
- Animated.View that slides left→right on button press
- Opacity fade in/out
- Duration control (fast/medium/slow buttons)
- Demonstrates: Animated.timing, Animated.Value, translateX, opacity

**2. SpringDemo**
- Animated.View with spring scale (tap to bounce)
- Spring physics feel vs timing comparison
- Demonstrates: Animated.spring, scale transform

**3. SequenceDemo**
- Three-step animation: move right → fade out → move back + fade in
- Play/reset buttons
- Demonstrates: Animated.sequence, chained animations

**4. ParallelDemo**
- Simultaneous: scale + rotate + color change
- Single button triggers all at once
- Demonstrates: Animated.parallel, multiple Animated.Values

**5. LoopDemo**
- Infinite rotation spinner
- Pulsing opacity loop
- Start/stop controls
- Loop with iterations=3 (finite)
- useInterval-driven counter that ticks every second alongside the animation
- Demonstrates: Animated.loop, iterations, start/stop, useInterval

### Tab 6: Interop (互操作)

**1. ReactInSolar2DDemo**
- Top section: native Solar2D display objects created manually (display.newText, display.newCircle, display.newRect) — static decorative elements
- Middle section: React component tree rendered via `RN.render()` into a sub-group — interactive card with useState counter, styled with the framework
- Bottom section: native Solar2D text showing "Native Solar2D footer"
- Key point: demonstrates native code hosting React subtrees, sharing the same display hierarchy
- Demonstrates: RN.render into arbitrary display.newGroup, mixed native + React

**2. Solar2DInReactDemo**
- Full React layout (View/Text header + footer)
- Middle area: a View container whose display group is accessed via a ref callback or useEffect
- Inside that container: manually created Solar2D objects (animated circles, bouncing ball with enterFrame listener, or simple particle-like effect)
- React manages layout and surrounding UI; Solar2D manages the custom rendering inside the container
- Demonstrates: useEffect + native display object creation inside React layout, cleanup on unmount

## Visual Design

- **Theme:** Dark (consistent with existing apps)
  - Background: #0D1117
  - Card/Surface: #161B22
  - Border: #30363D
  - Text primary: #E6EDF3
  - Text secondary: #8B949E
  - Accent: #58A6FF
  - Tab active: #FF6600 (matches existing main.lua)
  - Tab inactive: #666688

- **List pages:** Each item is a card with left icon circle (accent color) + title + description. Tap pushes demo screen.

- **Demo pages:** Section title at top explaining what's demonstrated, interactive content below, action buttons at bottom where applicable.

- **Spacing:** Consistent padding (16px), gap between cards (12px), border radius (12px for cards, 8px for buttons).

## File Structure

| File | Purpose |
|------|---------|
| `examples/KitchenSinkApp.lua` | Root: nested Tab + Stack navigators |
| `examples/kitchen_sink/BasicsScreens.lua` | 6 basics demo screens |
| `examples/kitchen_sink/FormsScreens.lua` | 4 forms demo screens |
| `examples/kitchen_sink/ListsScreens.lua` | 3 lists demo screens |
| `examples/kitchen_sink/NavigationScreens.lua` | 3 navigation demo screens |
| `examples/kitchen_sink/AnimationScreens.lua` | 5 animation demo screens |
| `examples/kitchen_sink/InteropScreens.lua` | 2 interop demo screens |
| `examples/kitchen_sink/theme.lua` | Shared color constants and spacing values |
| `examples/main.lua` | Add KitchenSink as 4th tab |

Each `*Screens.lua` file exports a table of `{ name, component, description, icon }` entries. The root app reads these to build list pages and register stack screens.

## What's NOT Included

- No hooks-specific demo pages (hooks demonstrated naturally: useState everywhere, useEffect in interop/animation, useRef in lists, useMemo in navigation, useInterval in LoopDemo, useTimeout in ActivityIndicatorDemo)
- No StyleSheet/Color demo page (styles demonstrated everywhere)
- No createContext/useContext standalone page (used implicitly by navigation system; the outer app shell is itself a Tab Navigator demo)
- No useLayoutEffect page (identical to useEffect in Solar2D's single-threaded model)
- No DeepLinking demo (launch-time only, not interactive)
- No useReducer standalone demo (overkill for showcase — used if a demo naturally needs it)

## Success Criteria

1. All 14 components demonstrated with interactive examples
2. All 6 tab sections navigable and functional
3. Embedded navigators (Stack/Drawer) work inside demo screens
4. Animations start/stop/loop correctly
5. FlatList virtualization shows < 30 display objects for 1000 items
6. Interop demos prove bidirectional native ↔ React embedding
7. Runs at 60fps in Solar2D Simulator
8. Visual quality consistent with existing NewsApp/QuizApp
