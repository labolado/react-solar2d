-- tests/renderer/test_hostConfig.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

-- Inject mock display globally (simulates Solar2D environment)
local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay

local HostConfig = require("renderer.HostConfig")

T.describe("HostConfig.createInstance", function()
    T.it("creates a group for View type", function()
        local inst = HostConfig.createInstance("View", {})
        T.expect(inst._type).toBe("group")
    end)

    T.it("creates rect background for View with backgroundColor", function()
        local inst = HostConfig.createInstance("View", {
            style = { backgroundColor = "#FF0000" }
        })
        -- Without explicit width/height, _bg creation is deferred until applyLayout.
        -- Either _bg (explicit size) or _pendingBg (deferred) must be set.
        T.expect(inst._bg or inst._pendingBg).toBeTruthy()
    end)

    T.it("creates text instance for Text type", function()
        local inst = HostConfig.createInstance("Text", {
            children = "Hello"
        })
        T.expect(inst._textObj).toBeTruthy()
    end)

    T.it("creates image for Image type", function()
        local inst = HostConfig.createInstance("Image", {
            source = "icon.png"
        })
        T.expect(inst._imageObj).toBeTruthy()
    end)
end)

T.describe("HostConfig.appendChild", function()
    T.it("inserts child into parent group", function()
        local parent = HostConfig.createInstance("View", {})
        local child = HostConfig.createInstance("View", {})
        HostConfig.appendChild(parent, child)
        T.expect(parent.numChildren).toBe(1)
    end)
end)

T.describe("HostConfig.removeChild", function()
    T.it("removes child from parent", function()
        local parent = HostConfig.createInstance("View", {})
        local child = HostConfig.createInstance("View", {})
        HostConfig.appendChild(parent, child)
        HostConfig.removeChild(parent, child)
        T.expect(parent.numChildren).toBe(0)
    end)
end)

T.summary()
