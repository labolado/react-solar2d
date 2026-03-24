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

-- Shared: centered modal content wrapper (renders inside Modal's centered container)
local function ModalContent(props)
    return ce("View", {
        style = {
            backgroundColor = T.surface,
            borderRadius = T.radius,
            borderWidth = 1,
            borderColor = T.border,
            padding = props.padding or 24,
            width = props.width or 300,
        },
    }, props.children)
end

-- 3. ModalDemo — multiple modal styles (uses pushOverlay/popOverlay for global overlay)
local function ModalDemo(props)
    local pushOverlay = props.pushOverlay
    local popOverlay = props.popOverlay
    local formName, setFormName = useState("")
    local formEmail, setFormEmail = useState("")
    local formNotes, setFormNotes = useState("")
    local formResult, setFormResult = useState("")
    local agreed, setAgreed = useState(false)

    local function close()
        if popOverlay then popOverlay() end
    end

    -- ── Modal content builders ──
    local function showBasicModal()
        if not pushOverlay then return end
        pushOverlay(ce(RN.Modal, {
            visible = true, transparent = true, onRequestClose = close,
        },
            ce(ModalContent, {},
                ce("Text", {
                    style = { fontSize = 18, color = T.textPrimary, fontWeight = "bold", marginBottom = 10, width = 252 },
                }, "Basic Modal"),
                ce("Text", {
                    style = { fontSize = 14, color = T.textSecondary, marginBottom = 20, lineHeight = 20, width = 252 },
                }, "This is a centered modal dialog with text that wraps automatically when the content is long enough to exceed the container width."),
                ce(RN.Button, { title = "OK", color = T.accent, onPress = close })
            )
        ))
    end

    local function showRichModal()
        if not pushOverlay then return end
        pushOverlay(ce(RN.Modal, {
            visible = true, transparent = true, onRequestClose = close,
        },
            ce(ModalContent, { width = 320, padding = 0 },
                -- Header with accent background
                ce("View", { style = { backgroundColor = T.accent, padding = 16 } },
                    ce("Text", { style = { fontSize = 18, color = "#FFF", fontWeight = "bold", width = 288 } }, "Update Available"),
                    ce("Text", { style = { fontSize = 12, color = "rgba(255,255,255,0.8)", marginTop = 4, width = 288 } }, "Version 2.5.0")
                ),
                -- Body
                ce("View", { style = { padding = 16 } },
                    ce("Text", { style = { fontSize = 14, color = T.textPrimary, fontWeight = "bold", marginBottom = 8, width = 288 } }, "What's New:"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 4, width = 288 } }, "• Modal overlay system with centering"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 4, width = 288 } }, "• Action sheet slide-up menu"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 4, width = 288 } }, "• Toast notification stack"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 12, width = 288 } }, "• Responsive layout components"),
                    -- Progress bar
                    ce("View", { style = { height = 6, backgroundColor = T.border, borderRadius = 3, overflow = "hidden", marginBottom = 4 } },
                        ce("View", { style = { width = 200, height = 6, backgroundColor = "#2ECC71", borderRadius = 3 } })
                    ),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary, width = 288 } }, "Download: 78%")
                ),
                -- Footer with buttons
                ce("View", { style = { flexDirection = "row", borderTopWidth = 1, borderColor = T.border } },
                    ce(RN.Pressable, {
                        style = { flex = 1, paddingVertical = 12, alignItems = "center", borderRightWidth = 1, borderColor = T.border },
                        onPress = close,
                    }, ce("Text", { style = { fontSize = 14, color = T.textSecondary } }, "Later")),
                    ce(RN.Pressable, {
                        style = { flex = 1, paddingVertical = 12, alignItems = "center" },
                        onPress = close,
                    }, ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold" } }, "Update Now"))
                )
            )
        ))
    end

    local function showFormModal()
        if not pushOverlay then return end
        pushOverlay(ce(RN.Modal, {
            visible = true, transparent = true, onRequestClose = close,
        },
            ce(ModalContent, { width = 320, padding = 0 },
                -- Header
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center", padding = 16, borderBottomWidth = 1, borderColor = T.border } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold", width = 250 } }, "Contact Form"),
                    ce(RN.Pressable, {
                        onPress = close,
                        style = { width = 40, height = 40, justifyContent = "center", alignItems = "center" },
                    }, ce("Text", { style = { fontSize = 24, color = T.textSecondary } }, "×"))
                ),
                -- Form fields
                ce("View", { style = { padding = 16 } },
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Name"),
                    ce(RN.TextInput, {
                        value = formName, onChangeText = setFormName,
                        placeholder = "Your name",
                        style = {
                            backgroundColor = T.bg, borderWidth = 1, borderColor = T.border,
                            borderRadius = T.radiusSmall, padding = 10, fontSize = 14,
                            color = T.textPrimary, marginBottom = 12, height = 42,
                        },
                    }),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Email"),
                    ce(RN.TextInput, {
                        value = formEmail, onChangeText = setFormEmail,
                        placeholder = "you@example.com",
                        style = {
                            backgroundColor = T.bg, borderWidth = 1, borderColor = T.border,
                            borderRadius = T.radiusSmall, padding = 10, fontSize = 14,
                            color = T.textPrimary, marginBottom = 12, height = 42,
                        },
                    }),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Notes"),
                    ce(RN.TextInput, {
                        value = formNotes, onChangeText = setFormNotes,
                        placeholder = "Any additional notes...",
                        multiline = true,
                        style = {
                            backgroundColor = T.bg, borderWidth = 1, borderColor = T.border,
                            borderRadius = T.radiusSmall, padding = 10, fontSize = 14,
                            color = T.textPrimary, height = 80, marginBottom = 12,
                        },
                    }),
                    ce("View", { style = { flexDirection = "row", alignItems = "center", marginBottom = 16 } },
                        ce(RN.Switch, { value = agreed, onValueChange = setAgreed, trackColor = { ["true"] = T.accent, ["false"] = "#444" } }),
                        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginLeft = 8, width = 240 } }, "I agree to the terms")
                    )
                ),
                -- Actions
                ce("View", { style = { flexDirection = "row", padding = 16, paddingTop = 0, gap = 12 } },
                    ce("View", { style = { flex = 1 } },
                        ce(RN.Button, { title = "Cancel", color = T.textSecondary, onPress = close })),
                    ce("View", { style = { flex = 1 } },
                        ce(RN.Button, {
                            title = "Submit",
                            color = agreed and T.accent or T.textSecondary,
                            onPress = function()
                                if agreed then
                                    setFormResult("Submitted: " .. formName .. " <" .. formEmail .. ">")
                                    close()
                                end
                            end,
                        }))
                )
            )
        ))
    end

    local function showConfirmModal()
        if not pushOverlay then return end
        pushOverlay(ce(RN.Modal, {
            visible = true, transparent = true, onRequestClose = close,
        },
            ce(ModalContent, { width = 300 },
                -- Warning icon circle (center using alignSelf)
                ce("View", {
                    style = {
                        width = 56, height = 56, borderRadius = 28,
                        backgroundColor = "rgba(231,76,60,0.15)",
                        justifyContent = "center", alignItems = "center", marginBottom = 16,
                        alignSelf = "center",
                    },
                }, ce("Text", { style = { fontSize = 28, color = "#E74C3C" } }, "!")),
                ce("Text", {
                    style = { fontSize = 18, color = T.textPrimary, fontWeight = "bold", marginBottom = 8, width = 252 },
                }, "Delete Project?"),
                ce("Text", {
                    style = { fontSize = 14, color = T.textSecondary, lineHeight = 20, marginBottom = 20, width = 252 },
                }, "This will permanently delete the project and all associated data. This action cannot be undone."),
                ce("View", { style = { flexDirection = "row", gap = 10 } },
                    ce("View", { style = { flex = 1 } },
                        ce(RN.Button, { title = "Cancel", color = T.textSecondary, onPress = close })),
                    ce("View", { style = { flex = 1 } },
                        ce(RN.Button, { title = "Delete", color = "#E74C3C", onPress = close }))
                )
            )
        ))
    end

    local function showFullModal()
        if not pushOverlay then return end
        local screenW = display.contentWidth
        local screenH = display.contentHeight
        pushOverlay(ce(RN.Modal, {
            visible = true, transparent = true, onRequestClose = close,
        },
            ce("View", {
                style = {
                    position = "absolute",
                    left = 12, top = 40,
                    width = screenW - 24,
                    height = screenH - 80,
                    backgroundColor = T.surface,
                    borderRadius = T.radius,
                    borderWidth = 1,
                    borderColor = T.border,
                    overflow = "hidden",
                },
            },
                -- Header bar
                ce("View", { style = { flexDirection = "row", alignItems = "center", padding = 14, borderBottomWidth = 1, borderColor = T.border } },
                    ce(RN.Pressable, { onPress = close },
                        ce("Text", { style = { fontSize = 14, color = T.accent } }, "← Close")),
                    ce("View", { style = { flex = 1 } }),
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold" } }, "Full Screen Modal"),
                    ce("View", { style = { flex = 1 } })
                ),
                -- Scrollable content
                ce("ScrollView", {
                    style = { flex = 1 },
                    contentContainerStyle = { padding = 16 },
                },
                    ce("Text", { style = { fontSize = 14, color = T.textPrimary, lineHeight = 22, marginBottom = 12, width = screenW - 56 } },
                        "This is a near-full-screen modal that demonstrates how to build complex overlay interfaces. It has a sticky header with a close button and scrollable content below."),
                    ce("Text", { style = { fontSize = 14, color = T.textPrimary, lineHeight = 22, marginBottom = 12, width = screenW - 56 } },
                        "Use this pattern for settings pages, detailed forms, media viewers, or any content that needs more space than a small dialog provides."),
                    ce("View", { style = { height = 120, backgroundColor = T.bg, borderRadius = T.radiusSmall, justifyContent = "center", alignItems = "center", marginBottom = 12 } },
                        ce("Text", { style = { fontSize = 16, color = T.textSecondary } }, "[ Content Area ]")),
                    ce("Text", { style = { fontSize = 14, color = T.textPrimary, lineHeight = 22, marginBottom = 12, width = screenW - 56 } },
                        "The modal uses absolute positioning with insets (12px from edges, 40px from top/bottom) to create a floating panel effect. Content inside can scroll independently."),
                    ce("View", { style = { height = 120, backgroundColor = T.bg, borderRadius = T.radiusSmall, justifyContent = "center", alignItems = "center", marginBottom = 12 } },
                        ce("Text", { style = { fontSize = 16, color = T.textSecondary } }, "[ More Content ]")),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, width = screenW - 56 } },
                        "Scroll down to see more. The content area is flexible and adapts to the available space. Long text like this paragraph wraps naturally within the modal boundaries.")
                )
            )
        ))
    end

    -- Render modals via pushOverlay - they appear at root level, covering categoryBar
    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
        contentContainerStyle = { padding = T.pad },
    },
        ce(Section, { title = "Modal Styles" },
            ce(RN.Button, { title = "Basic Dialog", color = T.accent, onPress = showBasicModal }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Rich Content (changelog)", color = "#2ECC71", onPress = showRichModal }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Form Dialog", color = "#9B59B6", onPress = showFormModal }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Confirm Delete (icon)", color = "#E74C3C", onPress = showConfirmModal }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Full Screen Modal", color = "#F39C12", onPress = showFullModal })
        ),
        formResult ~= "" and ce(Section, { title = "Form Result" },
            ce("Text", { style = { fontSize = 13, color = "#2ECC71" } }, formResult)
        ) or nil
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

-- 5. KeyboardAvoidingViewDemo
local function KeyboardAvoidingViewDemo()
    local text1, setText1 = useState("")
    local text2, setText2 = useState("")
    local text3, setText3 = useState("")
    local behavior, setBehavior = useState("padding")
    
    return ce(DemoPage, {},
        ce(Section, { title = "Behavior Mode: " .. behavior },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce(RN.Button, { 
                    title = "padding", 
                    color = behavior == "padding" and T.accent or T.textSecondary,
                    onPress = function() setBehavior("padding") end 
                }),
                ce(RN.Button, { 
                    title = "position", 
                    color = behavior == "position" and T.accent or T.textSecondary,
                    onPress = function() setBehavior("position") end 
                }),
                ce(RN.Button, { 
                    title = "height", 
                    color = behavior == "height" and T.accent or T.textSecondary,
                    onPress = function() setBehavior("height") end 
                })
            )
        ),
        ce(RN.KeyboardAvoidingView, {
            behavior = behavior,
            style = { flex = 1 },
        },
            ce("ScrollView", { style = { flex = 1 } },
                ce("View", { style = { padding = T.pad, gap = 16 } },
                    ce("Text", { 
                        style = { fontSize = 14, color = T.textSecondary, marginBottom = 8 } 
                    }, "Tap the text inputs below. The view will adjust when keyboard appears."),
                    
                    -- Input 1
                    ce("View", {},
                        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Username"),
                        ce(RN.TextInput, {
                            placeholder = "Enter username...",
                            value = text1,
                            onChangeText = setText1,
                            style = {
                                backgroundColor = T.surface,
                                borderWidth = 1,
                                borderColor = T.border,
                                borderRadius = T.radiusSmall,
                                padding = 12,
                                fontSize = 16,
                                color = T.textPrimary,
                            },
                        })
                    ),
                    
                    -- Input 2
                    ce("View", {},
                        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Email"),
                        ce(RN.TextInput, {
                            placeholder = "Enter email...",
                            value = text2,
                            onChangeText = setText2,
                            style = {
                                backgroundColor = T.surface,
                                borderWidth = 1,
                                borderColor = T.border,
                                borderRadius = T.radiusSmall,
                                padding = 12,
                                fontSize = 16,
                                color = T.textPrimary,
                            },
                        })
                    ),
                    
                    -- Input 3 (multiline)
                    ce("View", {},
                        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Bio (multiline)"),
                        ce(RN.TextInput, {
                            placeholder = "Tell us about yourself...",
                            value = text3,
                            onChangeText = setText3,
                            multiline = true,
                            style = {
                                backgroundColor = T.surface,
                                borderWidth = 1,
                                borderColor = T.border,
                                borderRadius = T.radiusSmall,
                                padding = 12,
                                fontSize = 16,
                                color = T.textPrimary,
                                height = 100,
                            },
                        })
                    ),
                    
                    -- Spacer to push content up
                    ce("View", { style = { height = 200 } }),
                    
                    ce("Text", { 
                        style = { fontSize = 12, color = T.textSecondary, textAlign = "center" } 
                    }, "Scroll down and tap the last input to test keyboard avoiding")
                )
            )
        )
    )
end

return {
    { name = "TextInput",  component = TextInputDemo,  description = "Single/multi-line, controlled input", icon = "T" },
    { name = "Switch",     component = SwitchDemo,     description = "Toggle switches, custom colors",      icon = "S" },
    { name = "Modal",      component = ModalDemo,      description = "Overlay dialog, open/close",          icon = "M" },
    { name = "Indicator",  component = ActivityIndicatorDemo, description = "Loading spinner, size/color/useTimeout", icon = "A" },
    { name = "KeyboardAV", component = KeyboardAvoidingViewDemo, description = "Keyboard avoiding behavior modes", icon = "K" },
}
