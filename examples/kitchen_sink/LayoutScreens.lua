-- examples/kitchen_sink/LayoutScreens.lua
-- Demos: Flex patterns, Responsive, SafeArea, Dimensions
local React = require("react")
local ce = React.createElement
local useState = React.useState
local T = require("examples.kitchen_sink.theme")
local RN = require("react_solar2d")
local Section = T.Section
local DemoPage = T.DemoPage

local W = display and display.contentWidth or 320
local H = display and display.contentHeight or 480

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. FlexDemo — flexbox layout patterns
-- ═══════════════════════════════════════════════════════════════════════════
local function FlexDemo()
    local colors = { "#E74C3C", "#3498DB", "#2ECC71", "#F39C12", "#9B59B6" }

    local function Box(props)
        return ce("View", {
            style = {
                width = props.w or 50, height = props.h or 50,
                backgroundColor = props.color or T.accent,
                borderRadius = 6,
                justifyContent = "center", alignItems = "center",
            },
        }, props.label and ce("Text", { style = { fontSize = 10, color = "#FFF" } }, props.label) or nil)
    end

    return ce(DemoPage, {},
        ce(Section, { title = "flexDirection = row" },
            ce("View", { style = { flexDirection = "row", gap = 8 } },
                Box({ color = colors[1], label = "1" }),
                Box({ color = colors[2], label = "2" }),
                Box({ color = colors[3], label = "3" })
            )
        ),
        ce(Section, { title = "flexDirection = column" },
            ce("View", { style = { flexDirection = "column", gap = 8 } },
                Box({ color = colors[1], w = 120, h = 30, label = "Row 1" }),
                Box({ color = colors[2], w = 120, h = 30, label = "Row 2" }),
                Box({ color = colors[3], w = 120, h = 30, label = "Row 3" })
            )
        ),
        ce(Section, { title = "justifyContent variations" },
            -- space-between
            ce("Text", { style = { fontSize = 11, color = T.textSecondary, marginBottom = 4 } }, "space-between:"),
            ce("View", { style = { flexDirection = "row", justifyContent = "space-between", backgroundColor = T.surface, padding = 8, borderRadius = 8, marginBottom = 8 } },
                Box({ color = colors[1], w = 40, h = 40 }),
                Box({ color = colors[2], w = 40, h = 40 }),
                Box({ color = colors[3], w = 40, h = 40 })
            ),
            -- center
            ce("Text", { style = { fontSize = 11, color = T.textSecondary, marginBottom = 4 } }, "center:"),
            ce("View", { style = { flexDirection = "row", justifyContent = "center", gap = 8, backgroundColor = T.surface, padding = 8, borderRadius = 8, marginBottom = 8 } },
                Box({ color = colors[4], w = 40, h = 40 }),
                Box({ color = colors[5], w = 40, h = 40 })
            ),
            -- flex-end
            ce("Text", { style = { fontSize = 11, color = T.textSecondary, marginBottom = 4 } }, "flex-end:"),
            ce("View", { style = { flexDirection = "row", justifyContent = "flex-end", gap = 8, backgroundColor = T.surface, padding = 8, borderRadius = 8 } },
                Box({ color = colors[1], w = 40, h = 40 }),
                Box({ color = colors[3], w = 40, h = 40 })
            )
        ),
        ce(Section, { title = "alignItems variations" },
            ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 8, backgroundColor = T.surface, padding = 8, borderRadius = 8, marginBottom = 8 } },
                Box({ color = colors[1], w = 40, h = 60 }),
                Box({ color = colors[2], w = 40, h = 30 }),
                Box({ color = colors[3], w = 40, h = 50 }),
                ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "center")
            ),
            ce("View", { style = { flexDirection = "row", alignItems = "flex-end", gap = 8, backgroundColor = T.surface, padding = 8, borderRadius = 8 } },
                Box({ color = colors[4], w = 40, h = 60 }),
                Box({ color = colors[5], w = 40, h = 30 }),
                Box({ color = colors[1], w = 40, h = 50 }),
                ce("Text", { style = { fontSize = 11, color = T.textSecondary } }, "flex-end")
            )
        ),
        ce(Section, { title = "flex: proportional sizing" },
            ce("View", { style = { flexDirection = "row", gap = 4, height = 40 } },
                ce("View", { style = { flex = 1, backgroundColor = colors[1], borderRadius = 6, justifyContent = "center", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "flex:1")),
                ce("View", { style = { flex = 2, backgroundColor = colors[2], borderRadius = 6, justifyContent = "center", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "flex:2")),
                ce("View", { style = { flex = 1, backgroundColor = colors[3], borderRadius = 6, justifyContent = "center", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "flex:1"))
            )
        ),
        ce(Section, { title = "Nested flex layout (Holy Grail)" },
            ce("View", { style = { height = 160, borderRadius = 8, overflow = "hidden", borderWidth = 1, borderColor = T.border } },
                -- Header
                ce("View", { style = { height = 30, backgroundColor = colors[1], justifyContent = "center", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 11, color = "#FFF" } }, "Header")),
                -- Middle row
                ce("View", { style = { flex = 1, flexDirection = "row" } },
                    ce("View", { style = { width = 60, backgroundColor = colors[4], justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "Nav")),
                    ce("View", { style = { flex = 1, backgroundColor = T.surface, justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "Main Content")),
                    ce("View", { style = { width = 50, backgroundColor = colors[5], justifyContent = "center", alignItems = "center" } },
                        ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "Side"))
                ),
                -- Footer
                ce("View", { style = { height = 26, backgroundColor = colors[3], justifyContent = "center", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "Footer"))
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. ResponsiveDemo — adapt to screen size
-- ═══════════════════════════════════════════════════════════════════════════
local function ResponsiveDemo()
    local SCALE = W / 1536
    local function s(v) return math.floor(v * SCALE + 0.5) end

    local isWide = W > 600
    local cols = isWide and 3 or 2
    local cardW = math.floor((W - T.pad * 2 - T.gap * (cols - 1)) / cols)

    local cards = {}
    for i = 1, 6 do
        local colors = { "#E74C3C", "#3498DB", "#2ECC71", "#F39C12", "#9B59B6", "#1ABC9C" }
        cards[#cards + 1] = ce("View", {
            key = i,
            style = {
                width = cardW, height = cardW * 0.75,
                backgroundColor = colors[i],
                borderRadius = T.radius,
                justifyContent = "center", alignItems = "center",
            },
        }, ce("Text", { style = { fontSize = 16, color = "#FFF", fontWeight = "bold" } }, "Card " .. i))
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Screen Info" },
            ce("View", { style = { backgroundColor = T.surface, borderRadius = T.radius, padding = T.pad } },
                ce("Text", { style = { fontSize = 13, color = T.textPrimary } }, "Width: " .. W .. "px"),
                ce("Text", { style = { fontSize = 13, color = T.textPrimary } }, "Height: " .. H .. "px"),
                ce("Text", { style = { fontSize = 13, color = T.textPrimary } }, "Scale: " .. string.format("%.3f", SCALE)),
                ce("Text", { style = { fontSize = 13, color = T.textPrimary } }, "Layout: " .. (isWide and "Wide (3 cols)" or "Narrow (2 cols)")),
                ce("Text", { style = { fontSize = 13, color = T.textPrimary } }, "Card width = " .. cardW .. "px")
            )
        ),
        ce(Section, { title = "Responsive Grid (" .. cols .. " columns)" },
            ce("View", {
                style = { flexDirection = "row", flexWrap = "wrap", gap = T.gap },
            }, cards)
        ),
        ce(Section, { title = "Scaled Text (base 1536px)" },
            ce("Text", { style = { fontSize = s(48), color = T.textPrimary, fontWeight = "bold" } }, "s(48) = " .. s(48) .. "px"),
            ce("Text", { style = { fontSize = s(36), color = T.accent } }, "s(36) = " .. s(36) .. "px"),
            ce("Text", { style = { fontSize = s(24), color = T.textSecondary } }, "s(24) = " .. s(24) .. "px")
        ),
        ce(Section, { title = "Percentage-like widths" },
            ce("View", { style = { gap = 6 } },
                ce("View", { style = { width = W * 0.9, height = 24, backgroundColor = "#3498DB", borderRadius = 4, justifyContent = "center", paddingHorizontal = 8 } },
                    ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "90%")),
                ce("View", { style = { width = W * 0.6, height = 24, backgroundColor = "#2ECC71", borderRadius = 4, justifyContent = "center", paddingHorizontal = 8 } },
                    ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "60%")),
                ce("View", { style = { width = W * 0.3, height = 24, backgroundColor = "#E74C3C", borderRadius = 4, justifyContent = "center", paddingHorizontal = 8 } },
                    ce("Text", { style = { fontSize = 10, color = "#FFF" } }, "30%"))
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. SafeAreaDemo — safe area insets visualization (manual calculation)
-- ═══════════════════════════════════════════════════════════════════════════
local function SafeAreaDemo()
    local insets = RN.getSafeAreaInsets and RN.getSafeAreaInsets() or { top = 0, bottom = 0, left = 0, right = 0 }

    local safeTop = 0
    local safeBottom = 0
    if display then
        if display.safeScreenOriginY and display.screenOriginY then
            safeTop = math.abs(display.safeScreenOriginY - display.screenOriginY)
        end
        if display.safeActualContentHeight and display.actualContentHeight then
            safeBottom = display.actualContentHeight - display.safeActualContentHeight - safeTop
            if safeBottom < 0 then safeBottom = 0 end
        end
    end

    return ce(DemoPage, {},
        ce(Section, { title = "Safe Area Insets (Manual)" },
            ce("View", { style = { backgroundColor = T.surface, borderRadius = T.radius, padding = T.pad } },
                ce("Text", { style = { fontSize = 14, color = T.textPrimary, marginBottom = 4 } }, "Top: " .. safeTop .. "px"),
                ce("Text", { style = { fontSize = 14, color = T.textPrimary, marginBottom = 4 } }, "Bottom: " .. safeBottom .. "px"),
                ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginTop = 8 } },
                    "Safe area avoids notch, home indicator, and status bar.")
            )
        ),
        ce(Section, { title = "Visual Representation" },
            ce("View", {
                style = {
                    height = 300, borderWidth = 2, borderColor = "#E74C3C",
                    borderRadius = T.radius, overflow = "hidden", backgroundColor = "#1a1a2e",
                },
            },
                -- Top unsafe zone
                ce("View", { style = { height = math.max(safeTop * 0.5, 20), backgroundColor = "rgba(231,76,60,0.3)", justifyContent = "center", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 10, color = "#E74C3C" } }, "Unsafe (notch/status)")
                ),
                -- Safe zone
                ce("View", { style = { flex = 1, backgroundColor = "rgba(46,204,113,0.15)", justifyContent = "center", alignItems = "center", borderTopWidth = 1, borderBottomWidth = 1, borderColor = "#2ECC71" } },
                    ce("Text", { style = { fontSize = 16, color = "#2ECC71", fontWeight = "bold" } }, "Safe Content Area"),
                    ce("Text", { style = { fontSize = 12, color = T.textSecondary, marginTop = 4 } }, "Place UI here")
                ),
                -- Bottom unsafe zone
                ce("View", { style = { height = math.max(safeBottom * 0.5, 20), backgroundColor = "rgba(231,76,60,0.3)", justifyContent = "center", alignItems = "center" } },
                    ce("Text", { style = { fontSize = 10, color = "#E74C3C" } }, "Unsafe (home indicator)")
                )
            )
        ),
        ce(Section, { title = "Display Properties" },
            ce("View", { style = { backgroundColor = T.surface, borderRadius = T.radius, padding = T.pad } },
                ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "contentWidth: " .. (display and display.contentWidth or "N/A")),
                ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "contentHeight: " .. (display and display.contentHeight or "N/A")),
                ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "actualContentWidth: " .. (display and display.actualContentWidth or "N/A")),
                ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "actualContentHeight: " .. (display and display.actualContentHeight or "N/A")),
                ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "pixelWidth: " .. (display and display.pixelWidth or "N/A")),
                ce("Text", { style = { fontSize = 12, color = T.textPrimary } }, "pixelHeight: " .. (display and display.pixelHeight or "N/A"))
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 3b. SafeAreaViewDemo — Using SafeAreaView component
-- ═══════════════════════════════════════════════════════════════════════════
local function SafeAreaViewDemo()
    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("ScrollView", { style = { flex = 1 } },
            ce("View", { style = { padding = T.pad } },
                ce(Section, { title = "SafeAreaView Component" },
                    ce("Text", { 
                        style = { fontSize = 14, color = T.textSecondary, marginBottom = 16 } 
                    }, "SafeAreaView automatically adds padding for notches, status bars, and home indicators."),
                    
                    -- Demo of SafeAreaView with colored content
                    ce(RN.SafeAreaView, {
                        style = {
                            backgroundColor = T.accent,
                            borderRadius = T.radius,
                            minHeight = 200,
                        }
                    },
                        ce("View", { 
                            style = { 
                                padding = T.pad,
                                alignItems = "center",
                                justifyContent = "center",
                            } 
                        },
                            ce("Text", { 
                                style = { 
                                    fontSize = 18, 
                                    color = "#FFF", 
                                    fontWeight = "bold",
                                    marginBottom = 8
                                } 
                            }, "Safe Area Container"),
                            ce("Text", { 
                                style = { 
                                    fontSize = 14, 
                                    color = "rgba(255,255,255,0.8)",
                                    textAlign = "center"
                                } 
                            }, "Content is within safe area insets"),
                            ce("Text", { 
                                style = { 
                                    fontSize = 12, 
                                    color = "rgba(255,255,255,0.6)",
                                    marginTop = 16
                                } 
                            }, "Padding auto-adjusts for:")
                        )
                    )
                ),
                
                ce(Section, { title = "Features" },
                    ce("View", { style = { gap = 12 } },
                        ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 12 } },
                            ce("View", { style = { width = 8, height = 8, borderRadius = 4, backgroundColor = "#E74C3C" } }),
                            ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, "Notch (top inset)")
                        ),
                        ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 12 } },
                            ce("View", { style = { width = 8, height = 8, borderRadius = 4, backgroundColor = "#3498DB" } }),
                            ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, "Status bar (top inset)")
                        ),
                        ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 12 } },
                            ce("View", { style = { width = 8, height = 8, borderRadius = 4, backgroundColor = "#F39C12" } }),
                            ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, "Home indicator (bottom inset)")
                        ),
                        ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 12 } },
                            ce("View", { style = { width = 8, height = 8, borderRadius = 4, backgroundColor = "#9B59B6" } }),
                            ce("Text", { style = { fontSize = 14, color = T.textPrimary } }, "Dynamic Island (top inset)")
                        )
                    )
                ),
                
                ce(Section, { title = "With Custom Padding" },
                    ce(RN.SafeAreaView, {
                        style = {
                            backgroundColor = "#2ECC71",
                            borderRadius = T.radius,
                            padding = 20,  -- Additional custom padding
                        }
                    },
                        ce("Text", { 
                            style = { 
                                fontSize = 14, 
                                color = "#FFF",
                                textAlign = "center"
                            } 
                        }, "SafeAreaView + custom padding = safe + comfortable")
                    )
                )
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. SpacingDemo — margin, padding, border visualization
-- ═══════════════════════════════════════════════════════════════════════════
local function SpacingDemo()
    return ce(DemoPage, {},
        ce(Section, { title = "Box Model: margin → border → padding → content" },
            -- Margin layer (outer)
            ce("View", { style = { backgroundColor = "rgba(243,156,18,0.2)", padding = 16, borderRadius = T.radius } },
                ce("Text", { style = { fontSize = 10, color = "#F39C12", marginBottom = 4 } }, "margin: 16"),
                -- Border layer
                ce("View", { style = { borderWidth = 3, borderColor = "#3498DB", borderRadius = 8, padding = 12 } },
                    ce("Text", { style = { fontSize = 10, color = "#3498DB", marginBottom = 4 } }, "border: 3"),
                    -- Padding layer
                    ce("View", { style = { backgroundColor = "rgba(46,204,113,0.2)", padding = 12, borderRadius = 4 } },
                        ce("Text", { style = { fontSize = 10, color = "#2ECC71", marginBottom = 4 } }, "padding = 12"),
                        -- Content
                        ce("View", { style = { backgroundColor = "#E74C3C", padding = 8, borderRadius = 4, alignItems = "center" } },
                            ce("Text", { style = { fontSize = 12, color = "#FFF", fontWeight = "bold" } }, "Content")
                        )
                    )
                )
            )
        ),
        ce(Section, { title = "Gap spacing (flexbox)" },
            ce("View", { style = { flexDirection = "row", gap = 4, marginBottom = 8 } },
                ce("View", { style = { flex = 1, height = 30, backgroundColor = "#E74C3C", borderRadius = 4 } }),
                ce("View", { style = { flex = 1, height = 30, backgroundColor = "#3498DB", borderRadius = 4 } }),
                ce("View", { style = { flex = 1, height = 30, backgroundColor = "#2ECC71", borderRadius = 4 } })
            ),
            ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginBottom = 8 } }, "gap = 4"),
            ce("View", { style = { flexDirection = "row", gap = 16, marginBottom = 8 } },
                ce("View", { style = { flex = 1, height = 30, backgroundColor = "#E74C3C", borderRadius = 4 } }),
                ce("View", { style = { flex = 1, height = 30, backgroundColor = "#3498DB", borderRadius = 4 } }),
                ce("View", { style = { flex = 1, height = 30, backgroundColor = "#2ECC71", borderRadius = 4 } })
            ),
            ce("Text", { style = { fontSize = 10, color = T.textSecondary } }, "gap = 16")
        ),
        ce(Section, { title = "Border radius variants" },
            ce("View", { style = { flexDirection = "row", gap = 12, flexWrap = "wrap" } },
                ce("View", { style = { width = 60, height = 60, backgroundColor = T.accent, borderRadius = 0 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = T.accent, borderRadius = 8 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = T.accent, borderRadius = 16 } }),
                ce("View", { style = { width = 60, height = 60, backgroundColor = T.accent, borderRadius = 30 } })
            ),
            ce("Text", { style = { fontSize = 10, color = T.textSecondary, marginTop = 4 } }, "radius: 0, 8, 16, 30")
        )
    )
end

return {
    { name = "Flexbox",    component = FlexDemo,       description = "Row, column, justify, align, flex",     icon = "F" },
    { name = "Responsive", component = ResponsiveDemo,  description = "Grid, scaling, screen adaptation",     icon = "R" },
    { name = "SafeArea",   component = SafeAreaDemo,     description = "Insets, display properties, safe zone", icon = "S" },
    { name = "SafeAreaView", component = SafeAreaViewDemo, description = "SafeAreaView component usage", icon = "V" },
    { name = "Spacing",    component = SpacingDemo,      description = "Box model, margin, padding, gap",      icon = "B" },
}
