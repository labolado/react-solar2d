-- components/FlatList.lua
-- Function component wrapping ScrollView
local React = require("react")
local createElement = React.createElement

local function FlatList(props)
    local data = props.data or {}
    local renderItem = props.renderItem
    local keyExtractor = props.keyExtractor or function(item, index) return tostring(index) end
    local ItemSeparator = props.ItemSeparatorComponent
    local ListHeader = props.ListHeaderComponent
    local ListFooter = props.ListFooterComponent
    local ListEmpty = props.ListEmptyComponent
    local horizontal = props.horizontal or false
    local style = props.style or {}
    local contentContainerStyle = props.contentContainerStyle or {}

    local children = {}

    if ListHeader then
        children[#children + 1] = createElement("View", { key = "__header" }, ListHeader)
    end

    if #data == 0 and ListEmpty then
        children[#children + 1] = createElement("View", { key = "__empty" }, ListEmpty)
    else
        for i, item in ipairs(data) do
            local key = keyExtractor(item, i)
            children[#children + 1] = renderItem({ item = item, index = i, key = key })
            if ItemSeparator and i < #data then
                children[#children + 1] = createElement(ItemSeparator, { key = key .. "_sep" })
            end
        end
    end

    if ListFooter then
        children[#children + 1] = createElement("View", { key = "__footer" }, ListFooter)
    end

    return createElement("ScrollView", {
        style = style,
        horizontal = horizontal,
        contentContainerStyle = contentContainerStyle,
        onScroll = props.onScroll,
    }, unpack(children))
end

return FlatList
