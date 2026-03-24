package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local mockDisplay = require("tests.helpers.mock_display")

display = mockDisplay
display.contentWidth = 375
display.contentHeight = 667
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }

local HostConfig = require("renderer.HostConfig")
local LinearGradientModule = require("lib.linear-gradient")

T.describe("lib/linear-gradient", function()
    T.it("exports callable default component", function()
        local node = LinearGradientModule({ colors = { "#FF0000", "#0000FF" } })
        T.expect(node.type).toBe("LinearGradient")
        T.expect(node.props.colors[1]).toBe("#FF0000")
    end)

    T.it("creates gradient rect with rounded corners", function()
        local inst = HostConfig.createInstance("LinearGradient", {
            colors = { "#FF0000", "#00FF00", "#0000FF" },
            style = { width = 120, height = 60, borderRadius = 20 },
        })
        T.expect(inst._bg).toBeTruthy()
        T.expect(inst._bg._type).toBe("roundedRect")
        local fill = inst._bg.fill
        T.expect(fill).toBeTruthy()
        T.expect(fill.type).toBe("gradient")
        T.expect(fill.color1[1]).toBe(1)
        T.expect(fill.color2[2]).toBe(1)
        T.expect(fill.color3[3]).toBe(1)
    end)

    T.it("updates gradient when colors change", function()
        local inst = HostConfig.createInstance("LinearGradient", {
            colors = { "#FF0000", "#00FF00" },
            style = { width = 80, height = 40 },
        })
        local oldFill = inst._bg.fill
        HostConfig.updateInstance(inst,
            { colors = { "#FF0000", "#00FF00" }, style = { width = 80, height = 40 } },
            { colors = { "#0000FF", "#FFFFFF" }, style = { width = 80, height = 40 } }
        )
        local newFill = inst._bg.fill
        T.expect(oldFill).toNotBe(newFill)
        T.expect(newFill.color1[3]).toBe(1) -- blue -> b channel 1
        T.expect(newFill.color2[1]).toBe(1) -- white -> r channel 1
    end)
end)

T.summary()
