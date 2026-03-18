-- lib/slider/init.lua
-- @react-native-community/slider implementation for Solar2D
-- Simple and reliable slider

local M = {}

function M.Slider(props)
    local React = require("react")
    local ce = React.createElement

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

    -- Dimensions
    local trackHeight = 4
    local thumbSize = 20
    local trackWidth = style.width or 200

    -- Calculate thumb position
    local ratio = (value - minimumValue) / (maximumValue - minimumValue)
    local thumbPosition = ratio * trackWidth

    -- Clamp position
    thumbPosition = math.max(0, math.min(trackWidth, thumbPosition))

    -- Handle tap on track
    local function handleTrackPress(e)
        if disabled then return end
        local pos = math.max(0, math.min(trackWidth, e.x or (trackWidth / 2)))
        local newRatio = pos / trackWidth
        local newValue = minimumValue + newRatio * (maximumValue - minimumValue)

        if step and step > 0 then
            newValue = math.floor((newValue - minimumValue) / step + 0.5) * step + minimumValue
        end

        newValue = math.max(minimumValue, math.min(maximumValue, newValue))

        if onValueChange then
            onValueChange(newValue)
        end
        if onSlidingComplete then
            onSlidingComplete(newValue)
        end
    end

    -- Handle decrement
    local function handleDecrement()
        if disabled then return end
        local delta = step or (maximumValue - minimumValue) / 20
        local newValue = math.max(minimumValue, value - delta)
        if onValueChange then
            onValueChange(newValue)
        end
        if onSlidingComplete then
            onSlidingComplete(newValue)
        end
    end

    -- Handle increment
    local function handleIncrement()
        if disabled then return end
        local delta = step or (maximumValue - minimumValue) / 20
        local newValue = math.min(maximumValue, value + delta)
        if onValueChange then
            onValueChange(newValue)
        end
        if onSlidingComplete then
            onSlidingComplete(newValue)
        end
    end

    -- Main container with padding for buttons
    return ce("View", {
        style = {
            width = trackWidth + 80, -- Space for buttons
            height = thumbSize + 10,
        }
    },
        -- Left button
        ce("Pressable", {
            style = {
                position = "absolute",
                left = 0,
                top = (thumbSize + 10 - 24) / 2,
                width = 30,
                height = 24,
            },
            onPress = handleDecrement,
        },
            ce("Text", {
                style = {
                    fontSize = 20,
                    color = disabled and "#999999" or "#007AFF",
                    fontWeight = "bold",
                    textAlign = "center",
                }
            }, "-")
        ),

        -- Track container (centered)
        ce("Pressable", {
            style = {
                position = "absolute",
                left = 40,
                top = (thumbSize + 10 - trackHeight) / 2,
                width = trackWidth,
                height = thumbSize,
            },
            onPress = handleTrackPress,
        },
            -- Background track
            ce("View", {
                style = {
                    position = "absolute",
                    left = 0,
                    top = (thumbSize - trackHeight) / 2,
                    width = trackWidth,
                    height = trackHeight,
                    backgroundColor = maximumTrackTintColor,
                    borderRadius = trackHeight / 2,
                }
            }),
            -- Filled track
            ce("View", {
                style = {
                    position = "absolute",
                    left = 0,
                    top = (thumbSize - trackHeight) / 2,
                    width = thumbPosition,
                    height = trackHeight,
                    backgroundColor = minimumTrackTintColor,
                    borderRadius = trackHeight / 2,
                }
            }),
            -- Thumb
            ce("View", {
                style = {
                    position = "absolute",
                    left = thumbPosition - thumbSize / 2,
                    top = 0,
                    width = thumbSize,
                    height = thumbSize,
                    borderRadius = thumbSize / 2,
                    backgroundColor = thumbTintColor,
                    borderWidth = 1,
                    borderColor = "#CCCCCC",
                }
            })
        ),

        -- Right button
        ce("Pressable", {
            style = {
                position = "absolute",
                left = 40 + trackWidth + 5,
                top = (thumbSize + 10 - 24) / 2,
                width = 30,
                height = 24,
            },
            onPress = handleIncrement,
        },
            ce("Text", {
                style = {
                    fontSize = 20,
                    color = disabled and "#999999" or "#007AFF",
                    fontWeight = "bold",
                    textAlign = "center",
                }
            }, "+")
        )
    )
end

return M
