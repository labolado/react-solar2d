-- tests/components/test_refreshcontrol.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local createElement = React.createElement

T.describe("RefreshControl", function()
    T.it("exists and can be required", function()
        local RefreshControl = require("components.RefreshControl")
        T.expect(type(RefreshControl)).toBe("function")
    end)

    T.it("returns a valid React element", function()
        local RefreshControl = require("components.RefreshControl")
        local element = createElement(RefreshControl, {
            refreshing = false,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
        T.expect(type(element.type)).toBe("function")
    end)

    T.it("creates element with refreshing=true", function()
        local RefreshControl = require("components.RefreshControl")
        local element = createElement(RefreshControl, {
            refreshing = true,
            onRefresh = function() end,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("accepts title prop", function()
        local RefreshControl = require("components.RefreshControl")
        local element = createElement(RefreshControl, {
            refreshing = false,
            title = "Pull to refresh",
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("accepts tintColor and titleColor props", function()
        local RefreshControl = require("components.RefreshControl")
        local element = createElement(RefreshControl, {
            refreshing = false,
            tintColor = "#FF0000",
            titleColor = "#00FF00",
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)
end)

T.summary()
