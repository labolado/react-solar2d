-- examples/kitchen_sink/OverlayScreens.lua
-- Demos: Alert, ActionSheet, Toast, Popover/Tooltip
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useRef = React.useRef
local T = require("kitchen_sink.theme")
local RN = require("react_solar2d")
local Animated = require("animated")
local Hooks = require("hooks.useTimer")
local Section = T.Section
local DemoPage = T.DemoPage

-- ─── Shared: overlay backdrop ───
local function Backdrop(props)
    return ce("View", {
        style = {
            position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
            backgroundColor = "rgba(0,0,0,0.5)",
            justifyContent = "center", alignItems = "center",
        },
    }, props.children)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. AlertDemo — simple alert dialogs (OK / OK+Cancel / custom buttons)
-- ═══════════════════════════════════════════════════════════════════════════
local function AlertDemo(props)
    local pushOverlay = props.pushOverlay
    local clearOverlay = props.clearOverlay
    local alertType, setAlertType = useState(nil) -- nil | "info" | "confirm" | "custom"
    local result, setResult = useState("")

    local function closeAlert(msg)
        setAlertType(nil)
        if msg then setResult(msg) end
        if clearOverlay then clearOverlay() end
    end

    -- Show alert using global overlay layer
    local function showAlert(type)
        setAlertType(type)
        if not pushOverlay then return end

        local alertContent
        if type == "info" then
            alertContent = ce(RN.Modal, { visible = true, transparent = true, onRequestClose = function() closeAlert() end },
                ce(Backdrop, {},
                    ce("View", { style = { width = 280, backgroundColor = T.surface, borderRadius = T.radius, padding = 24 } },
                        ce("Text", { style = { fontSize = 18, fontWeight = "bold", color = T.textPrimary, marginBottom = 8 } }, "Info"),
                        ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginBottom = 20 } }, "This is an information alert. Tap OK to dismiss."),
                        ce(RN.Button, { title = "OK", color = T.accent, onPress = function() closeAlert("Dismissed info") end })
                    )
                )
            )
        elseif type == "confirm" then
            alertContent = ce(RN.Modal, { visible = true, transparent = true, onRequestClose = function() closeAlert() end },
                ce(Backdrop, {},
                    ce("View", { style = { width = 280, backgroundColor = T.surface, borderRadius = T.radius, padding = 24 } },
                        ce("Text", { style = { fontSize = 18, fontWeight = "bold", color = T.textPrimary, marginBottom = 8 } }, "Confirm"),
                        ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginBottom = 20 } }, "Are you sure you want to proceed?"),
                        ce("View", { style = { flexDirection = "row", justifyContent = "flex-end", gap = 12 } },
                            ce(RN.Button, { title = "Cancel", color = T.textSecondary, onPress = function() closeAlert("Cancelled") end }),
                            ce(RN.Button, { title = "Confirm", color = "#E74C3C", onPress = function() closeAlert("Confirmed!") end })
                        )
                    )
                )
            )
        elseif type == "custom" then
            alertContent = ce(RN.Modal, { visible = true, transparent = true, onRequestClose = function() closeAlert() end },
                ce(Backdrop, {},
                    ce("View", { style = { width = 300, backgroundColor = T.surface, borderRadius = T.radius, overflow = "hidden" } },
                        ce("View", { style = { backgroundColor = "#E74C3C", padding = 16 } },
                            ce("Text", { style = { fontSize = 18, fontWeight = "bold", color = "#FFF" } }, "Warning!")
                        ),
                        ce("View", { style = { padding = 20 } },
                            ce("Text", { style = { fontSize = 14, color = T.textSecondary, marginBottom = 20 } }, "This action cannot be undone. Choose wisely."),
                            ce(RN.Button, { title = "Delete", color = "#E74C3C", onPress = function() closeAlert("Deleted!") end }),
                            ce("View", { style = { height = 8 } }),
                            ce(RN.Button, { title = "Archive", color = "#F39C12", onPress = function() closeAlert("Archived") end }),
                            ce("View", { style = { height = 8 } }),
                            ce(RN.Button, { title = "Cancel", color = T.textSecondary, onPress = function() closeAlert("Cancelled") end })
                        )
                    )
                )
            )
        end

        if alertContent then
            pushOverlay(alertContent)
        end
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Alert Dialogs" },
            ce(RN.Button, { title = "Info Alert (OK)", color = T.accent, onPress = function() showAlert("info") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Confirm Alert (OK / Cancel)", color = "#E67E22", onPress = function() showAlert("confirm") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Custom Alert (3 buttons)", color = "#E74C3C", onPress = function() showAlert("custom") end })
        ),
        ce(Section, { title = "Result" },
            ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, result ~= "" and result or "(tap an alert button)")
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. ActionSheetDemo — bottom slide-up option menu
-- ═══════════════════════════════════════════════════════════════════════════
local function ActionSheetDemo()
    local visible, setVisible = useState(false)
    local result, setResult = useState("")
    local slideY = useRef(Animated.Value(300)).current

    local function show()
        setVisible(true)
        slideY:setValue(300)
        Animated.timing(slideY, { toValue = 0, duration = 250 }).start()
    end

    local function hide(msg)
        Animated.timing(slideY, { toValue = 300, duration = 200 }).start(function()
            setVisible(false)
            if msg then setResult(msg) end
        end)
    end

    local options = {
        { label = "Share to Friends", icon = "S", color = T.accent },
        { label = "Copy Link", icon = "C", color = "#2ECC71" },
        { label = "Save to Gallery", icon = "G", color = "#9B59B6" },
        { label = "Report", icon = "!", color = "#E74C3C" },
    }

    local overlay = nil
    if visible then
        local optionRows = {}
        for _, opt in ipairs(options) do
            optionRows[#optionRows + 1] = ce(RN.Pressable, {
                key = opt.label,
                style = {
                    flexDirection = "row", alignItems = "center",
                    paddingVertical = 14, paddingHorizontal = 20,
                    borderBottomWidth = 1, borderColor = T.border,
                },
                onPress = function() hide(opt.label) end,
            },
                ce("View", {
                    style = { width = 32, height = 32, borderRadius = 16, backgroundColor = opt.color, justifyContent = "center", alignItems = "center", marginRight = 12 },
                }, ce("Text", { style = { fontSize = 14, color = "#FFF", fontWeight = "bold" } }, opt.icon)),
                ce("Text", { style = { fontSize = 16, color = T.textPrimary } }, opt.label)
            )
        end

        overlay = ce(RN.Modal, { visible = true, transparent = true },
            ce("View", { style = { flex = 1, justifyContent = "flex-end" } },
                ce(RN.Pressable, {
                    style = { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, backgroundColor = "rgba(0,0,0,0.4)" },
                    onPress = function() hide() end,
                }),
                ce(Animated.View, {
                    style = {
                        backgroundColor = T.surface,
                        borderTopLeftRadius = 20, borderTopRightRadius = 20,
                        paddingBottom = 20,
                        translateY = slideY,
                    },
                },
                    -- Handle bar
                    ce("View", { style = { alignItems = "center", paddingVertical = 10 } },
                        ce("View", { style = { width = 40, height = 4, borderRadius = 2, backgroundColor = T.border } })
                    ),
                    -- Title
                    ce("Text", {
                        style = { fontSize = 14, color = T.textSecondary, textAlign = "center", marginBottom = 8 },
                    }, "Choose an action"),
                    -- Options
                    ce("View", {}, optionRows),
                    -- Cancel
                    ce("View", { style = { paddingHorizontal = 20, paddingTop = 8 } },
                        ce(RN.Button, { title = "Cancel", color = T.textSecondary, onPress = function() hide("Cancelled") end })
                    )
                )
            )
        )
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Action Sheet (slide-up menu)" },
            ce(RN.Button, { title = "Show Action Sheet", color = T.accent, onPress = show })
        ),
        ce(Section, { title = "Result" },
            ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, result ~= "" and result or "(select an option)")
        ),
        overlay
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. ToastDemo — brief auto-dismiss notification
-- ═══════════════════════════════════════════════════════════════════════════
local function ToastDemo()
    local toasts, setToasts = useState({})
    local nextId = useRef(0)
    local opacities = useRef({})

    local function addToast(msg, color)
        nextId.current = nextId.current + 1
        local id = nextId.current
        local opacity = Animated.Value(0)
        opacities.current[id] = opacity
        setToasts(function(prev)
            local t = {}
            for _, v in ipairs(prev) do t[#t + 1] = v end
            t[#t + 1] = { id = id, msg = msg, color = color or T.accent }
            return t
        end)
        -- Fade in
        Animated.timing(opacity, { toValue = 1, duration = 200 }).start()
    end

    -- Auto-remove toasts after 2 seconds
    Hooks.useInterval(function()
        setToasts(function(prev)
            if #prev == 0 then return prev end
            -- Remove first toast
            local remaining = {}
            for i = 2, #prev do remaining[#remaining + 1] = prev[i] end
            return remaining
        end)
    end, #toasts > 0 and 2000 or false)

    -- Toast stack (shown at top)
    local toastViews = {}
    for _, t in ipairs(toasts) do
        local op = opacities.current[t.id]
        toastViews[#toastViews + 1] = ce(Animated.View, {
            key = t.id,
            style = {
                backgroundColor = t.color, borderRadius = T.radiusSmall,
                paddingHorizontal = 16, paddingVertical = 10, marginBottom = 6,
                opacity = op or 1,
            },
        }, ce("Text", { style = { fontSize = 14, color = "#FFF", fontWeight = "bold" } }, t.msg))
    end

    return ce(DemoPage, {},
        -- Toast container at top
        #toasts > 0 and ce("View", {
            style = { marginBottom = 12 },
        }, toastViews) or nil,
        ce(Section, { title = "Toast Notifications" },
            ce(RN.Button, { title = "Success Toast", color = "#2ECC71", onPress = function() addToast("Operation successful!", "#2ECC71") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Error Toast", color = "#E74C3C", onPress = function() addToast("Something went wrong!", "#E74C3C") end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Info Toast", color = T.accent, onPress = function() addToast("New message received", T.accent) end }),
            ce("View", { style = { height = 8 } }),
            ce(RN.Button, { title = "Warning Toast", color = "#F39C12", onPress = function() addToast("Low battery warning", "#F39C12") end })
        ),
        ce(Section, { title = "Info" },
            ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, "Toasts auto-dismiss after 2 seconds. Tap multiple buttons to stack them.")
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. PopoverDemo — contextual popup near trigger element
-- ═══════════════════════════════════════════════════════════════════════════
local function PopoverDemo()
    local activePopover, setActivePopover = useState(nil)

    local popovers = {
        { id = "top", label = "Popover Top", tip = "This appears above the button", y = -60 },
        { id = "info", label = "Info Tooltip", tip = "Helpful context information\nfor this element", y = -70 },
        { id = "menu", label = "Popup Menu", tip = nil, y = -120 },
    }

    local menuItems = { "Edit", "Duplicate", "Delete", "Share" }

    return ce(DemoPage, {},
        ce(Section, { title = "Popovers & Tooltips" },
            ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginBottom = 12 } },
                "Tap buttons to show contextual popups")
        ),
        -- Buttons with popovers
        ce("View", { style = { gap = 20, alignItems = "flex-start" } },
            -- Simple tooltip popover
            ce("View", {},
                activePopover == "top" and ce("View", {
                    style = {
                        backgroundColor = "#333", borderRadius = 8, padding = 10,
                        marginBottom = 4, maxWidth = 200,
                    },
                }, ce("Text", { style = { fontSize = 12, color = "#FFF" } }, "This appears above the button")) or nil,
                ce(RN.Button, {
                    title = "Popover Top",
                    color = T.accent,
                    onPress = function() setActivePopover(activePopover == "top" and nil or "top") end,
                })
            ),
            -- Info tooltip
            ce("View", {},
                activePopover == "info" and ce("View", {
                    style = {
                        backgroundColor = T.accent, borderRadius = 8, padding = 10,
                        marginBottom = 4, maxWidth = 220,
                    },
                },
                    ce("Text", { style = { fontSize = 12, color = "#FFF", fontWeight = "bold" } }, "Info"),
                    ce("Text", { style = { fontSize = 11, color = "#DDD", marginTop = 4 } }, "Helpful context information\nfor this element")
                ) or nil,
                ce(RN.Button, {
                    title = "Info Tooltip",
                    color = "#9B59B6",
                    onPress = function() setActivePopover(activePopover == "info" and nil or "info") end,
                })
            ),
            -- Menu popover
            ce("View", {},
                activePopover == "menu" and ce("View", {
                    style = {
                        backgroundColor = T.surface, borderRadius = T.radiusSmall,
                        borderWidth = 1, borderColor = T.border,
                        marginBottom = 4, minWidth = 140, overflow = "hidden",
                    },
                },
                    ce(RN.Pressable, { style = { paddingVertical = 10, paddingHorizontal = 16, borderBottomWidth = 1, borderColor = T.border }, onPress = function() setActivePopover(nil) end },
                        ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, "Edit")),
                    ce(RN.Pressable, { style = { paddingVertical = 10, paddingHorizontal = 16, borderBottomWidth = 1, borderColor = T.border }, onPress = function() setActivePopover(nil) end },
                        ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, "Duplicate")),
                    ce(RN.Pressable, { style = { paddingVertical = 10, paddingHorizontal = 16, borderBottomWidth = 1, borderColor = T.border }, onPress = function() setActivePopover(nil) end },
                        ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, "Share")),
                    ce(RN.Pressable, { style = { paddingVertical = 10, paddingHorizontal = 16 }, onPress = function() setActivePopover(nil) end },
                        ce("Text", { style = { fontSize = 14, color = "#E74C3C" } }, "Delete"))
                ) or nil,
                ce(RN.Button, {
                    title = "Popup Menu",
                    color = "#E67E22",
                    onPress = function() setActivePopover(activePopover == "menu" and nil or "menu") end,
                })
            )
        )
    )
end

return {
    { name = "Alert",       component = AlertDemo,       description = "OK, Confirm, Custom alert dialogs",  icon = "!" },
    { name = "ActionSheet", component = ActionSheetDemo, description = "Slide-up option menu from bottom",   icon = "A" },
    { name = "Toast",       component = ToastDemo,       description = "Auto-dismiss notifications, stacking", icon = "T" },
    { name = "Popover",     component = PopoverDemo,     description = "Tooltips, info popups, context menu", icon = "P" },
}
