-- lib/datetime-picker/tests/test.lua
-- Tests for datetime-picker

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local DateTimePicker = require("lib.datetime-picker")

T.describe("DateTimePicker", function()
    T.it("should export DateTimePicker component", function()
        T.expect(DateTimePicker.DateTimePicker).toNotBe(nil)
        T.expect(type(DateTimePicker.DateTimePicker)).toBe("function")
    end)

    T.it("should export constants", function()
        T.expect(type(DateTimePicker.Display)).toBe("table")
        T.expect(DateTimePicker.Display.DEFAULT).toNotBe(nil)
        T.expect(DateTimePicker.Display.SPINNER).toNotBe(nil)
        T.expect(DateTimePicker.Display.CLOCK).toNotBe(nil)
        T.expect(DateTimePicker.Display.CALENDAR).toNotBe(nil)
    end)

    T.it("should export event types", function()
        T.expect(type(DateTimePicker.EventType)).toBe("table")
        T.expect(DateTimePicker.EventType.SET).toNotBe(nil)
        T.expect(DateTimePicker.EventType.DISMISSED).toNotBe(nil)
    end)

    T.it("should export open function", function()
        T.expect(type(DateTimePicker.open)).toBe("function")
    end)

    T.it("should have proper exports", function()
        T.expect(DateTimePicker.DateTimePicker).toNotBe(nil)
        T.expect(type(DateTimePicker.DateTimePicker)).toBe("function")
        T.expect(type(DateTimePicker.open)).toBe("function")
    end)
end)

T.summary()
