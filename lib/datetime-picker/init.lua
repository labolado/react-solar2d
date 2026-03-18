-- lib/datetime-picker/init.lua
-- @react-native-community/datetimepicker implementation for Solar2D
-- Date and time picker component

local M = {}

-- Display modes
M.Display = {
    DEFAULT = "default",
    SPINNER = "spinner",
    CLOCK = "clock",
    CALENDAR = "calendar",
}

-- Event types
M.EventType = {
    SET = "set",
    DISMISSED = "dismissed",
}

-- Create a date picker button that shows native alert
function M.DateTimePicker(props)
    local React = require("react")
    local useState = React.useState
    local useCallback = React.useCallback

    local value = props.value or os.time()
    local mode = props.mode or "date" -- "date", "time", "datetime"
    local display = props.display or M.Display.DEFAULT
    local onChange = props.onChange
    local disabled = props.disabled or false
    local minimumDate = props.minimumDate
    local maximumDate = props.maximumDate
    local style = props.style or {}

    -- Format display value
    local function formatValue()
        if mode == "time" then
            return os.date("%H:%M", value)
        elseif mode == "datetime" then
            return os.date("%Y-%m-%d %H:%M", value)
        else
            return os.date("%Y-%m-%d", value)
        end
    end

    local showPicker = useCallback(function()
        if disabled then return end

        -- Use native.showAlert as a simple picker alternative
        -- In production, you'd use a custom native plugin
        local title = mode == "time" and "Select Time" or "Select Date"
        local message = "Current: " .. formatValue()

        -- For demo purposes, we'll just show a message
        -- Real implementation would show native picker
        if native and native.showAlert then
            native.showAlert(title, message, {"OK", "Cancel"}, function(event)
                if event.action == "clicked" and event.index == 1 then
                    -- Simulate date change - in real impl, get from native picker
                    if onChange then
                        onChange({
                            type = M.EventType.SET,
                            nativeEvent = {
                                timestamp = value,
                            },
                        })
                    end
                else
                    if onChange then
                        onChange({
                            type = M.EventType.DISMISSED,
                        })
                    end
                end
            end)
        end
    end)

    return React.createElement("Pressable", {
        style = {
            backgroundColor = style.backgroundColor or "#FFFFFF",
            borderWidth = style.borderWidth or 1,
            borderColor = style.borderColor or "#CCCCCC",
            borderRadius = style.borderRadius or 4,
            padding = style.padding or 12,
            opacity = disabled and 0.5 or 1,
            style = style,
        },
        onPress = showPicker,
        disabled = disabled,
    },
        React.createElement("Text", {
            style = {
                fontSize = style.fontSize or 16,
                color = style.color or "#333333",
            }
        }, formatValue())
    )
end

-- Open native date picker (imperative API)
function M.open(params)
    local mode = params.mode or "date"
    local value = params.value or os.time()
    local onChange = params.onChange

    if native and native.showAlert then
        local title = mode == "time" and "Select Time" or "Select Date"
        native.showAlert(title, "Select a value", {"OK", "Cancel"}, function(event)
            if event.action == "clicked" and event.index == 1 then
                if onChange then
                    onChange({
                        type = M.EventType.SET,
                        nativeEvent = {
                            timestamp = value,
                        },
                    })
                end
            else
                if onChange then
                    onChange({
                        type = M.EventType.DISMISSED,
                    })
                end
            end
        end)
    end
end

return M
