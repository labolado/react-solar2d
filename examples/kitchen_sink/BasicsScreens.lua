-- examples/kitchen_sink/BasicsScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local LinearGradient = require("lib.linear-gradient")
local LinearGradient = require("lib.linear-gradient")
local Section = T.Section
local DemoPage = T.DemoPage

-- 1. ViewDemo
local function ViewDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "Flex Direction" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce("View", { style = { width = 60, height = 60, backgroundColor = "#E74C3C", borderRadius = 4 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "#2ECC71", borderRadius = 4 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "#3498DB", borderRadius = 4 } })
            )
        ),
        ce(Section, { title = "Border Radius" },
            ce("View", { style = { flexDirection = "row", gap = 12, alignItems = "center" } },
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 0 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 16 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = T.accent, borderRadius = 25 } })
            )
        ),
        ce(Section, { title = "Opacity" },
            ce("View", { style = { flexDirection = "row", gap = 12 } },
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 1.0, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 0.7, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 0.4, borderRadius = 8 } }),
                ce("View", { style = { width = 50, height = 50, backgroundColor = "#FF6600", opacity = 0.1, borderRadius = 8 } })
            )
        ),
        ce(Section, { title = "Background Colors" },
            ce("View", { style = { flexDirection = "row", flexWrap = "wrap", gap = 8 } },
                ce("View", { style = { width = 44, height = 44, backgroundColor = "tomato", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "dodgerblue", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "gold", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "teal", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "coral", borderRadius = 8 } }),
                ce("View", { style = { width = 44, height = 44, backgroundColor = "indigo", borderRadius = 8 } })
            )
        )
    )
end

-- 7. LinearGradientDemo
local function LinearGradientDemo()
    local function GradientCard(cfg)
        return ce(LinearGradient, {
            colors = cfg.colors,
            start = cfg.start,
            ["end"] = cfg["end"],
            style = {
                width = 300,
                height = cfg.height or 90,
                borderRadius = T.radius,
                marginBottom = 12,
            }
        },
            ce("View", {
                style = {
                    flex = 1,
                    padding = 18,
                    justifyContent = "center",
                }
            },
                ce("Text", { style = { fontSize = 16, color = "#FFFFFF", fontWeight = "bold" } }, cfg.title),
                cfg.subtitle and ce("Text", { style = { fontSize = 12, color = "#FFFFFF", marginTop = 6 } }, cfg.subtitle) or nil
            )
        )
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Basic gradients" },
            GradientCard({
                title = "Top → Bottom",
                subtitle = "colors = ['#FF6B6B', '#FFD93D']",
                colors = { "#FF6B6B", "#FFD93D" },
                start = { x = 0.5, y = 0 },
                ["end"] = { x = 0.5, y = 1 },
            }),
            GradientCard({
                title = "Left → Right",
                subtitle = "start={0,0.5} end={1,0.5}",
                colors = { "#4FACFE", "#00F2FE" },
                start = { x = 0, y = 0.5 },
                ["end"] = { x = 1, y = 0.5 },
            }),
            GradientCard({
                title = "Diagonal",
                subtitle = "Three colors",
                colors = { "#845EC2", "#FF9671", "#FFC75F" },
                start = { x = 0, y = 0 },
                ["end"] = { x = 1, y = 1 },
            })
        ),
        ce(Section, { title = "Gradient badge row" },
            ce("View", { style = { flexDirection = "row", gap = 12, flexWrap = "wrap" } },
                ce(LinearGradient, {
                    colors = { "#00B09B", "#96C93D" },
                    style = { paddingHorizontal = 16, paddingVertical = 10, borderRadius = 999 },
                }, ce("Text", { style = { color = "#FFFFFF", fontSize = 12, fontWeight = "bold" } }, "Online")),
                ce(LinearGradient, {
                    colors = { "#FF512F", "#DD2476" },
                    style = { paddingHorizontal = 16, paddingVertical = 10, borderRadius = 999 },
                }, ce("Text", { style = { color = "#FFFFFF", fontSize = 12, fontWeight = "bold" } }, "Live")),
                ce(LinearGradient, {
                    colors = { "#1FA2FF", "#12D8FA", "#A6FFCB" },
                    style = { paddingHorizontal = 16, paddingVertical = 10, borderRadius = 999 },
                }, ce("Text", { style = { color = "#FFFFFF", fontSize = 12, fontWeight = "bold" } }, "Pro"))
            )
        ),
        ce(Section, { title = "Background overlay" },
            ce(LinearGradient, {
                colors = { "#000000AA", "#00000000" },
                start = { x = 0.5, y = 1 },
                ["end"] = { x = 0.5, y = 0 },
                style = { width = 300, height = 120, borderRadius = T.radius, justifyContent = "flex-end" },
            },
                ce("View", { style = { padding = 16 } },
                    ce("Text", { style = { fontSize = 14, color = "#FFFFFF", fontWeight = "bold" } }, "Overlay title"),
                    ce("Text", { style = { fontSize = 12, color = "#FFFFFF" } }, "Use gradients for readable overlays")
                )
            )
        )
    )
end

-- 2. TextDemo
local function TextDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "Font Sizes" },
            ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "fontSize: 12"),
            ce("Text", { style = { fontSize = 18, color = T.textPrimary } }, "fontSize: 18"),
            ce("Text", { style = { fontSize = 24, color = T.textPrimary } }, "fontSize: 24"),
            ce("Text", { style = { fontSize = 36, color = T.textPrimary } }, "fontSize: 36")
        ),
        ce(Section, { title = "Font Weight" },
            ce("Text", { style = { fontSize = 18, color = T.textPrimary } }, "Normal weight"),
            ce("Text", { style = { fontSize = 18, color = T.textPrimary, fontWeight = "bold" } }, "Bold weight")
        ),
        ce(Section, { title = "Colors" },
            ce("Text", { style = { fontSize = 16, color = "tomato" } }, "Tomato"),
            ce("Text", { style = { fontSize = 16, color = "dodgerblue" } }, "DodgerBlue"),
            ce("Text", { style = { fontSize = 16, color = "gold" } }, "Gold"),
            ce("Text", { style = { fontSize = 16, color = "#00C853" } }, "#00C853 Green")
        ),
        ce(Section, { title = "Number of Lines (truncation)" },
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary },
                numberOfLines = 1,
            }, "This is a very long text that should be truncated to a single line because numberOfLines is set to 1."),
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginTop = 8 },
                numberOfLines = 2,
            }, "This is another long text that can span up to two lines before being truncated. It has quite a lot of content to demonstrate the two-line limit clearly.")
        ),
        ce(Section, { title = "Nested Text" },
            ce("Text", { style = { fontSize = 14, color = T.textSecondary } },
                "Note: nested inline Text (bold/color within paragraph) is not yet supported in react-solar2d. Each Text is a separate display.newText object.")
        )
    )
end

-- 3. ImageDemo
local function ImageDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "resizeMode Comparison" },
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginBottom = 8 },
            }, "Image uses local file paths in Solar2D. resizeMode: cover / contain / stretch"),
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                ce("View", { style = { alignItems = "center" } },
                    ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 4 } }),
                    ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginTop = 4 } }, "cover")
                ),
                ce("View", { style = { alignItems = "center" } },
                    ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 4, opacity = 0.7 } }),
                    ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginTop = 4 } }, "contain")
                ),
                ce("View", { style = { alignItems = "center" } },
                    ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 4, opacity = 0.4 } }),
                    ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginTop = 4 } }, "stretch")
                )
            )
        ),
        ce(Section, { title = "Different Sizes" },
            ce("View", { style = { flexDirection = "row", gap = 12, alignItems = "flex-end" } },
                ce("View", { style = { width = 40, height = 40, backgroundColor = T.accent, borderRadius = 8 } }),
                ce("View", { style = { width = 80, height = 60, backgroundColor = T.accent, borderRadius = 8 } }),
                ce("View", { style = { width = 120, height = 80, backgroundColor = T.accent, borderRadius = T.radius } })
            )
        ),
        ce(Section, { title = "Border Radius on Images" },
            ce("View", { style = { flexDirection = "row", gap = 12 } },
                ce("View", { style = { width = 60, height = 60, backgroundColor = "coral", borderRadius = 0 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "coral", borderRadius = 12 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = "coral", borderRadius = 30 } })
            )
        )
    )
end

-- 4. ButtonDemo
local function ButtonDemo()
    local count, setCount = useState(0)
    return ce(DemoPage, {},
        ce(Section, { title = "Button Colors" },
            ce("View", { style = { gap = 8 } },
                ce(RN.Button, { title = "Default", onPress = function() end }),
                ce(RN.Button, { title = "Red", color = "#E74C3C", onPress = function() end }),
                ce(RN.Button, { title = "Blue", color = "#2979FF", onPress = function() end }),
                ce(RN.Button, { title = "Green", color = "#00C853", onPress = function() end })
            )
        ),
        ce(Section, { title = "onPress Counter" },
            ce("Text", {
                style = { fontSize = 24, color = T.textPrimary, marginBottom = 8 },
            }, "Count: " .. count),
            ce(RN.Button, {
                title = "Tap me (+1)",
                color = T.accent,
                onPress = function() setCount(function(c) return c + 1 end) end,
            })
        )
    )
end

-- 5. PressableDemo
local function PressableDemo()
    local pressMsg, setPressMsg = useState("Tap or long-press below")
    return ce(DemoPage, {},
        ce(Section, { title = "Press Feedback" },
            ce("Text", {
                style = { fontSize = 16, color = T.textPrimary, marginBottom = 12 },
            }, pressMsg),
            ce(RN.Pressable, {
                onPress = function() setPressMsg("Tapped!") end,
                style = {
                    backgroundColor = T.surface, padding = T.pad,
                    borderRadius = T.radiusSmall, borderWidth = 1, borderColor = T.border,
                    marginBottom = T.gap,
                },
            }, ce("Text", { style = { color = T.textPrimary, fontSize = 16 } }, "Tap me")),
            ce(RN.Pressable, {
                onLongPress = function() setPressMsg("Long pressed!") end,
                style = {
                    backgroundColor = T.surface, padding = T.pad,
                    borderRadius = T.radiusSmall, borderWidth = 1, borderColor = T.accent,
                },
            }, ce("Text", { style = { color = T.accent, fontSize = 16 } }, "Long press me"))
        ),
        ce(Section, { title = "Custom Styled (card-like)" },
            ce(RN.Pressable, {
                onPress = function() setPressMsg("Card pressed!") end,
                style = {
                    flexDirection = "row", alignItems = "center",
                    backgroundColor = T.surface, padding = T.pad,
                    borderRadius = T.radius, borderWidth = 1, borderColor = T.border,
                },
            },
                ce("View", { style = { width = 40, height = 40, borderRadius = 20, backgroundColor = T.accent, justifyContent = "center", alignItems = "center", marginRight = 12 } },
                    ce("Text", { style = { fontSize = 18, color = "#FFF" } }, "P")
                ),
                ce("View", { style = { flex = 1 } },
                    ce("Text", { style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold" } }, "Card Pressable"),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary } }, "Tap this card-like layout")
                )
            )
        )
    )
end

-- 6. TouchableOpacityDemo
local function TouchableOpacityDemo()
    local tapped, setTapped = useState("")
    return ce(DemoPage, {},
        ce(Section, { title = "Active Opacity Comparison" },
            ce("Text", {
                style = { fontSize = 14, color = T.textSecondary, marginBottom = 12 },
            }, tapped ~= "" and ("Tapped: " .. tapped) or "Tap the buttons below"),
            ce("View", { style = { flexDirection = "row", gap = 12 } },
                ce(RN.TouchableOpacity, {
                    activeOpacity = 0.2,
                    onPress = function() setTapped("opacity 0.2") end,
                    style = { flex = 1, backgroundColor = T.accent, padding = 16, borderRadius = T.radiusSmall, alignItems = "center" },
                }, ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, "0.2")),
                ce(RN.TouchableOpacity, {
                    activeOpacity = 0.5,
                    onPress = function() setTapped("opacity 0.5") end,
                    style = { flex = 1, backgroundColor = T.accent, padding = 16, borderRadius = T.radiusSmall, alignItems = "center" },
                }, ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, "0.5")),
                ce(RN.TouchableOpacity, {
                    activeOpacity = 0.8,
                    onPress = function() setTapped("opacity 0.8") end,
                    style = { flex = 1, backgroundColor = T.accent, padding = 16, borderRadius = T.radiusSmall, alignItems = "center" },
                }, ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, "0.8"))
            )
        )
    )
end

return {
    { name = "View",      component = ViewDemo,      description = "Layout, radius, opacity, colors", icon = "V" },
    { name = "Text",      component = TextDemo,      description = "Sizes, weight, color, truncation", icon = "T" },
    { name = "Image",     component = ImageDemo,     description = "Sizes, radius, placeholder",       icon = "I" },
    { name = "Button",    component = ButtonDemo,    description = "Colors, onPress counter",           icon = "B" },
    { name = "Pressable", component = PressableDemo, description = "Press and long-press feedback",     icon = "P" },
    { name = "Touchable", component = TouchableOpacityDemo, description = "ActiveOpacity comparison",   icon = "O" },
    { name = "LinearGradient", component = LinearGradientDemo, description = "react-native-linear-gradient", icon = "G" },
}
