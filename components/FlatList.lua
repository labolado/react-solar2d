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

    -- Virtualized path
    return createElement(VirtualizedList, {
        data = data,
        renderItem = wrappedRenderItem,
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
        _ListHeaderComponent = ListHeader,
        _ListFooterComponent = ListFooter,
        _ListEmptyComponent = ListEmpty,
    })
end

return FlatList
