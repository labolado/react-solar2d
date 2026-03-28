-- tetris_scenes/GameScene.lua
-- 主游戏场景：完整保留幽灵方块、Hold、连击、自适应缩放等功能

local SceneAdapter = require("components.SceneAdapter")
local E = require("kitchen_sink.tetris_scenes.engine")

local W = display.contentWidth
local H = display.contentHeight
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

local COLS = E.COLS
local ROWS = E.ROWS
local CELL_SIZE = math.floor(math.min((W - s(200)) / COLS, (H - s(500)) / ROWS))
local GRID_W = CELL_SIZE * COLS
local GRID_H = CELL_SIZE * ROWS
local GRID_X = math.floor((W - GRID_W) / 2)
local GRID_Y = math.floor(H * 0.09)
local PREVIEW_CELL    = math.max(10, math.floor(CELL_SIZE * 0.6))
local PREVIEW_CELL_SM = math.max(8,  math.floor(CELL_SIZE * 0.45))

local scene = SceneAdapter.newScene()

-- ── helpers ──────────────────────────────────────────────────────────────────

local function hexToRGBA(hex)
    local h = hex:sub(2)
    return tonumber(h:sub(1,2),16)/255,
           tonumber(h:sub(3,4),16)/255,
           tonumber(h:sub(5,6),16)/255
end

local function drawPiecePreview(parent, piece, cellSize, cx, cy, label)
    if label then
        local t = display.newText({
            parent = parent,
            text = label,
            x = cx, y = cy - cellSize * 2.5 - s(4),
            font = native.systemFont,
            fontSize = s(20),
        })
        t:setFillColor(0.376, 0.490, 0.545)
        t.anchorX, t.anchorY = 0.5, 1
    end
    if not piece then return end
    local blocks = piece.rotations and piece.rotations[1] or piece.blocks
    local cr, cg, cb = hexToRGBA(piece.color)
    for _, b in ipairs(blocks) do
        local bx = cx - cellSize * 1.5 + b[1] * cellSize + cellSize / 2
        local by = cy - cellSize * 1.5 + b[2] * cellSize + cellSize / 2
        local r = display.newRect(parent, bx, by, cellSize - 2, cellSize - 2)
        r.anchorX, r.anchorY = 0.5, 0.5
        r:setFillColor(cr, cg, cb)
        r.cornerRadius = s(3)
    end
end

local function drawControlBtn(parent, label, bx, by, size, bgHex, borderHex, onTap)
    local br, bg2, bb = hexToRGBA(bgHex)
    local btn = display.newCircle(parent, bx, by, size / 2)
    btn:setFillColor(br, bg2, bb)
    btn.strokeWidth = s(2)
    local sr, sg, sb = hexToRGBA(borderHex)
    btn:setStrokeColor(sr, sg, sb)

    local t = display.newText({
        parent = parent,
        text = label,
        x = bx, y = by,
        font = native.systemFontBold,
        fontSize = s(36),
    })
    t.anchorX, t.anchorY = 0.5, 0.5
    t:setFillColor(0.929, 0.937, 0.945)

    local tap = function() onTap() end
    btn:addEventListener("tap", tap)
    t:addEventListener("tap", tap)
    return btn, t
end

-- ── scene create ─────────────────────────────────────────────────────────────

scene:addEventListener("create", {
    create = function(self, event)
        local view   = event.view
        local params = event.params or {}
        -- params: { speedLevel, onGameOver, onPause }
        local speedLevel = params.speedLevel or 2
        local onGameOver = params.onGameOver or function() end
        local onPause    = params.onPause    or function() end

        -- background
        local bg = display.newRect(view, W / 2, H / 2, W, H)
        bg.anchorX, bg.anchorY = 0.5, 0.5
        bg:setFillColor(0.051, 0.067, 0.090)

        -- grid border
        local gridBorder = display.newRect(view,
            GRID_X + GRID_W / 2, GRID_Y + GRID_H / 2,
            GRID_W + 2, GRID_H + 2)
        gridBorder.anchorX, gridBorder.anchorY = 0.5, 0.5
        gridBorder:setFillColor(0, 0, 0, 0)
        gridBorder.strokeWidth = 2
        gridBorder:setStrokeColor(0.149, 0.216, 0.220)

        -- display cells
        local displayCells = {}
        for r = 1, ROWS do
            displayCells[r] = {}
            for c = 1, COLS do
                local cx = GRID_X + (c - 1) * CELL_SIZE
                local cy = GRID_Y + (r - 1) * CELL_SIZE
                local rect = display.newRect(view, cx, cy, CELL_SIZE - 2, CELL_SIZE - 2)
                rect.anchorX, rect.anchorY = 0, 0
                rect:setFillColor(0.08, 0.08, 0.12)
                rect:setStrokeColor(0.15, 0.15, 0.2)
                rect.strokeWidth = 1
                displayCells[r][c] = rect
            end
        end

        -- ── info panel (score / level / lines) ───────────────────────────────
        local panelX = W / 2
        local panelY = s(60)

        -- score label
        local scoreLbl = display.newText({
            parent = view, text = "分数",
            x = panelX, y = panelY - s(20),
            font = native.systemFont, fontSize = s(22),
        })
        scoreLbl.anchorX, scoreLbl.anchorY = 0.5, 0.5
        scoreLbl:setFillColor(0.376, 0.490, 0.545)

        local scoreVal = display.newText({
            parent = view, text = "0",
            x = panelX, y = panelY + s(16),
            font = native.systemFontBold, fontSize = s(48),
        })
        scoreVal.anchorX, scoreVal.anchorY = 0.5, 0.5
        scoreVal:setFillColor(1, 1, 1)

        -- level / lines row
        local levelLbl = display.newText({
            parent = view, text = "Lv.1",
            x = panelX - s(60), y = panelY + s(56),
            font = native.systemFont, fontSize = s(22),
        })
        levelLbl.anchorX, levelLbl.anchorY = 0.5, 0.5
        levelLbl:setFillColor(0.298, 0.686, 0.314)

        local linesLbl = display.newText({
            parent = view, text = "0行",
            x = panelX + s(60), y = panelY + s(56),
            font = native.systemFont, fontSize = s(22),
        })
        linesLbl.anchorX, linesLbl.anchorY = 0.5, 0.5
        linesLbl:setFillColor(1, 0.596, 0)

        -- combo
        local comboLbl = display.newText({
            parent = view, text = "",
            x = panelX, y = panelY + s(88),
            font = native.systemFontBold, fontSize = s(24),
        })
        comboLbl.anchorX, comboLbl.anchorY = 0.5, 0.5
        comboLbl:setFillColor(1, 0.843, 0)

        -- ── Hold panel (top-left) ────────────────────────────────────────────
        local holdX = GRID_X / 2
        local holdY = GRID_Y + PREVIEW_CELL * 2.5

        local holdBg = display.newRoundedRect(view,
            holdX, holdY,
            PREVIEW_CELL * 4 + s(24), PREVIEW_CELL * 4 + s(40), s(12))
        holdBg.anchorX, holdBg.anchorY = 0.5, 0.5
        holdBg:setFillColor(0.102, 0.137, 0.196)
        holdBg.strokeWidth = 1
        holdBg:setStrokeColor(0.149, 0.216, 0.220)

        -- group for hold piece drawing (recreated on update)
        local holdGroup = display.newGroup()
        holdGroup.x, holdGroup.y = 0, 0
        view:insert(holdGroup)

        local function drawHold(holdPiece)
            for i = holdGroup.numChildren, 1, -1 do
                holdGroup[i]:removeSelf()
            end
            drawPiecePreview(holdGroup, holdPiece, PREVIEW_CELL, holdX, holdY, "HOLD")
        end

        -- ── Next queue panel (top-right) ─────────────────────────────────────
        local nextX = GRID_X + GRID_W + (W - GRID_X - GRID_W) / 2
        local nextGroups = {}

        for i = 1, 3 do
            local cellSz = i == 1 and PREVIEW_CELL or PREVIEW_CELL_SM
            local ny = GRID_Y + (i - 1) * (cellSz * 4 + s(20)) + cellSz * 2.5

            local bg2 = display.newRoundedRect(view,
                nextX, ny,
                cellSz * 4 + s(24), cellSz * 4 + s(40), s(12))
            bg2.anchorX, bg2.anchorY = 0.5, 0.5
            bg2:setFillColor(0.102, 0.137, 0.196)
            if i == 1 then
                bg2.strokeWidth = 1
                bg2:setStrokeColor(0.149, 0.216, 0.220)
            end

            local g = display.newGroup()
            g.x, g.y = 0, 0
            view:insert(g)
            nextGroups[i] = { group = g, x = nextX, y = ny, cellSz = cellSz }
        end

        local function drawNext(nextQueue)
            for i = 1, 3 do
                local ng = nextGroups[i]
                for j = ng.group.numChildren, 1, -1 do
                    ng.group[j]:removeSelf()
                end
                local lbl = i == 1 and "NEXT" or nil
                drawPiecePreview(ng.group, nextQueue[i], ng.cellSz, ng.x, ng.y, lbl)
            end
        end

        -- ── game engine ───────────────────────────────────────────────────────
        local engine = E.createEngine(speedLevel)
        engine.start()

        local function renderGrid()
            local grid = engine.getGrid()
            local cur  = engine.getCurrent()
            local gy   = engine.getGhostY()

            for r = 1, ROWS do
                for c = 1, COLS do
                    local cell = displayCells[r][c]
                    if grid[r][c] then
                        local cr2, cg2, cb2 = hexToRGBA(grid[r][c])
                        cell:setFillColor(cr2, cg2, cb2)
                        cell.alpha = 1
                    else
                        cell:setFillColor(0.08, 0.08, 0.12)
                        cell.alpha = 1
                    end
                end
            end

            -- ghost
            if cur and gy and gy > cur.y then
                local gr2, gg2, gb2 = hexToRGBA(cur.ghostColor)
                for _, b in ipairs(cur.blocks) do
                    local c = cur.x + b[1]
                    local r = gy + b[2]
                    if r >= 1 and r <= ROWS and c >= 1 and c <= COLS then
                        displayCells[r][c]:setFillColor(gr2, gg2, gb2)
                        displayCells[r][c].alpha = 0.5
                    end
                end
            end

            -- current piece
            if cur then
                local cr2, cg2, cb2 = hexToRGBA(cur.color)
                for _, b in ipairs(cur.blocks) do
                    local c = cur.x + b[1]
                    local r = cur.y + b[2]
                    if r >= 1 and r <= ROWS and c >= 1 and c <= COLS then
                        displayCells[r][c]:setFillColor(cr2, cg2, cb2)
                        displayCells[r][c].alpha = 1
                    end
                end
            end
        end

        local function updateUI()
            scoreVal.text = E.formatScore(engine.getScore())
            levelLbl.text = "Lv." .. engine.getLevel()
            linesLbl.text = engine.getLines() .. "行"
            local c = engine.getCombo()
            comboLbl.text = c > 1 and (c .. "x COMBO!") or ""
            drawHold(engine.getHoldPiece())
            drawNext(engine.getNextQueue())
        end

        renderGrid()
        updateUI()

        -- ── game loop timer ───────────────────────────────────────────────────
        local timerRef = { current = nil }
        local paused = false

        local function startTimer()
            if timerRef.current then timer.cancel(timerRef.current) end
            local speed = engine.getSpeed()
            timerRef.current = timer.performWithDelay(speed, function()
                if paused or engine.isGameOver() then return end
                local alive = engine.tick()
                renderGrid()
                updateUI()
                if alive then
                    startTimer()
                else
                    timerRef.current = nil
                    onGameOver({
                        score  = engine.getScore(),
                        level  = engine.getLevel(),
                        lines  = engine.getLines(),
                    })
                end
            end)
        end

        startTimer()

        -- expose pause/resume/action to params callbacks via closures
        -- We store them in params table so parent can call them
        params._setPaused = function(val)
            paused = val
            if not val then startTimer() end
        end
        params._hardDrop = function()
            if paused or engine.isGameOver() then return end
            engine.hardDrop()
            renderGrid()
            updateUI()
            if engine.isGameOver() then
                if timerRef.current then timer.cancel(timerRef.current) end
                timerRef.current = nil
                onGameOver({
                    score = engine.getScore(),
                    level = engine.getLevel(),
                    lines = engine.getLines(),
                })
            end
        end

        -- ── bottom controls ───────────────────────────────────────────────────
        local ctrlY1 = H - s(200)
        local ctrlY2 = H - s(90)

        -- row 1: Hold | Rotate | Pause
        local btnSize1 = s(70)
        local gap1 = s(50)
        local row1Xs = { W/2 - gap1*1.5, W/2, W/2 + gap1*1.5 }

        -- HOLD
        drawControlBtn(view, "H", row1Xs[1], ctrlY1, btnSize1, "#1A237E", "#3F51B5", function()
            if paused or engine.isGameOver() then return end
            engine.hold()
            renderGrid()
            updateUI()
        end)

        -- ROTATE
        drawControlBtn(view, "↻", row1Xs[2], ctrlY1, btnSize1, "#4A148C", "#7B1FA2", function()
            if paused or engine.isGameOver() then return end
            engine.rotate()
            renderGrid()
        end)

        -- PAUSE
        drawControlBtn(view, "||", row1Xs[3], ctrlY1, s(70), "#37474F", "#546E7A", function()
            if engine.isGameOver() then return end
            paused = true
            if timerRef.current then timer.cancel(timerRef.current) end
            timerRef.current = nil
            onPause({
                resume = function()
                    paused = false
                    startTimer()
                end,
                quit = function()
                    paused = true
                    if timerRef.current then timer.cancel(timerRef.current) end
                    timerRef.current = nil
                end,
            })
        end)

        -- row 2: Left | SoftDrop | HardDrop | Right
        local btnSize2 = s(100)
        local gap2 = s(28)
        local totalW2 = 4 * btnSize2 + 3 * gap2
        local startX2 = W / 2 - totalW2 / 2 + btnSize2 / 2

        drawControlBtn(view, "◀", startX2, ctrlY2, btnSize2, "#263238", "#37474F", function()
            if paused or engine.isGameOver() then return end
            engine.moveLeft()
            renderGrid()
        end)

        drawControlBtn(view, "▼", startX2 + (btnSize2 + gap2), ctrlY2, btnSize2, "#263238", "#37474F", function()
            if paused or engine.isGameOver() then return end
            engine.softDrop()
            renderGrid()
            updateUI()
        end)

        drawControlBtn(view, "⬇", startX2 + (btnSize2 + gap2) * 2, ctrlY2, btnSize2, "#B71C1C", "#F44336", function()
            if paused or engine.isGameOver() then return end
            engine.hardDrop()
            renderGrid()
            updateUI()
            if engine.isGameOver() then
                if timerRef.current then timer.cancel(timerRef.current) end
                timerRef.current = nil
                onGameOver({
                    score = engine.getScore(),
                    level = engine.getLevel(),
                    lines = engine.getLines(),
                })
            end
        end)

        drawControlBtn(view, "▶", startX2 + (btnSize2 + gap2) * 3, ctrlY2, btnSize2, "#263238", "#37474F", function()
            if paused or engine.isGameOver() then return end
            engine.moveRight()
            renderGrid()
        end)

        -- cleanup on destroy
        scene._timerRef = timerRef
    end,
})

scene:addEventListener("destroy", {
    destroy = function(self, event)
        if scene._timerRef and scene._timerRef.current then
            timer.cancel(scene._timerRef.current)
            scene._timerRef.current = nil
        end
    end,
})

return scene
