-- examples/NewsApp.lua
-- 新闻浏览器 Demo — FlatList + ScrollView + Text styling
local React = require("react")
local createElement = React.createElement
local useState = React.useState

local W = display.contentWidth
local H = display.contentHeight

-- Mock news data
local NEWS_DATA = {
    { id = "1", title = "React-Solar2D 发布 1.0", category = "技术",
      summary = "全新 React Native 兼容框架，让 AI 生成的界面代码在 Solar2D 上运行。支持完整 Flexbox 布局、Hooks 和组件系统。",
      time = "2 小时前" },
    { id = "2", title = "Solar2D 引擎更新至 3.0", category = "技术",
      summary = "新版本带来 Metal 渲染支持、更好的性能和跨平台兼容性。",
      time = "5 小时前" },
    { id = "3", title = "Lua 入选年度编程语言", category = "编程",
      summary = "Lua 以轻量和强大的嵌入性获得开发者社区广泛认可。",
      time = "1 天前" },
    { id = "4", title = "儿童教育应用市场增长 40%", category = "教育",
      summary = "创意物理工具类应用成为最受欢迎的品类之一，labo 系列持续领先。",
      time = "2 天前" },
    { id = "5", title = "Flexbox 布局完全指南", category = "技术",
      summary = "从基础到高级，全面掌握 Flex 容器、项目属性和实战布局技巧。",
      time = "3 天前" },
    { id = "6", title = "Yoga 布局引擎深度解析", category = "技术",
      summary = "Facebook 开源的跨平台布局引擎，支持 Flexbox 标准的高性能 C 实现。",
      time = "4 天前" },
    { id = "7", title = "移动应用设计趋势 2026", category = "设计",
      summary = "简洁、动效、个性化成为三大设计趋势。圆角、渐变、大字体持续流行。",
      time = "5 天前" },
}

local CATEGORY_COLORS = {
    ["技术"] = { bg = "#E3F2FD", text = "#1976D2" },
    ["编程"] = { bg = "#E8F5E9", text = "#388E3C" },
    ["教育"] = { bg = "#FFF3E0", text = "#F57C00" },
    ["设计"] = { bg = "#FCE4EC", text = "#C2185B" },
}

-- Category tag component
local function CategoryTag(props)
    local colors = CATEGORY_COLORS[props.name] or { bg = "#F5F5F5", text = "#666666" }
    return createElement("View", {
        style = {
            backgroundColor = colors.bg,
            borderRadius = 12,
            paddingHorizontal = 20,
            paddingVertical = 8,
            alignSelf = "flex-start",
            marginBottom = 16,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 26,
                color = colors.text,
                fontWeight = "bold",
            },
        }, props.name)
    )
end

-- News card component
local function NewsCard(props)
    local item = props.item
    local isSelected = props.isSelected

    return createElement("View", {
        style = {
            backgroundColor = isSelected and "#F0F7FF" or "#FFFFFF",
            borderRadius = 20,
            marginHorizontal = 40,
            marginBottom = 24,
            padding = 32,
            borderBottomWidth = 1,
            borderBottomColor = "#EEEEEE",
        },
        onPress = props.onPress,
    },
        createElement(CategoryTag, { name = item.category }),
        -- Title
        createElement("Text", {
            style = {
                fontSize = 38,
                color = "#212121",
                fontWeight = "bold",
                marginBottom = 12,
            },
        }, item.title),
        -- Summary
        createElement("Text", {
            style = {
                fontSize = 30,
                color = "#757575",
                lineHeight = 44,
            },
        }, item.summary),
        -- Time
        createElement("Text", {
            style = {
                fontSize = 24,
                color = "#BDBDBD",
                marginTop = 16,
                textAlign = "right",
            },
        }, item.time)
    )
end

-- Top navigation bar
local function NavBar()
    return createElement("View", {
        style = {
            height = 140,
            backgroundColor = "#1976D2",
            flexDirection = "row",
            justifyContent = "center",
            alignItems = "center",
            paddingTop = 30,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 48,
                color = "#FFFFFF",
                fontWeight = "bold",
            },
        }, "📰 新闻浏览器")
    )
end

-- Stats bar
local function StatsBar(props)
    return createElement("View", {
        style = {
            height = 60,
            backgroundColor = "#F5F5F5",
            flexDirection = "row",
            justifyContent = "center",
            alignItems = "center",
            borderBottomWidth = 1,
            borderBottomColor = "#E0E0E0",
        },
    },
        createElement("Text", {
            style = {
                fontSize = 24,
                color = "#9E9E9E",
            },
        }, "共 " .. tostring(props.count) .. " 条新闻")
    )
end

-- Main NewsApp
local function NewsApp()
    local selectedId, setSelectedId = useState(nil)

    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#FAFAFA",
            width = W,
            height = H,
        },
    },
        createElement(NavBar),
        createElement(StatsBar, { count = #NEWS_DATA }),
        createElement("ScrollView", {
            style = {
                flex = 1,
                width = W,
                height = H - 200,
            },
        },
            -- Render news cards manually (ScrollView children)
            unpack((function()
                local cards = {}
                -- Top spacer
                cards[#cards + 1] = createElement("View", {
                    key = "spacer_top",
                    style = { height = 24 },
                })
                for i, item in ipairs(NEWS_DATA) do
                    cards[#cards + 1] = createElement(NewsCard, {
                        key = item.id,
                        item = item,
                        isSelected = selectedId == item.id,
                        onPress = function()
                            if selectedId == item.id then
                                setSelectedId(nil)
                            else
                                setSelectedId(item.id)
                                print("[NewsApp] Selected: " .. item.title)
                            end
                        end,
                    })
                end
                return cards
            end)())
        )
    )
end

return NewsApp
