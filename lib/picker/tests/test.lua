-- lib/picker/tests/test.lua
-- Tests for Picker

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local Picker = require("lib.picker")

T.describe("Picker", function()
    T.it("should export Picker and PickerItem", function()
        T.expect(Picker.Picker).toNotBe(nil)
        T.expect(Picker.PickerItem).toNotBe(nil)
    end)

    T.it("should create PickerItem", function()
        local item = Picker.PickerItem({ label = "Test", value = "test" })
        T.expect(item.type).toBe("PickerItem")
        T.expect(item.props.label).toBe("Test")
        T.expect(item.props.value).toBe("test")
    end)
end)

T.summary()
