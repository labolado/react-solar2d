-- examples/kitchen_sink/ButtonScreens.lua
-- Demos: ConfirmButton, PushButton, SwitchButton
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("kitchen_sink.theme")
local RN = require("react_solar2d")

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. ConfirmButtonDemo — two-step confirmation
-- ═══════════════════════════════════════════════════════════════════════════
local function ConfirmButtonDemo()
    local log, setLog = useState({})

    local function addLog(msg)
        setLog(function(prev)
            local new = {}
            -- Keep last 5 entries
            local start = #prev > 4 and #prev - 3 or 1
            for i = start, #prev do new[#new + 1] = prev[i] end
            new[#new + 1] = msg
            return new
        end)
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
        ce("Text", { style = { color = T.textPrimary, fontSize = 16, marginBottom = 12 } },
            "Tap once to arm, tap again to confirm:"),
        -- Default style
        ce("View", { style = { flexDirection = "row", gap = 12, marginBottom = 16 } },
            ce(RN.ConfirmButton, {
                label = "Delete",
                confirmLabel = "Really Delete?",
                onConfirm = function() addLog("Deleted!") end,
                timeout = 3000,
            }),
            ce(RN.ConfirmButton, {
                label = "Reset All",
                confirmLabel = "Confirm Reset",
                onConfirm = function() addLog("Reset done!") end,
                style = { backgroundColor = "#9B59B6" },
            })
        ),
        -- Custom styled
        ce(RN.ConfirmButton, {
            label = "Parental Gate",
            confirmLabel = "Hold to confirm (3s)",
            onConfirm = function() addLog("Gate passed!") end,
            timeout = 5000,
            style = { backgroundColor = "#2C3E50", borderWidth = 2, borderColor = T.accent, alignSelf = "flex-start" },
            confirmStyle = { backgroundColor = "#E67E22", borderWidth = 2, borderColor = "#FFF", alignSelf = "flex-start" },
        }),
        -- Log
        ce("View", { style = { marginTop = 20, flex = 1 } },
            ce("Text", { style = { color = T.textSecondary, fontSize = 13, marginBottom = 4 } }, "Log:"),
            unpack((function()
                local items = {}
                for i, msg in ipairs(log) do
                    items[i] = ce("Text", {
                        key = "log" .. i,
                        style = { color = T.accent, fontSize = 14 },
                    }, "> " .. msg)
                end
                return items
            end)())
        ),
        ce("Text", { style = { color = T.textSecondary, fontSize = 12, textAlign = "center" } },
            "Auto-resets after timeout if not confirmed")
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. SwitchButtonDemo — multi-state cycling
-- ═══════════════════════════════════════════════════════════════════════════
local function SwitchButtonDemo()
    local tool, setTool = useState("pen")
    local speed, setSpeed = useState("normal")
    local color, setColor = useState("red")

    local TOOLS = {
        { label = "Pen",    value = "pen",    color = "#58A6FF" },
        { label = "Eraser", value = "eraser", color = "#E74C3C" },
        { label = "Fill",   value = "fill",   color = "#2ECC71" },
        { label = "Select", value = "select", color = "#F1C40F" },
    }
    local SPEEDS = {
        { label = "Slow",   value = "slow",   color = "#95A5A6" },
        { label = "Normal", value = "normal", color = "#58A6FF" },
        { label = "Fast",   value = "fast",   color = "#E67E22" },
        { label = "Turbo",  value = "turbo",  color = "#E74C3C" },
    }
    local COLORS = {
        { label = "Red",    value = "red",    color = "#E74C3C" },
        { label = "Green",  value = "green",  color = "#2ECC71" },
        { label = "Blue",   value = "blue",   color = "#3498DB" },
        { label = "Yellow", value = "yellow", color = "#F1C40F" },
        { label = "Purple", value = "purple", color = "#9B59B6" },
    }

    return ce("View", { style = { flex = 1, backgroundColor = T.bg, padding = T.pad } },
        ce("Text", { style = { color = T.textPrimary, fontSize = 16, marginBottom = 16 } },
            "Tap to cycle through states:"),
        -- Tool selector
        ce("View", { style = { flexDirection = "row", alignItems = "center", marginBottom = 16 } },
            ce("Text", { style = { color = T.textSecondary, width = 60 } }, "Tool:"),
            ce(RN.SwitchButton, {
                states = TOOLS,
                value = tool,
                onValueChange = setTool,
                style = { minWidth = 80 },
            })
        ),
        -- Speed selector
        ce("View", { style = { flexDirection = "row", alignItems = "center", marginBottom = 16 } },
            ce("Text", { style = { color = T.textSecondary, width = 60 } }, "Speed:"),
            ce(RN.SwitchButton, {
                states = SPEEDS,
                value = speed,
                onValueChange = setSpeed,
                style = { minWidth = 80 },
            })
        ),
        -- Color selector
        ce("View", { style = { flexDirection = "row", alignItems = "center", marginBottom = 16 } },
            ce("Text", { style = { color = T.textSecondary, width = 60 } }, "Color:"),
            ce(RN.SwitchButton, {
                states = COLORS,
                value = color,
                onValueChange = setColor,
                style = { minWidth = 80 },
            })
        ),
        -- Status
        ce("View", {
            style = {
                marginTop = 20,
                padding = 16,
                borderRadius = 12,
                backgroundColor = T.surface,
            },
        },
            ce("Text", { style = { color = T.textPrimary, fontSize = 14 } },
                "Current: tool=" .. tool .. " speed=" .. speed .. " color=" .. color)
        ),
        ce("Text", {
            style = { color = T.textSecondary, fontSize = 12, textAlign = "center", marginTop = 16 },
        }, "Each button cycles through its own state list")
    )
end

-- ─── Exports ───────────────────────────────────────────────────────────────
return {
    { name = "Confirm",  title = "Confirm Button",  icon = "✅", component = ConfirmButtonDemo },
    { name = "SwitchBtn", title = "Switch Button",  icon = "🔄", component = SwitchButtonDemo },
}
