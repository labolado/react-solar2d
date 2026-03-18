-- lib/datetime-picker/tests/test_integration.lua
-- Integration tests for DateTimePicker exports

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local DateTimePicker = require("lib.datetime-picker")

T.describe("DateTimePicker Integration", function()
    T.it("should export all required components", function()
        T.expect(DateTimePicker.DateTimePicker).toNotBe(nil)
        T.expect(type(DateTimePicker.DateTimePicker)).toBe("function")
    end)

    T.it("should have correct Display constants", function()
        T.expect(DateTimePicker.Display).toNotBe(nil)
        T.expect(DateTimePicker.Display.DEFAULT).toBe("default")
        T.expect(DateTimePicker.Display.SPINNER).toBe("spinner")
        T.expect(DateTimePicker.Display.CLOCK).toBe("clock")
        T.expect(DateTimePicker.Display.CALENDAR).toBe("calendar")
    end)

    T.it("should have correct EventType constants", function()
        T.expect(DateTimePicker.EventType).toNotBe(nil)
        T.expect(DateTimePicker.EventType.SET).toBe("set")
        T.expect(DateTimePicker.EventType.DISMISSED).toBe("dismissed")
    end)

    T.it("should export open function", function()
        T.expect(DateTimePicker.open).toNotBe(nil)
        T.expect(type(DateTimePicker.open)).toBe("function")
    end)

    T.it("open function should not error with mocked native", function()
        -- Mock native.showAlert
        local originalNative = _G.native
        local alertCalled = false
        _G.native = {
            showAlert = function(title, message, buttons, listener)
                alertCalled = true
                -- Simulate user clicking OK
                if listener then
                    listener({ action = "clicked", index = 1 })
                end
            end
        }

        local callbackCalled = false
        local ok, err = pcall(function()
            DateTimePicker.open({
                mode = "date",
                value = os.time(),
                onChange = function(event)
                    callbackCalled = true
                    T.expect(event.type).toBe(DateTimePicker.EventType.SET)
                    T.expect(event.nativeEvent).toNotBe(nil)
                    T.expect(event.nativeEvent.timestamp).toNotBe(nil)
                end
            })
        end)

        T.expect(ok).toBe(true)
        T.expect(alertCalled).toBe(true)
        T.expect(callbackCalled).toBe(true)

        -- Restore
        _G.native = originalNative
    end)

    T.it("should handle all three modes in open", function()
        local originalNative = _G.native
        local testModes = {}

        _G.native = {
            showAlert = function(title, message, buttons, listener)
                table.insert(testModes, title)
            end
        }

        DateTimePicker.open({ mode = "date", value = os.time() })
        DateTimePicker.open({ mode = "time", value = os.time() })
        DateTimePicker.open({ mode = "datetime", value = os.time() })

        T.expect(#testModes).toBe(3)
        T.expect(testModes[1]).toBe("Select Date")
        T.expect(testModes[2]).toBe("Select Time")
        T.expect(testModes[3]).toBe("Select Date") -- datetime falls back to date title

        _G.native = originalNative
    end)
end)

T.summary()
