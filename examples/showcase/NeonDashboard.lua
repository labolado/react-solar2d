--- NeonDashboard — Animated stats dashboard with glowing accents.
-- Auto-counting numbers, animated progress bars, pulsing status dots.
-- Demonstrates Animated.timing/loop/parallel, StyleSheet, composition.

local RN = require("react_solar2d")
local ce, useState, useEffect, useRef = RN.createElement, RN.useState, RN.useEffect, RN.useRef
local Animated = RN.Animated
local StyleSheet = RN.StyleSheet

local W = display.contentWidth or 375

-- ─── Animated Counter ────────────────────────────────────────────────────
local function AnimCounter(props)
    local valRef = useRef(nil)
    if not valRef.current then valRef.current = Animated.Value(0) end
    local val = valRef.current
    local displayed, setDisplayed = useState(0)

    useEffect(function()
        val:setValue(0)
        Animated.timing(val, {
            toValue = props.target,
            duration = props.duration or 1500,
        }).start()
        local t = timer.performWithDelay(30, function()
            local raw = val:getValue()
            if props.decimal then
                setDisplayed(string.format("%.1f", raw))
            else
                setDisplayed(tostring(math.floor(raw)))
            end
        end, 50)
        return function() timer.cancel(t) end
    end, {})

    return ce("Text", { style = props.style }, (props.prefix or "") .. displayed .. (props.suffix or ""))
end

-- ─── Glow Card ───────────────────────────────────────────────────────────
local function GlowCard(props)
    local accent = props.accent or "#58A6FF"
    local s = {
        backgroundColor = "#111827",
        borderRadius = 16,
        padding = 20,
        marginBottom = 12,
        borderWidth = 1,
        borderColor = accent,
    }
    if props.style then
        for k, v in pairs(props.style) do s[k] = v end
    end
    return ce("View", { style = s }, props.children)
end

-- ─── Progress Bar ────────────────────────────────────────────────────────
local function ProgressBar(props)
    local pct = props.value or 0
    local color = props.color or "#58A6FF"
    local animRef = useRef(nil)
    if not animRef.current then animRef.current = Animated.Value(0) end
    local animWidth = animRef.current

    useEffect(function()
        animWidth:setValue(0)
        Animated.timing(animWidth, { toValue = pct, duration = 1200 }).start()
    end, {})

    return ce("View", {
        style = { height = 6, borderRadius = 3, backgroundColor = "rgba(255,255,255,0.08)" },
    },
        ce(Animated.View, {
            style = {
                height = 6, borderRadius = 3,
                backgroundColor = color,
                width = Animated.multiply(animWidth, (W - 80) / 100),
            },
        })
    )
end

-- ─── Pulse Dot ───────────────────────────────────────────────────────────
local function PulseDot(props)
    local opRef = useRef(nil)
    local scRef = useRef(nil)
    if not opRef.current then opRef.current = Animated.Value(1) end
    if not scRef.current then scRef.current = Animated.Value(1) end
    local opacity = opRef.current
    local scale = scRef.current

    useEffect(function()
        Animated.loop(
            Animated.sequence({
                Animated.parallel({
                    Animated.timing(opacity, { toValue = 0.3, duration = 800 }),
                    Animated.timing(scale, { toValue = 1.4, duration = 800 }),
                }),
                Animated.parallel({
                    Animated.timing(opacity, { toValue = 1, duration = 800 }),
                    Animated.timing(scale, { toValue = 1, duration = 800 }),
                }),
            })
        ).start()
    end, {})

    return ce(Animated.View, {
        style = {
            width = 10, height = 10, borderRadius = 5,
            backgroundColor = props.color or "#2ECC71",
            opacity = opacity,
            transform = { { scale = scale } },
        },
    })
end

-- ─── Mini Spark Line ─────────────────────────────────────────────────────
local function SparkLine(props)
    local data = props.data or { 3, 7, 4, 8, 5, 9, 6, 8, 7, 10, 8, 12 }
    local color = props.color or "#58A6FF"
    local maxVal = 0
    for _, v in ipairs(data) do if v > maxVal then maxVal = v end end

    local barW = math.floor((W - 80 - (#data - 1) * 2) / #data)
    local bars = {}
    for i, v in ipairs(data) do
        local h = math.max(2, math.floor((v / maxVal) * 32))
        bars[i] = ce("View", {
            key = "bar" .. i,
            style = {
                width = barW, height = h,
                backgroundColor = color,
                borderRadius = 1,
                opacity = 0.4 + (v / maxVal) * 0.6,
            },
        })
    end

    return ce("View", {
        style = { flexDirection = "row", alignItems = "flex-end", gap = 2, height = 36 },
    }, unpack(bars))
end

-- ─── Main Dashboard ──────────────────────────────────────────────────────
local function NeonDashboard()
    return ce(RN.ScrollView, {
        style = { flex = 1, backgroundColor = "#0A0F1C" },
        contentContainerStyle = { padding = 16, paddingTop = 40, paddingBottom = 40 },
    },
        -- Title
        ce("View", { style = { marginBottom = 24 } },
            ce("Text", {
                style = {
                    color = "#FFF", fontSize = 26, fontWeight = "bold",
                },
            }, "DASHBOARD"),
            ce("View", {
                style = { flexDirection = "row", alignItems = "center", gap = 8, marginTop = 6 },
            },
                ce(PulseDot, { color = "#2ECC71" }),
                ce("Text", { style = { color = "#2ECC71", fontSize = 13 } }, "All systems operational")
            )
        ),

        -- Top stats row
        ce("View", { style = { flexDirection = "row", gap = 12, marginBottom = 12 } },
            ce(GlowCard, { accent = "#58A6FF", style = { flex = 1 } },
                ce("Text", { style = { color = "rgba(255,255,255,0.5)", fontSize = 11, marginBottom = 4 } }, "USERS"),
                ce(AnimCounter, {
                    target = 12847,
                    style = { color = "#58A6FF", fontSize = 28, fontWeight = "bold" },
                }),
                ce("Text", { style = { color = "#2ECC71", fontSize = 12, marginTop = 4 } }, "+12.5%")
            ),
            ce(GlowCard, { accent = "#F59E0B", style = { flex = 1 } },
                ce("Text", { style = { color = "rgba(255,255,255,0.5)", fontSize = 11, marginBottom = 4 } }, "REVENUE"),
                ce(AnimCounter, {
                    target = 48.6, decimal = true, prefix = "$", suffix = "K",
                    style = { color = "#F59E0B", fontSize = 28, fontWeight = "bold" },
                }),
                ce("Text", { style = { color = "#2ECC71", fontSize = 12, marginTop = 4 } }, "+8.3%")
            )
        ),

        -- Server status card
        ce(GlowCard, { accent = "#2ECC71" },
            ce("View", {
                style = { flexDirection = "row", justifyContent = "space-between", alignItems = "center", marginBottom = 12 },
            },
                ce("Text", { style = { color = "#FFF", fontSize = 16, fontWeight = "bold" } }, "Server Load"),
                ce("View", {
                    style = { flexDirection = "row", alignItems = "center", gap = 6 },
                },
                    ce(PulseDot, { color = "#2ECC71" }),
                    ce("Text", { style = { color = "#2ECC71", fontSize = 13 } }, "Healthy")
                )
            ),
            -- CPU
            ce("View", { style = { marginBottom = 10 } },
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", marginBottom = 4 } },
                    ce("Text", { style = { color = "rgba(255,255,255,0.6)", fontSize = 12 } }, "CPU"),
                    ce(AnimCounter, {
                        target = 42,
                        suffix = "%",
                        style = { color = "#58A6FF", fontSize = 12 },
                    })
                ),
                ce(ProgressBar, { value = 42, color = "#58A6FF" })
            ),
            -- Memory
            ce("View", { style = { marginBottom = 10 } },
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", marginBottom = 4 } },
                    ce("Text", { style = { color = "rgba(255,255,255,0.6)", fontSize = 12 } }, "Memory"),
                    ce(AnimCounter, {
                        target = 67,
                        suffix = "%",
                        style = { color = "#F59E0B", fontSize = 12 },
                    })
                ),
                ce(ProgressBar, { value = 67, color = "#F59E0B" })
            ),
            -- Disk
            ce("View", {},
                ce("View", { style = { flexDirection = "row", justifyContent = "space-between", marginBottom = 4 } },
                    ce("Text", { style = { color = "rgba(255,255,255,0.6)", fontSize = 12 } }, "Disk"),
                    ce(AnimCounter, {
                        target = 23,
                        suffix = "%",
                        style = { color = "#2ECC71", fontSize = 12 },
                    })
                ),
                ce(ProgressBar, { value = 23, color = "#2ECC71" })
            )
        ),

        -- Activity chart
        ce(GlowCard, { accent = "#A78BFA" },
            ce("Text", {
                style = { color = "#FFF", fontSize = 16, fontWeight = "bold", marginBottom = 12 },
            }, "Weekly Activity"),
            ce(SparkLine, { color = "#A78BFA", data = { 45, 62, 38, 71, 56, 84, 65, 78, 92, 68, 85, 95 } }),
            ce("View", {
                style = { flexDirection = "row", justifyContent = "space-between", marginTop = 8 },
            },
                ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 10 } }, "Mon"),
                ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 10 } }, "Wed"),
                ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 10 } }, "Fri"),
                ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 10 } }, "Sun")
            )
        ),

        -- Recent events
        ce(GlowCard, { accent = "#EC4899" },
            ce("Text", {
                style = { color = "#FFF", fontSize = 16, fontWeight = "bold", marginBottom = 12 },
            }, "Recent Events"),
            ce("View", { style = { gap = 10 } },
                ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 10 } },
                    ce(PulseDot, { color = "#2ECC71" }),
                    ce("Text", { style = { color = "rgba(255,255,255,0.7)", fontSize = 13, flex = 1 } }, "Deploy #847 succeeded"),
                    ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 11 } }, "2m ago")
                ),
                ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 10 } },
                    ce(PulseDot, { color = "#F59E0B" }),
                    ce("Text", { style = { color = "rgba(255,255,255,0.7)", fontSize = 13, flex = 1 } }, "High memory alert — resolved"),
                    ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 11 } }, "15m ago")
                ),
                ce("View", { style = { flexDirection = "row", alignItems = "center", gap = 10 } },
                    ce(PulseDot, { color = "#58A6FF" }),
                    ce("Text", { style = { color = "rgba(255,255,255,0.7)", fontSize = 13, flex = 1 } }, "New user milestone: 12K"),
                    ce("Text", { style = { color = "rgba(255,255,255,0.3)", fontSize = 11 } }, "1h ago")
                )
            )
        ),

        -- Footer
        ce("Text", {
            style = {
                color = "rgba(255,255,255,0.15)", fontSize = 11,
                textAlign = "center", marginTop = 16,
            },
        }, "React-Solar2D • NeonDashboard Showcase")
    )
end

return NeonDashboard
