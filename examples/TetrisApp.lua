-- examples/TetrisApp.lua
-- 商业级俄罗斯方块 — 幽灵方块、Hold、连击系统、精致 UI
local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useRef = React.useRef
local useEffect = React.useEffect

local W = display.contentWidth
local H = display.contentHeight
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

-- ============================================================
-- 游戏常量
-- ============================================================
local COLS = 10
local ROWS = 20
local CELL_SIZE = math.floor(math.min((W - s(200)) / COLS, (H - s(500)) / ROWS))
local GRID_W = CELL_SIZE * COLS
local GRID_H = CELL_SIZE * ROWS
local GRID_X = math.floor((W - GRID_W) / 2)
local GRID_Y = math.floor(H * 0.09)
local PREVIEW_CELL = math.max(10, math.floor(CELL_SIZE * 0.6))
local PREVIEW_CELL_SM = math.max(8, math.floor(CELL_SIZE * 0.45))

-- 7种方块定义（含所有旋转状态）
local SHAPES = {
    I = {
        {{ 0,0 },{ 1,0 },{ 2,0 },{ 3,0 }},
        {{ 0,0 },{ 0,1 },{ 0,2 },{ 0,3 }},
    },
    O = {
        {{ 0,0 },{ 1,0 },{ 0,1 },{ 1,1 }},
    },
    T = {
        {{ 0,0 },{ 1,0 },{ 2,0 },{ 1,1 }},
        {{ 0,0 },{ 0,1 },{ 0,2 },{ 1,1 }},
        {{ 1,0 },{ 0,1 },{ 1,1 },{ 2,1 }},
        {{ 1,0 },{ 1,1 },{ 1,2 },{ 0,1 }},
    },
    S = {
        {{ 1,0 },{ 2,0 },{ 0,1 },{ 1,1 }},
        {{ 0,0 },{ 0,1 },{ 1,1 },{ 1,2 }},
    },
    Z = {
        {{ 0,0 },{ 1,0 },{ 1,1 },{ 2,1 }},
        {{ 1,0 },{ 0,1 },{ 1,1 },{ 0,2 }},
    },
    L = {
        {{ 0,0 },{ 0,1 },{ 0,2 },{ 1,2 }},
        {{ 0,0 },{ 1,0 },{ 2,0 },{ 0,1 }},
        {{ 0,0 },{ 1,0 },{ 1,1 },{ 1,2 }},
        {{ 2,0 },{ 0,1 },{ 1,1 },{ 2,1 }},
    },
    J = {
        {{ 1,0 },{ 1,1 },{ 1,2 },{ 0,2 }},
        {{ 0,0 },{ 0,1 },{ 1,1 },{ 2,1 }},
        {{ 0,0 },{ 1,0 },{ 0,1 },{ 0,2 }},
        {{ 0,0 },{ 1,0 },{ 2,0 },{ 2,1 }},
    },
}

local COLORS = {
    I = "#00BCD4", O = "#FFEB3B", T = "#9C27B0",
    S = "#4CAF50", Z = "#F44336", L = "#FF9800", J = "#2196F3",
}

-- 浅色版本用于幽灵方块
local GHOST_COLORS = {
    I = "#004D56", O = "#665E18", T = "#3E0F48",
    S = "#1B4D1F", Z = "#611B15", L = "#663D00", J = "#0D3A63",
}

local SHAPE_NAMES = { "I", "O", "T", "S", "Z", "L", "J" }

local SPEED_LEVELS = {
    { name = "轻松", desc = "慢速下落", base = 1000, color = "#4CAF50" },
    { name = "标准", desc = "经典速度", base = 700, color = "#FF9800" },
    { name = "极速", desc = "快速下落", base = 400, color = "#F44336" },
}

local SCORE_TABLE = { 100, 300, 500, 800 } -- 1/2/3/4 行

-- ============================================================
-- 工具函数
-- ============================================================
local function hexToRGBA(hex)
    local h = hex:sub(2)
    return tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255
end

local function formatScore(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 10000 then return string.format("%.1fK", n / 1000) end
    return tostring(n)
end

-- ============================================================
-- 游戏引擎
-- ============================================================
local function createGameEngine(speedLevel)
    local engine = {}
    local grid = {}
    local currentPiece = nil
    local score = 0
    local level = 1
    local linesCleared = 0
    local gameOver = false
    local displayCells = {}
    local ghostCells = {}
    local combo = 0
    local holdPiece = nil
    local holdUsed = false -- 每次锁定后重置
    local nextQueue = {} -- 3个预览方块
    local baseSpeed = SPEED_LEVELS[speedLevel or 2].base

    -- 初始化空网格
    for r = 1, ROWS do
        grid[r] = {}
        displayCells[r] = {}
        for c = 1, COLS do
            grid[r][c] = nil
        end
    end

    -- 生成随机方块（7-bag）
    local bag = {}
    local function randomPiece()
        if #bag == 0 then
            for _, n in ipairs(SHAPE_NAMES) do bag[#bag+1] = n end
            for i = #bag, 2, -1 do
                local j = math.random(i)
                bag[i], bag[j] = bag[j], bag[i]
            end
        end
        local name = table.remove(bag, 1)
        local rotations = SHAPES[name]
        return {
            name = name,
            color = COLORS[name],
            ghostColor = GHOST_COLORS[name],
            rotation = 1,
            rotations = rotations,
            blocks = rotations[1],
            x = math.floor(COLS / 2) - 1,
            y = 1,
        }
    end

    local function isValid(blocks, px, py)
        for _, b in ipairs(blocks) do
            local c = px + b[1]
            local r = py + b[2]
            if c < 1 or c > COLS or r < 1 or r > ROWS then return false end
            if grid[r][c] then return false end
        end
        return true
    end

    -- 计算幽灵位置
    local function getGhostY()
        if not currentPiece then return nil end
        local gy = currentPiece.y
        while isValid(currentPiece.blocks, currentPiece.x, gy + 1) do
            gy = gy + 1
        end
        return gy
    end

    local function lockPiece()
        for _, b in ipairs(currentPiece.blocks) do
            local c = currentPiece.x + b[1]
            local r = currentPiece.y + b[2]
            if r >= 1 and r <= ROWS and c >= 1 and c <= COLS then
                grid[r][c] = currentPiece.color
            end
        end
    end

    local function clearLines()
        local cleared = 0
        local flashRows = {}
        local r = ROWS
        while r >= 1 do
            local full = true
            for c = 1, COLS do
                if not grid[r][c] then full = false; break end
            end
            if full then
                flashRows[#flashRows + 1] = r
                table.remove(grid, r)
                local newRow = {}
                for c = 1, COLS do newRow[c] = nil end
                table.insert(grid, 1, newRow)
                cleared = cleared + 1
            else
                r = r - 1
            end
        end
        if cleared > 0 then
            combo = combo + 1
            local basePoints = SCORE_TABLE[math.min(cleared, 4)]
            local comboBonus = (combo - 1) * 50
            score = score + (basePoints + comboBonus) * level
            linesCleared = linesCleared + cleared
            level = math.floor(linesCleared / 10) + 1
            print(string.format("[Tetris] %d lines! combo=%d score=%d level=%d", cleared, combo, score, level))
        else
            combo = 0
        end
        return cleared, flashRows
    end

    function engine.init(parentGroup)
        engine.group = parentGroup
        -- 创建网格显示对象
        for r = 1, ROWS do
            for c = 1, COLS do
                local x = GRID_X + (c - 1) * CELL_SIZE
                local y = GRID_Y + (r - 1) * CELL_SIZE
                local rect = display.newRect(parentGroup, x, y, CELL_SIZE - 2, CELL_SIZE - 2)
                rect.anchorX, rect.anchorY = 0, 0
                rect:setFillColor(0.08, 0.08, 0.12)
                rect:setStrokeColor(0.15, 0.15, 0.2)
                rect.strokeWidth = 1
                displayCells[r][c] = rect
            end
        end
        -- 初始化方块队列
        for i = 1, 3 do
            nextQueue[i] = randomPiece()
        end
        currentPiece = randomPiece()
    end

    function engine.render()
        -- 清空所有单元格
        for r = 1, ROWS do
            for c = 1, COLS do
                local cell = displayCells[r][c]
                if grid[r][c] then
                    local cr, cg, cb = hexToRGBA(grid[r][c])
                    cell:setFillColor(cr, cg, cb)
                    cell.alpha = 1
                else
                    cell:setFillColor(0.08, 0.08, 0.12)
                    cell.alpha = 1
                end
            end
        end
        -- 绘制幽灵方块
        if currentPiece then
            local ghostY = getGhostY()
            if ghostY and ghostY > currentPiece.y then
                local gr, gg, gb = hexToRGBA(currentPiece.ghostColor)
                for _, b in ipairs(currentPiece.blocks) do
                    local c = currentPiece.x + b[1]
                    local r = ghostY + b[2]
                    if r >= 1 and r <= ROWS and c >= 1 and c <= COLS then
                        displayCells[r][c]:setFillColor(gr, gg, gb)
                        displayCells[r][c].alpha = 0.5
                    end
                end
            end
        end
        -- 绘制当前方块
        if currentPiece then
            local cr, cg, cb = hexToRGBA(currentPiece.color)
            for _, b in ipairs(currentPiece.blocks) do
                local c = currentPiece.x + b[1]
                local r = currentPiece.y + b[2]
                if r >= 1 and r <= ROWS and c >= 1 and c <= COLS then
                    displayCells[r][c]:setFillColor(cr, cg, cb)
                    displayCells[r][c].alpha = 1
                end
            end
        end
    end

    function engine.tick()
        if gameOver then return false end
        if not currentPiece then return false end

        if isValid(currentPiece.blocks, currentPiece.x, currentPiece.y + 1) then
            currentPiece.y = currentPiece.y + 1
        else
            lockPiece()
            holdUsed = false -- 锁定后可以再次 hold
            clearLines()
            -- 从队列取下一个方块
            currentPiece = table.remove(nextQueue, 1)
            nextQueue[#nextQueue + 1] = randomPiece()
            if not isValid(currentPiece.blocks, currentPiece.x, currentPiece.y) then
                gameOver = true
                return false
            end
        end
        engine.render()
        return true
    end

    function engine.moveLeft()
        if currentPiece and isValid(currentPiece.blocks, currentPiece.x - 1, currentPiece.y) then
            currentPiece.x = currentPiece.x - 1
            engine.render()
        end
    end

    function engine.moveRight()
        if currentPiece and isValid(currentPiece.blocks, currentPiece.x + 1, currentPiece.y) then
            currentPiece.x = currentPiece.x + 1
            engine.render()
        end
    end

    function engine.rotate()
        if not currentPiece then return end
        local nextRot = (currentPiece.rotation % #currentPiece.rotations) + 1
        local nextBlocks = currentPiece.rotations[nextRot]
        -- 尝试原位旋转
        if isValid(nextBlocks, currentPiece.x, currentPiece.y) then
            currentPiece.rotation = nextRot
            currentPiece.blocks = nextBlocks
            engine.render()
            return
        end
        -- Wall kick：尝试左移/右移1-2格
        for _, dx in ipairs({-1, 1, -2, 2}) do
            if isValid(nextBlocks, currentPiece.x + dx, currentPiece.y) then
                currentPiece.x = currentPiece.x + dx
                currentPiece.rotation = nextRot
                currentPiece.blocks = nextBlocks
                engine.render()
                return
            end
        end
    end

    function engine.softDrop()
        if currentPiece and isValid(currentPiece.blocks, currentPiece.x, currentPiece.y + 1) then
            currentPiece.y = currentPiece.y + 1
            score = score + 1 -- 软降加分
            engine.render()
        end
    end

    function engine.hardDrop()
        if not currentPiece then return end
        local dropped = 0
        while isValid(currentPiece.blocks, currentPiece.x, currentPiece.y + 1) do
            currentPiece.y = currentPiece.y + 1
            dropped = dropped + 1
        end
        score = score + dropped * 2 -- 硬降每格2分
        -- 立即锁定
        lockPiece()
        holdUsed = false
        clearLines()
        currentPiece = table.remove(nextQueue, 1)
        nextQueue[#nextQueue + 1] = randomPiece()
        if not isValid(currentPiece.blocks, currentPiece.x, currentPiece.y) then
            gameOver = true
        end
        engine.render()
    end

    function engine.hold()
        if holdUsed or not currentPiece then return end
        holdUsed = true
        local pieceToHold = {
            name = currentPiece.name,
            color = currentPiece.color,
            ghostColor = currentPiece.ghostColor,
            rotation = 1,
            rotations = currentPiece.rotations,
            blocks = currentPiece.rotations[1],
            x = math.floor(COLS / 2) - 1,
            y = 1,
        }
        if holdPiece then
            -- 交换
            currentPiece = holdPiece
            currentPiece.x = math.floor(COLS / 2) - 1
            currentPiece.y = 1
        else
            -- 从队列取新的
            currentPiece = table.remove(nextQueue, 1)
            nextQueue[#nextQueue + 1] = randomPiece()
        end
        holdPiece = pieceToHold
        engine.render()
    end

    function engine.getScore() return score end
    function engine.getLevel() return level end
    function engine.getLines() return linesCleared end
    function engine.getCombo() return combo end
    function engine.isGameOver() return gameOver end
    function engine.getNextQueue() return nextQueue end
    function engine.getHoldPiece() return holdPiece end
    function engine.getSpeed()
        return math.max(80, baseSpeed - (level - 1) * 50)
    end

    function engine.reset()
        for r = 1, ROWS do
            for c = 1, COLS do grid[r][c] = nil end
        end
        score = 0; level = 1; linesCleared = 0; gameOver = false; combo = 0
        holdPiece = nil; holdUsed = false
        bag = {}
        nextQueue = {}
        for i = 1, 3 do nextQueue[i] = randomPiece() end
        currentPiece = randomPiece()
        engine.render()
    end

    function engine.destroy()
        if engine.group then
            engine.group:removeSelf()
            engine.group = nil
        end
    end

    return engine
end

-- ============================================================
-- UI 组件
-- ============================================================

-- 方块预览组件
local function PiecePreview(props)
    local piece = props.piece
    local cellSize = props.cellSize or 20
    local label = props.label

    local children = {}
    if label then
        children[#children + 1] = createElement("Text", {
            key = "label",
            style = {
                fontSize = s(20), color = "#607D8B",
                marginBottom = s(8), textAlign = "center",
            },
        }, label)
    end

    if piece then
        local blocks = piece.rotations and piece.rotations[1] or piece.blocks or SHAPES[piece.name][1]
        local blockElements = {}
        for i, b in ipairs(blocks) do
            blockElements[#blockElements + 1] = createElement("View", {
                key = "pb_" .. i,
                style = {
                    position = "absolute",
                    left = b[1] * cellSize,
                    top = b[2] * cellSize,
                    width = cellSize - 2,
                    height = cellSize - 2,
                    backgroundColor = piece.color or COLORS[piece.name],
                    borderRadius = s(3),
                },
            })
        end
        children[#children + 1] = createElement("View", {
            key = "preview",
            style = { width = cellSize * 4, height = cellSize * 4 },
        }, unpack(blockElements))
    else
        children[#children + 1] = createElement("View", {
            key = "empty",
            style = {
                width = cellSize * 4, height = cellSize * 4,
                borderWidth = 1, borderColor = "#263238",
                borderRadius = s(4),
            },
        })
    end

    return createElement("View", {
        style = {
            alignItems = "center",
            padding = s(8),
        },
    }, unpack(children))
end

-- 控制按钮
local function ControlBtn(props)
    local size = props.size or s(100)
    return createElement("View", {
        style = {
            width = size, height = size,
            backgroundColor = props.color or "#263238",
            borderRadius = size / 2,
            borderWidth = s(2),
            borderColor = props.borderColor or "#37474F",
            justifyContent = "center",
            alignItems = "center",
        },
        onPress = props.onPress,
    },
        createElement("Text", {
            style = {
                fontSize = props.fontSize or s(36),
                color = props.textColor or "#ECEFF1",
                fontWeight = "bold",
            },
        }, props.label)
    )
end

-- 信息面板项
local function StatItem(props)
    return createElement("View", {
        style = { alignItems = "center", marginBottom = s(16) },
    },
        createElement("Text", {
            style = { fontSize = s(22), color = "#607D8B" },
        }, props.label),
        createElement("Text", {
            style = {
                fontSize = props.fontSize or s(36),
                fontWeight = "bold",
                color = props.color or "#FFFFFF",
                marginTop = s(2),
            },
        }, tostring(props.value))
    )
end

-- ============================================================
-- 开始页面
-- ============================================================
local function StartScreen(props)
    local selectedSpeed, setSelectedSpeed = useState(2)

    local speedButtons = {}
    for i, sp in ipairs(SPEED_LEVELS) do
        local isSelected = (i == selectedSpeed)
        speedButtons[#speedButtons + 1] = createElement("View", {
            key = "speed_" .. i,
            style = {
                backgroundColor = isSelected and sp.color or "#1A2332",
                borderRadius = s(16),
                borderWidth = s(2),
                borderColor = isSelected and sp.color or "#263238",
                padding = s(20),
                paddingHorizontal = s(28),
                flex = 1,
                alignItems = "center",
            },
            onPress = function() setSelectedSpeed(i) end,
        },
            createElement("Text", {
                style = {
                    fontSize = s(28),
                    fontWeight = "bold",
                    color = isSelected and "#FFFFFF" or "#607D8B",
                },
            }, sp.name),
            createElement("Text", {
                style = {
                    fontSize = s(22),
                    color = isSelected and "rgba(255,255,255,0.7)" or "#455A64",
                    marginTop = s(4),
                },
            }, sp.desc)
        )
    end

    return createElement("View", {
        style = {
            flex = 1, width = W, height = H,
            backgroundColor = "#0D1117",
            justifyContent = "center",
            alignItems = "center",
        },
    },
        -- 标题区域
        createElement("View", {
            style = { alignItems = "center" },
        },
            -- 方块装饰
            createElement("View", {
                style = {
                    flexDirection = "row",
                    marginBottom = s(16),
                    gap = s(6),
                },
            },
                createElement("View", { style = { width = s(32), height = s(32), backgroundColor = "#00BCD4", borderRadius = s(4) } }),
                createElement("View", { style = { width = s(32), height = s(32), backgroundColor = "#FFEB3B", borderRadius = s(4) } }),
                createElement("View", { style = { width = s(32), height = s(32), backgroundColor = "#9C27B0", borderRadius = s(4) } }),
                createElement("View", { style = { width = s(32), height = s(32), backgroundColor = "#F44336", borderRadius = s(4) } })
            ),
            createElement("Text", {
                style = {
                    fontSize = s(96),
                    fontWeight = "bold",
                    color = "#FFFFFF",
                },
            }, "TETRIS"),
            createElement("Text", {
                style = {
                    fontSize = s(28),
                    color = "#546E7A",
                    marginTop = s(4),
                },
            }, "React-Solar2D")
        ),

        -- 速度选择
        createElement("View", {
            style = {
                marginTop = s(80),
                width = W * 0.85,
            },
        },
            createElement("Text", {
                style = {
                    fontSize = s(24), color = "#607D8B",
                    textAlign = "center", marginBottom = s(16),
                },
            }, "选择速度"),
            createElement("View", {
                style = {
                    flexDirection = "row",
                    gap = s(16),
                },
            }, unpack(speedButtons))
        ),

        -- 开始按钮
        createElement("View", {
            style = {
                marginTop = s(60),
                backgroundColor = SPEED_LEVELS[selectedSpeed].color,
                borderRadius = s(28),
                paddingVertical = s(24),
                paddingHorizontal = s(100),
            },
            onPress = function() props.onStart(selectedSpeed) end,
        },
            createElement("Text", {
                style = { fontSize = s(44), color = "#FFFFFF", fontWeight = "bold" },
            }, "START")
        ),

        -- 最佳记录
        props.bestScore > 0 and createElement("View", {
            style = { marginTop = s(40), alignItems = "center" },
        },
            createElement("Text", {
                style = { fontSize = s(22), color = "#455A64" },
            }, "最佳记录"),
            createElement("Text", {
                style = { fontSize = s(36), fontWeight = "bold", color = "#FF9800", marginTop = s(4) },
            }, formatScore(props.bestScore))
        ) or nil,

        -- 操作说明
        createElement("View", {
            style = {
                position = "absolute",
                bottom = s(60),
                alignItems = "center",
            },
        },
            createElement("Text", {
                style = { fontSize = s(20), color = "#37474F" },
            }, "Hold · 左右移动 · 旋转 · 下落")
        )
    )
end

-- ============================================================
-- 游戏结束弹窗
-- ============================================================
local function GameOverModal(props)
    if not props.visible then return nil end

    local pct = props.lines > 0 and math.floor(props.score / math.max(props.lines, 1)) or 0

    return createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = W, height = H,
            backgroundColor = "rgba(0,0,0,0.85)",
            justifyContent = "center",
            alignItems = "center",
            zIndex = 100,
        },
    },
        createElement("View", {
            style = {
                width = W * 0.75,
                backgroundColor = "#1A2332",
                borderRadius = s(32),
                padding = s(48),
                alignItems = "center",
                borderWidth = s(2),
                borderColor = "#F44336",
            },
        },
            createElement("Text", {
                style = { fontSize = s(72), fontWeight = "bold", color = "#F44336" },
            }, "GAME OVER"),

            -- 分数
            createElement("View", {
                style = {
                    marginTop = s(32),
                    backgroundColor = "#0D1117",
                    borderRadius = s(20),
                    padding = s(28),
                    width = W * 0.6,
                    alignItems = "center",
                },
            },
                createElement("Text", {
                    style = { fontSize = s(20), color = "#607D8B" },
                }, "最终得分"),
                createElement("Text", {
                    style = { fontSize = s(72), fontWeight = "bold", color = "#FFFFFF", marginTop = s(4) },
                }, formatScore(props.score)),

                -- 统计栏
                createElement("View", {
                    style = {
                        flexDirection = "row",
                        justifyContent = "space-around",
                        width = W * 0.55,
                        marginTop = s(20),
                        paddingTop = s(16),
                        borderTopWidth = 1,
                        borderTopColor = "#263238",
                    },
                },
                    createElement("View", { style = { alignItems = "center" } },
                        createElement("Text", { style = { fontSize = s(32), fontWeight = "bold", color = "#4CAF50" } }, tostring(props.level)),
                        createElement("Text", { style = { fontSize = s(22), color = "#607D8B" } }, "等级")
                    ),
                    createElement("View", { style = { alignItems = "center" } },
                        createElement("Text", { style = { fontSize = s(32), fontWeight = "bold", color = "#FF9800" } }, tostring(props.lines)),
                        createElement("Text", { style = { fontSize = s(22), color = "#607D8B" } }, "行数")
                    ),
                    createElement("View", { style = { alignItems = "center" } },
                        createElement("Text", { style = { fontSize = s(32), fontWeight = "bold", color = "#2196F3" } }, tostring(pct)),
                        createElement("Text", { style = { fontSize = s(22), color = "#607D8B" } }, "每行均分")
                    )
                )
            ),

            -- 新纪录提示
            props.isNewBest and createElement("Text", {
                style = {
                    fontSize = s(28), fontWeight = "bold",
                    color = "#FFD700", marginTop = s(20),
                },
            }, "★ 新纪录！★") or nil,

            -- 按钮
            createElement("View", {
                style = {
                    marginTop = s(36),
                    flexDirection = "row",
                    gap = s(20),
                },
            },
                createElement("View", {
                    style = {
                        backgroundColor = "#4CAF50",
                        borderRadius = s(20),
                        paddingVertical = s(18),
                        paddingHorizontal = s(48),
                    },
                    onPress = props.onRestart,
                },
                    createElement("Text", {
                        style = { fontSize = s(32), color = "#FFFFFF", fontWeight = "bold" },
                    }, "再来")
                ),
                createElement("View", {
                    style = {
                        backgroundColor = "#263238",
                        borderRadius = s(20),
                        borderWidth = s(2),
                        borderColor = "#455A64",
                        paddingVertical = s(18),
                        paddingHorizontal = s(48),
                    },
                    onPress = props.onHome,
                },
                    createElement("Text", {
                        style = { fontSize = s(32), color = "#ECEFF1" },
                    }, "首页")
                )
            )
        )
    )
end

-- ============================================================
-- 暂停弹窗
-- ============================================================
local function PauseOverlay(props)
    if not props.visible then return nil end

    return createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = W, height = H,
            backgroundColor = "rgba(0,0,0,0.8)",
            justifyContent = "center",
            alignItems = "center",
            zIndex = 90,
        },
    },
        createElement("Text", {
            style = { fontSize = s(72), fontWeight = "bold", color = "#FFFFFF" },
        }, "PAUSED"),
        createElement("View", {
            style = {
                marginTop = s(48),
                backgroundColor = "#4CAF50",
                borderRadius = s(24),
                paddingVertical = s(20),
                paddingHorizontal = s(60),
            },
            onPress = props.onResume,
        },
            createElement("Text", {
                style = { fontSize = s(36), color = "#FFFFFF", fontWeight = "bold" },
            }, "继续")
        ),
        createElement("View", {
            style = {
                marginTop = s(16),
                paddingVertical = s(16),
                paddingHorizontal = s(40),
            },
            onPress = props.onQuit,
        },
            createElement("Text", {
                style = { fontSize = s(28), color = "#90A4AE" },
            }, "退出")
        )
    )
end

-- ============================================================
-- 主应用
-- ============================================================
local function TetrisApp()
    local screen, setScreen = useState("start") -- "start" | "game"
    local speedLevel, setSpeedLevel = useState(2)
    local score, setScore = useState(0)
    local level, setLevel = useState(1)
    local lines, setLines = useState(0)
    local combo, setCombo = useState(0)
    local gameOverVisible, setGameOverVisible = useState(false)
    local pauseVisible, setPauseVisible = useState(false)
    local bestScore, setBestScore = useState(0)
    local isNewBest, setIsNewBest = useState(false)
    local engineRef = useRef(nil)
    local timerRef = useRef(nil)
    -- 强制刷新 hold/next 显示
    local uiTick, setUiTick = useState(0)

    -- 启动游戏
    local function startGame(speed)
        setSpeedLevel(speed)
        setScore(0)
        setLevel(1)
        setLines(0)
        setCombo(0)
        setGameOverVisible(false)
        setPauseVisible(false)
        setIsNewBest(false)
        setScreen("game")
    end

    -- 游戏引擎生命周期
    useEffect(function()
        if screen ~= "game" then return end

        local engine = createGameEngine(speedLevel)
        local gameGroup = display.newGroup()
        engine.init(gameGroup)
        engine.render()
        engineRef.current = engine

        -- 游戏循环
        local function startTimer()
            if timerRef.current and timer and timer.cancel then
                timer.cancel(timerRef.current)
            end
            local speed = engine.getSpeed()
            if timer and timer.performWithDelay then
                timerRef.current = timer.performWithDelay(speed, function()
                    if pauseVisible then
                        startTimer()
                        return
                    end
                    local alive = engine.tick()
                    setScore(engine.getScore())
                    setLevel(engine.getLevel())
                    setLines(engine.getLines())
                    setCombo(engine.getCombo())
                    setUiTick(function(t) return t + 1 end)
                    if alive then
                        startTimer() -- 递归调度
                    else
                        -- 游戏结束
                        local finalScore = engine.getScore()
                        if finalScore > bestScore then
                            setBestScore(finalScore)
                            setIsNewBest(true)
                        end
                        setGameOverVisible(true)
                    end
                end)
            end
        end
        startTimer()

        return function()
            if timerRef.current and timer and timer.cancel then
                timer.cancel(timerRef.current)
            end
            engine.destroy()
        end
    end, {screen})

    -- 开始页
    if screen == "start" then
        return createElement(StartScreen, {
            bestScore = bestScore,
            onStart = startGame,
        })
    end

    -- 获取 hold 和 next 信息
    local holdPiece = engineRef.current and engineRef.current.getHoldPiece() or nil
    local nextQueue = engineRef.current and engineRef.current.getNextQueue() or {}

    -- 游戏页
    return createElement("View", {
        style = {
            flex = 1, width = W, height = H,
            backgroundColor = "#0D1117",
        },
    },
        -- 顶部信息栏
        createElement("View", {
            style = {
                height = s(150),
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingHorizontal = s(32),
                paddingTop = s(20),
            },
        },
            -- Hold 区域
            createElement("View", {
                style = {
                    backgroundColor = "#1A2332",
                    borderRadius = s(12),
                    padding = s(8),
                    borderWidth = 1,
                    borderColor = "#263238",
                },
            },
                createElement(PiecePreview, { piece = holdPiece, cellSize = PREVIEW_CELL, label = "HOLD" })
            ),
            -- 得分/等级/行数
            createElement("View", {
                style = { alignItems = "center" },
            },
                createElement("Text", {
                    style = { fontSize = s(48), fontWeight = "bold", color = "#FFFFFF" },
                }, formatScore(score)),
                createElement("View", {
                    style = { flexDirection = "row", gap = s(20), marginTop = s(4) },
                },
                    createElement("Text", {
                        style = { fontSize = s(22), color = "#4CAF50" },
                    }, "Lv." .. level),
                    createElement("Text", {
                        style = { fontSize = s(22), color = "#FF9800" },
                    }, lines .. "行")
                ),
                -- 连击指示
                combo > 1 and createElement("Text", {
                    style = {
                        fontSize = s(24), fontWeight = "bold",
                        color = "#FFD700", marginTop = s(4),
                    },
                }, combo .. "x COMBO!") or nil
            ),
            -- Next 队列
            createElement("View", {
                style = {
                    backgroundColor = "#1A2332",
                    borderRadius = s(12),
                    padding = s(8),
                    borderWidth = 1,
                    borderColor = "#263238",
                },
            },
                createElement(PiecePreview, {
                    piece = nextQueue[1],
                    cellSize = PREVIEW_CELL,
                    label = "NEXT",
                })
            )
        ),

        -- 右侧小型预览（第2、3个 next）
        createElement("View", {
            style = {
                position = "absolute",
                top = GRID_Y + s(10),
                right = s(10),
            },
        },
            nextQueue[2] and createElement(PiecePreview, {
                piece = nextQueue[2], cellSize = PREVIEW_CELL_SM,
            }) or nil,
            nextQueue[3] and createElement(PiecePreview, {
                piece = nextQueue[3], cellSize = PREVIEW_CELL_SM,
            }) or nil
        ),

        -- 游戏网格由引擎直接渲染在 GRID_X, GRID_Y 位置

        -- 底部控制区域
        createElement("View", {
            style = {
                position = "absolute",
                bottom = s(40),
                left = 0, width = W,
                alignItems = "center",
            },
        },
            -- 上排：Hold + 旋转 + 暂停
            createElement("View", {
                style = {
                    flexDirection = "row",
                    justifyContent = "center",
                    gap = s(40),
                    marginBottom = s(20),
                },
            },
                createElement(ControlBtn, {
                    label = "H",
                    size = s(70),
                    fontSize = s(28),
                    color = "#1A237E",
                    borderColor = "#3F51B5",
                    onPress = function()
                        if engineRef.current then
                            engineRef.current.hold()
                            setUiTick(function(t) return t + 1 end)
                        end
                    end,
                }),
                createElement(ControlBtn, {
                    label = "↻",
                    size = s(70),
                    fontSize = s(36),
                    color = "#4A148C",
                    borderColor = "#7B1FA2",
                    onPress = function()
                        if engineRef.current then engineRef.current.rotate() end
                    end,
                }),
                createElement(ControlBtn, {
                    label = "||",
                    size = s(70),
                    fontSize = s(24),
                    color = "#37474F",
                    borderColor = "#546E7A",
                    onPress = function()
                        setPauseVisible(true)
                    end,
                })
            ),
            -- 下排：左 + 下 + 硬降 + 右
            createElement("View", {
                style = {
                    flexDirection = "row",
                    justifyContent = "center",
                    gap = s(24),
                },
            },
                createElement(ControlBtn, {
                    label = "◀",
                    size = s(100),
                    color = "#263238",
                    borderColor = "#37474F",
                    onPress = function()
                        if engineRef.current then engineRef.current.moveLeft() end
                    end,
                }),
                createElement(ControlBtn, {
                    label = "▼",
                    size = s(100),
                    color = "#263238",
                    borderColor = "#37474F",
                    onPress = function()
                        if engineRef.current then engineRef.current.softDrop() end
                    end,
                }),
                createElement(ControlBtn, {
                    label = "⬇",
                    size = s(100),
                    fontSize = s(40),
                    color = "#B71C1C",
                    borderColor = "#F44336",
                    textColor = "#FFCDD2",
                    onPress = function()
                        if engineRef.current then
                            engineRef.current.hardDrop()
                            setScore(engineRef.current.getScore())
                            setLines(engineRef.current.getLines())
                            setLevel(engineRef.current.getLevel())
                            setUiTick(function(t) return t + 1 end)
                            if engineRef.current.isGameOver() then
                                local finalScore = engineRef.current.getScore()
                                if finalScore > bestScore then
                                    setBestScore(finalScore)
                                    setIsNewBest(true)
                                end
                                setGameOverVisible(true)
                            end
                        end
                    end,
                }),
                createElement(ControlBtn, {
                    label = "▶",
                    size = s(100),
                    color = "#263238",
                    borderColor = "#37474F",
                    onPress = function()
                        if engineRef.current then engineRef.current.moveRight() end
                    end,
                })
            )
        ),

        -- 暂停弹窗
        createElement(PauseOverlay, {
            visible = pauseVisible,
            onResume = function() setPauseVisible(false) end,
            onQuit = function()
                setPauseVisible(false)
                if timerRef.current and timer and timer.cancel then
                    timer.cancel(timerRef.current)
                end
                if engineRef.current then
                    engineRef.current.destroy()
                    engineRef.current = nil
                end
                setScreen("start")
            end,
        }),

        -- Game Over 弹窗
        createElement(GameOverModal, {
            visible = gameOverVisible,
            score = score,
            level = level,
            lines = lines,
            isNewBest = isNewBest,
            onRestart = function()
                setGameOverVisible(false)
                setIsNewBest(false)
                if engineRef.current then
                    engineRef.current.reset()
                    setScore(0)
                    setLevel(1)
                    setLines(0)
                    setCombo(0)
                    setUiTick(function(t) return t + 1 end)
                end
            end,
            onHome = function()
                setGameOverVisible(false)
                if timerRef.current and timer and timer.cancel then
                    timer.cancel(timerRef.current)
                end
                if engineRef.current then
                    engineRef.current.destroy()
                    engineRef.current = nil
                end
                setScreen("start")
            end,
        })
    )
end

return TetrisApp
