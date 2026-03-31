--- OnboardingFlow — Elegant app onboarding with PagerSlideView.
-- Full-screen pages with animated illustrations, smooth page transitions.
-- Demonstrates PagerSlideView, Animated, composition, real-world UX pattern.

local RN = require("react_solar2d")
local ce, useState, useEffect, useRef = RN.createElement, RN.useState, RN.useEffect, RN.useRef
local Animated = RN.Animated
local StyleSheet = RN.StyleSheet

local W = display.contentWidth or 375
local H = display.contentHeight or 667

local PAGES = {
    {
        title = "Create",
        subtitle = "Build beautiful interfaces\nwith simple components",
        icon = "✦",
        accent = "#6366F1",
        bg = "#0F0A2E",
        shapes = { "circle", "square", "triangle" },
    },
    {
        title = "Animate",
        subtitle = "Bring your UI to life\nwith spring physics",
        icon = "◈",
        accent = "#EC4899",
        bg = "#1A0A20",
        shapes = { "wave", "pulse", "bounce" },
    },
    {
        title = "Touch",
        subtitle = "Multitouch gestures\nthat feel natural",
        icon = "✧",
        accent = "#14B8A6",
        bg = "#0A1A1A",
        shapes = { "drag", "pinch", "swipe" },
    },
    {
        title = "Ship",
        subtitle = "Deploy to iOS & Android\nwith Solar2D",
        icon = "◆",
        accent = "#F59E0B",
        bg = "#1A150A",
        shapes = { "rocket", "star", "check" },
    },
}

-- ─── Floating Shape ──────────────────────────────────────────────────────
local function FloatingShape(props)
    local yRef = useRef(nil)
    local opRef = useRef(nil)
    if not yRef.current then yRef.current = Animated.Value(0) end
    if not opRef.current then opRef.current = Animated.Value(0) end
    local y = yRef.current
    local opacity = opRef.current

    useEffect(function()
        Animated.timing(opacity, { toValue = props.targetOpacity or 0.15, duration = 800 }).start()
        Animated.loop(
            Animated.sequence({
                Animated.timing(y, { toValue = -(props.drift or 12), duration = props.speed or 2500 }),
                Animated.timing(y, { toValue = (props.drift or 12), duration = props.speed or 2500 }),
            })
        ).start()
    end, {})

    return ce(Animated.View, {
        style = {
            position = "absolute",
            left = props.x, top = props.y,
            width = props.size, height = props.size,
            borderRadius = props.round and props.size / 2 or 8,
            backgroundColor = props.color,
            opacity = opacity,
            transform = { { translateY = y } },
        },
    })
end

-- ─── Page Component ──────────────────────────────────────────────────────
local function OnboardingPage(props)
    local page = props.page
    local isLast = props.isLast

    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = page.bg,
            justifyContent = "center",
            alignItems = "center",
            padding = 32,
        },
    },
        -- Floating decoration shapes
        ce(FloatingShape, { x = W * 0.1, y = H * 0.15, size = 80, round = true, color = page.accent, drift = 15, speed = 3000, targetOpacity = 0.08 }),
        ce(FloatingShape, { x = W * 0.65, y = H * 0.12, size = 50, round = false, color = page.accent, drift = 10, speed = 2000, targetOpacity = 0.12 }),
        ce(FloatingShape, { x = W * 0.3, y = H * 0.7, size = 60, round = true, color = page.accent, drift = 18, speed = 3500, targetOpacity = 0.06 }),
        ce(FloatingShape, { x = W * 0.75, y = H * 0.6, size = 40, round = false, color = page.accent, drift = 8, speed = 2800, targetOpacity = 0.1 }),

        -- Icon
        ce("View", {
            style = {
                width = 120, height = 120, borderRadius = 60,
                backgroundColor = page.accent,
                justifyContent = "center", alignItems = "center",
                marginBottom = 40,
                borderWidth = 2,
                borderColor = "rgba(255,255,255,0.2)",
            },
        },
            ce("Text", { style = { fontSize = 48, color = "#FFF" } }, page.icon)
        ),
        -- Title
        ce("Text", {
            style = {
                color = "#FFF", fontSize = 36, fontWeight = "bold",
                textAlign = "center", marginBottom = 16,
                letterSpacing = 1,
            },
        }, page.title),
        -- Subtitle
        ce("Text", {
            style = {
                color = "rgba(255,255,255,0.5)",
                fontSize = 17, textAlign = "center",
                lineHeight = 24,
            },
        }, page.subtitle),

        -- CTA on last page
        isLast and ce("View", {
            style = {
                marginTop = 40,
                backgroundColor = page.accent,
                paddingHorizontal = 40, paddingVertical = 14,
                borderRadius = 30,
            },
            onPress = function() end,
        },
            ce("Text", {
                style = { color = "#FFF", fontSize = 17, fontWeight = "bold" },
            }, "Get Started")
        ) or nil
    )
end

-- ─── Main ────────────────────────────────────────────────────────────────
local function OnboardingFlow()
    local page, setPage = useState(1)

    local data = {}
    for i, p in ipairs(PAGES) do
        data[i] = p
    end

    return ce("View", { style = { flex = 1, backgroundColor = "#000" } },
        ce(RN.PagerSlideView, {
            data = data,
            renderPage = function(item, index)
                return ce(OnboardingPage, {
                    page = item,
                    isLast = index == #PAGES,
                })
            end,
            pageWidth = W,
            onPageChange = setPage,
            activeDotColor = PAGES[page] and PAGES[page].accent or "#FFF",
            dotColor = "rgba(255,255,255,0.2)",
            dotSize = 10,
            dotSpacing = 10,
            style = { flex = 1 },
        }),
        -- Skip button
        page < #PAGES and ce("View", {
            style = {
                position = "absolute", top = 44, right = 20,
                paddingHorizontal = 12, paddingVertical = 6,
                borderRadius = 12, backgroundColor = "rgba(255,255,255,0.1)",
            },
            onPress = function() setPage(#PAGES) end,
        },
            ce("Text", {
                style = { color = "rgba(255,255,255,0.4)", fontSize = 15 },
            }, "Skip")
        ) or nil
    )
end

return OnboardingFlow
