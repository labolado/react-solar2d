-- tests/renderer/test_hostConfig_new.lua — Tests for new HostConfig features
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 375
display.contentHeight = 812
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }

local HostConfig = require("renderer.HostConfig")

T.describe("View: circle for perfect round shapes", function()
    T.it("uses roundedRect when borderRadius >= width/2 and width == height", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, borderRadius = 50, backgroundColor = "#FF0000" }
        })
        T.expect(inst._bg).toBeTruthy()
        T.expect(inst._bg._type).toBe("roundedRect")
    end)

    T.it("uses roundedRect when borderRadius < width/2", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, borderRadius = 20, backgroundColor = "#FF0000" }
        })
        T.expect(inst._bg._type).toBe("roundedRect")
    end)

    T.it("uses roundedRect when width != height", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 200, height = 100, borderRadius = 50, backgroundColor = "#FF0000" }
        })
        T.expect(inst._bg._type).toBe("roundedRect")
    end)

    T.it("uses plain rect when no borderRadius", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, backgroundColor = "#FF0000" }
        })
        T.expect(inst._bg._type).toBe("rect")
    end)
end)

T.describe("View: centering support", function()
    T.it("stores centering metadata for alignItems", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 300, height = 200, alignItems = "center" }
        })
        T.expect(inst._centerChildren).toBe(true)
        T.expect(inst._alignItems).toBe("center")
        T.expect(inst._viewW).toBe(300)
    end)

    T.it("stores centering metadata for justifyContent", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 300, height = 200, justifyContent = "center" }
        })
        T.expect(inst._centerChildren).toBe(true)
        T.expect(inst._justifyContent).toBe("center")
        T.expect(inst._viewH).toBe(200)
    end)

    T.it("does not set centering without layout props", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 300, height = 200 }
        })
        T.expect(inst._centerChildren).toBeNil()
    end)
end)

T.describe("View: appendChild centering", function()
    T.it("centers child horizontally with alignItems=center", function()
        local parent = HostConfig.createInstance("View", {
            style = { width = 300, height = 200, alignItems = "center", backgroundColor = "#FFF" }
        })
        local child = HostConfig.createInstance("View", {
            style = { width = 100, height = 50, backgroundColor = "#000" }
        })
        -- Mock contentWidth on the child group
        rawset(child, "contentWidth", 100)
        rawset(child, "contentHeight", 50)

        HostConfig.appendChild(parent, child)
        T.expect(child.x).toBe(100) -- (300 - 100) / 2
    end)

    T.it("centers child vertically with justifyContent=center", function()
        local parent = HostConfig.createInstance("View", {
            style = { width = 300, height = 200, justifyContent = "center", backgroundColor = "#FFF" }
        })
        local child = HostConfig.createInstance("View", {
            style = { width = 100, height = 50, backgroundColor = "#000" }
        })
        rawset(child, "contentWidth", 100)
        rawset(child, "contentHeight", 50)

        HostConfig.appendChild(parent, child)
        T.expect(child.y).toBe(75) -- (200 - 50) / 2
    end)
end)

T.describe("wireEvents: tap on group", function()
    T.it("registers tap on group with isHitTestable", function()
        local pressed = false
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 50, backgroundColor = "#FF0000" },
            onPress = function() pressed = true end,
        })
        T.expect(inst._onPress).toBeTruthy()
        -- Tap should be on group itself (isHitTestable = true)
        T.expect(inst._listeners["tap"]).toBeTruthy()
        T.expect(inst.isHitTestable).toBe(true)
    end)

    T.it("registers tap on group for Text with onPress", function()
        local inst = HostConfig.createInstance("Text", {
            children = "Click me",
            onPress = function() end,
        })
        T.expect(inst._listeners["tap"]).toBeTruthy()
        T.expect(inst.isHitTestable).toBe(true)
    end)
end)

T.describe("ScrollView: mouse scroll", function()
    T.it("has mouse listener on touch overlay", function()
        local inst = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        local overlay = inst[inst.numChildren]
        T.expect(overlay._listeners["mouse"]).toBeTruthy()
    end)

    T.it("has touch listener on touch overlay", function()
        local inst = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        local overlay = inst[inst.numChildren]
        T.expect(overlay._listeners["touch"]).toBeTruthy()
    end)
end)

T.describe("parseColor", function()
    T.it("parses #RGB shorthand", function()
        local c = HostConfig._parseColor("#F00")
        -- #F00 -> #FF0000
        T.expect(math.abs(c[1] - 1) < 0.01).toBe(true)
        T.expect(math.abs(c[2] - 0) < 0.01).toBe(true)
        T.expect(math.abs(c[3] - 0) < 0.01).toBe(true)
    end)

    T.it("parses #RRGGBB", function()
        local c = HostConfig._parseColor("#00FF00")
        T.expect(math.abs(c[1] - 0) < 0.01).toBe(true)
        T.expect(math.abs(c[2] - 1) < 0.01).toBe(true)
        T.expect(math.abs(c[3] - 0) < 0.01).toBe(true)
    end)

    T.it("parses rgba()", function()
        local c = HostConfig._parseColor("rgba(255, 128, 0, 0.5)")
        T.expect(math.abs(c[1] - 1) < 0.01).toBe(true)
        T.expect(math.abs(c[2] - 128/255) < 0.01).toBe(true)
        T.expect(math.abs(c[4] - 0.5) < 0.01).toBe(true)
    end)

    T.it("parses named colors", function()
        local c = HostConfig._parseColor("red")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
    end)
end)

T.summary()
