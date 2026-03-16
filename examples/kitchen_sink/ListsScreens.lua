-- examples/kitchen_sink/ListsScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Section = T.Section

-- 1. ScrollViewDemo
local function ScrollViewDemo()
    local scrollY, setScrollY = useState(0)
    -- Vertical cards
    local cards = {}
    local cardColors = { "#E74C3C", "#2979FF", "#00C853", "#FF6600", "#9C27B0", "#00BCD4" }
    for i = 1, 24 do
        local color = cardColors[((i - 1) % #cardColors) + 1]
        cards[#cards + 1] = ce("View", {
            key = "card" .. i,
            style = {
                height = 80, backgroundColor = color, borderRadius = T.radius,
                justifyContent = "center", alignItems = "center", marginBottom = T.gap,
            },
        }, ce("Text", { style = { fontSize = 20, color = "#FFFFFF", fontWeight = "bold" } }, "Card " .. i))
    end

    -- Horizontal thumbnails
    local thumbs = {}
    for i = 1, 12 do
        local color = cardColors[((i - 1) % #cardColors) + 1]
        thumbs[#thumbs + 1] = ce("View", {
            key = "thumb" .. i,
            style = {
                width = 100, height = 100, backgroundColor = color,
                borderRadius = T.radiusSmall, marginRight = T.gap,
                justifyContent = "center", alignItems = "center",
            },
        }, ce("Text", { style = { fontSize = 14, color = "#FFF" } }, "#" .. i))
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("View", {
            style = { padding = T.pad, backgroundColor = T.surface, borderBottomWidth = 1, borderColor = T.border },
        },
            ce("Text", { style = { fontSize = 12, color = T.textSecondary } },
                "Scroll Y: " .. math.floor(scrollY))
        ),
        ce("ScrollView", {
            style = { flex = 1 },
            contentContainerStyle = { padding = T.pad },
            onScroll = function(e)
                setScrollY(math.abs(e.contentOffset.y))
            end,
        },
            ce(Section, { title = "Vertical Scroll (24 cards)" }, cards),
            ce(Section, { title = "Horizontal Scroll" },
                ce("ScrollView", {
                    horizontal = true,
                    style = { height = 120 },
                    contentContainerStyle = { paddingVertical = 8 },
                }, thumbs)
            )
        )
    )
end

-- 2. FlatListBasicDemo
local function FlatListBasicDemo()
    local showData, setShowData = useState(true)
    local data = {}
    if showData then
        for i = 1, 30 do
            data[i] = { id = tostring(i), title = "Item " .. i, subtitle = "Description for item " .. i }
        end
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("View", { style = { padding = T.pad, flexDirection = "row", gap = 8 } },
            ce(RN.Button, {
                title = showData and "Clear Data" or "Load Data",
                color = T.accent,
                onPress = function() setShowData(function(v) return not v end) end,
            })
        ),
        ce(RN.FlatList, {
            data = data,
            keyExtractor = function(item) return item.id end,
            renderItem = function(info)
                return ce("View", {
                    key = info.item.id,
                    style = { padding = T.pad, backgroundColor = T.bg },
                },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, info.item.title),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, info.item.subtitle)
                )
            end,
            ItemSeparatorComponent = function()
                return ce("View", { style = { height = 1, backgroundColor = T.border } })
            end,
            ListHeaderComponent = function()
                return ce("View", { style = { padding = T.pad, backgroundColor = T.surface } },
                    ce("Text", { style = { fontSize = 18, color = T.accent, fontWeight = "bold" } }, "FlatList Header")
                )
            end,
            ListFooterComponent = function()
                return ce("View", { style = { padding = T.pad, backgroundColor = T.surface } },
                    ce("Text", { style = { fontSize = 14, color = T.textSecondary } }, "— End of list —")
                )
            end,
            ListEmptyComponent = function()
                return ce("View", { style = { padding = 40, alignItems = "center" } },
                    ce("Text", { style = { fontSize = 18, color = T.textSecondary } }, "No data"),
                    ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginTop = 8 } }, "Tap 'Load Data' above")
                )
            end,
        })
    )
end

-- 3. FlatListVirtualDemo
local function FlatListVirtualDemo()
    local count, setCount = useState(1000)
    local data = {}
    for i = 1, count do
        data[i] = { id = tostring(i), index = i }
    end
    local ITEM_HEIGHT = 60

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("View", {
            style = { padding = T.pad, backgroundColor = T.surface, borderBottomWidth = 1, borderColor = T.border },
        },
            ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold" } },
                "Virtualized: " .. count .. " items (window renders ~" .. math.ceil(display.contentHeight / ITEM_HEIGHT) .. " at a time)"),
            ce("Text", { style = { fontSize = 12, color = T.textSecondary } },
                "Each item is " .. ITEM_HEIGHT .. "px tall")
        ),
        ce(RN.FlatList, {
            data = data,
            keyExtractor = function(item) return item.id end,
            getItemLayout = function(d, i)
                return { length = ITEM_HEIGHT, offset = ITEM_HEIGHT * (i - 1), index = i }
            end,
            renderItem = function(info)
                local bg = info.index % 2 == 0 and T.surface or T.bg
                return ce("View", {
                    key = info.item.id,
                    style = {
                        height = ITEM_HEIGHT, paddingHorizontal = T.pad,
                        justifyContent = "center", backgroundColor = bg,
                        borderBottomWidth = 1, borderColor = T.border,
                    },
                },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } },
                        "Item #" .. info.item.index),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary } },
                        "id: " .. info.item.id)
                )
            end,
            onEndReached = function()
                setCount(function(c) return c + 100 end)
            end,
            onEndReachedThreshold = 0.5,
        })
    )
end

return {
    { name = "ScrollView",     component = ScrollViewDemo,     description = "Vertical + horizontal, onScroll", icon = "S" },
    { name = "FlatList",       component = FlatListBasicDemo,  description = "Header, footer, separator, empty", icon = "F" },
    { name = "VirtualList",    component = FlatListVirtualDemo, description = "1000+ items, windowed rendering", icon = "V" },
}
