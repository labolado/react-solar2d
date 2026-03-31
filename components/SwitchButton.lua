--- SwitchButton component.
-- A button that cycles through multiple states on each tap.
-- Unlike Switch (boolean only), SwitchButton supports N states.
-- Common for tool selectors, drawing mode toggles, etc.
-- @module components.SwitchButton

local React = require("react")
local ce = React.createElement

--- SwitchButton component.
-- @param props table
--   states table              Array of state definitions: { {label, value, color}, ... }
--   value any                 Current value (matches states[i].value)
--   onValueChange function    Called with (newValue, newIndex) on tap
--   style table               Additional button style
--   textStyle table           Additional text style
--   disabled boolean
-- @return table React element
--
-- Example:
--   ce(SwitchButton, {
--     states = {
--       { label = "Pen",    value = "pen",    color = "#58A6FF" },
--       { label = "Eraser", value = "eraser", color = "#E74C3C" },
--       { label = "Fill",   value = "fill",   color = "#2ECC71" },
--     },
--     value = currentTool,
--     onValueChange = function(val) setCurrentTool(val) end,
--   })
local function SwitchButton(props)
    local states = props.states or {}
    if #states == 0 then return nil end

    -- Find current index
    local currentIndex = 1
    if props.value ~= nil then
        for i, s in ipairs(states) do
            if s.value == props.value then
                currentIndex = i
                break
            end
        end
    end

    local current = states[currentIndex]
    local label = current.label or tostring(current.value or "")
    local color = current.color or "#58A6FF"

    local function onPress()
        if props.disabled then return end
        local nextIndex = (currentIndex % #states) + 1
        local nextState = states[nextIndex]
        if props.onValueChange then
            props.onValueChange(nextState.value, nextIndex)
        end
    end

    local style = {
        paddingHorizontal = 16,
        paddingVertical = 10,
        borderRadius = 8,
        backgroundColor = color,
        justifyContent = "center",
        alignItems = "center",
    }
    if props.style then
        for k, v in pairs(props.style) do style[k] = v end
    end

    local textStyle = { color = "#FFF", fontWeight = "bold", textAlign = "center" }
    if props.textStyle then
        for k, v in pairs(props.textStyle) do textStyle[k] = v end
    end

    return ce("View", {
        style = style,
        onPress = onPress,
    },
        ce("Text", { style = textStyle }, label)
    )
end

return SwitchButton
