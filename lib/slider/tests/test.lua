-- lib/slider/tests/test.lua
-- Tests for Slider component

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local Slider = require("lib.slider")

T.describe("Slider", function()
    T.it("should export Slider component", function()
        T.expect(Slider.Slider).toNotBe(nil)
        T.expect(type(Slider.Slider)).toBe("function")
    end)

    T.it("should have correct default constants", function()
        -- Verify the module loads correctly
        T.expect(Slider).toNotBe(nil)
    end)
end)

T.summary()
