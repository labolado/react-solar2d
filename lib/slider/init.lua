-- lib/slider/init.lua
-- @react-native-community/slider for Solar2D
-- Uses _onDragHandler stored on overlay instance, which ScrollView detects and forwards touches to.
-- propsRef ensures handlers always see latest values.

local M = {}

function M.Slider(props)
    local React = require("react")
    local ce = React.createElement
    local useRef = React.useRef
    local useCallback = React.useCallback

    -- Props
    local value         = props.value or 0
    local minimumValue  = props.minimumValue or 0
    local maximumValue  = props.maximumValue or 1
    local step          = props.step
    local disabled      = props.disabled or false
    local onValueChange = props.onValueChange
    local onSlidingComplete = props.onSlidingComplete
    local style         = props.style or {}

    -- Colors
    local minimumTrackTintColor = props.minimumTrackTintColor or "#007AFF"
    local maximumTrackTintColor = props.maximumTrackTintColor or "#B3B3B3"
    local thumbTintColor        = props.thumbTintColor or "#FFFFFF"

    -- Dimensions
    local trackHeight = 4
    local thumbSize   = 20
    local trackWidth  = style.width or 200

    -- Computed from current value
    local ratio    = (value - minimumValue) / (maximumValue - minimumValue)
    local thumbPos = math.max(0, math.min(trackWidth, ratio * trackWidth))

    -- Ref for direct thumb manipulation during drag
    local thumbRef = useRef(nil)

    -- propsRef: always holds latest props, avoids stale closures
    local propsRef = useRef({})
    propsRef.current = {
        value = value,
        minimumValue = minimumValue,
        maximumValue = maximumValue,
        step = step,
        disabled = disabled,
        onValueChange = onValueChange,
        onSlidingComplete = onSlidingComplete,
        trackWidth = trackWidth,
        thumbSize = thumbSize,
    }

    -- Calculate value from relative X position
    local function calcValue(relX)
        local p = propsRef.current
        local r = math.max(0, math.min(1, relX / p.trackWidth))
        local v = p.minimumValue + r * (p.maximumValue - p.minimumValue)
        if p.step and p.step > 0 then
            v = math.floor((v - p.minimumValue) / p.step + 0.5) * p.step + p.minimumValue
        end
        return math.max(p.minimumValue, math.min(p.maximumValue, v))
    end

    -- Move thumb directly for immediate feedback (filled track handled by React re-render)
    local function updateThumbVisual(relX)
        local p = propsRef.current
        relX = math.max(0, math.min(p.trackWidth, relX))
        local thumb = thumbRef.current
        if thumb then thumb.x = relX - p.thumbSize / 2 end
    end

    -- ref callback: store _onDragHandler on the overlay instance
    -- ScrollView detects this and forwards touch events instead of scrolling
    local overlayRefCallback = useCallback(function(instance)
        if not instance then return end
        instance._onDragHandler = function(event)
            if propsRef.current.disabled then return end
            local bounds = instance.contentBounds
            if not bounds then return end
            local relX = event.x - bounds.xMin

            if event.phase == "began" or event.phase == "moved" then
                updateThumbVisual(relX)
                local newVal = calcValue(relX)
                if propsRef.current.onValueChange then
                    propsRef.current.onValueChange(newVal)
                end
            elseif event.phase == "ended" or event.phase == "cancelled" then
                updateThumbVisual(relX)
                local newVal = calcValue(relX)
                if propsRef.current.onValueChange then
                    propsRef.current.onValueChange(newVal)
                end
                if propsRef.current.onSlidingComplete then
                    propsRef.current.onSlidingComplete(newVal)
                end
            end
        end
    end, {})

    -- Button handlers (increment / decrement)
    local handleDecrement = useCallback(function()
        if disabled then return end
        local delta    = step or (maximumValue - minimumValue) / 20
        local newValue = math.max(minimumValue, value - delta)
        if onValueChange    then onValueChange(newValue) end
        if onSlidingComplete then onSlidingComplete(newValue) end
    end, {disabled, value, step, minimumValue, maximumValue, onValueChange, onSlidingComplete})

    local handleIncrement = useCallback(function()
        if disabled then return end
        local delta    = step or (maximumValue - minimumValue) / 20
        local newValue = math.min(maximumValue, value + delta)
        if onValueChange    then onValueChange(newValue) end
        if onSlidingComplete then onSlidingComplete(newValue) end
    end, {disabled, value, step, minimumValue, maximumValue, onValueChange, onSlidingComplete})

    -- Build UI
    local btnW = 30
    local btnH = 24

    return ce("View", {
        style = {
            width  = trackWidth + 80,
            height = thumbSize + 10,
        }
    },
        -- Decrement button
        ce("View", {
            style = {
                position        = "absolute",
                left            = 0,
                top             = (thumbSize + 10 - btnH) / 2,
                width           = btnW,
                height          = btnH,
                backgroundColor = "#E8E8E8",
                borderRadius    = 4,
                justifyContent  = "center",
                alignItems      = "center",
            },
            onPress = handleDecrement,
        },
            ce("Text", {
                style = {
                    fontSize   = 18,
                    color      = disabled and "#BBBBBB" or "#007AFF",
                    fontWeight = "bold",
                    textAlign  = "center",
                }
            }, "-")
        ),

        -- Track container
        ce("View", {
            style = {
                position = "absolute",
                left     = 40,
                top      = 0,
                width    = trackWidth,
                height   = thumbSize + 10,
            },
        },
            -- Background (inactive) track
            ce("View", {
                style = {
                    position        = "absolute",
                    left            = 0,
                    top             = (thumbSize + 10 - trackHeight) / 2,
                    width           = trackWidth,
                    height          = trackHeight,
                    backgroundColor = maximumTrackTintColor,
                    borderRadius    = trackHeight / 2,
                }
            }),
            -- Filled (active) track — no borderRadius to avoid path.width issues
            ce("View", {
                style = {
                    position        = "absolute",
                    left            = 0,
                    top             = (thumbSize + 10 - trackHeight) / 2,
                    width           = math.max(1, thumbPos),
                    height          = trackHeight,
                    backgroundColor = minimumTrackTintColor,
                },
            }),
            -- Thumb
            ce("View", {
                style = {
                    position        = "absolute",
                    left            = thumbPos - thumbSize / 2,
                    top             = (thumbSize + 10 - thumbSize) / 2,
                    width           = thumbSize,
                    height          = thumbSize,
                    borderRadius    = thumbSize / 2,
                    backgroundColor = thumbTintColor,
                    borderWidth     = 2,
                    borderColor     = "#AAAAAA",
                },
                ref = function(r) thumbRef.current = r end,
            }),
            -- OVERLAY: on top, stores _onDragHandler for ScrollView to find
            ce("View", {
                style = {
                    position        = "absolute",
                    left            = 0,
                    top             = 0,
                    width           = trackWidth,
                    height          = thumbSize + 10,
                    backgroundColor = "#00000001",
                },
                ref = overlayRefCallback,
            })
        ),

        -- Increment button
        ce("View", {
            style = {
                position        = "absolute",
                left            = 40 + trackWidth + 5,
                top             = (thumbSize + 10 - btnH) / 2,
                width           = btnW,
                height          = btnH,
                backgroundColor = "#E8E8E8",
                borderRadius    = 4,
                justifyContent  = "center",
                alignItems      = "center",
            },
            onPress = handleIncrement,
        },
            ce("Text", {
                style = {
                    fontSize   = 18,
                    color      = disabled and "#BBBBBB" or "#007AFF",
                    fontWeight = "bold",
                    textAlign  = "center",
                }
            }, "+")
        )
    )
end

return M
