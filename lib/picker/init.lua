-- lib/picker/init.lua
-- @react-native-picker/picker implementation for Solar2D
-- Native picker using Solar2D's native picker API

local M = {}

-- Picker component
function M.Picker(props)
    local React = require("react")
    local useState = React.useState
    local useEffect = React.useEffect
    local useRef = React.useRef

    local selectedValue = props.selectedValue
    local onValueChange = props.onValueChange
    local enabled = props.enabled ~= false
    local style = props.style or {}

    -- Simple dropdown-like picker using buttons (since Solar2D doesn't have native UIPickerView)
    local function handleSelect(value)
        if onValueChange and enabled then
            onValueChange(value)
        end
    end

    -- Build picker items
    local children = props.children or {}
    local items = {}

    -- Flatten children if needed
    if type(children) ~= "table" then
        children = { children }
    end

    for _, child in ipairs(children) do
        if child and child.type == "PickerItem" then
            table.insert(items, {
                label = child.props.label,
                value = child.props.value,
                color = child.props.color,
            })
        end
    end

    return React.createElement("View", {
        style = {
            backgroundColor = style.backgroundColor or "#FFFFFF",
            borderWidth = style.borderWidth or 1,
            borderColor = style.borderColor or "#CCCCCC",
            borderRadius = style.borderRadius or 4,
            padding = style.padding or 8,
        }
    }, (function()
        local buttons = {}
        for i, item in ipairs(items) do
            local isSelected = item.value == selectedValue
            table.insert(buttons, React.createElement("Pressable", {
                key = item.value,
                style = {
                    paddingVertical = 8,
                    paddingHorizontal = 12,
                    backgroundColor = isSelected and (style.selectedColor or "#007AFF") or "transparent",
                    borderRadius = 2,
                    marginBottom = i < #items and 2 or 0,
                },
                onPress = function() handleSelect(item.value) end,
            },
                React.createElement("Text", {
                    style = {
                        fontSize = style.fontSize or 14,
                        color = isSelected and "#FFFFFF" or (item.color or style.color or "#333333"),
                    }
                }, item.label or item.value)
            ))
        end
        return buttons
    end)())
end

-- PickerItem component (just a marker, actual rendering handled by Picker)
function M.PickerItem(props)
    -- This is a placeholder component
    return {
        type = "PickerItem",
        props = props,
    }
end

return M
