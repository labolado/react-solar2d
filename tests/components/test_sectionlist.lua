-- tests/components/test_sectionlist.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local createElement = React.createElement

T.describe("SectionList", function()
    T.it("exists and can be required", function()
        local SectionList = require("components.SectionList")
        T.expect(type(SectionList)).toBe("function")
    end)

    T.it("returns a valid React element when rendered", function()
        local SectionList = require("components.SectionList")
        local sections = {
            {
                title = "Section 1",
                data = { { name = "Item 1" }, { name = "Item 2" } },
            },
        }

        local element = createElement(SectionList, {
            sections = sections,
            renderItem = function(info)
                return createElement("Text", {}, info.item.name)
            end,
            renderSectionHeader = function(info)
                return createElement("Text", {}, info.section.title)
            end,
            keyExtractor = function(item, index) return item.name end,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
        -- SectionList is a function component
        T.expect(type(element.type)).toBe("function")
    end)

    T.it("handles empty sections", function()
        local SectionList = require("components.SectionList")
        local element = createElement(SectionList, {
            sections = {},
            renderItem = function() return nil end,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("creates valid element with getItemLayout", function()
        local SectionList = require("components.SectionList")
        local sections = {
            { title = "A", data = { { name = "A1" }, { name = "A2" } } },
        }

        local element = createElement(SectionList, {
            sections = sections,
            renderItem = function(info)
                return createElement("Text", {}, info.item.name)
            end,
            getItemLayout = function(item, index)
                return { length = 50, offset = 50 * (index - 1), index = index }
            end,
            keyExtractor = function(item) return item.name end,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("supports section footer rendering", function()
        local SectionList = require("components.SectionList")
        local sections = {
            { title = "A", data = { { name = "A1" } } },
        }

        local element = createElement(SectionList, {
            sections = sections,
            renderItem = function(info)
                return createElement("Text", {}, info.item.name)
            end,
            renderSectionFooter = function(info)
                return createElement("Text", {}, "Footer")
            end,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)
end)

T.summary()
