-- components/SectionList.lua
-- Sectioned list component with sticky headers. Wraps VirtualizedList.
-- Falls back to ScrollView when getItemLayout is not provided.
local React = require("react")
local createElement = React.createElement
local VirtualizedList = require("components.VirtualizedList")

local function SectionList(props)
    local sections = props.sections or {}
    local renderItem = props.renderItem
    local renderSectionHeader = props.renderSectionHeader
    local renderSectionFooter = props.renderSectionFooter
    local keyExtractor = props.keyExtractor or function(item, index) return tostring(index) end
    local ItemSeparator = props.ItemSeparatorComponent
    local ListHeader = props.ListHeaderComponent
    local ListFooter = props.ListFooterComponent
    local ListEmpty = props.ListEmptyComponent
    local SectionSeparator = props.SectionSeparatorComponent

    -- Flatten sections into a single data array for virtualization
    local flatData = {}
    local sectionMeta = {} -- Maps flat index to { sectionIndex, itemIndex, isHeader, isFooter }

    for sectionIndex, section in ipairs(sections) do
        local sectionData = section.data or {}
        local sectionKey = section.key or ("section_" .. sectionIndex)

        -- Section header
        if renderSectionHeader then
            table.insert(flatData, {
                _isSectionHeader = true,
                section = section,
                sectionIndex = sectionIndex,
                key = sectionKey .. "_header",
            })
            table.insert(sectionMeta, {
                sectionIndex = sectionIndex,
                itemIndex = nil,
                isHeader = true,
                isFooter = false,
            })
        end

        -- Section items
        for itemIndex, item in ipairs(sectionData) do
            table.insert(flatData, {
                _isItem = true,
                item = item,
                section = section,
                sectionIndex = sectionIndex,
                itemIndex = itemIndex,
                key = keyExtractor(item, itemIndex),
            })
            table.insert(sectionMeta, {
                sectionIndex = sectionIndex,
                itemIndex = itemIndex,
                isHeader = false,
                isFooter = false,
            })
        end

        -- Section footer
        if renderSectionFooter then
            table.insert(flatData, {
                _isSectionFooter = true,
                section = section,
                sectionIndex = sectionIndex,
                key = sectionKey .. "_footer",
            })
            table.insert(sectionMeta, {
                sectionIndex = sectionIndex,
                itemIndex = nil,
                isHeader = false,
                isFooter = true,
            })
        end

        -- Section separator (between sections)
        if SectionSeparator and sectionIndex < #sections then
            table.insert(flatData, {
                _isSectionSeparator = true,
                sectionIndex = sectionIndex,
                key = sectionKey .. "_sep",
            })
            table.insert(sectionMeta, {
                sectionIndex = sectionIndex,
                itemIndex = nil,
                isHeader = false,
                isFooter = false,
                isSectionSeparator = true,
            })
        end
    end

    -- Custom renderItem that handles section headers/footers
    local function wrappedRenderItem(info)
        local item = info.item

        if item._isSectionHeader then
            return createElement("View", { key = item.key },
                renderSectionHeader({ section = item.section })
            )
        end

        if item._isSectionFooter then
            return createElement("View", { key = item.key },
                renderSectionFooter({ section = item.section })
            )
        end

        if item._isSectionSeparator then
            return createElement("View", { key = item.key },
                createElement(SectionSeparator)
            )
        end

        -- Regular item
        local sectionData = item.section.data or {}
        local isLastItem = item.itemIndex == #sectionData

        local element = renderItem({
            item = item.item,
            index = item.itemIndex,
            section = item.section,
            key = item.key,
        })

        -- Item separator (within section)
        if ItemSeparator and not isLastItem then
            return createElement("View", { key = item.key .. "_wrap" },
                element,
                createElement(ItemSeparator, { key = item.key .. "_sep" })
            )
        end

        return element
    end

    -- Custom getItemLayout for flattened data
    local function flattenedGetItemLayout(data, index)
        if not props.getItemLayout then
            return nil
        end

        local item = data[index]
        if item._isSectionHeader or item._isSectionFooter or item._isSectionSeparator then
            -- For section headers/footers/separators, use a default or custom height
            if props.getSectionHeaderLayout and item._isSectionHeader then
                return props.getSectionHeaderLayout(item.section)
            elseif props.getSectionFooterLayout and item._isSectionFooter then
                return props.getSectionFooterLayout(item.section)
            else
                return { length = props.sectionHeaderHeight or 30, offset = 0, index = index }
            end
        end

        -- Regular item - delegate to user's getItemLayout with section-aware info
        local sectionIndex = item.sectionIndex
        local itemIndex = item.itemIndex
        local layout = props.getItemLayout(item.item, itemIndex, item.section)

        -- Calculate offset by summing up previous items
        -- Note: This is simplified; accurate offset requires pre-calculation
        return layout
    end

    -- If no getItemLayout, fall back to non-virtualized ScrollView rendering
    if not props.getItemLayout then
        local children = {}

        if ListHeader then
            children[#children + 1] = createElement("View", { key = "__header" }, ListHeader)
        end

        if #flatData == 0 and ListEmpty then
            children[#children + 1] = createElement("View", { key = "__empty" }, ListEmpty)
        else
            for i, item in ipairs(flatData) do
                children[#children + 1] = wrappedRenderItem({ item = item, index = i })
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
        data = flatData,
        renderItem = wrappedRenderItem,
        keyExtractor = function(item, index) return item.key or tostring(index) end,
        getItemLayout = flattenedGetItemLayout,
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

return SectionList
