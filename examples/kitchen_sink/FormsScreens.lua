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

-- Shared: centered modal backdrop
local function ModalBackdrop(props)
    return ce("View", {
        style = {
            position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
            backgroundColor = "rgba(0,0,0,0.55)",
            justifyContent = "center", alignItems = "center",
        },
    }, props.children)
end

-- 3. ModalDemo — multiple modal styles
local function ModalDemo()
    local activeModal, setActiveModal = useState(nil)
    local formName, setFormName = useState("")
    local formEmail, setFormEmail = useState("")
    local formNotes, setFormNotes = useState("")
    local formResult, setFormResult = useState("")
    local agreed, setAgreed = useState(false)

    local function close() setActiveModal(nil) end

    -- ── Modal A: Basic centered dialog ──
    local modalBasic = activeModal == "basic" and ce(RN.Modal, {
        visible = true, transparent = true, onRequestClose = close,
    },
        ce(ModalBackdrop, {},
            ce("View", {
                style = {
                    backgroundColor = T.surface, borderRadius = T.radius,
                    padding = 24, width = 300, maxWidth = 300,
                    borderWidth = 1, borderColor = T.border,
                },
            },
                ce("Text", {
                    style = { fontSize = 18, color = T.textPrimary, fontWeight = "bold", marginBottom = 10 },
                }, "Basic Modal"),
                ce("Text", {
                    style = { fontSize = 14, color = T.textSecondary, marginBottom = 20, lineHeight = 20 },
                }, "This is a centered modal dialog with text that wraps automatically when the content is long enough to exceed the container width."),
                ce(RN.Button, { title = "OK", color = T.accent, onPress = close })
            )
        )
    ) or nil

    -- ── Modal B: Rich content with sections ──
    local modalRich = activeModal == "rich" and ce(RN.Modal, {
        visible = true, transparent = true, onRequestClose = close,
    },
        ce(ModalBackdrop, {},
            ce("View", {
                style = {
                    backgroundColor = T.surface, borderRadius = T.radius,
                    width = 320, maxWidth = 320, overflow = "hidden",
                    borderWidth = 1, borderColor = T.border,
                },
            },
                -- Header with accent background
                ce("View", { style = { backgroundColor = T.accent, padding = 16 } },
                    ce("Text", { style = { fontSize = 18, color = "#FFF", fontWeight = "bold" } }, "Update Available"),
                    ce("Text", { style = { fontSize = 12, color = "rgba(255,255,255,0.8)", marginTop = 4 } }, "Version 2.5.0")
                ),
                -- Body
                ce("View", { style = { padding = 16 } },
                    ce("Text", { style = { fontSize = 14, color = T.textPrimary, fontWeight = "bold", marginBottom = 8 } }, "What's New:"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 4 } }, "• Modal overlay system with centering"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 4 } }, "• Action sheet slide-up menu"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 4 } }, "• Toast notification stack"),
                    ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20, marginBottom = 12 } }, "• Responsive layout components"),
                    -- Progress bar
                    ce("View", { style = { height = 6, backgroundColor = T.border, borderRadius = 3, overflow = "hidden", marginBottom = 4 } },
                        ce("View", { style = { width = 200, height = 6, backgroundColor = "#2ECC71", borderRadius = 3 } })
                    ),
                    ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "Download: 78%")
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
        )
    ) or nil

    -- ── Modal C: Form dialog ──
    local modalForm = activeModal == "form" and ce(RN.Modal, {
        visible = true, transparent = true, onRequestClose = close,
    },
        ce(ModalBackdrop, {},
            ce("View", {
                style = {
                    backgroundColor = T.surface, borderRadius = T.radius,
                    width = 320, maxWidth = 320, overflow = "hidden",
                    borderWidth = 1, borderColor = T.border,
                },
            },
                -- Header
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center", padding = 16, borderBottomWidth = 1, borderColor = T.border } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold" } }, "Contact Form"),
                    ce(RN.Pressable, { onPress = close },
                        ce("Text", { style = { fontSize = 18, color = T.textSecondary } }, "✕"))
                ),
                -- Form fields
                ce("View", { style = { padding = 16 } },
                    -- Name
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Name"),
                    ce(RN.TextInput, {
                        value = formName, onChangeText = setFormName,
                        placeholder = "Your name",
                        style = {
                            backgroundColor = T.bg, borderWidth = 1, borderColor = T.border,
                            borderRadius = T.radiusSmall, padding = 10, fontSize = 14,
                            color = T.textPrimary, marginBottom = 12,
                        },
                    }),
                    -- Email
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Email"),
                    ce(RN.TextInput, {
                        value = formEmail, onChangeText = setFormEmail,
                        placeholder = "you@example.com",
                        style = {
                            backgroundColor = T.bg, borderWidth = 1, borderColor = T.border,
                            borderRadius = T.radiusSmall, padding = 10, fontSize = 14,
                            color = T.textPrimary, marginBottom = 12,
                        },
                    }),
                    -- Notes
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 4 } }, "Notes"),
                    ce(RN.TextInput, {
                        value = formNotes, onChangeText = setFormNotes,
                        placeholder = "Any additional notes...",
                        multiline = true,
                        style = {
                            backgroundColor = T.bg, borderWidth = 1, borderColor = T.border,
                            borderRadius = T.radiusSmall, padding = 10, fontSize = 14,
                            color = T.textPrimary, height = 70, marginBottom = 12,
                        },
                    }),
                    -- Agreement switch
                    ce("View", { style = { flexDirection = "row", alignItems = "center", marginBottom = 16 } },
                        ce(RN.Switch, { value = agreed, onValueChange = setAgreed, trackColor = { ["true"] = T.accent, ["false"] = "#444" } }),
                        ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginLeft = 8, flex = 1 } }, "I agree to the terms and conditions")
                    )
                ),
                -- Actions
                ce("View", { style = { flexDirection = "row", padding = 16, paddingTop = 0, gap = 8 } },
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
        )
    ) or nil

    -- ── Modal D: Confirmation with icon ──
    local modalConfirm = activeModal == "confirm" and ce(RN.Modal, {
        visible = true, transparent = true, onRequestClose = close,
    },
        ce(ModalBackdrop, {},
            ce("View", {
                style = {
                    backgroundColor = T.surface, borderRadius = T.radius,
                    padding = 24, width = 300, maxWidth = 300, alignItems = "center",
                    borderWidth = 1, borderColor = T.border,
                },
            },
                -- Warning icon circle
                ce("View", {
                    style = {
                        width = 56, height = 56, borderRadius = 28,
                        backgroundColor = "rgba(231,76,60,0.15)",
                        justifyContent = "center", alignItems = "center", marginBottom = 16,
                    },
                }, ce("Text", { style = { fontSize = 28, color = "#E74C3C" } }, "!")),
                ce("Text", {
                    style = { fontSize = 18, color = T.textPrimary, fontWeight = "bold", marginBottom = 8, textAlign = "center" },
                }, "Delete Project?"),
                ce("Text", {
                    style = { fontSize = 14, color = T.textSecondary, textAlign = "center", lineHeight = 20, marginBottom = 20 },
                }, "This will permanently delete the project and all associated data. This action cannot be undone."),
                ce("View", { style = { flexDirection = "row", gap = 10 } },
                    ce("View", { style = { flex = 1 } },
                        ce(RN.Button, { title = "Cancel", color = T.textSecondary, onPress = close })),
                    ce("View", { style = { flex = 1 } },
                        ce(RN.Button, { title = "Delete", color = "#E74C3C", onPress = close }))
                )
            )
        )
    ) or nil

    -- ── Modal E: Full-screen modal ──
    local modalFull = activeModal == "full" and ce(RN.Modal, {
        visible = true, transparent = true, onRequestClose = close,
    },
        ce("View", {
            style = {
                position = "absolute", left = 12, right = 12, top = 40, bottom = 40,
                backgroundColor = T.surface, borderRadius = T.radius,
                borderWidth = 1, borderColor = T.border, overflow = "hidden",
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
                ce("Text", { style = { fontSize = 14, color = T.textPrimary, lineHeight = 22, marginBottom = 12 } },
                    "This is a near-full-screen modal that demonstrates how to build complex overlay interfaces. It has a sticky header with a close button and scrollable content below."),
                ce("Text", { style = { fontSize = 14, color = T.textPrimary, lineHeight = 22, marginBottom = 12 } },
                    "Use this pattern for settings pages, detailed forms, media viewers, or any content that needs more space than a small dialog provides."),
                ce("View", { style = { height = 120, backgroundColor = T.bg, borderRadius = T.radiusSmall, justifyContent = "center", alignItems = "center", marginBottom = 12 } },
                    ce("Text", { style = { fontSize = 16, color = T.textSecondary } }, "[ Content Area ]")),
                ce("Text", { style = { fontSize = 14, color = T.textPrimary, lineHeight = 22, marginBottom = 12 } },
                    "The modal uses absolute positioning with insets (12px from edges, 40px from top/bottom) to create a floating panel effect. Content inside can scroll independently."),
                ce("View", { style = { height = 120, backgroundColor = T.bg, borderRadius = T.radiusSmall, justifyContent = "center", alignItems = "center", marginBottom = 12 } },
                    ce("Text", { style = { fontSize = 16, color = T.textSecondary } }, "[ More Content ]")),
                ce("Text", { style = { fontSize = 13, color = T.textSecondary, lineHeight = 20 } },
                    "Scroll down to see more. The content area is flexible and adapts to the available space. Long text like this paragraph wraps naturally within the modal boundaries.")
            )
        )
    ) or nil

    return ce(DemoPage, {},
        ce(Section, { title = "Modal Styles" },
            ce(RN.Button, { title = "Basic Dialog", color = T.accent, onPress = function() setActiveModal("basic") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Rich Content (changelog)", color = "#2ECC71", onPress = function() setActiveModal("rich") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Form Dialog", color = "#9B59B6", onPress = function() setActiveModal("form") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Confirm Delete (icon)", color = "#E74C3C", onPress = function() setActiveModal("confirm") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Full Screen Modal", color = "#F39C12", onPress = function() setActiveModal("full") end })
        ),
        formResult ~= "" and ce(Section, { title = "Form Result" },
            ce("Text", { style = { fontSize = 13, color = "#2ECC71" } }, formResult)
        ) or nil,
        modalBasic, modalRich, modalForm, modalConfirm, modalFull
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
