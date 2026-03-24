-- tests/components/test_keyboard_avoiding.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local React = require("react")
local createElement = React.createElement

T.describe("KeyboardAvoidingView", function()
    T.it("exists and can be required", function()
        local KeyboardAvoidingView = require("components.KeyboardAvoidingView")
        T.expect(type(KeyboardAvoidingView)).toBe("function")
    end)

    T.it("returns a valid React element", function()
        local KeyboardAvoidingView = require("components.KeyboardAvoidingView")
        local element = createElement(KeyboardAvoidingView, {},
            createElement("View", {}, "Child content")
        )

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
        T.expect(type(element.type)).toBe("function")
    end)

    T.it("accepts behavior='padding' prop", function()
        local KeyboardAvoidingView = require("components.KeyboardAvoidingView")
        local element = createElement(KeyboardAvoidingView, {
            behavior = "padding",
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("accepts behavior='position' prop", function()
        local KeyboardAvoidingView = require("components.KeyboardAvoidingView")
        local element = createElement(KeyboardAvoidingView, {
            behavior = "position",
            keyboardVerticalOffset = 50,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("accepts behavior='height' prop", function()
        local KeyboardAvoidingView = require("components.KeyboardAvoidingView")
        local element = createElement(KeyboardAvoidingView, {
            behavior = "height",
            style = { height = 400 },
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)

    T.it("can be disabled", function()
        local KeyboardAvoidingView = require("components.KeyboardAvoidingView")
        local element = createElement(KeyboardAvoidingView, {
            enabled = false,
        })

        T.expect(element).toBeTruthy()
        T.expect(React.isValidElement(element)).toBe(true)
    end)
end)

T.summary()
