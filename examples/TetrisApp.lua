-- examples/TetrisApp.lua
-- 俄罗斯方块 Demo — React UI + Solar2D game grid
-- React manages: menu, score, next piece preview, game over modal
-- Solar2D manages: game grid rendering (direct display.newRect for performance)
local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useRef = React.useRef
local useEffect = React.useEffect

local W = display.contentWidth
local H = display.contentHeight

-- Game constants
local COLS = 10
local ROWS = 20
local CELL_SIZE = math.floor((W - 120) / COLS)
local GRID_W = CELL_SIZE * COLS
local GRID_H = CELL_SIZE * ROWS
local GRID_X = math.floor((W - GRID_W) / 2)
local GRID_Y = 200

-- Tetromino shapes (4 rotations each)
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

local SHAPE_NAMES = { "I", "O", "T", "S", "Z", "L", "J" }

-- Parse hex color to Solar2D rgba
local function hexToRGBA(hex)
    local h = hex:sub(2)
    return tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255
end

-- Game engine (pure Lua, no React)
local function createGameEngine()
    local engine = {}
    local grid = {} -- grid[row][col] = color or nil
    local currentPiece = nil
    local score = 0
    local level = 1
    local linesCleared = 0
    local gameOver = false
    local displayCells = {} -- displayCells[row][col] = display rect

    -- Initialize empty grid
    for r = 1, ROWS do
        grid[r] = {}
        displayCells[r] = {}
        for c = 1, COLS do
            grid[r][c] = nil
        end
    end

    local function randomPiece()
        local name = SHAPE_NAMES[math.random(#SHAPE_NAMES)]
        local rotations = SHAPES[name]
        return {
            name = name,
            color = COLORS[name],
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
        local r = ROWS
        while r >= 1 do
            local full = true
            for c = 1, COLS do
                if not grid[r][c] then full = false; break end
            end
            if full then
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
            local points = ({ 100, 300, 500, 800 })[cleared] or 800
            score = score + points * level
            linesCleared = linesCleared + cleared
            level = math.floor(linesCleared / 10) + 1
        end
        return cleared
    end

    function engine.init(parentGroup)
        engine.group = parentGroup
        -- Create grid cell display objects
        for r = 1, ROWS do
            for c = 1, COLS do
                local x = GRID_X + (c - 1) * CELL_SIZE
                local y = GRID_Y + (r - 1) * CELL_SIZE
                local rect = display.newRect(parentGroup, x, y, CELL_SIZE - 2, CELL_SIZE - 2)
                rect.anchorX, rect.anchorY = 0, 0
                rect:setFillColor(0.12, 0.12, 0.15)
                rect:setStrokeColor(0.2, 0.2, 0.25)
                rect.strokeWidth = 1
                displayCells[r][c] = rect
            end
        end
        currentPiece = randomPiece()
        engine.nextPiece = randomPiece()
    end

    function engine.render()
        -- Clear all cells
        for r = 1, ROWS do
            for c = 1, COLS do
                local cell = displayCells[r][c]
                if grid[r][c] then
                    local cr, cg, cb = hexToRGBA(grid[r][c])
                    cell:setFillColor(cr, cg, cb)
                else
                    cell:setFillColor(0.12, 0.12, 0.15)
                end
            end
        end
        -- Draw current piece
        if currentPiece then
            local cr, cg, cb = hexToRGBA(currentPiece.color)
            for _, b in ipairs(currentPiece.blocks) do
                local c = currentPiece.x + b[1]
                local r = currentPiece.y + b[2]
                if r >= 1 and r <= ROWS and c >= 1 and c <= COLS then
                    displayCells[r][c]:setFillColor(cr, cg, cb)
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
            clearLines()
            currentPiece = engine.nextPiece
            engine.nextPiece = randomPiece()
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
        if isValid(nextBlocks, currentPiece.x, currentPiece.y) then
            currentPiece.rotation = nextRot
            currentPiece.blocks = nextBlocks
            engine.render()
        end
    end

    function engine.drop()
        if not currentPiece then return end
        while isValid(currentPiece.blocks, currentPiece.x, currentPiece.y + 1) do
            currentPiece.y = currentPiece.y + 1
        end
        engine.render()
    end

    function engine.getScore() return score end
    function engine.getLevel() return level end
    function engine.getLines() return linesCleared end
    function engine.isGameOver() return gameOver end
    function engine.getNextPiece() return engine.nextPiece end

    function engine.reset()
        for r = 1, ROWS do
            for c = 1, COLS do grid[r][c] = nil end
        end
        score = 0; level = 1; linesCleared = 0; gameOver = false
        currentPiece = randomPiece()
        engine.nextPiece = randomPiece()
        engine.render()
    end

    return engine
end

-- Control button component
local function ControlBtn(props)
    return createElement("View", {
        style = {
            width = props.width or 130,
            height = props.height or 100,
            backgroundColor = props.color or "#37474F",
            borderRadius = 16,
            justifyContent = "center",
            alignItems = "center",
        },
        onPress = props.onPress,
    },
        createElement("Text", {
            style = {
                fontSize = props.fontSize or 40,
                color = "#FFFFFF",
                fontWeight = "bold",
            },
        }, props.label)
    )
end

-- Next piece preview
local function NextPiecePreview(props)
    local piece = props.piece
    if not piece then return createElement("View", {}) end

    -- Draw a small preview of the piece
    local previewSize = 24
    local blocks = {}
    for i, b in ipairs(piece.blocks or SHAPES[piece.name][1]) do
        blocks[#blocks + 1] = createElement("View", {
            key = "nb_" .. i,
            style = {
                position = "absolute",
                left = b[1] * previewSize,
                top = b[2] * previewSize,
                width = previewSize - 2,
                height = previewSize - 2,
                backgroundColor = piece.color,
                borderRadius = 4,
            },
        })
    end

    return createElement("View", {
        style = {
            width = previewSize * 4,
            height = previewSize * 4,
        },
    }, unpack(blocks))
end

-- Game Over modal
local function GameOverModal(props)
    if not props.visible then return nil end

    return createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = W, height = H,
            backgroundColor = "rgba(0,0,0,180)",
            justifyContent = "center",
            alignItems = "center",
            zIndex = 100,
        },
    },
        createElement("View", {
            style = {
                width = W * 0.7,
                backgroundColor = "#263238",
                borderRadius = 32,
                padding = 48,
                alignItems = "center",
                borderWidth = 3,
                borderColor = "#F44336",
            },
        },
            createElement("Text", {
                style = { fontSize = 64, fontWeight = "bold", color = "#F44336" },
            }, "GAME OVER"),
            createElement("Text", {
                style = { fontSize = 48, color = "#FFFFFF", marginTop = 24 },
            }, "Score: " .. tostring(props.score)),
            createElement("Text", {
                style = { fontSize = 32, color = "#90A4AE", marginTop = 8 },
            }, "Level " .. tostring(props.level) .. " · " .. tostring(props.lines) .. " lines"),
            createElement("View", {
                style = {
                    marginTop = 40,
                    backgroundColor = "#4CAF50",
                    borderRadius = 20,
                    paddingVertical = 20,
                    paddingHorizontal = 60,
                },
                onPress = props.onRestart,
            },
                createElement("Text", {
                    style = { fontSize = 36, color = "#FFFFFF", fontWeight = "bold" },
                }, "RESTART")
            )
        )
    )
end

-- Main TetrisApp
local function TetrisApp()
    local gameStarted, setGameStarted = useState(false)
    local gameOverVisible, setGameOverVisible = useState(false)
    local score, setScore = useState(0)
    local level, setLevel = useState(1)
    local lines, setLines = useState(0)
    local paused, setPaused = useState(false)
    local engineRef = useRef(nil)
    local timerRef = useRef(nil)

    -- Initialize game engine
    useEffect(function()
        if not gameStarted then return end
        local engine = createGameEngine()
        local gameGroup = display.newGroup()
        engine.init(gameGroup)
        engine.render()
        engineRef.current = engine

        -- Game loop timer
        local function gameLoop()
            if paused then return end
            local alive = engine.tick()
            setScore(engine.getScore())
            setLevel(engine.getLevel())
            setLines(engine.getLines())
            if not alive then
                setGameOverVisible(true)
                if timerRef.current then
                    timer.cancel(timerRef.current)
                end
            end
        end

        local speed = math.max(100, 800 - (level - 1) * 70)
        if timer and timer.performWithDelay then
            timerRef.current = timer.performWithDelay(speed, gameLoop, 0)
        end

        return function()
            if timerRef.current then
                timer.cancel(timerRef.current)
            end
            gameGroup:removeSelf()
        end
    end, {gameStarted, level})

    -- Start screen
    if not gameStarted then
        return createElement("View", {
            style = {
                flex = 1, width = W, height = H,
                backgroundColor = "#1A237E",
                justifyContent = "center",
                alignItems = "center",
            },
        },
            createElement("Text", {
                style = { fontSize = 80, fontWeight = "bold", color = "#FFFFFF" },
            }, "TETRIS"),
            createElement("Text", {
                style = { fontSize = 36, color = "#7986CB", marginTop = 16 },
            }, "React-Solar2D Edition"),
            createElement("View", {
                style = {
                    marginTop = 80,
                    backgroundColor = "#4CAF50",
                    borderRadius = 24,
                    paddingVertical = 28,
                    paddingHorizontal = 80,
                },
                onPress = function()
                    setGameStarted(true)
                end,
            },
                createElement("Text", {
                    style = { fontSize = 48, color = "#FFFFFF", fontWeight = "bold" },
                }, "START")
            )
        )
    end

    -- Game screen (React UI only — grid is rendered by engine directly)
    return createElement("View", {
        style = {
            flex = 1, width = W, height = H,
            backgroundColor = "#0D1117",
        },
    },
        -- Top bar: score + level
        createElement("View", {
            style = {
                height = 160,
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingHorizontal = 40,
                paddingTop = 20,
            },
        },
            -- Score
            createElement("View", {
                style = { alignItems = "center" },
            },
                createElement("Text", {
                    style = { fontSize = 24, color = "#90A4AE" },
                }, "SCORE"),
                createElement("Text", {
                    style = { fontSize = 44, fontWeight = "bold", color = "#FFFFFF" },
                }, tostring(score))
            ),
            -- Level
            createElement("View", {
                style = { alignItems = "center" },
            },
                createElement("Text", {
                    style = { fontSize = 24, color = "#90A4AE" },
                }, "LEVEL"),
                createElement("Text", {
                    style = { fontSize = 44, fontWeight = "bold", color = "#4CAF50" },
                }, tostring(level))
            ),
            -- Lines
            createElement("View", {
                style = { alignItems = "center" },
            },
                createElement("Text", {
                    style = { fontSize = 24, color = "#90A4AE" },
                }, "LINES"),
                createElement("Text", {
                    style = { fontSize = 44, fontWeight = "bold", color = "#FF9800" },
                }, tostring(lines))
            )
        ),

        -- Game grid area is rendered by engine at GRID_X, GRID_Y (not React managed)

        -- Controls (below grid)
        createElement("View", {
            style = {
                position = "absolute",
                bottom = 60,
                left = 0, width = W,
                flexDirection = "row",
                justifyContent = "center",
                gap = 20,
                paddingHorizontal = 40,
            },
        },
            createElement(ControlBtn, {
                label = "◀",
                onPress = function()
                    if engineRef.current then engineRef.current.moveLeft() end
                end,
            }),
            createElement(ControlBtn, {
                label = "▼",
                onPress = function()
                    if engineRef.current then engineRef.current.drop() end
                end,
            }),
            createElement(ControlBtn, {
                label = "↻",
                fontSize = 44,
                onPress = function()
                    if engineRef.current then engineRef.current.rotate() end
                end,
            }),
            createElement(ControlBtn, {
                label = "▶",
                onPress = function()
                    if engineRef.current then engineRef.current.moveRight() end
                end,
            })
        ),

        -- Pause button
        createElement("View", {
            style = {
                position = "absolute",
                top = GRID_Y + GRID_H + 20,
                right = 40,
            },
        },
            createElement(ControlBtn, {
                label = paused and "▶" or "❚❚",
                width = 100, height = 60,
                fontSize = 28,
                color = "#546E7A",
                onPress = function()
                    setPaused(function(p) return not p end)
                end,
            })
        ),

        -- Game over modal
        createElement(GameOverModal, {
            visible = gameOverVisible,
            score = score,
            level = level,
            lines = lines,
            onRestart = function()
                setGameOverVisible(false)
                if engineRef.current then
                    engineRef.current.reset()
                end
                setScore(0)
                setLevel(1)
                setLines(0)
            end,
        })
    )
end

return TetrisApp
