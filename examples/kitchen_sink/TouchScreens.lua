-- examples/kitchen_sink/TouchScreens.lua
-- Demos: Draggable, Pinch, Drawing, Stickers, Gamepad
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useRef = React.useRef
local useCallback = React.useCallback
local T = require("kitchen_sink.theme")
local RN = require("react_solar2d")

local W = display and display.contentWidth or 375
local H = display and display.contentHeight or 667

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. DraggableDemo — five coloured squares, optional grid snap
-- ═══════════════════════════════════════════════════════════════════════════
local function DraggableDemo()
    local snapEnabled, setSnapEnabled = useState(false)
    local GRID = 40

    local COLORS = { "#E74C3C", "#3498DB", "#2ECC71", "#F1C40F", "#9B59B6" }
    local LABELS = { "A", "B", "C", "D", "E" }
    local SIZE = 64

    local tiles = {}
    for i, color in ipairs(COLORS) do
        tiles[#tiles + 1] = ce(RN.DraggableView, {
            key = "tile" .. i,
            snapToGrid = snapEnabled and GRID or nil,
            style = {
                position = "absolute",
                left = 20 + (i - 1) * (SIZE + 8),
                top = 60,
                width = SIZE,
                height = SIZE,
                borderRadius = 12,
                backgroundColor = color,
                justifyContent = "center",
                alignItems = "center",
            },
        },
            ce("Text", { style = { color = "#FFF", fontWeight = "bold", fontSize = 20 } }, LABELS[i])
        )
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        -- Canvas area
        ce("View", {
            style = {
                flex = 1,
                borderBottomWidth = 1,
                borderColor = T.border,
            },
        }, unpack(tiles)),
        -- Controls
        ce("View", {
            style = {
                padding = T.pad,
                flexDirection = "row",
                alignItems = "center",
                backgroundColor = T.surface,
            },
        },
            ce("Text", { style = { color = T.textPrimary, flex = 1 } }, "Grid snap (" .. GRID .. "px)"),
            ce(RN.Switch, {
                value = snapEnabled,
                onValueChange = setSnapEnabled,
                trackColor = { true_color = T.accent, false_color = T.border },
            })
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. PinchDemo — pinch-zoom + rotate an image, shows live readout
-- ═══════════════════════════════════════════════════════════════════════════
local function PinchDemo()
    local scale, setScale = useState(1)
    local rot, setRot = useState(0)

    local IMG_URL = "https://picsum.photos/seed/pinch/300/300"
    local SIZE = 180

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        -- Info bar
        ce("View", {
            style = {
                padding = T.pad,
                backgroundColor = T.surface,
                borderBottomWidth = 1, borderColor = T.border,
                flexDirection = "row", justifyContent = "space-around",
            },
        },
            ce("Text", { style = { color = T.textSecondary } },
                string.format("Scale: %.2f", scale)),
            ce("Text", { style = { color = T.textSecondary } },
                string.format("Rotation: %.0f°", rot))
        ),
        -- Interaction area
        ce("View", {
            style = {
                flex = 1,
                justifyContent = "center",
                alignItems = "center",
            },
        },
            ce(RN.PinchableView, {
                minScale = 0.2,
                maxScale = 4,
                onTransform = function(info)
                    setScale(math.floor(info.scale * 100) / 100)
                    setRot(math.floor(info.rotation))
                end,
                style = {
                    width = SIZE,
                    height = SIZE,
                    borderRadius = 16,
                    overflow = "hidden",
                },
            },
                ce(RN.Image, {
                    source = { uri = IMG_URL },
                    style = { width = SIZE, height = SIZE },
                    resizeMode = "cover",
                })
            )
        ),
        ce("Text", {
            style = {
                padding = T.pad,
                color = T.textSecondary,
                textAlign = "center",
                fontSize = 13,
            },
        }, "1 finger to pan • 2 fingers to pinch and rotate")
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. DrawingDemo — multi-finger painting with colour/brush picker
-- ═══════════════════════════════════════════════════════════════════════════
local function DrawingDemo()
    local brushColor, setBrushColor = useState("#58A6FF")
    local brushSize, setBrushSize = useState(4)
    local canvasRef = useRef(nil)

    local PALETTE = { "#E74C3C", "#E67E22", "#F1C40F", "#2ECC71", "#58A6FF", "#9B59B6", "#FFFFFF", "#000000" }
    local SIZES   = { { label = "S", size = 2 }, { label = "M", size = 6 }, { label = "L", size = 12 } }

    local CANVAS_H = H * 0.55

    local colorDots = {}
    for _, c in ipairs(PALETTE) do
        local active = c == brushColor
        colorDots[#colorDots + 1] = ce(RN.Pressable, {
            key = c,
            onPress = function() setBrushColor(c) end,
            style = {
                width = 28, height = 28, borderRadius = 14,
                backgroundColor = c,
                marginRight = 6,
                borderWidth = active and 3 or 1,
                borderColor = active and "#FFF" or "rgba(255,255,255,0.3)",
            },
        })
    end

    local sizeBtns = {}
    for _, s in ipairs(SIZES) do
        local active = s.size == brushSize
        sizeBtns[#sizeBtns + 1] = ce(RN.Pressable, {
            key = s.label,
            onPress = function() setBrushSize(s.size) end,
            style = {
                paddingHorizontal = 12, paddingVertical = 6,
                borderRadius = 8,
                backgroundColor = active and T.accent or T.border,
                marginRight = 6,
            },
        },
            ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, s.label)
        )
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        -- Canvas
        ce("View", {
            style = {
                height = CANVAS_H,
                backgroundColor = "#1A1A2E",
                borderBottomWidth = 1, borderColor = T.border,
            },
        },
            ce(RN.DrawingCanvas, {
                ref = canvasRef,
                brushColor = brushColor,
                brushSize = brushSize,
                style = { flex = 1 },
            })
        ),
        -- Palette row
        ce("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
                padding = T.pad,
                flexWrap = "wrap",
            },
        }, unpack(colorDots)),
        -- Size + clear row
        ce("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = T.pad,
                paddingBottom = T.pad,
            },
        },
            unpack(sizeBtns),
            ce("View", { style = { flex = 1 } }),
            ce(RN.Pressable, {
                onPress = function()
                    -- Access clearStrokes via the canvas view instance
                    if canvasRef.current and canvasRef.current.clearStrokes then
                        canvasRef.current.clearStrokes()
                    end
                end,
                style = {
                    paddingHorizontal = 14, paddingVertical = 8,
                    borderRadius = 8,
                    backgroundColor = "#E74C3C",
                },
            },
                ce("Text", { style = { color = "#FFF", fontWeight = "bold" } }, "Clear")
            )
        )
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. StickersDemo — multiple PinchableView stickers, each independently transformable
-- ═══════════════════════════════════════════════════════════════════════════
local function StickersDemo()
    local STICKERS = {
        { emoji = "⭐", color = "#F1C40F", x = 40,  y = 80  },
        { emoji = "❤️", color = "#E74C3C", x = 180, y = 60  },
        { emoji = "🎉", color = "#9B59B6", x = 100, y = 200 },
        { emoji = "🌈", color = "#2ECC71", x = 220, y = 180 },
        { emoji = "🔥", color = "#E67E22", x = 60,  y = 320 },
    }

    local cards = {}
    for i, s in ipairs(STICKERS) do
        cards[#cards + 1] = ce(RN.PinchableView, {
            key = "sticker" .. i,
            minScale = 0.3,
            maxScale = 3,
            style = {
                position = "absolute",
                left = s.x, top = s.y,
                width = 80, height = 80,
                borderRadius = 40,
                backgroundColor = s.color,
                justifyContent = "center",
                alignItems = "center",
            },
        },
            ce("Text", { style = { fontSize = 36 } }, s.emoji)
        )
    end

    return ce("View", { style = { flex = 1, backgroundColor = T.bg } },
        ce("View", {
            style = {
                flex = 1,
                borderBottomWidth = 1, borderColor = T.border,
            },
        }, unpack(cards)),
        ce("Text", {
            style = {
                padding = T.pad,
                color = T.textSecondary,
                textAlign = "center",
                fontSize = 13,
                backgroundColor = T.surface,
            },
        }, "Each sticker is independently pinchable and rotatable")
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. GamepadDemo — virtual joystick (left) + fire button (right)
-- ═══════════════════════════════════════════════════════════════════════════
local function GamepadDemo()
    local joyX, setJoyX = useState(0)
    local joyY, setJoyY = useState(0)
    local firing, setFiring = useState(false)

    local STICK_AREA = 120
    local THUMB = 40

    return ce("View", { style = { flex = 1, backgroundColor = "#0D0D1A" } },
        -- Status bar
        ce("View", {
            style = {
                padding = T.pad,
                backgroundColor = "rgba(0,0,0,0.5)",
                flexDirection = "row",
                justifyContent = "space-around",
            },
        },
            ce("Text", { style = { color = T.textSecondary, fontFamily = "monospace" } },
                string.format("Joy: (%.2f, %.2f)", joyX, joyY)),
            ce("Text", { style = { color = firing and "#E74C3C" or T.textSecondary } },
                firing and "FIRE!" or "FIRE")
        ),
        -- Gamepad area
        ce("View", {
            style = {
                flex = 1,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 40,
            },
        },
            -- Left: joystick
            ce(RN.DraggableView, {
                bounds = {
                    xMin = -(STICK_AREA - THUMB) / 2,
                    yMin = -(STICK_AREA - THUMB) / 2,
                    xMax = (STICK_AREA - THUMB) / 2,
                    yMax = (STICK_AREA - THUMB) / 2,
                },
                onDrag = function(info)
                    local range = (STICK_AREA - THUMB) / 2
                    setJoyX(math.floor((info.x / range) * 100) / 100)
                    setJoyY(math.floor((info.y / range) * 100) / 100)
                end,
                onDragEnd = function()
                    setJoyX(0)
                    setJoyY(0)
                end,
                style = {
                    width = THUMB, height = THUMB, borderRadius = THUMB / 2,
                    backgroundColor = T.accent,
                    borderWidth = 2, borderColor = "#FFF",
                    justifyContent = "center", alignItems = "center",
                },
            },
                ce("View", {
                    style = {
                        width = 8, height = 8, borderRadius = 4,
                        backgroundColor = "#FFF",
                    },
                })
            ),
            -- Spacer
            ce("View", { style = { flex = 1 } }),
            -- Right: fire button
            ce(RN.Pressable, {
                onPressIn = function() setFiring(true) end,
                onPressOut = function() setFiring(false) end,
                style = {
                    width = 72, height = 72, borderRadius = 36,
                    backgroundColor = firing and "#E74C3C" or "#7F0000",
                    borderWidth = 3,
                    borderColor = firing and "#FF6666" or "#CC0000",
                    justifyContent = "center", alignItems = "center",
                },
            },
                ce("Text", {
                    style = {
                        color = "#FFF", fontWeight = "bold", fontSize = 13,
                        textAlign = "center",
                    },
                }, "FIRE")
            )
        ),
        -- Hint
        ce("Text", {
            style = {
                padding = T.pad,
                color = T.textSecondary,
                textAlign = "center",
                fontSize = 12,
                backgroundColor = "rgba(0,0,0,0.4)",
            },
        }, "Drag stick + tap FIRE simultaneously with two thumbs")
    )
end

-- ─── Exports ───────────────────────────────────────────────────────────────
return {
    { name = "Draggable", title = "Draggable Tiles",  icon = "✋", component = DraggableDemo },
    { name = "Pinch",     title = "Pinch & Rotate",   icon = "🤏", component = PinchDemo },
    { name = "Drawing",   title = "Multi-finger Draw", icon = "✏️", component = DrawingDemo },
    { name = "Stickers",  title = "Sticker Board",    icon = "⭐", component = StickersDemo },
    { name = "Gamepad",   title = "Virtual Gamepad",  icon = "🕹️", component = GamepadDemo },
}
