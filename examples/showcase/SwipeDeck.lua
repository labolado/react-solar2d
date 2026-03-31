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
local CARD_H = CARD_W * 1.3
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

local styles = StyleSheet.create({
    container = { flex = 1, backgroundColor = "#0A0A1A" },
    header = {
        paddingTop = 40, paddingBottom = 12,
        alignItems = "center",
    },
    title = { color = "#FFF", fontSize = 22, fontWeight = "bold", letterSpacing = 1 },
    subtitle = { color = "rgba(255,255,255,0.4)", fontSize = 13, marginTop = 4 },
    cardArea = {
        flex = 1, alignItems = "center", justifyContent = "center",
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
        flexDirection = "row", justifyContent = "center",
        gap = 32, paddingBottom = 36, paddingTop = 16,
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

    -- Active card with drag
    local function ActiveCard()
        return ce(RN.DraggableView, {
            key = "card_" .. index,
            onDrag = function(info)
                if info.dx > 30 then
                    setSwipeDir("right")
                elseif info.dx < -30 then
                    setSwipeDir("left")
                else
                    setSwipeDir(nil)
                end
            end,
            onDragEnd = function(info)
                if info.dx > 80 then
                    advance("right")
                elseif info.dx < -80 then
                    advance("left")
                else
                    setSwipeDir(nil)
                end
            end,
            snapBack = true,
            style = styles.card,
        },
            -- Background color via inline
            ce("View", {
                style = {
                    position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
                    borderRadius = 24, backgroundColor = current.color,
                },
            }),
            -- Like/Nope badge
            swipeDir == "right" and ce("View", {
                style = {
                    position = "absolute", top = 24, left = 24,
                    paddingHorizontal = 14, paddingVertical = 6,
                    borderRadius = 20, borderWidth = 3, borderColor = "#2ECC71",
                    transform = { { rotate = -15 } },
                },
            },
                ce("Text", { style = { color = "#2ECC71", fontSize = 20, fontWeight = "bold" } }, "LIKE")
            ) or nil,
            swipeDir == "left" and ce("View", {
                style = {
                    position = "absolute", top = 24, right = 24,
                    paddingHorizontal = 14, paddingVertical = 6,
                    borderRadius = 20, borderWidth = 3, borderColor = "#E74C3C",
                    transform = { { rotate = 15 } },
                },
            },
                ce("Text", { style = { color = "#E74C3C", fontSize = 20, fontWeight = "bold" } }, "NOPE")
            ) or nil,
            -- Content
            ce("Text", { style = styles.cardEmoji }, current.emoji),
            ce("Text", { style = styles.cardName }, current.name),
            ce("Text", { style = styles.cardAge }, current.age .. " years old"),
            ce("Text", { style = styles.cardBio }, current.bio)
        )
    end

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
            ce(ActiveCard, {})
        ),
        -- Footer buttons
        ce("View", { style = styles.footer },
            ce("View", {
                style = {
                    width = 56, height = 56, borderRadius = 28,
                    justifyContent = "center", alignItems = "center",
                    borderWidth = 2, borderColor = "#E74C3C",
                },
                onPress = function() advance("left") end,
            },
                ce("Text", { style = { fontSize = 24 } }, "✗")
            ),
            ce("View", {
                style = {
                    width = 56, height = 56, borderRadius = 28,
                    justifyContent = "center", alignItems = "center",
                    borderWidth = 2, borderColor = "#58A6FF",
                },
                onPress = function() setIndex(function(i) return i + 1 end) end,
            },
                ce("Text", { style = { fontSize = 24 } }, "↻")
            ),
            ce("View", {
                style = {
                    width = 56, height = 56, borderRadius = 28,
                    justifyContent = "center", alignItems = "center",
                    borderWidth = 2, borderColor = "#2ECC71",
                },
                onPress = function() advance("right") end,
            },
                ce("Text", { style = { fontSize = 24 } }, "♥")
            )
        )
    )
end

return SwipeDeck
