--- VirtualizedList component.
-- Core windowed rendering component. Manages scroll-driven window state.
-- @module components.VirtualizedList

local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useRef = React.useRef
local calculateWindow = require("components.WindowCalculator")

--- VirtualizedList component.
-- @param props table {data, renderItem, keyExtractor, getItemLayout, initialNumToRender, windowSize, onEndReached, ...}
-- @return table React element
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

    local scrollStyle = props.style or {}
    if not scrollStyle.height and not scrollStyle.flex then
        scrollStyle = {}
        if props.style then
            for k, v in pairs(props.style) do scrollStyle[k] = v end
        end
        scrollStyle.flex = 1
    end

    return createElement("ScrollView", {
        style = scrollStyle,
        horizontal = props.horizontal,
        contentContainerStyle = props.contentContainerStyle,
        onScroll = handleScroll,
        refreshing = props.refreshing,
        onRefresh = props.onRefresh,
    }, children)
end

return VirtualizedList
