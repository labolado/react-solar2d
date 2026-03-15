-- tests/components/test_textinput.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 1536
display.contentHeight = 2048
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }

local HostConfig = require("renderer.HostConfig")

T.describe("TextInput: creation", function()
    T.it("creates a group with background", function()
        local inst = HostConfig.createInstance("TextInput", {
            style = { width = 300, height = 50, fontSize = 24 },
            placeholder = "Type here...",
        })
        T.expect(inst._type).toBe("group")
        T.expect(inst._bg).toBeTruthy()
        T.expect(inst._isTextInput).toBe(true)
    end)

    T.it("creates placeholder text in mock environment", function()
        local inst = HostConfig.createInstance("TextInput", {
            style = { width = 300, height = 50 },
            placeholder = "Enter name",
        })
        T.expect(inst._placeholder).toBeTruthy()
        T.expect(inst._placeholder.text).toBe("Enter name")
    end)

    T.it("applies borderRadius", function()
        local inst = HostConfig.createInstance("TextInput", {
            style = { width = 300, height = 50, borderRadius = 10 },
        })
        T.expect(inst._bg._type).toBe("roundedRect")
    end)
end)

T.describe("Modal", function()
    T.it("is a function component", function()
        local Modal = require("components.Modal")
        T.expect(type(Modal)).toBe("function")
    end)
end)

T.describe("Switch", function()
    T.it("is a function component", function()
        local Switch = require("components.Switch")
        T.expect(type(Switch)).toBe("function")
    end)
end)

T.describe("Pressable", function()
    T.it("is a function component", function()
        local Pressable = require("components.Pressable")
        T.expect(type(Pressable)).toBe("function")
    end)
end)

T.summary()
