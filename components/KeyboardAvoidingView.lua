-- components/KeyboardAvoidingView.lua
-- Adjusts view position/height when keyboard appears.
-- Solar2D provides native keyboard events via Runtime:addEventListener("keyboard").
local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local function KeyboardAvoidingView(props)
    local behavior = props.behavior or "padding" -- "padding", "position", "height"
    local keyboardVerticalOffset = props.keyboardVerticalOffset or 0
    local style = props.style or {}
    local children = props.children
    local enabled = props.enabled ~= false

    local keyboardHeight, setKeyboardHeight = useState(0)
    local isKeyboardVisible, setIsKeyboardVisible = useState(false)
    local contentHeightRef = useRef(nil)

    useEffect(function()
        if not enabled then
            return nil
        end

        local function onKeyboard(event)
            if event.phase == "began" then
                setIsKeyboardVisible(true)
                setKeyboardHeight(event.keyboardHeight or 0)
            elseif event.phase == "ended" then
                setIsKeyboardVisible(false)
                setKeyboardHeight(0)
            end
        end

        -- Register keyboard event listener if Runtime is available
        if Runtime and Runtime.addEventListener then
            Runtime:addEventListener("keyboard", onKeyboard)
        end

        -- Cleanup function
        return function()
            if Runtime and Runtime.removeEventListener then
                Runtime:removeEventListener("keyboard", onKeyboard)
            end
        end
    end, { enabled })

    -- Calculate adjusted style based on behavior
    local adjustedStyle = {}
    for k, v in pairs(style) do
        adjustedStyle[k] = v
    end

    local effectiveKeyboardHeight = math.max(0, keyboardHeight - keyboardVerticalOffset)

    if isKeyboardVisible and enabled then
        if behavior == "padding" then
            -- Add bottom padding to avoid keyboard
            adjustedStyle.paddingBottom = (style.paddingBottom or 0) + effectiveKeyboardHeight
        elseif behavior == "position" then
            -- Move view up by keyboard height
            adjustedStyle.transform = adjustedStyle.transform or {}
            local foundTranslateY = false
            for _, t in ipairs(adjustedStyle.transform) do
                if t.translateY ~= nil then
                    t.translateY = -(effectiveKeyboardHeight)
                    foundTranslateY = true
                    break
                end
            end
            if not foundTranslateY then
                table.insert(adjustedStyle.transform, { translateY = -effectiveKeyboardHeight })
            end
        elseif behavior == "height" then
            -- Reduce height by keyboard amount
            if style.height then
                adjustedStyle.height = style.height - effectiveKeyboardHeight
            end
        end
    end

    return createElement("View", {
        style = adjustedStyle,
    }, children)
end

return KeyboardAvoidingView
