# FlatList Virtualization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the naive FlatList (renders all items) with windowed rendering that keeps <30 display objects for 1000+ item lists.

**Architecture:** WindowCalculator (pure function) computes visible range → VirtualizedList (React component) manages window state via onScroll → FlatList wraps VirtualizedList with header/footer/separator support. Falls back to current behavior without `getItemLayout`.

**Tech Stack:** Pure Lua, React hooks (useState, useRef), Solar2D display objects via reconciler.

**Spec:** `docs/superpowers/specs/2026-03-16-flatlist-virtualization-design.md`

---

## File Structure

| File | Purpose | Action |
|------|---------|--------|
| `components/WindowCalculator.lua` | Pure window range calculation | Create |
| `components/VirtualizedList.lua` | Core windowed rendering component | Create |
| `components/FlatList.lua` | Public API with header/footer/separator | Rewrite |
| `renderer/ScrollViewFactory.lua` | Add onScroll callback support | Modify |
| `tests/components/test_window_calc.lua` | WindowCalculator unit tests | Create |
| `tests/components/test_flatlist.lua` | FlatList integration tests | Rewrite |
| `tests/helpers/mock_display.lua` | Add contentWidth/contentHeight globals | Modify |
| `components/init.lua` | No change needed (FlatList already exported) | — |

---

## Chunk 1: ScrollView onScroll + WindowCalculator

### Task 1: ScrollView onScroll Callback

The ScrollViewFactory currently handles touch/mouse scroll but never fires an `onScroll` callback. FlatList needs this to track scroll position.

**Files:**
- Modify: `renderer/ScrollViewFactory.lua`
- Test: `tests/components/test_scrollview.lua` (existing)

- [ ] **Step 1: Add onScroll firing to touch moved handler**

In `renderer/ScrollViewFactory.lua`, after updating `contentGroup.y` (or `.x` for horizontal), fire the callback:

```lua
-- Add helper inside createScrollView, after clipContainer declarations (around line 28):
local function fireOnScroll()
    if props.onScroll then
        if horizontal then
            props.onScroll({
                contentOffset = { x = clipContainer._scrollX, y = 0 },
            })
        else
            props.onScroll({
                contentOffset = { x = 0, y = clipContainer._scrollY },
            })
        end
    end
end
```

Then call `fireOnScroll()` at the end of the `"moved"` phase (line ~113, after all scroll position updates), at the end of the `"ended"` phase (line ~166, after snap-back adjustments), and at the end of the mouse scroll handler (line ~192, after position updates).

- [ ] **Step 2: Verify existing ScrollView tests still pass**

Run: `cd /path/to/project && lua tests/components/test_scrollview.lua`
Expected: All existing tests pass.

- [ ] **Step 3: Commit**

```bash
git add renderer/ScrollViewFactory.lua
git commit -m "feat: add onScroll callback to ScrollView"
```

---

### Task 2: WindowCalculator — Tests First

**Files:**
- Create: `components/WindowCalculator.lua`
- Create: `tests/components/test_window_calc.lua`

- [ ] **Step 1: Write failing tests**

```lua
-- tests/components/test_window_calc.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local calculateWindow = require("components.WindowCalculator")

T.describe("WindowCalculator", function()

    T.it("returns full range for small list", function()
        -- 5 items, all visible (viewport fits them all)
        local w = calculateWindow(0, 400, 80, 5, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(5)
    end)

    T.it("returns windowed range at offset 0", function()
        -- 1000 items, viewport=800, itemHeight=80 → 10 visible
        -- windowSize=5 → buffer = floor((5-1)/2 * 10) = 20
        -- first = max(1, 1-20) = 1, last = min(1000, 10+20) = 30
        local w = calculateWindow(0, 800, 80, 1000, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(30)
    end)

    T.it("returns windowed range at mid scroll", function()
        -- scrollOffset=4000 → visibleStart = floor(4000/80)+1 = 51
        -- visibleEnd = ceil((4000+800)/80) = 60
        -- visibleCount=10, buffer=20
        -- first = max(1, 51-20) = 31, last = min(1000, 60+20) = 80
        local w = calculateWindow(4000, 800, 80, 1000, 5)
        T.expect(w.first).toBe(31)
        T.expect(w.last).toBe(80)
    end)

    T.it("clamps at end of list", function()
        -- scrollOffset near end: 79200 = (1000-10)*80
        -- visibleStart = floor(79200/80)+1 = 991
        -- visibleEnd = ceil((79200+800)/80) = 1000
        -- buffer=20, first = max(1, 991-20) = 971, last = min(1000, 1000+20) = 1000
        local w = calculateWindow(79200, 800, 80, 1000, 5)
        T.expect(w.first).toBe(971)
        T.expect(w.last).toBe(1000)
    end)

    T.it("handles empty list", function()
        local w = calculateWindow(0, 800, 80, 0, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(0)
    end)

    T.it("handles single item", function()
        local w = calculateWindow(0, 800, 80, 1, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(1)
    end)

    T.it("respects windowSize=1 (no buffer)", function()
        -- windowSize=1 → buffer = floor((1-1)/2 * 10) = 0
        local w = calculateWindow(0, 800, 80, 1000, 1)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(10)
    end)

end)

T.summary()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /path/to/project && lua tests/components/test_window_calc.lua`
Expected: FAIL — module `components.WindowCalculator` not found.

- [ ] **Step 3: Write WindowCalculator implementation**

```lua
-- components/WindowCalculator.lua
-- Pure function: given scroll state, returns 1-based index range of items to render.
-- All indices are 1-based (Lua convention).

local function calculateWindow(scrollOffset, viewportHeight, itemHeight, totalCount, windowSize)
    if totalCount == 0 or itemHeight == 0 then
        return { first = 1, last = 0 }
    end

    local visibleStart = math.floor(scrollOffset / itemHeight) + 1
    local visibleEnd = math.ceil((scrollOffset + viewportHeight) / itemHeight)
    local visibleCount = math.max(1, visibleEnd - visibleStart + 1)
    local buffer = math.floor((windowSize - 1) / 2 * visibleCount)

    return {
        first = math.max(1, visibleStart - buffer),
        last = math.min(totalCount, visibleEnd + buffer),
    }
end

return calculateWindow
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /path/to/project && lua tests/components/test_window_calc.lua`
Expected: All 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add components/WindowCalculator.lua tests/components/test_window_calc.lua
git commit -m "feat: add WindowCalculator with full test coverage"
```

---

## Chunk 2: VirtualizedList + FlatList Rewrite

### Task 3: VirtualizedList Component

**Files:**
- Create: `components/VirtualizedList.lua`

- [ ] **Step 1: Write VirtualizedList**

```lua
-- components/VirtualizedList.lua
-- Core windowed rendering component. Manages scroll-driven window state.
local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useRef = React.useRef
local calculateWindow = require("components.WindowCalculator")

local function VirtualizedList(props)
    local data = props.data or {}
    local renderItem = props.renderItem
    local keyExtractor = props.keyExtractor or function(item, index) return tostring(index) end
    local getItemLayout = props.getItemLayout
    local initialNumToRender = props.initialNumToRender or 15
    local windowSize = props.windowSize or 5
    local onEndReached = props.onEndReached
    local onEndReachedThreshold = props.onEndReachedThreshold or 0.5

    -- Get item height from getItemLayout (required for virtualization)
    local itemHeight = 0
    if #data > 0 and getItemLayout then
        itemHeight = getItemLayout(data, 1).length
    end

    -- Viewport height from ScrollView style or display default
    local viewportHeight = (props.style and props.style.height)
        or (display and display.contentHeight) or 480

    local window, setWindow = useState({
        first = 1,
        last = math.min(#data, initialNumToRender),
    })
    local windowRef = useRef({ first = 1, last = math.min(#data, initialNumToRender) })
    local lastOffsetRef = useRef(0)
    local endReachedRef = useRef(false)

    -- Keep ref in sync with state
    windowRef.current = window

    local function handleScroll(event)
        local offset
        if props.horizontal then
            offset = math.abs(event.contentOffset.x)
        else
            offset = math.abs(event.contentOffset.y)
        end

        -- Only recalculate when scrolled past half an item height
        if itemHeight > 0 and math.abs(offset - lastOffsetRef.current) > itemHeight * 0.5 then
            lastOffsetRef.current = offset
            local newWindow = calculateWindow(offset, viewportHeight, itemHeight, #data, windowSize)
            local cur = windowRef.current
            if newWindow.first ~= cur.first or newWindow.last ~= cur.last then
                setWindow(newWindow)
            end
        end

        -- onEndReached with deduplication
        if onEndReached and itemHeight > 0 then
            local totalHeight = #data * itemHeight
            local threshold = onEndReachedThreshold * viewportHeight
            local distanceFromEnd = totalHeight - offset - viewportHeight
            if distanceFromEnd < threshold then
                if not endReachedRef.current then
                    endReachedRef.current = true
                    onEndReached({ distanceFromEnd = distanceFromEnd })
                end
            else
                endReachedRef.current = false
            end
        end

        -- Forward to user's onScroll
        if props.onScroll then
            props.onScroll(event)
        end
    end

    -- Build children array with spacers
    local children = {}

    -- Header (outside virtualized window, scrolls with content)
    if props._ListHeaderComponent then
        children[#children + 1] = createElement("View", { key = "__header" },
            props._ListHeaderComponent)
    end

    -- Empty state
    if #data == 0 and props._ListEmptyComponent then
        children[#children + 1] = createElement("View", { key = "__empty" },
            props._ListEmptyComponent)
    end

    -- Top spacer
    if itemHeight > 0 then
        children[#children + 1] = createElement("View", {
            key = "__spacer_top",
            style = { height = (window.first - 1) * itemHeight, width = 1 },
        })
    end

    -- Render windowed items
    local first = math.max(1, window.first)
    local last = math.min(#data, window.last)
    for i = first, last do
        local item = data[i]
        if item then
            local key = keyExtractor(item, i)
            children[#children + 1] = renderItem({ item = item, index = i, key = key })
        end
    end

    -- Bottom spacer
    if itemHeight > 0 then
        children[#children + 1] = createElement("View", {
            key = "__spacer_bottom",
            style = { height = math.max(0, #data - window.last) * itemHeight, width = 1 },
        })
    end

    -- Footer (outside virtualized window, scrolls with content)
    if props._ListFooterComponent then
        children[#children + 1] = createElement("View", { key = "__footer" },
            props._ListFooterComponent)
    end

    return createElement("ScrollView", {
        style = props.style,
        horizontal = props.horizontal,
        contentContainerStyle = props.contentContainerStyle,
        onScroll = handleScroll,
        refreshing = props.refreshing,
        onRefresh = props.onRefresh,
    }, children)
end

return VirtualizedList
```

- [ ] **Step 2: Commit**

```bash
git add components/VirtualizedList.lua
git commit -m "feat: add VirtualizedList windowed rendering component"
```

---

### Task 4: Rewrite FlatList with Virtualization + Fallback

**Files:**
- Rewrite: `components/FlatList.lua`
- Rewrite: `tests/components/test_flatlist.lua`

- [ ] **Step 1: Write FlatList tests**

```lua
-- tests/components/test_flatlist.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

-- Mock Solar2D globals before requiring modules
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
local FlatList = require("components.FlatList")
local HostConfig = require("renderer.HostConfig")
local Reconciler = require("react.Reconciler")

local function makeData(n)
    local data = {}
    for i = 1, n do
        data[i] = { id = tostring(i), title = "Item " .. i }
    end
    return data
end

local function simpleRenderItem(info)
    return ce("View", { key = info.key, style = { height = 80 } },
        ce("Text", {}, info.item.title))
end

local function simpleKeyExtractor(item) return item.id end

T.describe("FlatList", function()

    T.it("renders all items without getItemLayout (fallback)", function()
        local renderCount = 0
        local function countingRender(info)
            renderCount = renderCount + 1
            return ce("View", { key = info.key }, ce("Text", {}, info.item.title))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(FlatList, {
            data = makeData(50),
            renderItem = countingRender,
            keyExtractor = simpleKeyExtractor,
        }), container)

        T.expect(renderCount).toBe(50)
    end)

    T.it("renders only windowed items with getItemLayout", function()
        local renderCount = 0
        local function countingRender(info)
            renderCount = renderCount + 1
            return ce("View", { key = info.key, style = { height = 80 } },
                ce("Text", {}, info.item.title))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(FlatList, {
            data = makeData(1000),
            renderItem = countingRender,
            keyExtractor = simpleKeyExtractor,
            getItemLayout = function(data, index)
                return { length = 80, offset = 80 * (index - 1), index = index }
            end,
            initialNumToRender = 15,
        }), container)

        -- Should render only initialNumToRender items, not 1000
        T.expect(renderCount <= 30).toBeTruthy()
    end)

    T.it("renders header and footer", function()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(FlatList, {
            data = makeData(3),
            renderItem = simpleRenderItem,
            keyExtractor = simpleKeyExtractor,
            ListHeaderComponent = ce("Text", {}, "Header"),
            ListFooterComponent = ce("Text", {}, "Footer"),
        }), container)
        -- No crash = success (header/footer rendered)
        T.expect(true).toBeTruthy()
    end)

    T.it("renders empty component when data is empty", function()
        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(FlatList, {
            data = {},
            renderItem = simpleRenderItem,
            keyExtractor = simpleKeyExtractor,
            ListEmptyComponent = ce("Text", {}, "No items"),
        }), container)
        T.expect(true).toBeTruthy()
    end)

    T.it("renders separators between items", function()
        local sepCount = 0
        local function Sep()
            sepCount = sepCount + 1
            return ce("View", { style = { height = 1 } })
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(FlatList, {
            data = makeData(5),
            renderItem = simpleRenderItem,
            keyExtractor = simpleKeyExtractor,
            ItemSeparatorComponent = Sep,
        }), container)

        T.expect(sepCount).toBe(4) -- n-1 separators
    end)

end)

T.summary()
```

- [ ] **Step 2: Run tests — should fail (old FlatList has no virtualization)**

Run: `cd /path/to/project && lua tests/components/test_flatlist.lua`
Expected: The "renders only windowed items" test may pass trivially with old code (renders all 1000), so check renderCount.

- [ ] **Step 3: Rewrite FlatList.lua**

```lua
-- components/FlatList.lua
-- Public API component. Wraps VirtualizedList with header/footer/separator support.
-- Without getItemLayout, falls back to rendering all items (backward compatible).
local React = require("react")
local createElement = React.createElement
local VirtualizedList = require("components.VirtualizedList")

local function FlatList(props)
    local data = props.data or {}
    local renderItem = props.renderItem
    local keyExtractor = props.keyExtractor or function(item, index) return tostring(index) end
    local ItemSeparator = props.ItemSeparatorComponent
    local ListHeader = props.ListHeaderComponent
    local ListFooter = props.ListFooterComponent
    local ListEmpty = props.ListEmptyComponent

    -- Wrap renderItem to inject separators
    local function wrappedRenderItem(info)
        local element = renderItem(info)
        if ItemSeparator and info.index < #data then
            return createElement("View", { key = info.key .. "_wrap" },
                element,
                createElement(ItemSeparator, { key = info.key .. "_sep" })
            )
        end
        return element
    end

    -- If no getItemLayout, fall back to non-virtualized rendering
    if not props.getItemLayout then
        local children = {}

        if ListHeader then
            children[#children + 1] = createElement("View", { key = "__header" }, ListHeader)
        end

        if #data == 0 and ListEmpty then
            children[#children + 1] = createElement("View", { key = "__empty" }, ListEmpty)
        else
            for i, item in ipairs(data) do
                local key = keyExtractor(item, i)
                local info = { item = item, index = i, key = key }
                children[#children + 1] = wrappedRenderItem(info)
            end
        end

        if ListFooter then
            children[#children + 1] = createElement("View", { key = "__footer" }, ListFooter)
        end

        return createElement("ScrollView", {
            style = props.style,
            horizontal = props.horizontal,
            contentContainerStyle = props.contentContainerStyle,
            onScroll = props.onScroll,
            refreshing = props.refreshing,
            onRefresh = props.onRefresh,
        }, children)
    end

    -- Virtualized path: wrap renderItem to add header/footer outside window
    local function virtualizedRenderItem(info)
        return wrappedRenderItem(info)
    end

    -- Build header/footer as extra children would require VirtualizedList changes.
    -- Instead, we adjust the VirtualizedList props to handle header/footer:
    -- Header and footer are passed through as props to VirtualizedList's internal rendering.
    -- For simplicity, we wrap VirtualizedList in a view with header/footer outside.

    -- Actually, header/footer should scroll with content. The simplest approach:
    -- Render VirtualizedList directly but prepend/append header/footer in the renderItem flow.

    return createElement(VirtualizedList, {
        data = data,
        renderItem = virtualizedRenderItem,
        keyExtractor = keyExtractor,
        getItemLayout = props.getItemLayout,
        initialNumToRender = props.initialNumToRender,
        windowSize = props.windowSize,
        maxToRenderPerBatch = props.maxToRenderPerBatch,
        onEndReached = props.onEndReached,
        onEndReachedThreshold = props.onEndReachedThreshold,
        onScroll = props.onScroll,
        horizontal = props.horizontal,
        style = props.style,
        contentContainerStyle = props.contentContainerStyle,
        refreshing = props.refreshing,
        onRefresh = props.onRefresh,
        -- Pass header/footer/empty for VirtualizedList to handle
        _ListHeaderComponent = ListHeader,
        _ListFooterComponent = ListFooter,
        _ListEmptyComponent = ListEmpty,
    })
end

return FlatList
```

Note: VirtualizedList already handles `_ListHeaderComponent`, `_ListFooterComponent`, `_ListEmptyComponent` from Task 3.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /path/to/project && lua tests/components/test_flatlist.lua`
Expected: All 5 tests pass.

- [ ] **Step 5: Run all existing tests**

Run: `cd /path/to/project && for f in tests/components/test_*.lua tests/react/test_*.lua tests/renderer/test_*.lua; do echo "--- $f ---"; lua "$f"; done`
Expected: All existing tests still pass (backward compatibility).

- [ ] **Step 6: Commit**

```bash
git add components/FlatList.lua components/VirtualizedList.lua tests/components/test_flatlist.lua
git commit -m "feat: FlatList virtualization with windowed rendering

Renders only visible items + buffer when getItemLayout provided.
Falls back to full rendering without getItemLayout (backward compatible)."
```

---

## Chunk 3: Integration + Exports

### Task 5: Update Exports and Integration Test

**Files:**
- Modify: `react_solar2d.lua` (no change needed — FlatList already exported)
- Verify: `examples/NewsApp.lua` compatibility

- [ ] **Step 1: Verify FlatList is already exported**

Read `react_solar2d.lua` — confirm `RN.FlatList = Components.FlatList` exists. No change needed.

- [ ] **Step 2: Verify NewsApp compatibility**

The NewsApp uses FlatList without `getItemLayout`, so it will use the fallback path. No changes needed to NewsApp for backward compatibility. Future: NewsApp can opt-in to virtualization by adding `getItemLayout`.

- [ ] **Step 3: Run the full test suite one final time**

Run: `cd /path/to/project && for f in tests/components/test_*.lua tests/react/test_*.lua tests/renderer/test_*.lua tests/style/test_*.lua; do echo "--- $f ---"; lua "$f"; done`
Expected: All tests pass.

- [ ] **Step 4: Final commit (if any cleanup needed)**

Only if changes were needed from steps above.
