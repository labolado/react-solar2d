-- tests/components/test_scrollview.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
display.contentWidth = 1536
display.contentHeight = 2048
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }

local HostConfig = require("renderer.HostConfig")

T.describe("ScrollView: creation", function()
    T.it("creates a container with content group", function()
        local inst = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        T.expect(inst._type).toBe("group")
        T.expect(inst._contentGroup).toBeTruthy()
        T.expect(inst._scrollH).toBe(400)
        T.expect(inst._scrollW).toBe(300)
    end)

    T.it("defaults to full screen dimensions", function()
        local inst = HostConfig.createInstance("ScrollView", {
            style = {},
        })
        T.expect(inst._scrollW).toBe(1536)
        T.expect(inst._scrollH).toBe(2048)
    end)

    T.it("supports horizontal mode", function()
        local inst = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
            horizontal = true,
        })
        T.expect(inst._horizontal).toBe(true)
    end)
end)

T.describe("ScrollView: appendChild routes to content group", function()
    T.it("inserts child into contentGroup", function()
        local sv = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        local child = HostConfig.createInstance("View", {
            style = { height = 100 },
        })
        HostConfig.appendChild(sv, child)
        T.expect(sv._contentGroup.numChildren).toBe(1)
    end)

    T.it("regular View still uses direct insert", function()
        local parent = HostConfig.createInstance("View", {})
        local child = HostConfig.createInstance("View", {})
        HostConfig.appendChild(parent, child)
        T.expect(parent.numChildren).toBe(1)
    end)
end)

T.describe("ScrollView: scroll state", function()
    T.it("initializes scroll position to 0", function()
        local inst = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        T.expect(inst._scrollX).toBe(0)
        T.expect(inst._scrollY).toBe(0)
    end)

    T.it("has touch overlay for scrolling", function()
        local inst = HostConfig.createInstance("ScrollView", {
            style = { width = 300, height = 400 },
        })
        -- touchOverlay is inside offsetGroup (Container center→top-left translation)
        local overlay = inst._touchOverlay
        T.expect(overlay).toBeTruthy()
        T.expect(overlay._type).toBe("rect")
        T.expect(overlay.isHitTestable).toBe(true)
        T.expect(overlay._listeners["touch"]).toBeTruthy()
        T.expect(overlay._listeners["mouse"]).toBeTruthy()
    end)
end)

T.summary()
