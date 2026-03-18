-- lib/slider/init.lua
-- @react-native-community/slider implementation for Solar2D
-- Cross-platform slider component

local M = {}

function M.Slider(props)
    local React = require("react")
    local useState = React.useState
    local useRef = React.useRef
    local useCallback = React.useCallback

    local value = props.value or 0
    local minimumValue = props.minimumValue or 0
    local maximumValue = props.maximumValue or 1
    local step = props.step
    local disabled = props.disabled or false
    local onValueChange = props.onValueChange
    local onSlidingComplete = props.onSlidingComplete
    local style = props.style or {}

    -- Default colors
    local minimumTrackTintColor = props.minimumTrackTintColor or "#007AFF"
    local maximumTrackTintColor = props.maximumTrackTintColor or "#B3B3B3"
    local thumbTintColor = props.thumbTintColor or "#FFFFFF"

    -- Thumb and track dimensions
    local trackHeight = style.trackHeight or 4
    local thumbSize = style.thumbSize or 20
    local trackWidth = style.width or 200

    -- Internal state for dragging
    local isDragging, setIsDragging = useState(false)
    local localValue, setLocalValue = useState(value)

    -- Sync with external value
    React.useEffect(function()
        setLocalValue(value)
    end, {value})

    -- Calculate position from value
    local function valueToPosition(v)
        local ratio = (v - minimumValue) / (maximumValue - minimumValue)
        return ratio * (trackWidth - thumbSize)
    end

    -- Calculate value from position
    local function positionToValue(pos)
        local ratio = pos / (trackWidth - thumbSize)
        local v = minimumValue + ratio * (maximumValue - minimumValue)
        -- Apply step if specified
        if step and step > 0 then
            v = math.floor((v - minimumValue) / step + 0.5) * step + minimumValue
        end
        -- Clamp to bounds
        return math.max(minimumValue, math.min(maximumValue, v))
    end

    local handlePress = useCallback(function(e)
        if disabled then return end
        local pos = math.max(0, math.min(trackWidth - thumbSize, e.x - thumbSize / 2))
        local newValue = positionToValue(pos)
        setLocalValue(newValue)
        if onValueChange then
            onValueChange(newValue)
        end
        setIsDragging(true)
    end)

    local handleMove = useCallback(function(e)
        if not isDragging or disabled then return end
        local pos = math.max(0, math.min(trackWidth - thumbSize, e.x - thumbSize / 2))
        local newValue = positionToValue(pos)
        setLocalValue(newValue)
        if onValueChange then
            onValueChange(newValue)
        end
    end)

    local handleRelease = useCallback(function()
        if not isDragging then return end
        setIsDragging(false)
        if onSlidingComplete then
            onSlidingComplete(localValue)
        end
    end)

    local thumbPosition = valueToPosition(localValue)
    local filledWidth = thumbPosition + thumbSize / 2

    return React.createElement("View", {
        style = {
            width = trackWidth,
            height = math.max(trackHeight, thumbSize) + 10,
            justifyContent = "center",
            style = style,
        }
    },
        -- Track background (unfilled)
        React.createElement("View", {
            style = {
                position = "absolute",
                left = 0,
                right = 0,
                height = trackHeight,
                backgroundColor = maximumTrackTintColor,
                borderRadius = trackHeight / 2,
            }
        }),
        -- Track fill
        React.createElement("View", {
            style = {
                position = "absolute",
                left = 0,
                width = filledWidth,
                height = trackHeight,
                backgroundColor = minimumTrackTintColor,
                borderRadius = trackHeight / 2,
            }
        }),
        -- Touchable area and thumb
        React.createElement("Pressable", {
            style = {
                position = "absolute",
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
            onPressIn = handlePress,
            onPress = handleRelease,
        },
            -- Thumb
            React.createElement("View", {
                style = {
                    position = "absolute",
                    left = thumbPosition,
                    top = (math.max(trackHeight, thumbSize) + 10 - thumbSize) / 2 - (trackHeight + 10) / 2,
                    width = thumbSize,
                    height = thumbSize,
                    borderRadius = thumbSize / 2,
                    backgroundColor = thumbTintColor,
                    shadowColor = "#000",
                    shadowOffset = { width = 0, height = 2 },
                    shadowOpacity = 0.2,
                    shadowRadius = 2,
                    elevation = 3,
                    borderWidth = disabled and 0 or 1,
                    borderColor = "#DDDDDD",
                }
            })
        )
    )
end

return M
