--- SwipeDeck — Tinder-style swipeable card stack.
-- Cards fan out with rotation on drag, fly off-screen on release.
-- Demonstrates DraggableView, Animated.spring, dynamic card cycling.

local RN = require("react_solar2d")
local ce, useState, useRef, useCallback = RN.createElement, RN.useState, RN.useRef, RN.useCallback
local Animated = RN.Animated
local StyleSheet = RN.StyleSheet

local W = display.contentWidth or 375
local H = display.contentHeight or 667
local CARD_W = W * 0.82
-- Card height: fit within available space (screen - nav bar - tab bar - header - footer)
local CARD_H = math.min(CARD_W * 1.3, H * 0.38)
local SWIPE_OUT = W * 1.5

local PROFILES = {
    { name = "Luna",    age = 24, bio = "Photographer & traveler",  color = "#FF6B6B", emoji = "📸" },
    { name = "Atlas",   age = 28, bio = "Coffee addict, night owl", color = "#4ECDC4", emoji = "☕" },
    { name = "Nova",    age = 22, bio = "Music producer & dreamer", color = "#45B7D1", emoji = "🎵" },
    { name = "Sage",    age = 26, bio = "Plant parent, book lover", color = "#96CEB4", emoji = "🌿" },
    { name = "Ember",   age = 25, bio = "Chef & flavor explorer",   color = "#FFEAA7", emoji = "🍳" },
    { name = "Storm",   age = 27, bio = "Surfer chasing waves",     color = "#DDA0DD", emoji = "🌊" },
    { name = "Pixel",   age = 23, bio = "Game dev & pixel artist",  color = "#98D8C8", emoji = "🎮" },
    { name = "Blaze",   age = 29, bio = "Fitness coach & dancer",   color = "#F7DC6F", emoji = "💃" },
}

-- Compute layout manually to avoid flex height constraint issues in Stack nav
local NAV_H = 88       -- Stack nav header height (approx)
local TAB_H = 100      -- Tab bar height (approx)
local AVAIL_H = H - NAV_H - TAB_H
local HEADER_H = 100
local FOOTER_H = 88
local CARD_AREA_H = AVAIL_H - HEADER_H - FOOTER_H - 40  -- 40 for stats+margins
-- Clamp card to fit
CARD_H = math.min(CARD_H, CARD_AREA_H)

local styles = StyleSheet.create({
    container = { flex = 1, backgroundColor = "#0A0A1A", alignItems = "center" },
    header = {
        paddingTop = 20, paddingBottom = 8,
        alignItems = "center",
    },
    title = { color = "#FFF", fontSize = 22, fontWeight = "bold", letterSpacing = 1 },
    subtitle = { color = "rgba(255,255,255,0.4)", fontSize = 13, marginTop = 4 },
    cardArea = {
        height = CARD_AREA_H,
        alignItems = "center", justifyContent = "center",
    },
    card = {
        width = CARD_W, height = CARD_H,
        borderRadius = 24,
        padding = 28,
        justifyContent = "flex-end",
        -- Shadow effect via border
        borderWidth = 1,
        borderColor = "rgba(255,255,255,0.08)",
    },
    cardEmoji = { fontSize = 64, textAlign = "center", marginBottom = 20 },
    cardName = { color = "#FFF", fontSize = 32, fontWeight = "bold" },
    cardAge = { color = "rgba(255,255,255,0.7)", fontSize = 18, marginTop = 2 },
    cardBio = { color = "rgba(255,255,255,0.5)", fontSize = 15, marginTop = 8 },
    badge = {
        position = "absolute", top = 24, right = 24,
        paddingHorizontal = 16, paddingVertical = 6,
        borderRadius = 20, borderWidth = 2,
    },
    badgeText = { fontSize = 18, fontWeight = "bold" },
    footer = {
        flexDirection = "row", justifyContent = "center", alignItems = "center",
        gap = 32, marginTop = 24,
    },
    footerBtn = {
        width = 56, height = 56, borderRadius = 28,
        justifyContent = "center", alignItems = "center",
        borderWidth = 2,
    },
    footerIcon = { fontSize = 24 },
    stats = {
        flexDirection = "row", justifyContent = "center", gap = 24,
        paddingBottom = 8,
    },
    statText = { color = "rgba(255,255,255,0.3)", fontSize = 12 },
})

local function SwipeDeck()
    local index, setIndex = useState(1)
    local liked, setLiked = useState(0)
    local passed, setPassed = useState(0)
    local swipeDir, setSwipeDir = useState(nil) -- "left" / "right" / nil

    local current = PROFILES[((index - 1) % #PROFILES) + 1]
    local next1 = PROFILES[(index % #PROFILES) + 1]
    local next2 = PROFILES[((index + 1) % #PROFILES) + 1]

    local function advance(direction)
        if direction == "right" then
            setLiked(function(n) return n + 1 end)
        else
            setPassed(function(n) return n + 1 end)
        end
        setSwipeDir(nil)
        setIndex(function(i) return i + 1 end)
    end

    -- Back card (peek)
    local function BackCard(props)
        local p = props.profile
        local depth = props.depth or 1
        local scale = 1 - depth * 0.06
        local offsetY = depth * 10
        return ce("View", {
            style = {
                position = "absolute",
                width = CARD_W, height = CARD_H,
                borderRadius = 24,
                backgroundColor = p.color,
                opacity = 0.3 + (1 - depth * 0.3),
                transform = {
                    { scale = scale },
                    { translateY = offsetY },
                },
                borderWidth = 1,
                borderColor = "rgba(255,255,255,0.05)",
            },
        })
    end

    -- Active card (inline, not a sub-component — sub-components defined inside
    -- the render function get a new function reference each render, causing
    -- the reconciler to unmount/remount and destroy active touch state)

    return ce("View", { style = styles.container },
        -- Header
        ce("View", { style = styles.header },
            ce("Text", { style = styles.title }, "SwipeDeck"),
            ce("Text", { style = styles.subtitle }, "drag cards left or right")
        ),
        -- Stats
        ce("View", { style = styles.stats },
            ce("Text", { style = styles.statText }, "💚 " .. liked .. " liked"),
            ce("Text", { style = styles.statText }, "❌ " .. passed .. " passed"),
            ce("Text", { style = styles.statText }, "#" .. index .. " / ∞")
        ),
        -- Card stack
        ce("View", { style = styles.cardArea },
            ce(BackCard, { profile = next2, depth = 2 }),
            ce(BackCard, { profile = next1, depth = 1 }),
            ce(RN.DraggableView, {
                key = "card_" .. index,
                onDragEnd = function(info)
                    if info.dx > 80 then
                        advance("right")
                    elseif info.dx < -80 then
                        advance("left")
                    end
                end,
                snapBack = true,
                style = {
                    width = CARD_W, height = CARD_H,
                    borderRadius = 24, padding = 28,
                    justifyContent = "flex-end",
                    backgroundColor = current.color,
                },
            },
                ce("Text", { style = styles.cardEmoji }, current.emoji),
                ce("Text", { style = styles.cardName }, current.name),
                ce("Text", { style = styles.cardAge }, current.age .. " years old"),
                ce("Text", { style = styles.cardBio }, current.bio)
            ),
            -- Action buttons below card
            ce("View", { style = { flexDirection = "row", justifyContent = "center", alignItems = "center", gap = 40, marginTop = 24, width = W } },
            ce("View", {
                style = {
                    width = 60, height = 60, borderRadius = 30,
                    justifyContent = "center", alignItems = "center",
                    backgroundColor = "rgba(231,76,60,0.3)", borderWidth = 2, borderColor = "#E74C3C",
                },
                onPress = function() advance("left") end,
            },
                ce("Text", { style = { fontSize = 26, color = "#E74C3C" } }, "✗")
            ),
            ce("View", {
                style = {
                    width = 60, height = 60, borderRadius = 30,
                    justifyContent = "center", alignItems = "center",
                    backgroundColor = "rgba(88,166,255,0.3)", borderWidth = 2, borderColor = "#58A6FF",
                },
                onPress = function() setIndex(function(i) return i + 1 end) end,
            },
                ce("Text", { style = { fontSize = 26, color = "#58A6FF" } }, "↻")
            ),
            ce("View", {
                style = {
                    width = 60, height = 60, borderRadius = 30,
                    justifyContent = "center", alignItems = "center",
                    backgroundColor = "rgba(46,204,113,0.3)", borderWidth = 2, borderColor = "#2ECC71",
                },
                onPress = function() advance("right") end,
            },
                ce("Text", { style = { fontSize = 26, color = "#2ECC71" } }, "♥")
            )
        )  -- close button row
        )  -- close cardArea
    )  -- close container
end

return SwipeDeck
