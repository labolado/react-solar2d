-- examples/TetrisApp.lua
-- 俄罗斯方块 — Pagelet + SceneCanvas 混合架构演示
-- Menu/GameOver: React 组件 (Pagelet)
-- 游戏棋盘: SceneCanvas (composer scene)
-- HUD: React 组件叠在 Canvas 上

local React = require("react")
local ce = React.createElement
local useState = React.useState
local useRef = React.useRef
local useMemo = React.useMemo
local useEffect = React.useEffect

local Pagelet = require("components.Pagelet")
local SceneCanvas = require("components.SceneCanvas")
local E = require("kitchen_sink.tetris_scenes.engine")
local createBoardScene = require("kitchen_sink.tetris_scenes.BoardScene")

local W = display.contentWidth
local TAB_BAR_H = 56
local SAFE_BOTTOM = 0
if display.safeActualContentHeight and display.safeScreenOriginY then
    local safeH = display.safeActualContentHeight
    local safeY = display.safeScreenOriginY
    local screenH = display.actualContentHeight or display.contentHeight
    local originY = display.screenOriginY or 0
    SAFE_BOTTOM = math.max(0, (screenH + originY) - (safeH + safeY))
end
local H = display.contentHeight - TAB_BAR_H - SAFE_BOTTOM
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

-- ============================================================
-- Menu Page (Pure React)
-- ============================================================
local function MenuPage(props)
    local bestScore = props.bestScore or 0
    local selectedSpeed = props.selectedSpeed or 2
    local onStart = props.onStart
    local speed, setSpeed = useState(selectedSpeed)

    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = "#0A0A1E",
            alignItems = "center",
            justifyContent = "center",
        },
    },
        -- Title
        ce("Text", {
            style = {
                fontSize = s(120),
                color = "#FFFFFF",
                fontWeight = "bold",
                marginBottom = s(20),
            },
        }, "TETRIS"),

        ce("Text", {
            style = {
                fontSize = s(28),
                color = "#546E7A",
                marginBottom = s(80),
            },
        }, "SceneCanvas + Pagelet Demo"),

        -- Speed selection
        ce("View", {
            style = {
                flexDirection = "row",
                marginBottom = s(60),
                gap = s(20),
            },
        },
            unpack((function()
                local btns = {}
                for i, lvl in ipairs(E.SPEED_LEVELS) do
                    local isSelected = (i == speed)
                    btns[#btns + 1] = ce("Pressable", {
                        key = "speed-" .. i,
                        onPress = function() setSpeed(i) end,
                    },
                        ce("View", {
                            style = {
                                width = s(250),
                                height = s(120),
                                backgroundColor = isSelected and lvl.color or "#1A1A3E",
                                borderRadius = s(16),
                                alignItems = "center",
                                justifyContent = "center",
                                borderWidth = isSelected and 3 or 1,
                                borderColor = isSelected and "#FFFFFF" or "#333366",
                            },
                        },
                            ce("Text", {
                                style = {
                                    fontSize = s(32),
                                    color = "#FFFFFF",
                                    fontWeight = "bold",
                                },
                            }, lvl.name),
                            ce("Text", {
                                style = {
                                    fontSize = s(20),
                                    color = isSelected and "#FFFFFF" or "#666688",
                                    marginTop = s(4),
                                },
                            }, lvl.desc)
                        )
                    )
                end
                return btns
            end)())
        ),

        -- Start button
        ce("Pressable", {
            onPress = function() if onStart then onStart(speed) end end,
        },
            ce("View", {
                style = {
                    width = s(500),
                    height = s(100),
                    backgroundColor = "#4CAF50",
                    borderRadius = s(50),
                    alignItems = "center",
                    justifyContent = "center",
                },
            },
                ce("Text", {
                    style = {
                        fontSize = s(40),
                        color = "#FFFFFF",
                        fontWeight = "bold",
                    },
                }, "开始游戏")
            )
        ),

        -- Best score
        bestScore > 0 and ce("Text", {
            style = {
                fontSize = s(28),
                color = "#546E7A",
                marginTop = s(40),
            },
        }, "最佳: " .. E.formatScore(bestScore)) or nil
    )
end

-- ============================================================
-- HUD (React overlay on game board)
-- ============================================================
local function HUD(props)
    local engine = props.engine
    local onPause = props.onPause
    if not engine then return ce("View", {}) end

    local score = engine.getScore()
    local level = engine.getLevel()
    local lines = engine.getLines()
    local combo = engine.getCombo()
    local holdPiece = engine.getHoldPiece()
    local nextQueue = engine.getNextQueue()

    local CELL_SIZE_SM = math.max(8, math.floor(s(60) * 0.45))

    -- Mini piece preview
    local function PiecePreview(previewProps)
        local piece = previewProps.piece
        local cellSize = previewProps.cellSize or CELL_SIZE_SM
        if not piece then
            return ce("View", {
                style = { width = cellSize * 4, height = cellSize * 4 },
            })
        end
        local blocks = E.SHAPES[piece.name][1]
        local cells = {}
        for _, b in ipairs(blocks) do
            cells[#cells + 1] = ce("View", {
                key = b[1] .. "-" .. b[2],
                style = {
                    position = "absolute",
                    left = b[1] * cellSize,
                    top = b[2] * cellSize,
                    width = cellSize - 1,
                    height = cellSize - 1,
                    backgroundColor = piece.color or E.COLORS[piece.name],
                },
            })
        end
        return ce("View", {
            style = { width = cellSize * 4, height = cellSize * 4 },
        }, unpack(cells))
    end

    -- Stat box
    local function StatBox(statProps)
        return ce("View", {
            style = {
                marginBottom = s(16),
            },
        },
            ce("Text", {
                style = { fontSize = s(18), color = "#546E7A" },
            }, statProps.label),
            ce("Text", {
                style = { fontSize = s(28), color = "#FFFFFF", fontWeight = "bold" },
            }, statProps.value)
        )
    end

    return ce("View", {
        style = {
            position = "absolute",
            top = 0,
            left = 0,
            width = W,
            height = H,
        },
    },
        -- Left panel: Hold + Stats
        ce("View", {
            style = {
                position = "absolute",
                left = s(20),
                top = math.floor(H * 0.09) + s(10),
                width = s(160),
            },
        },
            ce("Text", {
                style = { fontSize = s(20), color = "#546E7A", marginBottom = s(8) },
            }, "HOLD"),
            ce("View", {
                style = {
                    backgroundColor = "#0D0D20",
                    borderRadius = s(8),
                    padding = s(8),
                    marginBottom = s(24),
                    alignItems = "center",
                    height = s(80),
                    justifyContent = "center",
                },
            },
                holdPiece and ce(PiecePreview, { piece = holdPiece }) or nil
            ),
            ce(StatBox, { label = "SCORE", value = E.formatScore(score) }),
            ce(StatBox, { label = "LEVEL", value = tostring(level) }),
            ce(StatBox, { label = "LINES", value = tostring(lines) }),
            combo > 1 and ce("Text", {
                style = { fontSize = s(22), color = "#FF9800", fontWeight = "bold" },
            }, combo .. "x COMBO!") or nil
        ),

        -- Right panel: Next queue
        ce("View", {
            style = {
                position = "absolute",
                right = s(20),
                top = math.floor(H * 0.09) + s(10),
                width = s(120),
            },
        },
            ce("Text", {
                style = { fontSize = s(20), color = "#546E7A", marginBottom = s(8) },
            }, "NEXT"),
            unpack((function()
                local previews = {}
                for i, piece in ipairs(nextQueue or {}) do
                    previews[#previews + 1] = ce("View", {
                        key = "next-" .. i,
                        style = {
                            backgroundColor = "#0D0D20",
                            borderRadius = s(8),
                            padding = s(6),
                            marginBottom = s(8),
                            alignItems = "center",
                        },
                    },
                        ce(PiecePreview, { piece = piece })
                    )
                end
                return previews
            end)())
        ),

        -- Pause button (top right)
        ce("Pressable", {
            onPress = onPause,
            style = {
                position = "absolute",
                right = s(20),
                top = s(20),
            },
        },
            ce("View", {
                style = {
                    width = s(60),
                    height = s(60),
                    borderRadius = s(30),
                    backgroundColor = "rgba(255,255,255,0.15)",
                    alignItems = "center",
                    justifyContent = "center",
                },
            },
                ce("Text", {
                    style = { fontSize = s(24), color = "#FFFFFF" },
                }, "⏸")
            )
        )
    )
end

-- ============================================================
-- GameOver Page (Pure React, overlay)
-- ============================================================
local function GameOverPage(props)
    local result = props.result or {}
    local onRestart = props.onRestart
    local onHome = props.onHome

    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = "rgba(0,0,0,0.85)",
            alignItems = "center",
            justifyContent = "center",
        },
    },
        ce("Text", {
            style = {
                fontSize = s(80),
                color = "#F44336",
                fontWeight = "bold",
                marginBottom = s(40),
            },
        }, "GAME OVER"),

        -- Score
        ce("Text", {
            style = { fontSize = s(30), color = "#546E7A", marginBottom = s(8) },
        }, "最终分数"),
        ce("Text", {
            style = {
                fontSize = s(60),
                color = "#FFFFFF",
                fontWeight = "bold",
                marginBottom = s(30),
            },
        }, E.formatScore(result.score or 0)),

        -- Stats row
        ce("View", {
            style = { flexDirection = "row", gap = s(60), marginBottom = s(50) },
        },
            ce("View", { style = { alignItems = "center" } },
                ce("Text", { style = { fontSize = s(22), color = "#546E7A" } }, "等级"),
                ce("Text", { style = { fontSize = s(36), color = "#FFFFFF", fontWeight = "bold" } },
                    tostring(result.level or 1))
            ),
            ce("View", { style = { alignItems = "center" } },
                ce("Text", { style = { fontSize = s(22), color = "#546E7A" } }, "行数"),
                ce("Text", { style = { fontSize = s(36), color = "#FFFFFF", fontWeight = "bold" } },
                    tostring(result.lines or 0))
            )
        ),

        -- New best indicator
        result.isNewBest and ce("Text", {
            style = {
                fontSize = s(32),
                color = "#FFD700",
                fontWeight = "bold",
                marginBottom = s(30),
            },
        }, "★ 新纪录! ★") or nil,

        -- Buttons
        ce("Pressable", {
            onPress = onRestart,
        },
            ce("View", {
                style = {
                    width = s(400),
                    height = s(80),
                    backgroundColor = "#4CAF50",
                    borderRadius = s(40),
                    alignItems = "center",
                    justifyContent = "center",
                    marginBottom = s(20),
                },
            },
                ce("Text", {
                    style = { fontSize = s(32), color = "#FFFFFF", fontWeight = "bold" },
                }, "再来一局")
            )
        ),

        ce("Pressable", {
            onPress = onHome,
        },
            ce("Text", {
                style = { fontSize = s(28), color = "#546E7A", marginTop = s(10) },
            }, "返回菜单")
        )
    )
end

-- ============================================================
-- Pause Overlay (Pure React)
-- ============================================================
local function PauseOverlay(props)
    return ce("View", {
        style = {
            flex = 1,
            backgroundColor = "rgba(0,0,0,0.80)",
            alignItems = "center",
            justifyContent = "center",
        },
    },
        ce("Text", {
            style = {
                fontSize = s(72),
                color = "#FFFFFF",
                fontWeight = "bold",
                marginBottom = s(60),
            },
        }, "PAUSED"),

        ce("Pressable", { onPress = props.onResume },
            ce("View", {
                style = {
                    width = s(400),
                    height = s(90),
                    backgroundColor = "#4CAF50",
                    borderRadius = s(24),
                    alignItems = "center",
                    justifyContent = "center",
                    marginBottom = s(30),
                },
            },
                ce("Text", {
                    style = { fontSize = s(36), color = "#FFFFFF", fontWeight = "bold" },
                }, "继续")
            )
        ),

        ce("Pressable", { onPress = props.onQuit },
            ce("Text", {
                style = { fontSize = s(28), color = "#90A4AE" },
            }, "退出")
        )
    )
end

-- ============================================================
-- TetrisApp: Pagelet.Container orchestrator
-- ============================================================
local function TetrisApp()
    local screen, setScreen = useState("menu")
    local speedLevel, setSpeedLevel = useState(2)
    local bestScore, setBestScore = useState(0)
    local gameResult, setGameResult = useState(nil)
    local paused, setPaused = useState(false)
    local engineRef = useRef(nil)
    local tick, setTick = useState(0)  -- force HUD re-render

    -- Create engine + scene on game start
    local engine = useMemo(function()
        if screen ~= "game" and screen ~= "gameover" then return nil end
        local eng = E.createEngine(speedLevel)
        engineRef.current = eng
        return eng
    end, { screen == "game" and speedLevel or nil })

    -- Fresh scene per game session (avoids stale listeners on remount)
    local boardScene = useMemo(function()
        if not engine then return nil end
        return createBoardScene()
    end, { engine })

    -- Board scene params
    local boardParams = useMemo(function()
        return {
            engine = engine,
            onGameOver = function(result)
                local isNewBest = result.score > bestScore
                if isNewBest then setBestScore(result.score) end
                setGameResult({
                    score = result.score,
                    level = result.level,
                    lines = result.lines,
                    isNewBest = isNewBest,
                })
                setScreen("gameover")
            end,
            onPause = function()
                setPaused(true)
            end,
            onTick = function()
                setTick(function(t) return t + 1 end)
            end,
        }
    end, { engine, bestScore })

    return ce(Pagelet.Container, { current = screen, style = { width = W, height = H } },

        -- ── Menu ──────────────────────────────────────────────
        ce(Pagelet, {
            name = "menu",
            onShow = function(e)
                if e.phase == "did" then
                    engineRef.current = nil
                end
            end,
        },
            ce(MenuPage, {
                bestScore = bestScore,
                selectedSpeed = speedLevel,
                onStart = function(speed)
                    setSpeedLevel(speed)
                    setGameResult(nil)
                    setPaused(false)
                    setScreen("game")
                end,
            })
        ),

        -- ── Game ──────────────────────────────────────────────
        ce(Pagelet, {
            name = "game",
            style = { width = W, height = H },
        },
            -- Layer 1: Game board (SceneCanvas — composer scene)
            ce(SceneCanvas, {
                key = "board-" .. speedLevel,
                scene = boardScene,
                params = boardParams,
                style = { width = W, height = H },
            }),
            -- Layer 2: HUD (React overlay)
            ce(HUD, {
                engine = engine,
                onPause = function()
                    setPaused(true)
                end,
            }),
            -- Layer 3: Pause overlay (React, conditional)
            paused and ce(PauseOverlay, {
                onResume = function() setPaused(false) end,
                onQuit = function()
                    setPaused(false)
                    setScreen("menu")
                end,
            }) or nil
        ),

        -- ── Game Over ─────────────────────────────────────────
        ce(Pagelet, {
            name = "gameover",
            style = { width = W, height = H },
        },
            ce(GameOverPage, {
                result = gameResult,
                onRestart = function()
                    setGameResult(nil)
                    setPaused(false)
                    setScreen("game")
                end,
                onHome = function()
                    setGameResult(nil)
                    setPaused(false)
                    setScreen("menu")
                end,
            })
        )
    )
end

return TetrisApp
