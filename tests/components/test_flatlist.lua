-- tests/components/test_flatlist.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

T.describe("FlatList", function()
    T.it("is a function component", function()
        local FlatList = require("components.FlatList")
        T.expect(type(FlatList)).toBe("function")
    end)

    T.it("returns a ScrollView element", function()
        local React = require("react")
        local FlatList = require("components.FlatList")
        local element = React.createElement(FlatList, {
            data = {{ id = "1", text = "Hello" }},
            renderItem = function(info)
                return React.createElement("Text", { key = info.key }, info.item.text)
            end,
            keyExtractor = function(item) return item.id end,
        })
        -- FlatList is a function component, calling it returns a ScrollView element
        T.expect(element.type).toBe(FlatList)
        T.expect(element.props.data[1].text).toBe("Hello")
    end)
end)

T.summary()
