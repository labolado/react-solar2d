-- lib/datetime-picker/init.lua
-- @react-native-community/datetimepicker implementation for Solar2D
-- Column-based picker: each column shows selected value with tap-to-change

local M = {}

M.Display = {
    DEFAULT = "default",
    SPINNER = "spinner",
    CLOCK = "clock",
    CALENDAR = "calendar",
}

M.EventType = {
    SET = "set",
    DISMISSED = "dismissed",
}

-- Format number with leading zero
local function pad2(n)
    return string.format("%02d", n)
end

-- Get days in month
local function getDaysInMonth(year, month)
    local nextMonth = month + 1
    local nextYear = year
    if nextMonth > 12 then
        nextMonth = 1
        nextYear = year + 1
    end
    local firstDayNextMonth = os.time({ year = nextYear, month = nextMonth, day = 1, hour = 0, min = 0 })
    local lastDayThisMonth = os.date("*t", firstDayNextMonth - 86400)
    return lastDayThisMonth.day
end

-- Wrap a value within [min, max]
local function wrapValue(val, minVal, maxVal)
    if val > maxVal then return minVal end
    if val < minVal then return maxVal end
    return val
end

-- Single column: shows prev/current/next values with up/down tap areas
local function Column(props)
    local React = require("react")
    local ce = React.createElement
    local useCallback = React.useCallback
    local useRef = React.useRef

    local value = props.value
    local minVal = props.min or 0
    local maxVal = props.max or 99
    local onChange = props.onChange
    local width = props.width or 52
    local formatter = props.formatter or tostring
    local disabled = props.disabled or false

    local propsRef = useRef({})
    propsRef.current = { value = value, minVal = minVal, maxVal = maxVal, onChange = onChange, disabled = disabled }

    local handleUp = useCallback(function()
        local p = propsRef.current
        if p.disabled then return end
        local newVal = wrapValue(p.value - 1, p.minVal, p.maxVal)
        if p.onChange then p.onChange(newVal) end
    end, {})

    local handleDown = useCallback(function()
        local p = propsRef.current
        if p.disabled then return end
        local newVal = wrapValue(p.value + 1, p.minVal, p.maxVal)
        if p.onChange then p.onChange(newVal) end
    end, {})

    local prevVal = wrapValue(value - 1, minVal, maxVal)
    local nextVal = wrapValue(value + 1, minVal, maxVal)

    local dimColor = "#666666"
    local selectedColor = "#FFFFFF"
    local itemH = 32

    return ce("View", {
        style = {
            width = width,
            height = itemH * 3,
            alignItems = "center",
        }
    },
        -- Previous value (tap to decrement)
        ce("View", {
            style = {
                width = width,
                height = itemH,
                justifyContent = "center",
                alignItems = "center",
            },
            onPress = handleUp,
        },
            ce("Text", {
                style = { fontSize = 13, color = dimColor, textAlign = "center" }
            }, formatter(prevVal))
        ),

        -- Current value (selected)
        ce("View", {
            style = {
                width = width,
                height = itemH,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = "#333333",
                borderRadius = 6,
            },
        },
            ce("Text", {
                style = { fontSize = 17, color = selectedColor, fontWeight = "bold", textAlign = "center" }
            }, formatter(value))
        ),

        -- Next value (tap to increment)
        ce("View", {
            style = {
                width = width,
                height = itemH,
                justifyContent = "center",
                alignItems = "center",
            },
            onPress = handleDown,
        },
            ce("Text", {
                style = { fontSize = 13, color = dimColor, textAlign = "center" }
            }, formatter(nextVal))
        )
    )
end

-- Separator label between columns
local function Sep(props)
    local React = require("react")
    local ce = React.createElement
    return ce("View", {
        style = {
            width = 12,
            height = 32 * 3,
            justifyContent = "center",
            alignItems = "center",
        }
    },
        ce("Text", {
            style = { fontSize = 16, color = "#999999", textAlign = "center" }
        }, props.text or "")
    )
end

function M.DateTimePicker(props)
    local React = require("react")
    local ce = React.createElement
    local useCallback = React.useCallback
    local useRef = React.useRef

    local value = props.value or os.time()
    local mode = props.mode or "date"
    local onChange = props.onChange
    local disabled = props.disabled or false
    local style = props.style or {}
    local minimumDate = props.minimumDate
    local maximumDate = props.maximumDate

    local t = os.date("*t", value)
    local year, month, day, hour, min = t.year, t.month, t.day, t.hour, t.min

    local propsRef = useRef({})
    propsRef.current = {
        value = value, year = year, month = month, day = day,
        hour = hour, min = min, onChange = onChange,
        minimumDate = minimumDate, maximumDate = maximumDate, disabled = disabled,
    }

    local function emitChange(newTs)
        local p = propsRef.current
        if p.minimumDate and newTs < p.minimumDate then newTs = p.minimumDate end
        if p.maximumDate and newTs > p.maximumDate then newTs = p.maximumDate end
        if p.onChange then
            p.onChange({ type = M.EventType.SET, nativeEvent = { timestamp = newTs } })
        end
    end

    local handleYearChange = useCallback(function(newYear)
        local p = propsRef.current
        local d = math.min(p.day, getDaysInMonth(newYear, p.month))
        emitChange(os.time({ year = newYear, month = p.month, day = d, hour = p.hour, min = p.min }))
    end, {})

    local handleMonthChange = useCallback(function(newMonth)
        local p = propsRef.current
        local d = math.min(p.day, getDaysInMonth(p.year, newMonth))
        emitChange(os.time({ year = p.year, month = newMonth, day = d, hour = p.hour, min = p.min }))
    end, {})

    local handleDayChange = useCallback(function(newDay)
        local p = propsRef.current
        emitChange(os.time({ year = p.year, month = p.month, day = newDay, hour = p.hour, min = p.min }))
    end, {})

    local handleHourChange = useCallback(function(newHour)
        local p = propsRef.current
        emitChange(os.time({ year = p.year, month = p.month, day = p.day, hour = newHour, min = p.min }))
    end, {})

    local handleMinChange = useCallback(function(newMin)
        local p = propsRef.current
        emitChange(os.time({ year = p.year, month = p.month, day = p.day, hour = p.hour, min = newMin }))
    end, {})

    local daysInMonth = getDaysInMonth(year, month)

    -- Build column elements based on mode
    if mode == "time" then
        return ce("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                backgroundColor = style.backgroundColor or "#1E1E2E",
                borderRadius = style.borderRadius or 8,
                padding = 8,
                width = style.width,
                height = style.height,
            }
        },
            ce(Column, { value = hour, min = 0, max = 23, onChange = handleHourChange, width = 48, formatter = pad2, disabled = disabled }),
            ce(Sep, { text = ":" }),
            ce(Column, { value = min, min = 0, max = 59, onChange = handleMinChange, width = 48, formatter = pad2, disabled = disabled })
        )
    elseif mode == "datetime" then
        return ce("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                backgroundColor = style.backgroundColor or "#1E1E2E",
                borderRadius = style.borderRadius or 8,
                padding = 8,
                width = style.width,
                height = style.height,
            }
        },
            ce(Column, { value = year, min = 1970, max = 2099, onChange = handleYearChange, width = 56, formatter = tostring, disabled = disabled }),
            ce(Sep, { text = "-" }),
            ce(Column, { value = month, min = 1, max = 12, onChange = handleMonthChange, width = 40, formatter = pad2, disabled = disabled }),
            ce(Sep, { text = "-" }),
            ce(Column, { value = day, min = 1, max = daysInMonth, onChange = handleDayChange, width = 40, formatter = pad2, disabled = disabled }),
            ce(Sep, { text = "" }),
            ce(Column, { value = hour, min = 0, max = 23, onChange = handleHourChange, width = 40, formatter = pad2, disabled = disabled }),
            ce(Sep, { text = ":" }),
            ce(Column, { value = min, min = 0, max = 59, onChange = handleMinChange, width = 40, formatter = pad2, disabled = disabled })
        )
    else
        -- date mode (default)
        return ce("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                backgroundColor = style.backgroundColor or "#1E1E2E",
                borderRadius = style.borderRadius or 8,
                padding = 8,
                width = style.width,
                height = style.height,
            }
        },
            ce(Column, { value = year, min = 1970, max = 2099, onChange = handleYearChange, width = 56, formatter = tostring, disabled = disabled }),
            ce(Sep, { text = "-" }),
            ce(Column, { value = month, min = 1, max = 12, onChange = handleMonthChange, width = 44, formatter = pad2, disabled = disabled }),
            ce(Sep, { text = "-" }),
            ce(Column, { value = day, min = 1, max = daysInMonth, onChange = handleDayChange, width = 44, formatter = pad2, disabled = disabled })
        )
    end
end

-- Open native date picker dialog (kept for compatibility)
function M.open(params)
    local mode = params.mode or "date"
    local value = params.value or os.time()
    local onChange = params.onChange
    local title = params.title or (mode == "time" and "Select Time" or "Select Date")

    if native and native.showAlert then
        native.showAlert(title, "Current: " .. os.date("%Y-%m-%d %H:%M", value), {"OK"}, function(event)
            if onChange then onChange({ type = M.EventType.SET, nativeEvent = { timestamp = value } }) end
        end)
    end
end

return M
