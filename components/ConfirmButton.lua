--- ConfirmButton component.
-- Two-step confirmation button: first tap enters confirm state,
-- second tap within timeout executes the action. Common pattern for
-- destructive actions and parental gates in children's apps.
-- @module components.ConfirmButton

local React = require("react")
local ce = React.createElement

--- ConfirmButton component.
-- @param props table
--   label string              Default label (e.g. "Delete")
--   confirmLabel string       Label shown in confirm state (e.g. "Confirm?")
--   onConfirm function        Called on second tap (confirmed)
--   timeout number            Ms to auto-reset from confirm state (default 3000)
--   style table               Default style
--   confirmStyle table        Style override in confirm state
--   textStyle table           Default text style
--   confirmTextStyle table    Text style override in confirm state
--   disabled boolean
-- @return table React element
local function ConfirmButton(props)
    local confirming, setConfirming = React.useState(false)
    local timerRef = React.useRef(nil)

    local label = confirming and (props.confirmLabel or "Confirm?") or (props.label or "OK")
    local timeout = props.timeout or 3000

    local function cancelTimer()
        if timerRef.current then
            timer.cancel(timerRef.current)
            timerRef.current = nil
        end
    end

    -- Cleanup timer on unmount
    React.useEffect(function()
        return function()
            cancelTimer()
        end
    end, {})

    local function onPress()
        if props.disabled then return end
        if confirming then
            -- Second tap: confirmed
            cancelTimer()
            setConfirming(false)
            if props.onConfirm then props.onConfirm() end
        else
            -- First tap: enter confirm state
            setConfirming(true)
            timerRef.current = timer.performWithDelay(timeout, function()
                timerRef.current = nil
                setConfirming(false)
            end)
        end
    end

    local baseStyle = {
        paddingHorizontal = 16,
        paddingVertical = 10,
        borderRadius = 8,
        backgroundColor = "#58A6FF",
        justifyContent = "center",
        alignItems = "center",
    }
    local confirmBaseStyle = {
        paddingHorizontal = 16,
        paddingVertical = 10,
        borderRadius = 8,
        backgroundColor = "#E74C3C",
        justifyContent = "center",
        alignItems = "center",
    }

    local style = confirming and confirmBaseStyle or baseStyle
    local override = confirming and props.confirmStyle or props.style
    if override then
        for k, v in pairs(override) do style[k] = v end
    end

    local textBase = { color = "#FFF", fontWeight = "bold", textAlign = "center" }
    local textOverride = confirming and props.confirmTextStyle or props.textStyle
    if textOverride then
        for k, v in pairs(textOverride) do textBase[k] = v end
    end

    return ce("View", {
        style = style,
        onPress = onPress,
    },
        ce("Text", { style = textBase }, label)
    )
end

return ConfirmButton
