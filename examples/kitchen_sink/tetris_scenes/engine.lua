-- kitchen_sink/tetris_scenes/engine.lua
-- 共享游戏引擎：7-bag、幽灵方块、Hold、连击、分数/等级/行数

local COLS = 10
local ROWS = 20

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

local GHOST_COLORS = {
    I = "#004D56", O = "#665E18", T = "#3E0F48",
    S = "#1B4D1F", Z = "#611B15", L = "#663D00", J = "#0D3A63",
}

local SHAPE_NAMES = { "I", "O", "T", "S", "Z", "L", "J" }

local SCORE_TABLE = { 100, 300, 500, 800 }

local SPEED_LEVELS = {
    { name = "轻松", desc = "慢速下落", base = 1000, color = "#4CAF50" },
    { name = "标准", desc = "经典速度", base = 700,  color = "#FF9800" },
    { name = "极速", desc = "快速下落", base = 400,  color = "#F44336" },
}

local M = {}
M.COLS = COLS
M.ROWS = ROWS
M.SHAPES = SHAPES
M.COLORS = COLORS
M.GHOST_COLORS = GHOST_COLORS
M.SHAPE_NAMES = SHAPE_NAMES
M.SPEED_LEVELS = SPEED_LEVELS

function M.hexToRGBA(hex)
    local h = hex:sub(2)
    return tonumber(h:sub(1,2),16)/255,
           tonumber(h:sub(3,4),16)/255,
           tonumber(h:sub(5,6),16)/255
end

function M.formatScore(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 10000   then return string.format("%.1fK", n / 1000) end
    return tostring(n)
end

function M.createEngine(speedLevel)
    local engine = {}
    local grid = {}
    local currentPiece = nil
    local score = 0
    local level = 1
    local linesCleared = 0
    local gameOver = false
    local combo = 0
    local holdPiece = nil
    local holdUsed = false
    local nextQueue = {}
    local bag = {}
    local baseSpeed = SPEED_LEVELS[speedLevel or 2].base

    for r = 1, ROWS do
        grid[r] = {}
        for c = 1, COLS do grid[r][c] = nil end
    end

    local function randomPiece()
        if #bag == 0 then
            for _, n in ipairs(SHAPE_NAMES) do bag[#bag+1] = n end
            for i = #bag, 2, -1 do
                local j = math.random(i)
                bag[i], bag[j] = bag[j], bag[i]
            end
        end
        local name = table.remove(bag, 1)
        return {
            name     = name,
            color    = COLORS[name],
            ghostColor = GHOST_COLORS[name],
            rotation = 1,
            rotations = SHAPES[name],
            blocks   = SHAPES[name][1],
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
            combo = combo + 1
            local basePoints = SCORE_TABLE[math.min(cleared, 4)]
            local comboBonus = (combo - 1) * 50
            score = score + (basePoints + comboBonus) * level
            linesCleared = linesCleared + cleared
            level = math.floor(linesCleared / 10) + 1
        else
            combo = 0
        end
        return cleared
    end

    -- 初始化方块队列
    local function initQueue()
        bag = {}
        nextQueue = {}
        for i = 1, 3 do nextQueue[i] = randomPiece() end
        currentPiece = randomPiece()
    end

    function engine.start()
        initQueue()
    end

    function engine.getGrid()    return grid end
    function engine.getCurrent() return currentPiece end
    function engine.getGhostY() return getGhostY() end
    function engine.getScore()   return score end
    function engine.getLevel()   return level end
    function engine.getLines()   return linesCleared end
    function engine.getCombo()   return combo end
    function engine.isGameOver() return gameOver end
    function engine.getNextQueue() return nextQueue end
    function engine.getHoldPiece() return holdPiece end
    function engine.getSpeed()
        return math.max(80, baseSpeed - (level - 1) * 50)
    end

    function engine.tick()
        if gameOver then return false end
        if not currentPiece then return false end
        if isValid(currentPiece.blocks, currentPiece.x, currentPiece.y + 1) then
            currentPiece.y = currentPiece.y + 1
        else
            lockPiece()
            holdUsed = false
            clearLines()
            currentPiece = table.remove(nextQueue, 1)
            nextQueue[#nextQueue + 1] = randomPiece()
            if not isValid(currentPiece.blocks, currentPiece.x, currentPiece.y) then
                gameOver = true
                return false
            end
        end
        return true
    end

    function engine.moveLeft()
        if currentPiece and isValid(currentPiece.blocks, currentPiece.x - 1, currentPiece.y) then
            currentPiece.x = currentPiece.x - 1
        end
    end

    function engine.moveRight()
        if currentPiece and isValid(currentPiece.blocks, currentPiece.x + 1, currentPiece.y) then
            currentPiece.x = currentPiece.x + 1
        end
    end

    function engine.rotate()
        if not currentPiece then return end
        local nextRot = (currentPiece.rotation % #currentPiece.rotations) + 1
        local nextBlocks = currentPiece.rotations[nextRot]
        if isValid(nextBlocks, currentPiece.x, currentPiece.y) then
            currentPiece.rotation = nextRot
            currentPiece.blocks = nextBlocks
            return
        end
        for _, dx in ipairs({-1, 1, -2, 2}) do
            if isValid(nextBlocks, currentPiece.x + dx, currentPiece.y) then
                currentPiece.x = currentPiece.x + dx
                currentPiece.rotation = nextRot
                currentPiece.blocks = nextBlocks
                return
            end
        end
    end

    function engine.softDrop()
        if currentPiece and isValid(currentPiece.blocks, currentPiece.x, currentPiece.y + 1) then
            currentPiece.y = currentPiece.y + 1
            score = score + 1
        end
    end

    function engine.hardDrop()
        if not currentPiece then return end
        local dropped = 0
        while isValid(currentPiece.blocks, currentPiece.x, currentPiece.y + 1) do
            currentPiece.y = currentPiece.y + 1
            dropped = dropped + 1
        end
        score = score + dropped * 2
        lockPiece()
        holdUsed = false
        clearLines()
        currentPiece = table.remove(nextQueue, 1)
        nextQueue[#nextQueue + 1] = randomPiece()
        if not isValid(currentPiece.blocks, currentPiece.x, currentPiece.y) then
            gameOver = true
        end
    end

    function engine.hold()
        if holdUsed or not currentPiece then return end
        holdUsed = true
        local pieceToHold = {
            name      = currentPiece.name,
            color     = currentPiece.color,
            ghostColor = currentPiece.ghostColor,
            rotation  = 1,
            rotations = currentPiece.rotations,
            blocks    = currentPiece.rotations[1],
            x = math.floor(COLS / 2) - 1,
            y = 1,
        }
        if holdPiece then
            currentPiece = holdPiece
            currentPiece.x = math.floor(COLS / 2) - 1
            currentPiece.y = 1
        else
            currentPiece = table.remove(nextQueue, 1)
            nextQueue[#nextQueue + 1] = randomPiece()
        end
        holdPiece = pieceToHold
    end

    function engine.reset()
        for r = 1, ROWS do
            for c = 1, COLS do grid[r][c] = nil end
        end
        score = 0; level = 1; linesCleared = 0
        gameOver = false; combo = 0
        holdPiece = nil; holdUsed = false
        initQueue()
    end

    return engine
end

return M
