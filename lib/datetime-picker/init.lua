-- lib/datetime-picker/init.lua
-- @react-native-community/datetimepicker implementation for Solar2D
-- Date and time picker component using native text input

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

-- Parse date string to timestamp
local function parseDate(dateStr, mode)
    if not dateStr then return nil end

    local year, month, day, hour, min

    if mode == "date" then
        -- Expected format: YYYY-MM-DD
        year, month, day = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)")
        if year and month and day then
            return os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
            })
        end
    elseif mode == "time" then
        -- Expected format: HH:MM
        hour, min = dateStr:match("(%d%d):(%d%d)")
        if hour and min then
            local now = os.date("*t")
            return os.time({
                year = now.year,
                month = now.month,
                day = now.day,
                hour = tonumber(hour),
                min = tonumber(min),
            })
        end
    else
        -- datetime format: YYYY-MM-DDTHH:MM
        year, month, day, hour, min = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d)")
        if year and month and day and hour and min then
            return os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
            })
        end
    end

    return nil
end

-- Format timestamp for display
local function formatForDisplay(timestamp, mode)
    if mode == "time" then
        return os.date("%H:%M", timestamp)
    elseif mode == "datetime" then
        return os.date("%Y-%m-%d %H:%M", timestamp)
    else
        return os.date("%Y-%m-%d", timestamp)
    end
end

-- Format timestamp for native input value
local function formatForInput(timestamp, mode)
    if mode == "time" then
        return os.date("%H:%M", timestamp)
    elseif mode == "datetime" then
        return os.date("%Y-%m-%dT%H:%M", timestamp)
    else
        return os.date("%Y-%m-%d", timestamp)
    end
end

-- Create a date picker using native text field
function M.DateTimePicker(props)
    local React = require("react")
    local useState = React.useState
    local useCallback = React.useCallback
    local useRef = React.useRef

    local value = props.value or os.time()
    local mode = props.mode or "date" -- "date", "time", "datetime"
    local onChange = props.onChange
    local disabled = props.disabled or false
    local style = props.style or {}

    -- Input type based on mode
    local inputType = "default"
    if mode == "date" then
        inputType = "date"
    elseif mode == "time" then
        inputType = "time"
    elseif mode == "datetime" then
        inputType = "datetime"
    end

    local handleChange = useCallback(function(text)
        if disabled then return end

        local newTimestamp = parseDate(text, mode)
        if newTimestamp and onChange then
            onChange({
                type = M.EventType.SET,
                nativeEvent = {
                    timestamp = newTimestamp,
                },
            })
        end
    end)

    return React.createElement("View", {
        style = {
            backgroundColor = style.backgroundColor or "#FFFFFF",
            borderWidth = style.borderWidth or 1,
            borderColor = style.borderColor or "#CCCCCC",
            borderRadius = style.borderRadius or 4,
            padding = style.padding or 0,
            opacity = disabled and 0.5 or 1,
        }
    },
        React.createElement(require("react_solar2d").TextInput, {
            style = {
                fontSize = style.fontSize or 16,
                color = style.color or "#333333",
                padding = 12,
                height = 44,
            },
            value = formatForInput(value, mode),
            onChangeText = handleChange,
            editable = not disabled,
            placeholder = mode == "time" and "HH:MM" or (mode == "date" and "YYYY-MM-DD" or "YYYY-MM-DD HH:MM"),
        })
    )
end

-- Open native date picker (imperative API)
-- Uses native.showAlert as a fallback since Solar2D doesn't have native date picker
function M.open(params)
    local mode = params.mode or "date"
    local value = params.value or os.time()
    local onChange = params.onChange
    local title = params.title or (mode == "time" and "Select Time" or "Select Date")

    -- Format current value for display
    local currentValue = formatForDisplay(value, mode)

    -- Show alert with current value - this is a simplified fallback
    -- In production, you'd want a custom native plugin or picker UI
    if native and native.showAlert then
        native.showAlert(
            title,
            "Current: " .. currentValue .. "\n\nPlease use the picker component for better UX.",
            {"OK"},
            function(event)
                if event.action == "clicked" and onChange then
                    onChange({
                        type = M.EventType.SET,
                        nativeEvent = {
                            timestamp = value,
                        },
                    })
                end
            end
        )
    end
end

return M
