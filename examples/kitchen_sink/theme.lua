-- examples/kitchen_sink/theme.lua
local T = {}

T.bg = "#0D1117"
T.surface = "#161B22"
T.border = "#30363D"
T.textPrimary = "#E6EDF3"
T.textSecondary = "#8B949E"
T.accent = "#58A6FF"
T.tabActive = "#FF6600"
T.tabInactive = "#666688"

T.pad = 16
T.gap = 12
T.radius = 12
T.radiusSmall = 8

-- Shared helpers used by all *Screens.lua files
local React = require("react")
local ce = React.createElement

function T.Section(props)
    return ce("View", { style = { marginBottom = T.gap } },
        ce("Text", { style = { fontSize = 14, color = T.accent, fontWeight = "bold", marginBottom = 8 } }, props.title),
        ce("View", {}, props.children)
    )
end

function T.DemoPage(props)
    local W = display.contentWidth - 24  -- subtract KitchenSink paddingHorizontal
    return ce("ScrollView", {
        style = { flex = 1, backgroundColor = T.bg },
    }, ce("View", {
        style = { padding = T.pad, paddingBottom = 70, width = W },
    }, props.children))
end

return T
