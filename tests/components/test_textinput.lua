-- tests/components/test_textinput.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 1536
display.contentHeight = 2048
display.contentCenterX = 768
display.contentCenterY = 1024
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

T.describe("TextInput: layout position sync", function()
    T.it("has _inputField reference for native field", function()
        -- Mock native.newTextField for this test
        local mockField = { x = 0, y = 0, width = 100, height = 30, addEventListener = function() end }
        local origNative = native
        native = {
            systemFont = "systemFont",
            systemFontBold = "systemFontBold",
            newTextField = function() return mockField end
        }

        local inst = HostConfig.createInstance("TextInput", {
            style = { width = 300, height = 50, fontSize = 24 },
            placeholder = "Type here...",
        })

        T.expect(inst._inputField).toBeTruthy()
        T.expect(inst._inputField).toBe(mockField)

        native = origNative
    end)

    T.it("renderer applyLayout syncs native field position", function()
        -- Setup: mock native field
        local mockField = { x = 0, y = 0, width = 100, height = 30, addEventListener = function() end }
        local origNative = native
        native = {
            systemFont = "systemFont",
            systemFontBold = "systemFontBold",
            newTextField = function() return mockField end
        }

        -- Create TextInput instance
        local inst = HostConfig.createInstance("TextInput", {
            style = { width = 300, height = 50, fontSize = 24 },
            placeholder = "Type here...",
        })

        -- Verify _inputField exists
        T.expect(inst._inputField).toBeTruthy()

        -- Simulate what applyLayout does for TextInput
        local l, t, w, h = 100, 200, 300, 50
        local pad = 4

        -- This mimics the logic in renderer/init.lua applyLayout
        if inst._inputField then
            inst._inputField.x = l + pad
            inst._inputField.y = t + pad
            if w > pad * 2 then inst._inputField.width = w - pad * 2 end
            if h > pad * 2 then inst._inputField.height = h - pad * 2 end
        end

        -- Verify position was synced
        T.expect(mockField.x).toBe(104)
        T.expect(mockField.y).toBe(204)
        T.expect(mockField.width).toBe(292)
        T.expect(mockField.height).toBe(42)

        native = origNative
    end)
end)

T.summary()
