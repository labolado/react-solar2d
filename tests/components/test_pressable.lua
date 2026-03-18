-- tests/components/test_pressable.lua
-- Test Pressable component
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local Pressable = require("components.Pressable")

T.describe("Pressable component", function()
    T.it("returns a host element of type View when called", function()
        local el = Pressable({ style = { flex = 1 } })
        T.expect(el.type).toBe("View")
    end)

    T.it("passes through style and onPress", function()
        local fn = function() end
        local el = Pressable({
            style = { backgroundColor = "red" },
            onPress = fn,
        })
        T.expect(el.props.style.backgroundColor).toBe("red")
        T.expect(el.props.onPress).toBe(fn)
    end)

    T.it("adds transparent background when none specified", function()
        -- Bug fix: Pressable without backgroundColor should still receive taps
        local el = Pressable({
            style = { width = 100, height = 50 },  -- No backgroundColor
        })
        T.expect(el.props.style.backgroundColor).toBe("transparent")
        T.expect(el.props.style.width).toBe(100)
    end)

    T.it("preserves explicit backgroundColor", function()
        local el = Pressable({
            style = { width = 100, height = 50, backgroundColor = "#FF0000" },
        })
        T.expect(el.props.style.backgroundColor).toBe("#FF0000")
    end)

    T.it("sets _touchFeedback and _activeOpacity", function()
        local el = Pressable({
            style = {},
            activeOpacity = 0.8,
        })
        T.expect(el.props._touchFeedback).toBe("opacity")
        T.expect(el.props._activeOpacity).toBe(0.8)
    end)

    T.it("uses default activeOpacity when not specified", function()
        local el = Pressable({ style = {} })
        T.expect(el.props._activeOpacity).toBe(0.6)
    end)
end)

T.summary()
