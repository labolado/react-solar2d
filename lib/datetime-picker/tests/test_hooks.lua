-- lib/datetime-picker/tests/test_hooks.lua
-- Tests for DateTimePicker with hooks support

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local DateTimePicker = require("lib.datetime-picker")

T.describe("DateTimePicker with Hooks", function()
    T.itWithHooks("should create component with useState", function(fiber)
        local React = require("react")
        local element = DateTimePicker.DateTimePicker({
            value = os.time(),
            mode = "date",
        })

        T.expect(element).toNotBe(nil)
        T.expect(element.type).toBe("View")
    end)

    T.itWithHooks("should render with correct props", function(fiber)
        local testTime = os.time({ year = 2024, month = 6, day = 15, hour = 14, min = 30 })

        local element = DateTimePicker.DateTimePicker({
            value = testTime,
            mode = "date",
            disabled = true,
        })

        -- Check style has disabled opacity
        local style = element.props.style
        T.expect(style.opacity).toBe(0.5)

        -- Should have 3 children: - button, input, + button
        local children = element.props.children
        T.expect(#children).toBe(3)
        T.expect(children[1].type).toBe("Pressable")
        T.expect(children[2].type).toBe("TextInput")
        T.expect(children[3].type).toBe("Pressable")
    end)

    T.itWithHooks("should format value for date mode", function(fiber)
        local testTime = os.time({ year = 2024, month = 6, day = 15, hour = 14, min = 30 })

        local element = DateTimePicker.DateTimePicker({
            value = testTime,
            mode = "date",
        })

        local inputProps = element.props.children[2].props
        T.expect(inputProps.value).toBe("2024-06-15")
    end)

    T.itWithHooks("should format value for time mode", function(fiber)
        local testTime = os.time({ year = 2024, month = 6, day = 15, hour = 14, min = 30 })

        local element = DateTimePicker.DateTimePicker({
            value = testTime,
            mode = "time",
        })

        local inputProps = element.props.children[2].props
        T.expect(inputProps.value).toBe("14:30")
    end)

    T.itWithHooks("should format value for datetime mode", function(fiber)
        local testTime = os.time({ year = 2024, month = 6, day = 15, hour = 14, min = 30 })

        local element = DateTimePicker.DateTimePicker({
            value = testTime,
            mode = "datetime",
        })

        local inputProps = element.props.children[2].props
        T.expect(inputProps.value).toBe("2024-06-15 14:30")
    end)

    T.itWithHooks("should have callback handlers", function(fiber)
        local element = DateTimePicker.DateTimePicker({
            value = os.time(),
            mode = "date",
            onChange = function() end,
        })

        local decButton = element.props.children[1]
        local incButton = element.props.children[3]
        local input = element.props.children[2]

        T.expect(type(decButton.props.onPress)).toBe("function")
        T.expect(type(incButton.props.onPress)).toBe("function")
        T.expect(type(input.props.onChangeText)).toBe("function")
        T.expect(type(input.props.onSubmitEditing)).toBe("function")
    end)
end)

T.summary()
