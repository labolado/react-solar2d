-- lib/datetime-picker/init.lua
-- @react-native-community/datetimepicker implementation for Solar2D
-- Fixed: working version with proper controls

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

function M.DateTimePicker(props)
    local React = require("react")
    local useState = React.useState
    local useCallback = React.useCallback
    local ce = React.createElement

    local value = props.value or os.time()
    local mode = props.mode or "date"
    local onChange = props.onChange
    local disabled = props.disabled or false
    local style = props.style or {}
    local minimumDate = props.minimumDate
    local maximumDate = props.maximumDate

    local pickerHeight = 44
    local displayValue = formatDisplay(value, mode)

    -- Local state for editing
    local editValue, setEditValue = useState(displayValue)
    local isEditing, setIsEditing = useState(false)

    -- Update edit value when prop changes
    React.useEffect(function()
        if not isEditing then
            setEditValue(formatDisplay(value, mode))
        end
    end, {value, mode})

    -- Handlers
    local handleDecrement = useCallback(function()
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
    end, {disabled, value, mode, minimumDate, maximumDate, onChange})

    local handleIncrement = useCallback(function()
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
    end, {disabled, value, mode, minimumDate, maximumDate, onChange})

    local handleEditStart = useCallback(function()
        if disabled then return end
        setIsEditing(true)
        setEditValue(formatDisplay(value, mode))
    end, {disabled, value, mode})

    local handleEditChange = useCallback(function(e)
        setEditValue(e.text or "")
    end, {})

    local handleEditSubmit = useCallback(function(e)
        setIsEditing(false)
        local text = e.text or editValue
        local newTs = tryParse(text, mode, value)
        if newTs then
            if minimumDate and newTs < minimumDate then newTs = minimumDate end
            if maximumDate and newTs > maximumDate then newTs = maximumDate end
            if onChange then
                onChange({ type = M.EventType.SET, nativeEvent = { timestamp = newTs } })
            end
        else
            -- Revert on invalid input
            setEditValue(formatDisplay(value, mode))
        end
    end, {editValue, mode, value, minimumDate, maximumDate, onChange})

    local handleEditCancel = useCallback(function()
        setIsEditing(false)
        setEditValue(formatDisplay(value, mode))
    end, {value, mode})

    -- Container width
    local containerWidth = style.width or 220

    -- Use View for display mode, TextInput for edit mode
    if isEditing then
        -- Edit mode with native text input
        return ce("View", {
            style = {
                width = containerWidth,
                height = pickerHeight,
                flexDirection = "row",
                alignItems = "center",
            }
        },
            -- Decrement button
            ce("View", {
                style = {
                    width = 40,
                    height = pickerHeight,
                    backgroundColor = "transparent",
                },
                onPress = handleDecrement,
            },
                ce("Text", {
                    style = {
                        fontSize = 24,
                        color = disabled and "#999999" or "#007AFF",
                        textAlign = "center",
                        textAlignVertical = "center",
                        lineHeight = pickerHeight,
                    }
                }, "-")
            ),

            -- TextInput for editing
            ce("TextInput", {
                style = {
                    flex = 1,
                    height = pickerHeight - 4,
                    fontSize = 16,
                    color = style.color or "#333333",
                    textAlign = "center",
                    backgroundColor = "#FFFFFF",
                    borderWidth = 2,
                    borderColor = "#007AFF",
                    borderRadius = 4,
                },
                value = editValue,
                onChangeText = handleEditChange,
                onSubmitEditing = handleEditSubmit,
                onBlur = handleEditCancel,
                autoFocus = true,
                editable = not disabled,
                keyboardType = mode == "time" and "numbers-and-punctuation" or "default",
            }),

            -- Increment button
            ce("View", {
                style = {
                    width = 40,
                    height = pickerHeight,
                    backgroundColor = "transparent",
                },
                onPress = handleIncrement,
            },
                ce("Text", {
                    style = {
                        fontSize = 24,
                        color = disabled and "#999999" or "#007AFF",
                        textAlign = "center",
                        textAlignVertical = "center",
                        lineHeight = pickerHeight,
                    }
                }, "+")
            )
        )
    else
        -- Display mode
        return ce("View", {
            style = {
                width = containerWidth,
                height = pickerHeight,
                flexDirection = "row",
                alignItems = "center",
            }
        },
            -- Decrement button
            ce("View", {
                style = {
                    width = 40,
                    height = pickerHeight,
                    backgroundColor = "transparent",
                },
                onPress = handleDecrement,
            },
                ce("Text", {
                    style = {
                        fontSize = 24,
                        color = disabled and "#999999" or "#007AFF",
                        textAlign = "center",
                        textAlignVertical = "center",
                        lineHeight = pickerHeight,
                    }
                }, "-")
            ),

            -- Value display (tap to edit)
            ce("View", {
                style = {
                    flex = 1,
                    height = pickerHeight - 4,
                    backgroundColor = style.backgroundColor or "#FFFFFF",
                    borderWidth = 1,
                    borderColor = style.borderColor or "#CCCCCC",
                    borderRadius = 4,
                    justifyContent = "center",
                    alignItems = "center",
                },
                onPress = handleEditStart,
            },
                ce("Text", {
                    style = {
                        fontSize = 16,
                        color = style.color or "#333333",
                        textAlign = "center",
                    }
                }, displayValue)
            ),

            -- Increment button
            ce("View", {
                style = {
                    width = 40,
                    height = pickerHeight,
                    backgroundColor = "transparent",
                },
                onPress = handleIncrement,
            },
                ce("Text", {
                    style = {
                        fontSize = 24,
                        color = disabled and "#999999" or "#007AFF",
                        textAlign = "center",
                        textAlignVertical = "center",
                        lineHeight = pickerHeight,
                    }
                }, "+")
            )
        )
    end
end

-- Open native date picker dialog
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
