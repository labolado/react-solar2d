-- Test DateTimePicker specifically
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local mockHooks = require("tests.helpers.mock_hooks")
local DateTimePicker = require("lib.datetime-picker")

T.describe("DateTimePicker Hooks", function()
    T.it("should export DateTimePicker", function()
        T.expect(DateTimePicker.DateTimePicker).toNotBe(nil)
    end)

    T.it("should render with hooks", function()
        local testTime = os.time({ year = 2024, month = 6, day = 15, hour = 14, min = 30 })

        local element, fiber, err = mockHooks.renderComponent(DateTimePicker.DateTimePicker, {
            value = testTime,
            mode = "date",
        })

        if err then
            print("Error: " .. tostring(err))
        end

        T.expect(err).toBe(nil)
        T.expect(element).toNotBe(nil)
        T.expect(element.type).toBe("View")
    end)

    T.it("should render with time mode", function()
        local testTime = os.time({ year = 2024, month = 6, day = 15, hour = 14, min = 30 })

        local element, fiber, err = mockHooks.renderComponent(DateTimePicker.DateTimePicker, {
            value = testTime,
            mode = "time",
        })

        T.expect(err).toBe(nil)
        T.expect(element).toNotBe(nil)
    end)
end)

T.summary()
