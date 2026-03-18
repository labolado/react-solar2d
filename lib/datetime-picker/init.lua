-- lib/datetime-picker/init.lua
-- @react-native-community/datetimepicker implementation for Solar2D
-- Simple, working version without hooks for production stability

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

-- Format timestamp for display
local function formatDisplay(timestamp, mode)
    if mode == "time" then
        return os.date("%H:%M", timestamp)
    elseif mode == "datetime" then
        return os.date("%Y-%m-%d %H:%M", timestamp)
    else
        return os.date("%Y-%m-%d", timestamp)
    end
end

-- Parse date from text
local function tryParse(text, mode, currentValue)
    if mode == "date" then
        local y, m, d = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        if y and m and d then
            local parts = os.date("*t", currentValue)
            return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = parts.hour, min = parts.min })
        end
    elseif mode == "time" then
        local h, mi = text:match("^(%d%d):(%d%d)$")
        if h and mi then
            local parts = os.date("*t", currentValue)
            return os.time({ year = parts.year, month = parts.month, day = parts.day, hour = tonumber(h), min = tonumber(mi) })
        end
    else -- datetime
        local y, m, d, h, mi = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$")
        if y and m and d and h and mi then
            return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = tonumber(h), min = tonumber(mi) })
        end
    end
    return nil
end

-- Get date parts for adjustment
local function getParts(timestamp)
    local t = os.date("*t", timestamp)
    return t.year, t.month, t.day, t.hour, t.min
end

-- Simple picker using text input with +/- buttons
-- NO HOOKS - pure props-driven for stability
function M.DateTimePicker(props)
    local React = require("react")
    local ce = React.createElement

    local value = props.value or os.time()
    local mode = props.mode or "date"
    local onChange = props.onChange
    local disabled = props.disabled or false
    local style = props.style or {}
    local minimumDate = props.minimumDate
    local maximumDate = props.maximumDate

    -- Get TextInput safely
    local TextInput = "View"
    local ok, rn = pcall(require, "react_solar2d")
    if ok and rn and rn.TextInput then
        TextInput = rn.TextInput
    end

    local pickerHeight = style.height or 44
    local displayValue = formatDisplay(value, mode)

    -- Handler functions that close over current props
    local function handleDecrement()
        if disabled then return end

        local year, month, day, hour, min = getParts(value)
        local newTs

        if mode == "date" then
            newTs = os.time({ year = year, month = month, day = day - 1, hour = hour, min = min })
        elseif mode == "time" then
            newTs = os.time({ year = year, month = month, day = day, hour = hour, min = min - 1 })
        else
            newTs = os.time({ year = year, month = month, day = day, hour = hour - 1, min = min })
        end

        if minimumDate and newTs < minimumDate then newTs = minimumDate end
        if maximumDate and newTs > maximumDate then newTs = maximumDate end

        if onChange then
            onChange({ type = M.EventType.SET, nativeEvent = { timestamp = newTs } })
        end
    end

    local function handleIncrement()
        if disabled then return end

        local year, month, day, hour, min = getParts(value)
        local newTs

        if mode == "date" then
            newTs = os.time({ year = year, month = month, day = day + 1, hour = hour, min = min })
        elseif mode == "time" then
            newTs = os.time({ year = year, month = month, day = day, hour = hour, min = min + 1 })
        else
            newTs = os.time({ year = year, month = month, day = day, hour = hour + 1, min = min })
        end

        if minimumDate and newTs < minimumDate then newTs = minimumDate end
        if maximumDate and newTs > maximumDate then newTs = maximumDate end

        if onChange then
            onChange({ type = M.EventType.SET, nativeEvent = { timestamp = newTs } })
        end
    end

    local function handleSubmit(e)
        if disabled then return end

        local text = e.text or displayValue
        local newTs = tryParse(text, mode, value)

        if newTs then
            if minimumDate and newTs < minimumDate then newTs = minimumDate end
            if maximumDate and newTs > maximumDate then newTs = maximumDate end

            if onChange then
                onChange({ type = M.EventType.SET, nativeEvent = { timestamp = newTs } })
            end
        end
    end

    return ce("View", {
        style = {
            backgroundColor = style.backgroundColor or "#FFFFFF",
            borderWidth = style.borderWidth or 1,
            borderColor = style.borderColor or "#CCCCCC",
            borderRadius = style.borderRadius or 4,
            opacity = disabled and 0.5 or 1,
            height = pickerHeight,
            flexDirection = "row",
            alignItems = "center",
        }
    },
        -- Decrement button
        ce("Pressable", {
            style = {
                width = 36,
                height = pickerHeight - 2,
                justifyContent = "center",
                alignItems = "center",
                borderRightWidth = 1,
                borderColor = "#EEEEEE",
            },
            onPress = handleDecrement,
            disabled = disabled,
        }, ce("Text", { style = { fontSize = 18, color = "#007AFF" } }, "-")),

        -- Text input (controlled component - value always reflects props)
        ce(TextInput, {
            style = {
                flex = 1,
                fontSize = style.fontSize or 16,
                color = style.color or "#333333",
                textAlign = "center",
                height = pickerHeight - 2,
                padding = 0,
            },
            value = displayValue,
            onChangeText = function() end, -- Required for controlled component
            onSubmitEditing = handleSubmit,
            editable = not disabled,
        }),

        -- Increment button
        ce("Pressable", {
            style = {
                width = 36,
                height = pickerHeight - 2,
                justifyContent = "center",
                alignItems = "center",
                borderLeftWidth = 1,
                borderColor = "#EEEEEE",
            },
            onPress = handleIncrement,
            disabled = disabled,
        }, ce("Text", { style = { fontSize = 18, color = "#007AFF" } }, "+"))
    )
end

-- Open native date picker (imperative API)
function M.open(params)
    local mode = params.mode or "date"
    local value = params.value or os.time()
    local onChange = params.onChange
    local title = params.title or (mode == "time" and "Select Time" or "Select Date")

    if native and native.showAlert then
        native.showAlert(title, "Current: " .. formatDisplay(value, mode), {"OK"}, function(event)
            if onChange then onChange({ type = M.EventType.SET, nativeEvent = { timestamp = value } }) end
        end)
    end
end

return M
