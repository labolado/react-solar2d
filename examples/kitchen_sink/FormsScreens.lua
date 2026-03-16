-- examples/kitchen_sink/FormsScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Hooks = require("hooks.useTimer")
local Section = T.Section
local DemoPage = T.DemoPage

-- 1. TextInputDemo
local function TextInputDemo()
    local text, setText = useState("")
    local multiText, setMultiText = useState("")
    return ce(DemoPage, {},
        ce(Section, { title = "Single Line Input" },
            ce(RN.TextInput, {
                placeholder = "Type something...",
                value = text,
                onChangeText = function(t) setText(t) end,
                style = {
                    backgroundColor = T.surface, color = T.textPrimary,
                    padding = 12, borderRadius = T.radiusSmall,
                    borderWidth = 1, borderColor = T.border, fontSize = 16,
                },
            }),
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginTop = 8 },
            }, "You typed: " .. text)
        ),
        ce(Section, { title = "Multi-line Input" },
            ce(RN.TextInput, {
                placeholder = "Write a paragraph...",
                value = multiText,
                onChangeText = function(t) setMultiText(t) end,
                multiline = true,
                style = {
                    backgroundColor = T.surface, color = T.textPrimary,
                    padding = 12, borderRadius = T.radiusSmall,
                    borderWidth = 1, borderColor = T.border,
                    fontSize = 16, height = 120,
                },
            })
        )
    )
end

-- 2. SwitchDemo
local function SwitchDemo()
    local wifi, setWifi = useState(true)
    local bluetooth, setBluetooth = useState(false)
    local darkMode, setDarkMode = useState(true)
    return ce(DemoPage, {},
        ce(Section, { title = "Switches" },
            ce("View", { style = { gap = 16 } },
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Wi-Fi: " .. (wifi and "ON" or "OFF")),
                    ce(RN.Switch, { value = wifi, onValueChange = setWifi })
                ),
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Bluetooth: " .. (bluetooth and "ON" or "OFF")),
                    ce(RN.Switch, {
                        value = bluetooth, onValueChange = setBluetooth,
                        trackColor = { ["true"] = "#2979FF", ["false"] = "#444" },
                    })
                ),
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, "Dark Mode: " .. (darkMode and "ON" or "OFF")),
                    ce(RN.Switch, {
                        value = darkMode, onValueChange = setDarkMode,
                        trackColor = { ["true"] = "#FF6600", ["false"] = "#444" },
                        thumbColor = "#FFF",
                    })
                )
            )
        )
    )
end

-- 3. ModalDemo
local function ModalDemo()
    local visible, setVisible = useState(false)
    return ce(DemoPage, {},
        ce(Section, { title = "Modal" },
            ce(RN.Button, {
                title = "Open Modal",
                color = T.accent,
                onPress = function() setVisible(true) end,
            }),
            ce(RN.Modal, {
                visible = visible,
                transparent = true,
                onRequestClose = function() setVisible(false) end,
            },
                ce("View", {
                    style = {
                        backgroundColor = T.surface, borderRadius = T.radius,
                        padding = 24, width = 280,
                        borderWidth = 1, borderColor = T.border,
                    },
                },
                    ce("Text", {
                        style = { fontSize = 20, color = T.textPrimary, fontWeight = "bold", marginBottom = 12 },
                    }, "Hello Modal!"),
                    ce("Text", {
                        style = { fontSize = 14, color = T.textSecondary, marginBottom = 20 },
                    }, "This is a modal dialog rendered as an overlay."),
                    ce(RN.Button, {
                        title = "Close",
                        color = T.accent,
                        onPress = function() setVisible(false) end,
                    })
                )
            )
        )
    )
end

-- 4. ActivityIndicatorDemo
local function ActivityIndicatorDemo()
    local animating, setAnimating = useState(true)
    local sizeLabel, setSizeLabel = useState("small")
    local colorIdx, setColorIdx = useState(1)
    local colors = { "#58A6FF", "#FF6600", "#00C853", "#E74C3C" }
    local colorNames = { "Blue", "Orange", "Green", "Red" }

    -- useTimeout: auto-hide after 3 seconds then re-show
    local autoHidden, setAutoHidden = useState(false)
    Hooks.useTimeout(function()
        if animating and not autoHidden then
            setAutoHidden(true)
            setAnimating(false)
        end
    end, animating and not autoHidden and 3000 or false)

    Hooks.useTimeout(function()
        if autoHidden then
            setAutoHidden(false)
            setAnimating(true)
        end
    end, autoHidden and 1500 or false)

    local sizeVal = sizeLabel
    if sizeLabel == "custom" then sizeVal = 60 end

    return ce(DemoPage, {},
        ce(Section, { title = "Activity Indicator" },
            ce("View", {
                style = { alignItems = "center", padding = 24, backgroundColor = T.surface, borderRadius = T.radius, marginBottom = T.gap },
            },
                ce(RN.ActivityIndicator, {
                    animating = animating,
                    size = sizeVal,
                    color = colors[colorIdx],
                }),
                ce("Text", {
                    style = { fontSize = 12, color = T.textSecondary, marginTop = 12 },
                }, animating and "Auto-hides in 3s, re-shows in 1.5s" or "Paused...")
            )
        ),
        ce(Section, { title = "Size" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce(RN.Button, { title = "Small", color = sizeLabel == "small" and T.accent or T.textSecondary, onPress = function() setSizeLabel("small") end }),
                ce(RN.Button, { title = "Large", color = sizeLabel == "large" and T.accent or T.textSecondary, onPress = function() setSizeLabel("large") end }),
                ce(RN.Button, { title = "60px", color = sizeLabel == "custom" and T.accent or T.textSecondary, onPress = function() setSizeLabel("custom") end })
            )
        ),
        ce(Section, { title = "Color: " .. colorNames[colorIdx] },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce(RN.Button, { title = "Next Color", color = colors[colorIdx], onPress = function()
                    setColorIdx(function(i) return (i % #colors) + 1 end)
                end })
            )
        ),
        ce(Section, { title = "Animating" },
            ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center" } },
                ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, animating and "ON" or "OFF"),
                ce(RN.Switch, { value = animating, onValueChange = function(v)
                    setAutoHidden(false)
                    setAnimating(v)
                end })
            )
        )
    )
end

return {
    { name = "TextInput",  component = TextInputDemo,  description = "Single/multi-line, controlled input", icon = "T" },
    { name = "Switch",     component = SwitchDemo,     description = "Toggle switches, custom colors",      icon = "S" },
    { name = "Modal",      component = ModalDemo,      description = "Overlay dialog, open/close",          icon = "M" },
    { name = "Indicator",  component = ActivityIndicatorDemo, description = "Loading spinner, size/color/useTimeout", icon = "A" },
}
