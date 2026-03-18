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

-- Create wheel picker data
local function createWheelData(min, max, pad)
    local data = {}
    for i = min, max do
        local s = tostring(i)
        if pad and i < 10 then
            s = "0" .. s
        end
        table.insert(data, s)
    end
    return data
end

-- Get current date parts
local function getDateParts(timestamp)
    local t = os.date("*t", timestamp)
    return {
        year = t.year,
        month = t.month,
        day = t.day,
        hour = t.hour,
        min = t.min,
    }
end

-- Format for display
local function formatDisplay(timestamp, mode)
    if mode == "time" then
        return os.date("%H:%M", timestamp)
    elseif mode == "datetime" then
        return os.date("%Y-%m-%d %H:%M", timestamp)
    else
        return os.date("%Y-%m-%d", timestamp)
    end
end

-- Build timestamp from parts
local function buildTimestamp(parts)
    return os.time({
        year = parts.year,
        month = parts.month,
        day = parts.day,
        hour = parts.hour or 0,
        min = parts.min or 0,
    })
end

-- Simple picker using text input with increment/decrement buttons
function M.DateTimePicker(props)
    local React = require("react")
    local useState = React.useState
    local ce = React.createElement

    local value = props.value or os.time()
    local mode = props.mode or "date"
    local onChange = props.onChange
    local disabled = props.disabled or false
    local style = props.style or {}

    local minimumDate = props.minimumDate
    local maximumDate = props.maximumDate

    -- Local state for editing
    local displayValue = formatDisplay(value, mode)
    local inputText, setInputText = useState(displayValue)

    -- Update input when value prop changes
    React.useEffect(function()
        setInputText(formatDisplay(value, mode))
    end, {value, mode})

    -- Parse and set value
    local function tryParseAndSet(text)
        local parts = getDateParts(value)
        local valid = false

        if mode == "date" then
            -- Try YYYY-MM-DD
            local y, m, d = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
            if y and m and d then
                parts.year = tonumber(y)
                parts.month = tonumber(m)
                parts.day = tonumber(d)
                valid = true
            end
        elseif mode == "time" then
            -- Try HH:MM
            local h, mi = text:match("^(%d%d):(%d%d)$")
            if h and mi then
                parts.hour = tonumber(h)
                parts.min = tonumber(mi)
                valid = true
            end
        else
            -- Try YYYY-MM-DD HH:MM
            local y, m, d, h, mi = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$")
            if y and m and d and h and mi then
                parts.year = tonumber(y)
                parts.month = tonumber(m)
                parts.day = tonumber(d)
                parts.hour = tonumber(h)
                parts.min = tonumber(mi)
                valid = true
            end
        end

        if valid then
            local newTs = buildTimestamp(parts)
            -- Check bounds
            if minimumDate and newTs < minimumDate then
                newTs = minimumDate
            end
            if maximumDate and newTs > maximumDate then
                newTs = maximumDate
            end

            if onChange then
                onChange({
                    type = M.EventType.SET,
                    nativeEvent = { timestamp = newTs },
                })
            end
            setInputText(formatDisplay(newTs, mode))
        else
            -- Invalid format, reset to current
            setInputText(formatDisplay(value, mode))
        end
    end

    -- Increment/decrement helpers
    local function adjustDate(field, delta)
        local parts = getDateParts(value)
        parts[field] = parts[field] + delta
        local newTs = buildTimestamp(parts)

        if minimumDate and newTs < minimumDate then
            newTs = minimumDate
        end
        if maximumDate and newTs > maximumDate then
            newTs = maximumDate
        end

        if onChange then
            onChange({
                type = M.EventType.SET,
                nativeEvent = { timestamp = newTs },
            })
        end
    end

    local pickerHeight = style.height or 44

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
            onPress = function()
                if disabled then return end
                if mode == "date" then
                    adjustDate("day", -1)
                elseif mode == "time" then
                    adjustDate("min", -1)
                else
                    adjustDate("hour", -1)
                end
            end,
            activeOpacity = 0.7,
        }, ce("Text", { style = { fontSize = 18, color = "#007AFF" } }, "-")),

        -- Text input for direct editing
        ce(require("react_solar2d").TextInput, {
            style = {
                flex = 1,
                fontSize = style.fontSize or 16,
                color = style.color or "#333333",
                textAlign = "center",
                height = pickerHeight - 2,
                padding = 0,
            },
            value = inputText,
            onChangeText = function(text)
                setInputText(text)
            end,
            onEndEditing = function()
                tryParseAndSet(inputText)
            end,
            editable = not disabled,
            returnKeyType = "done",
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
            onPress = function()
                if disabled then return end
                if mode == "date" then
                    adjustDate("day", 1)
                elseif mode == "time" then
                    adjustDate("min", 1)
                else
                    adjustDate("hour", 1)
                end
            end,
            activeOpacity = 0.7,
        }, ce("Text", { style = { fontSize = 18, color = "#007AFF" } }, "+"))
    )
end

-- Open native date picker (imperative API)
function M.open(params)
    local mode = params.mode or "date"
    local value = params.value or os.time()
    local onChange = params.onChange
    local title = params.title or (mode == "time" and "Select Time" or "Select Date")

    local current = formatDisplay(value, mode)

    if native and native.showAlert then
        native.showAlert(
            title,
            "Current: " .. current .. "\n\nUse +/- buttons or edit directly.",
            {"OK"},
            function(event)
                if onChange then
                    onChange({
                        type = M.EventType.SET,
                        nativeEvent = { timestamp = value },
                    })
                end
            end
        )
    end
end

return M
