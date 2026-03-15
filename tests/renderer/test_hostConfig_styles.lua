-- tests/renderer/test_hostConfig_styles.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

-- Inject mock display + native
local mockDisplay = require("tests.helpers.mock_display")
display = mockDisplay
native = {
    systemFont = "systemFont",
    systemFontBold = "systemFontBold",
}

local HostConfig = require("renderer.HostConfig")

-- ============================================================
-- Task 1.1: Text Styles
-- ============================================================

T.describe("Text: fontWeight", function()
    T.it("applies bold font", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24, fontWeight = "bold" },
            children = "Hello",
        })
        T.expect(inst._textObj._font).toBe("systemFontBold")
    end)

    T.it("defaults to system font when no fontWeight", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24 },
            children = "Hello",
        })
        T.expect(inst._textObj._font).toBe("systemFont")
    end)
end)

T.describe("Text: fontFamily", function()
    T.it("applies custom font family", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24, fontFamily = "Helvetica" },
            children = "Hello",
        })
        T.expect(inst._textObj._font).toBe("Helvetica")
    end)

    T.it("applies bold variant of custom font", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24, fontFamily = "Helvetica", fontWeight = "bold" },
            children = "Hello",
        })
        T.expect(inst._textObj._font).toBe("Helvetica-Bold")
    end)
end)

T.describe("Text: textAlign", function()
    T.it("applies center alignment", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24, textAlign = "center", width = 200 },
            children = "Hello",
        })
        T.expect(inst._textObj._align).toBe("center")
    end)

    T.it("defaults to left alignment", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24 },
            children = "Hello",
        })
        T.expect(inst._textObj._align).toBe("left")
    end)
end)

T.describe("Text: lineHeight", function()
    T.it("stores lineHeight on group", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24, lineHeight = 36 },
            children = "Hello",
        })
        T.expect(inst._lineHeight).toBe(36)
    end)
end)

T.describe("Text: dynamic update", function()
    T.it("updates fontSize", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24 },
            children = "Hello",
        })
        HostConfig.updateInstance(inst,
            { style = { fontSize = 24 }, children = "Hello" },
            { style = { fontSize = 36 }, children = "Hello" }
        )
        T.expect(inst._textObj.size).toBe(36)
    end)

    T.it("updates fontWeight by recreating text", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24 },
            children = "Hello",
        })
        HostConfig.updateInstance(inst,
            { style = { fontSize = 24 }, children = "Hello" },
            { style = { fontSize = 24, fontWeight = "bold" }, children = "Hello" }
        )
        T.expect(inst._textObj._font).toBe("systemFontBold")
    end)

    T.it("updates textAlign by recreating text", function()
        local inst = HostConfig.createInstance("Text", {
            style = { fontSize = 24, textAlign = "left" },
            children = "Hello",
        })
        HostConfig.updateInstance(inst,
            { style = { fontSize = 24, textAlign = "left" }, children = "Hello" },
            { style = { fontSize = 24, textAlign = "center" }, children = "Hello" }
        )
        T.expect(inst._textObj._align).toBe("center")
    end)
end)

-- ============================================================
-- Task 1.2: Transform
-- ============================================================

T.describe("Transform: rotate", function()
    T.it("applies rotation from transform array", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, transform = {{ rotate = "45deg" }} },
        })
        T.expect(inst.rotation).toBe(45)
    end)

    T.it("applies rotation in radians", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, transform = {{ rotate = "3.14159rad" }} },
        })
        -- 3.14159 rad ≈ 180 deg
        T.expect(math.floor(inst.rotation + 0.5)).toBe(180)
    end)
end)

T.describe("Transform: scale", function()
    T.it("applies uniform scale", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, transform = {{ scale = 2 }} },
        })
        T.expect(inst.xScale).toBe(2)
        T.expect(inst.yScale).toBe(2)
    end)

    T.it("applies scaleX and scaleY separately", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, transform = {{ scaleX = 1.5 }, { scaleY = 0.5 }} },
        })
        T.expect(inst.xScale).toBe(1.5)
        T.expect(inst.yScale).toBe(0.5)
    end)
end)

T.describe("Transform: update", function()
    T.it("updates transform dynamically", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100 },
        })
        HostConfig.updateInstance(inst,
            { style = { width = 100, height = 100 } },
            { style = { width = 100, height = 100, transform = {{ rotate = "90deg" }} } }
        )
        T.expect(inst.rotation).toBe(90)
    end)

    T.it("resets transform when removed", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, transform = {{ rotate = "45deg" }, { scale = 2 }} },
        })
        HostConfig.updateInstance(inst,
            { style = { width = 100, height = 100, transform = {{ rotate = "45deg" }, { scale = 2 }} } },
            { style = { width = 100, height = 100 } }
        )
        T.expect(inst.rotation).toBe(0)
        T.expect(inst.xScale).toBe(1)
        T.expect(inst.yScale).toBe(1)
    end)
end)

-- ============================================================
-- Task 1.3: Image resizeMode, zIndex, per-side borders
-- ============================================================

T.describe("Image: resizeMode", function()
    T.it("stores resizeMode from props", function()
        local inst = HostConfig.createInstance("Image", {
            source = { uri = "test.png" },
            style = { width = 200, height = 200 },
            resizeMode = "cover",
        })
        T.expect(inst._resizeMode).toBe("cover")
    end)

    T.it("defaults to cover", function()
        local inst = HostConfig.createInstance("Image", {
            source = { uri = "test.png" },
            style = { width = 200, height = 200 },
        })
        T.expect(inst._resizeMode).toBe("cover")
    end)
end)

T.describe("View: zIndex", function()
    T.it("stores zIndex on instance", function()
        local inst = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, zIndex = 10 },
        })
        T.expect(inst._zIndex).toBe(10)
    end)
end)

T.describe("View: per-side borders", function()
    T.it("creates bottom border line", function()
        local inst = HostConfig.createInstance("View", {
            style = {
                width = 200, height = 50,
                borderBottomWidth = 2,
                borderBottomColor = "#CCCCCC",
            },
        })
        T.expect(inst._borderBottom).toBeTruthy()
    end)

    T.it("creates top border line", function()
        local inst = HostConfig.createInstance("View", {
            style = {
                width = 200, height = 50,
                borderTopWidth = 2,
                borderTopColor = "#FF0000",
            },
        })
        T.expect(inst._borderTop).toBeTruthy()
    end)
end)

T.summary()
