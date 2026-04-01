--- MusicPlayer — Sleek music player UI with animated waveform.
-- Album art, progress slider, animated equalizer bars.
-- Demonstrates Animated.loop, Slider, composition, dark UI design.

local RN = require("react_solar2d")
local ce, useState, useEffect, useRef = RN.createElement, RN.useState, RN.useEffect, RN.useRef
local React = require("react")
local StyleSheet = RN.StyleSheet

local W = display.contentWidth or 375
local ART_SIZE = W * 0.65

-- ─── Equalizer ───────────────────────────────────────────────────────────
-- Uses a single enterFrame listener to animate all bars imperatively.
-- Much faster than 12 individual Animated.loop chains.
local function Equalizer(props)
    local playing = props.playing
    local color = props.color or "#1DB954"
    local containerRef = useRef(nil)
    local barsRef = useRef(nil)

    local configs = {
        { maxH = 20, speed = 300 },
        { maxH = 32, speed = 250 },
        { maxH = 16, speed = 350 },
        { maxH = 28, speed = 200 },
        { maxH = 22, speed = 320 },
        { maxH = 36, speed = 180 },
        { maxH = 18, speed = 280 },
        { maxH = 30, speed = 220 },
        { maxH = 14, speed = 340 },
        { maxH = 26, speed = 260 },
        { maxH = 20, speed = 300 },
        { maxH = 34, speed = 190 },
    }
    local minH = 3
    local barW = 4
    local gap = 3
    local totalH = 40

    local onRef = React.useCallback(function(instance)
        containerRef.current = instance
    end, {})

    useEffect(function()
        local container = containerRef.current
        if not container then return end

        -- Create bar rects imperatively (plain rects, no borderRadius for performance)
        local bars = {}
        for i, cfg in ipairs(configs) do
            local x = (i - 1) * (barW + gap)
            local rect = display.newRect(container, x, totalH - minH, barW, minH)
            rect.anchorX, rect.anchorY = 0, 1  -- anchor bottom-left
            local r, g, b = 29/255, 185/255, 84/255  -- #1DB954
            rect:setFillColor(r, g, b)
            bars[i] = {
                rect = rect,
                maxH = cfg.maxH,
                speed = cfg.speed,
                phase = math.random() * math.pi * 2,  -- random start phase
            }
        end
        barsRef.current = bars

        -- Single enterFrame drives all bars via sine wave
        local function onFrame()
            local t = system.getTimer() / 1000  -- seconds
            for i, bar in ipairs(bars) do
                if playing then
                    -- Sine oscillation: speed controls frequency
                    local freq = 1000 / bar.speed  -- higher speed value = slower frequency
                    local wave = (math.sin(t * freq * math.pi * 2 + bar.phase) + 1) / 2
                    local h = minH + wave * (bar.maxH - minH)
                    bar.rect.height = h
                    bar.rect.alpha = 1
                else
                    bar.rect.height = minH
                    bar.rect.alpha = 0.3
                end
            end
        end
        Runtime:addEventListener("enterFrame", onFrame)

        return function()
            Runtime:removeEventListener("enterFrame", onFrame)
            for _, bar in ipairs(bars) do
                bar.rect:removeSelf()
            end
            barsRef.current = nil
        end
    end, { playing })

    -- Total width: 12 bars * 4px + 11 gaps * 3px = 81px
    local totalW = #configs * barW + (#configs - 1) * gap
    return ce("View", {
        ref = onRef,
        style = { width = totalW, height = totalH },
    })
end

-- ─── Progress Bar ────────────────────────────────────────────────────────
local function TrackProgress(props)
    local pct = props.progress or 0
    local barW = W - 64

    return ce("View", { style = { paddingHorizontal = 32, marginTop = 20 } },
        ce("View", {
            style = {
                height = 3, borderRadius = 2,
                backgroundColor = "rgba(255,255,255,0.1)",
            },
        },
            ce("View", {
                style = {
                    height = 3, borderRadius = 2,
                    backgroundColor = "#1DB954",
                    width = barW * pct,
                },
            })
        ),
        ce("View", {
            style = { flexDirection = "row", justifyContent = "space-between", marginTop = 6 },
        },
            ce("Text", { style = { color = "rgba(255,255,255,0.4)", fontSize = 11 } }, props.elapsed or "0:00"),
            ce("Text", { style = { color = "rgba(255,255,255,0.4)", fontSize = 11 } }, props.total or "3:42")
        )
    )
end

-- ─── Main Player ─────────────────────────────────────────────────────────
local function MusicPlayer()
    local playing, setPlaying = useState(true)
    local elapsed, setElapsed = useState(0)
    local totalSecs = 222 -- 3:42
    local liked, setLiked = useState(false)

    -- Simulate playback
    useEffect(function()
        if not playing then return end
        local t = timer.performWithDelay(1000, function()
            setElapsed(function(e)
                if e >= totalSecs then return 0 end
                return e + 1
            end)
        end, 0)
        return function() timer.cancel(t) end
    end, { playing })

    local function fmtTime(s)
        return string.format("%d:%02d", math.floor(s / 60), s % 60)
    end

    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = "#0D0D0D",
            paddingTop = 50,
        },
    },
        -- Album art with rotating border
        ce("View", {
            style = {
                alignItems = "center",
                marginBottom = 30,
            },
        },
            -- Outer glow ring
            ce("View", {
                style = {
                    width = ART_SIZE + 8, height = ART_SIZE + 8,
                    borderRadius = (ART_SIZE + 8) / 2,
                    borderWidth = 2,
                    borderColor = "#1DB954",
                    justifyContent = "center", alignItems = "center",
                    opacity = playing and 0.6 or 0.2,
                },
            },
                -- Album art (simulated with gradient colors)
                ce("View", {
                    style = {
                        width = ART_SIZE, height = ART_SIZE,
                        borderRadius = ART_SIZE / 2,
                        backgroundColor = "#1a1a2e",
                        justifyContent = "center", alignItems = "center",
                        borderWidth = 1,
                        borderColor = "rgba(255,255,255,0.1)",
                    },
                },
                    -- Inner design
                    ce("View", {
                        style = {
                            width = ART_SIZE * 0.6, height = ART_SIZE * 0.6,
                            borderRadius = ART_SIZE * 0.3,
                            backgroundColor = "#16213e",
                            justifyContent = "center", alignItems = "center",
                            borderWidth = 1,
                            borderColor = "rgba(29,185,84,0.3)",
                        },
                    },
                        ce("View", {
                            style = {
                                width = ART_SIZE * 0.25, height = ART_SIZE * 0.25,
                                borderRadius = ART_SIZE * 0.125,
                                backgroundColor = "#0f3460",
                                borderWidth = 2,
                                borderColor = "rgba(29,185,84,0.5)",
                            },
                        })
                    )
                )
            )
        ),

        -- Song info
        ce("View", { style = { alignItems = "center", marginBottom = 8 } },
            ce("Text", {
                style = { color = "#FFF", fontSize = 22, fontWeight = "bold" },
            }, "Midnight Circuit"),
            ce("Text", {
                style = { color = "rgba(255,255,255,0.5)", fontSize = 15, marginTop = 4 },
            }, "Neon Collective")
        ),

        -- Equalizer
        ce("View", { style = { alignItems = "center", marginVertical = 12 } },
            ce(Equalizer, { playing = playing, color = "#1DB954" })
        ),

        -- Progress
        ce(TrackProgress, {
            progress = elapsed / totalSecs,
            elapsed = fmtTime(elapsed),
            total = fmtTime(totalSecs),
        }),

        -- Controls
        ce("View", {
            style = {
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "center",
                gap = 36,
                marginTop = 28,
            },
        },
            -- Shuffle
            ce("View", {
                style = { padding = 10 },
                onPress = function() end,
            },
                ce("Text", { style = { color = "rgba(255,255,255,0.4)", fontSize = 20 } }, "⇄")
            ),
            -- Prev
            ce("View", {
                style = { padding = 10 },
                onPress = function() setElapsed(0) end,
            },
                ce("Text", { style = { color = "#FFF", fontSize = 28 } }, "⏮")
            ),
            -- Play/Pause
            ce("View", {
                style = {
                    width = 64, height = 64, borderRadius = 32,
                    backgroundColor = "#1DB954",
                    justifyContent = "center", alignItems = "center",
                },
                onPress = function() setPlaying(function(p) return not p end) end,
            },
                ce("Text", {
                    style = { color = "#000", fontSize = 28, fontWeight = "bold" },
                }, playing and "⏸" or "▶")
            ),
            -- Next
            ce("View", {
                style = { padding = 10 },
                onPress = function() setElapsed(0) end,
            },
                ce("Text", { style = { color = "#FFF", fontSize = 28 } }, "⏭")
            ),
            -- Like
            ce("View", {
                style = { padding = 10 },
                onPress = function() setLiked(function(l) return not l end) end,
            },
                ce("Text", {
                    style = { color = liked and "#1DB954" or "rgba(255,255,255,0.4)", fontSize = 20 },
                }, liked and "♥" or "♡")
            )
        ),

        -- Footer
        ce("Text", {
            style = {
                color = "rgba(255,255,255,0.1)", fontSize = 11,
                textAlign = "center", marginTop = 30,
            },
        }, "React-Solar2D • MusicPlayer Showcase")
    )
end

return MusicPlayer
