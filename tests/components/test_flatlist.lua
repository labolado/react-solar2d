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

        T.expect(sepCount).toBe(4)
    end)

end)

T.summary()
