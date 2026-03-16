# FlatList Virtualization Design

## Problem

Current FlatList renders all items upfront — a simple wrapper around ScrollView. With 1000+ items this means 1000+ display objects in memory, unacceptable for Solar2D's 60fps target.

## Solution

Windowed rendering: FlatList renders only visible items + buffer as React children. The reconciler handles mount/unmount normally via keyed reconciliation. Off-screen items are unmounted (not pooled), new items are mounted fresh. This keeps the architecture simple and avoids reconciler/imperative conflicts.

## Reconciler Boundary

**Decision: FlatList is a normal React component.** It renders a dynamic children array into ScrollView. The reconciler owns all display object lifecycle. There is no manual display object pool — the reconciler's keyed diffing handles reuse naturally.

Why: The existing reconciler manages fiber tree ↔ display object mapping tightly. Bypassing it with manual pooling would cause stale stateNode references and crashes on `flushUpdates()`. Keeping FlatList as a pure React component avoids this entirely.

## API (React Native compatible)

```lua
local ce = React.createElement

ce(FlatList, {
    data = items,                    -- array of data items
    renderItem = function(info)      -- info = { item, index }
        return ce("View", { ... },
            ce("Text", {}, info.item.title)
        )
    end,
    keyExtractor = function(item, index)
        return item.id or tostring(index)
    end,

    -- Required for virtualization (without it, falls back to non-virtualized)
    getItemLayout = function(data, index)
        return { length = 80, offset = 80 * (index - 1), index = index }
    end,

    -- Optional
    initialNumToRender = 15,         -- items rendered on first pass
    windowSize = 5,                  -- visible height multiplier for buffer
    maxToRenderPerBatch = 10,        -- items added per scroll batch
    ListHeaderComponent = Header,
    ListFooterComponent = Footer,
    ListEmptyComponent = Empty,
    ItemSeparatorComponent = Sep,
    horizontal = false,
    contentContainerStyle = {},
    onEndReached = function() end,   -- infinite scroll trigger
    onEndReachedThreshold = 0.5,     -- trigger at 50% from bottom
    onScroll = function(event) end,  -- scroll position callback
})

-- Fallback: without getItemLayout, FlatList renders all items (current behavior)
```

## ScrollView onScroll Callback

**New public API on ScrollView** (needed by FlatList, also useful standalone):

```lua
ce(ScrollView, {
    onScroll = function(event)
        -- event = { contentOffset = { x = 0, y = -scrollY } }
    end,
})
```

Implemented in ScrollViewFactory.lua: fires on touch moved + mouse scroll events. This replaces direct `_scrollY` access with a documented contract.

## Architecture

```
FlatList (function component)
  ├── useState: firstIndex, lastIndex (visible window)
  ├── useRef: lastOffset (scroll position tracking)
  ├── useEffect: subscribe to onScroll, cleanup on unmount
  └── renders → ScrollView
       └── children array (dynamic, only windowed items):
            ├── spacerTop (View with height = firstIndex * itemHeight)
            ├── item[firstIndex] (key from keyExtractor)
            ├── item[firstIndex+1] ...
            ├── item[lastIndex] (key from keyExtractor)
            └── spacerBottom (View with height = remaining)
```

### Key Modules

**1. WindowCalculator** — pure function, no display objects
```lua
-- Given scroll offset, viewport height, item height, total count → window range
-- All indices are 1-based (Lua convention)
function calculateWindow(scrollOffset, viewportHeight, itemHeight, totalCount, windowSize)
    -- visibleStart: first item whose top edge is above viewport bottom
    local visibleStart = math.floor(scrollOffset / itemHeight) + 1
    -- visibleEnd: last item whose bottom edge is below viewport top
    local visibleEnd = math.ceil((scrollOffset + viewportHeight) / itemHeight)
    local visibleCount = visibleEnd - visibleStart + 1
    local buffer = math.floor((windowSize - 1) / 2 * visibleCount)
    return {
        first = math.max(1, visibleStart - buffer),
        last = math.min(totalCount, visibleEnd + buffer),
    }
end

-- Example: scrollOffset=0, viewportHeight=800, itemHeight=80, totalCount=1000, windowSize=5
-- visibleStart=1, visibleEnd=10, visibleCount=10, buffer=20
-- first=1, last=30 → 30 items rendered
```

**2. VirtualizedList** (internal component)
- Manages window state via `useState(firstIndex, lastIndex)`
- Subscribes to ScrollView's `onScroll` callback
- On scroll: recalculate window via WindowCalculator
- Only calls `setState` when window actually changes (avoids unnecessary re-renders)
- Renders dynamic children array with stable keys from `keyExtractor`

**3. FlatList** (public component)
- Thin wrapper over VirtualizedList
- Adds header/footer/empty/separator support
- Header/footer are outside the virtualized range (scroll with content but not virtualized)
- Separators are included in itemHeight calculation (caller must account for them in getItemLayout)
- Compatible API surface with React Native
- Without `getItemLayout`: falls back to rendering all items (current non-virtualized behavior)

## Scroll Position Tracking

FlatList subscribes to scroll via `onScroll` callback, not `enterFrame`:

```lua
-- Inside VirtualizedList component:
local function VirtualizedList(props)
    local window, setWindow = useState({ first = 1, last = props.initialNumToRender or 15 })
    local lastOffsetRef = useRef(0)
    local endReachedRef = useRef(false)

    local function handleScroll(event)
        local offset = math.abs(event.contentOffset.y)
        local itemHeight = props.getItemLayout(props.data, 1).length

        -- Only recalculate when scrolled past half an item height
        if math.abs(offset - lastOffsetRef.current) > itemHeight * 0.5 then
            lastOffsetRef.current = offset
            local newWindow = calculateWindow(offset, viewportHeight, itemHeight, #props.data, props.windowSize or 5)
            if newWindow.first ~= window.first or newWindow.last ~= window.last then
                setWindow(newWindow)
            end
        end

        -- onEndReached with deduplication
        if props.onEndReached then
            local totalHeight = #props.data * itemHeight
            local threshold = (props.onEndReachedThreshold or 0.5) * viewportHeight
            local distanceFromEnd = totalHeight - offset - viewportHeight
            if distanceFromEnd < threshold then
                if not endReachedRef.current then
                    endReachedRef.current = true
                    props.onEndReached({ distanceFromEnd = distanceFromEnd })
                end
            else
                endReachedRef.current = false  -- reset when scrolled away
            end
        end
    end

    -- Render only windowed items with stable keys
    local children = {}
    children[#children + 1] = ce("View", {
        key = "__spacer_top",
        style = { height = (window.first - 1) * itemHeight },
    })
    for i = window.first, window.last do
        local item = props.data[i]
        if item then
            local key = props.keyExtractor(item, i)
            children[#children + 1] = props.renderItem({ item = item, index = i, key = key })
        end
    end
    children[#children + 1] = ce("View", {
        key = "__spacer_bottom",
        style = { height = (#props.data - window.last) * itemHeight },
    })

    return ce(ScrollView, { onScroll = handleScroll, ... }, unpack(children))
end
```

## Key Stability

Each rendered item uses `keyExtractor` for its React key. This ensures:
- Items that stay in the window (53-65) are reconciled in-place (no unmount/remount)
- Items leaving the window are properly unmounted by the reconciler
- Items entering the window are freshly mounted with the correct key

## Constraints

- **Phase 1: Fixed height only** — `getItemLayout` required for virtualization. Without it, falls back to current non-virtualized behavior.
- **No horizontal virtualization in Phase 1** — horizontal FlatList works but without virtualization.
- **renderItem must be pure** — same data + index → same UI structure. Required for efficient keyed reconciliation.
- **Separators in itemHeight** — caller must include separator height in `getItemLayout` calculations.

## Testing

### Mock Tests
- **WindowCalculator**: edge cases (empty list, 1 item, scroll to end, scroll to start, off-by-one with 1-based indices)
- **FlatList rendering**: verify renderItem called with correct indices at offset 0, mid-scroll, end
- **Fallback**: without getItemLayout, all items rendered (backward compatible)
- **onEndReached**: fires at threshold, deduplicated (doesn't fire repeatedly)
- **Key stability**: items remaining in window not re-created

### Simulator Tests
- Render 1000 items, verify only ~30 display objects exist in contentGroup
- Scroll to bottom, verify last items visible
- Scroll back to top, verify first items restored
- onEndReached fires at correct threshold
- Header/footer scroll with content but outside virtualized range
- Performance: no frame drops during continuous scroll

### Test Route Support
```lua
-- test_flatlist_virtual.lua
local sv = RN.render(ce(FlatList, {
    data = generateItems(1000),
    renderItem = ...,
    getItemLayout = function(data, i) return { length = 80, offset = 80*(i-1), index = i } end,
    onScroll = captureScroll,
}), container)
-- Simulate scroll via onScroll callback
captureScroll({ contentOffset = { x = 0, y = -500 } })
RN.flushUpdates()
-- Assert: items 1-6 not rendered, items 7-20 rendered
```

## Files

| File | Purpose |
|------|---------|
| `components/FlatList.lua` | Public API (rewrite existing) |
| `components/VirtualizedList.lua` | Core windowed rendering |
| `components/WindowCalculator.lua` | Pure window calculation |
| `renderer/ScrollViewFactory.lua` | Add onScroll callback support |
| `tests/components/test_flatlist.lua` | Updated tests |
| `tests/components/test_window_calc.lua` | Window calculation tests |
| `tests/solar2d/test_flatlist_virtual.lua` | Simulator perf test |

## Success Criteria

1. 1000 items renders with < 30 display objects at any time
2. Scrolling at 60fps (no frame drops measurable in simulator)
3. API compatible with current FlatList usage in NewsApp
4. Without `getItemLayout`, falls back to non-virtualized (backward compatible)
5. All existing FlatList tests still pass
6. onEndReached fires correctly with deduplication
