-- lib/slider/init.lua
-- @react-native-community/slider implementation for Solar2D
-- Cross-platform slider component

local M = {}

function M.Slider(props)
    local React = require("react")
    local useState = React.useState
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

    -- Calculate thumb position from value
    local function getThumbPosition()
        local ratio = (value - minimumValue) / (maximumValue - minimumValue)
        return ratio * (trackWidth - thumbSize)
    end

    -- Calculate value from position (0 to trackWidth)
    local function positionToValue(pos)
        local ratio = pos / trackWidth
        local v = minimumValue + ratio * (maximumValue - minimumValue)
        -- Apply step if specified
        if step and step > 0 then
            v = math.floor((v - minimumValue) / step + 0.5) * step + minimumValue
        end
        -- Clamp to bounds
        return math.max(minimumValue, math.min(maximumValue, v))
    end

    -- Handle tap on track - jump to that position
    local handleTrackPress = useCallback(function(e)
        if disabled then return end
        local pos = e.x or (trackWidth / 2)
        local newValue = positionToValue(pos)
        if onValueChange then
            onValueChange(newValue)
        end
        if onSlidingComplete then
            onSlidingComplete(newValue)
        end
    end)

    -- Handle decrement
    local handleDecrement = useCallback(function()
        if disabled then return end
        local delta = step or (maximumValue - minimumValue) / 20
        local newValue = math.max(minimumValue, value - delta)
        if onValueChange then
            onValueChange(newValue)
        end
        if onSlidingComplete then
            onSlidingComplete(newValue)
        end
    end)

    -- Handle increment
    local handleIncrement = useCallback(function()
        if disabled then return end
        local delta = step or (maximumValue - minimumValue) / 20
        local newValue = math.min(maximumValue, value + delta)
        if onValueChange then
            onValueChange(newValue)
        end
        if onSlidingComplete then
            onSlidingComplete(newValue)
        end
    end)

    local thumbPosition = getThumbPosition()
    local filledWidth = thumbPosition + thumbSize / 2

    return React.createElement("View", {
        style = {
            width = trackWidth,
            height = math.max(trackHeight, thumbSize) + 10,
            justifyContent = "center",
        }
    },
        -- Decrement button (no feedback for instant response)
        React.createElement("Pressable", {
            style = {
                position = "absolute",
                left = -30,
                width = 24,
                height = 24,
                borderRadius = 12,
                backgroundColor = disabled and "#CCCCCC" or "#007AFF",
                justifyContent = "center",
                alignItems = "center",
            },
            onPress = handleDecrement,
            disabled = disabled,
            activeOpacity = 1.0,
        },
            React.createElement("Text", {
                style = {
                    fontSize = 16,
                    color = "#FFFFFF",
                    fontWeight = "bold",
                    textAlign = "center",
                    lineHeight = 24,
                }
            }, "-")
        ),

        -- Track background (with tap handler, no feedback)
        React.createElement("Pressable", {
            style = {
                position = "absolute",
                left = 0,
                right = 0,
                height = trackHeight + 20,
                justifyContent = "center",
            },
            onPress = handleTrackPress,
            disabled = disabled,
            activeOpacity = 1.0,
        },
            -- Visual track background
            React.createElement("View", {
                style = {
                    width = trackWidth,
                    height = trackHeight,
                    backgroundColor = maximumTrackTintColor,
                    borderRadius = trackHeight / 2,
                }
            },
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
                })
            ),
            -- Thumb (visual only, positioned over track)
            React.createElement("View", {
                style = {
                    position = "absolute",
                    left = thumbPosition,
                    width = thumbSize,
                    height = thumbSize,
                    borderRadius = thumbSize / 2,
                    backgroundColor = thumbTintColor,
                    borderWidth = 1,
                    borderColor = "#DDDDDD",
                }
            })
        ),

        -- Increment button (no feedback for instant response)
        React.createElement("Pressable", {
            style = {
                position = "absolute",
                right = -30,
                width = 24,
                height = 24,
                borderRadius = 12,
                backgroundColor = disabled and "#CCCCCC" or "#007AFF",
                justifyContent = "center",
                alignItems = "center",
            },
            onPress = handleIncrement,
            disabled = disabled,
            activeOpacity = 1.0,
        },
            React.createElement("Text", {
                style = {
                    fontSize = 16,
                    color = "#FFFFFF",
                    fontWeight = "bold",
                    textAlign = "center",
                    lineHeight = 24,
                }
            }, "+")
        )
    )
end

return M
