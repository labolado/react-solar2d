-- lib/vector-icons/tests/test.lua
-- Tests for vector-icons

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local VectorIcons = require("lib.vector-icons")

T.describe("VectorIcons", function()
    T.it("should export MaterialIcons, FontAwesome, Ionicons", function()
        T.expect(VectorIcons.MaterialIcons).toNotBe(nil)
        T.expect(VectorIcons.FontAwesome).toNotBe(nil)
        T.expect(VectorIcons.Ionicons).toNotBe(nil)
    end)

    T.it("should export Icon component and getIconChar", function()
        T.expect(VectorIcons.Icon).toNotBe(nil)
        T.expect(type(VectorIcons.getIconChar)).toBe("function")
    end)

    T.it("should get icon char for known icons", function()
        T.expect(VectorIcons.getIconChar("MaterialIcons", "home")).toNotBe(nil)
        T.expect(VectorIcons.getIconChar("FontAwesome", "home")).toNotBe(nil)
        T.expect(VectorIcons.getIconChar("Ionicons", "home")).toNotBe(nil)
    end)

    T.it("should return nil for unknown icon sets", function()
        T.expect(VectorIcons.getIconChar("UnknownSet", "home")).toBe(nil)
    end)

    T.it("should return nil for unknown icon names", function()
        T.expect(VectorIcons.getIconChar("MaterialIcons", "unknown_icon")).toBe(nil)
    end)

    T.it("should create icon components", function()
        local React = require("react")
        local icon = VectorIcons.MaterialIcons({
            name = "home",
            size = 32,
            color = "#FF0000"
        })
        T.expect(icon).toNotBe(nil)
        T.expect(icon.type).toBe("Text")
        T.expect(icon.props.style.fontSize).toBe(32)
        T.expect(icon.props.style.color).toBe("#FF0000")
    end)

    T.it("should use defaults for missing props", function()
        local icon = VectorIcons.MaterialIcons({ name = "settings" })
        T.expect(icon.props.style.fontSize).toBe(24)
        T.expect(icon.props.style.color).toBe("#000000")
    end)

    T.it("should show ? for unknown icon names", function()
        local icon = VectorIcons.MaterialIcons({ name = "nonexistent" })
        T.expect(icon.props.children).toBe("?")
    end)
end)

T.summary()
