-- tetris_scenes/BoardScene.lua
-- SceneAdapter scene factory: renders the tetris game board (imperative)
-- Returns a NEW scene each call to avoid stale state on remount

local SceneAdapter = require("components.SceneAdapter")
local E = require("kitchen_sink.tetris_scenes.engine")

local COLS = E.COLS
local ROWS = E.ROWS

local function hexToRGBA(hex)
    local h = hex:sub(2)
    return tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255
end

local function createBoardScene()
    local scene = SceneAdapter.newScene()
    local alive = false
    local cellObjs = nil
    local engineRef = nil
    local onFrameRef = nil
    local onKeyRef = nil
    local timerRef = nil

    scene:addEventListener("create", {
        create = function(self, event)
            local view = event.view
            local p = event.params or {}
            local engine = p.engine
            if not engine then return end

            local W = event.width or display.contentWidth
            local H = event.height or display.contentHeight
            local SCALE = W / 1536
            local function s(v) return math.floor(v * SCALE + 0.5) end

            local CELL_SIZE = math.floor(math.min((W - s(200)) / COLS, (H - s(500)) / ROWS))
            local GRID_W = CELL_SIZE * COLS
            local GRID_H = CELL_SIZE * ROWS
            local GRID_X = math.floor((W - GRID_W) / 2)
            local GRID_Y = math.floor(H * 0.09)

            -- Grid background
            local gridBg = display.newRect(view, GRID_X, GRID_Y, GRID_W, GRID_H)
            gridBg.anchorX, gridBg.anchorY = 0, 0
            gridBg:setFillColor(0.06, 0.06, 0.12)

            -- Grid border
            local gridBorder = display.newRect(view, GRID_X - 2, GRID_Y - 2, GRID_W + 4, GRID_H + 4)
            gridBorder.anchorX, gridBorder.anchorY = 0, 0
            gridBorder:setFillColor(0, 0, 0, 0)
            gridBorder.strokeWidth = 2
            gridBorder:setStrokeColor(0.2, 0.2, 0.35)

            -- Grid lines
            for c = 1, COLS - 1 do
                local line = display.newLine(view,
                    GRID_X + c * CELL_SIZE, GRID_Y,
                    GRID_X + c * CELL_SIZE, GRID_Y + GRID_H)
                line:setStrokeColor(0.12, 0.12, 0.2)
                line.strokeWidth = 1
            end
            for r = 1, ROWS - 1 do
                local line = display.newLine(view,
                    GRID_X, GRID_Y + r * CELL_SIZE,
                    GRID_X + GRID_W, GRID_Y + r * CELL_SIZE)
                line:setStrokeColor(0.12, 0.12, 0.2)
                line.strokeWidth = 1
            end

            -- Cell display objects
            cellObjs = {}
            for r = 1, ROWS do
                cellObjs[r] = {}
                for c = 1, COLS do
                    local cell = display.newRect(view,
                        GRID_X + (c - 1) * CELL_SIZE + 1,
                        GRID_Y + (r - 1) * CELL_SIZE + 1,
                        CELL_SIZE - 2, CELL_SIZE - 2)
                    cell.anchorX, cell.anchorY = 0, 0
                    cell:setFillColor(0, 0, 0, 0)
                    cell.isVisible = false
                    cellObjs[r][c] = cell
                end
            end

            engineRef = engine

            -- Keyboard input
            local function onKey(ev)
                if ev.phase ~= "down" or not alive then return end
                if engine.isGameOver() then return end
                local k = ev.keyName
                if k == "left"  then engine.moveLeft()
                elseif k == "right" then engine.moveRight()
                elseif k == "up"    then engine.rotate()
                elseif k == "down"  then engine.softDrop()
                elseif k == "space" then engine.hardDrop()
                elseif k == "c" or k == "shift" then engine.hold()
                elseif k == "p" or k == "escape" then
                    if p.onPause then p.onPause() end
                end
            end
            Runtime:addEventListener("key", onKey)
            onKeyRef = onKey

            -- Game timer
            engine.start()
            alive = true
            local function tickLoop()
                if not alive then return end
                if engine.isGameOver() then
                    if p.onGameOver then
                        p.onGameOver({
                            score = engine.getScore(),
                            level = engine.getLevel(),
                            lines = engine.getLines(),
                        })
                    end
                    return
                end
                engine.tick()
                if p.onTick then p.onTick() end
                timerRef = timer.performWithDelay(engine.getSpeed(), tickLoop)
            end
            timerRef = timer.performWithDelay(engine.getSpeed(), tickLoop)
        end,
    })

    scene:addEventListener("show", {
        show = function(self, event)
            if event.phase ~= "did" then return end
            if not engineRef or not cellObjs then return end

            local engine = engineRef
            local function onFrame()
                if not alive or not cellObjs then return end

                local grid = engine.getGrid()
                local cur = engine.getCurrent()
                local ghostY = engine.getGhostY()

                for r = 1, ROWS do
                    for c = 1, COLS do
                        cellObjs[r][c].isVisible = false
                    end
                end

                for r = 1, ROWS do
                    for c = 1, COLS do
                        if grid[r][c] then
                            cellObjs[r][c].isVisible = true
                            cellObjs[r][c]:setFillColor(hexToRGBA(grid[r][c]))
                        end
                    end
                end

                if cur and ghostY and ghostY ~= cur.y then
                    for _, b in ipairs(cur.blocks) do
                        local gc = cur.x + b[1]
                        local gr = ghostY + b[2]
                        if gr >= 1 and gr <= ROWS and gc >= 1 and gc <= COLS then
                            cellObjs[gr][gc].isVisible = true
                            cellObjs[gr][gc]:setFillColor(hexToRGBA(cur.ghostColor))
                        end
                    end
                end

                if cur then
                    for _, b in ipairs(cur.blocks) do
                        local cc = cur.x + b[1]
                        local cr = cur.y + b[2]
                        if cr >= 1 and cr <= ROWS and cc >= 1 and cc <= COLS then
                            cellObjs[cr][cc].isVisible = true
                            cellObjs[cr][cc]:setFillColor(hexToRGBA(cur.color))
                        end
                    end
                end
            end

            Runtime:addEventListener("enterFrame", onFrame)
            onFrameRef = onFrame
        end,
    })

    scene:addEventListener("hide", {
        hide = function(self, event)
            if event.phase ~= "will" then return end
            alive = false
            if onFrameRef then
                Runtime:removeEventListener("enterFrame", onFrameRef)
                onFrameRef = nil
            end
            if timerRef then
                timer.cancel(timerRef)
                timerRef = nil
            end
        end,
    })

    scene:addEventListener("destroy", {
        destroy = function(self, event)
            if onKeyRef then
                Runtime:removeEventListener("key", onKeyRef)
                onKeyRef = nil
            end
            cellObjs = nil
            engineRef = nil
        end,
    })

    return scene
end

return createBoardScene
