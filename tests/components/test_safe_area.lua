-- tests/components/test_safe_area.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local createElement = React.createElement

T.describe("SafeAreaView", function()
    T.it("exists and can be required", function()
        local SafeAreaView = require("components.SafeAreaView")
        T.expect(type(SafeAreaView)).toBe("function")
    end)

    T.it("returns a valid React element", function()
        local SafeAreaView = require("components.SafeAreaView")
        local element = createElement(SafeAreaView, {},
            createElement("View", {}, "Child content")
        )

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
        T.expect(type(element.type)).toBe("function")
    end)

    T.it("creates element with style prop", function()
        local SafeAreaView = require("components.SafeAreaView")
        local element = createElement(SafeAreaView, {
            style = { backgroundColor = "#FFFFFF" },
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("accepts padding in style", function()
        local SafeAreaView = require("components.SafeAreaView")
        local element = createElement(SafeAreaView, {
            style = { paddingTop = 10, paddingBottom = 20 },
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)
end)

T.summary()
