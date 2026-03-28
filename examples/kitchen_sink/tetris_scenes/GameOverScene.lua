-- tetris_scenes/GameOverScene.lua
-- 游戏结束场景

local SceneAdapter = require("components.SceneAdapter")
local E = require("kitchen_sink.tetris_scenes.engine")

local W = display.contentWidth
local H = display.contentHeight
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

local scene = SceneAdapter.newScene()

scene:addEventListener("create", {
    create = function(self, event)
        local view   = event.view
        local params = event.params or {}
        -- params: { score, level, lines, bestScore, isNewBest, onRestart, onHome }
        local score      = params.score      or 0
        local level      = params.level      or 1
        local lines      = params.lines      or 0
        local bestScore  = params.bestScore  or 0
        local isNewBest  = params.isNewBest  or false
        local onRestart  = params.onRestart  or function() end
        local onHome     = params.onHome     or function() end

        -- dim overlay
        local bg = display.newRect(view, W / 2, H / 2, W, H)
        bg.anchorX, bg.anchorY = 0.5, 0.5
        bg:setFillColor(0, 0, 0, 0.85)

        -- card
        local cardW = W * 0.75
        local cardH = s(620)
        local cardX = W / 2
        local cardY = H / 2

        local card = display.newRoundedRect(view, cardX, cardY, cardW, cardH, s(32))
        card.anchorX, card.anchorY = 0.5, 0.5
        card:setFillColor(0.102, 0.137, 0.196)
        card.strokeWidth = s(2)
        card:setStrokeColor(0.957, 0.263, 0.212) -- red border

        -- GAME OVER title
        local titleY = cardY - cardH / 2 + s(80)
        local title = display.newText({
            parent = view,
            text   = "GAME OVER",
            x      = cardX,
            y      = titleY,
            font   = native.systemFontBold,
            fontSize = s(72),
        })
        title.anchorX, title.anchorY = 0.5, 0.5
        title:setFillColor(0.957, 0.263, 0.212)

        -- score box
        local boxY = titleY + s(130)
        local box = display.newRoundedRect(view, cardX, boxY, cardW - s(80), s(200), s(20))
        box.anchorX, box.anchorY = 0.5, 0.5
        box:setFillColor(0.051, 0.067, 0.090)

        local scoreLbl = display.newText({
            parent = view, text = "最终得分",
            x = cardX, y = boxY - s(68),
            font = native.systemFont, fontSize = s(22),
        })
        scoreLbl.anchorX, scoreLbl.anchorY = 0.5, 0.5
        scoreLbl:setFillColor(0.376, 0.490, 0.545)

        local scoreVal = display.newText({
            parent = view, text = E.formatScore(score),
            x = cardX, y = boxY - s(20),
            font = native.systemFontBold, fontSize = s(72),
        })
        scoreVal.anchorX, scoreVal.anchorY = 0.5, 0.5
        scoreVal:setFillColor(1, 1, 1)

        -- stats row: level / lines / avg
        local pct = lines > 0 and math.floor(score / lines) or 0
        local statsData = {
            { val = tostring(level), lbl = "等级",   color = "#4CAF50" },
            { val = tostring(lines), lbl = "行数",   color = "#FF9800" },
            { val = tostring(pct),   lbl = "每行均分", color = "#2196F3" },
        }
        local statSpacing = (cardW - s(80)) / 3
        for i, st in ipairs(statsData) do
            local sx = cardX - (cardW - s(80)) / 2 + (i - 0.5) * statSpacing
            local sy = boxY + s(60)
            local sr, sg, sb = E.hexToRGBA(st.color)

            local vt = display.newText({
                parent = view, text = st.val,
                x = sx, y = sy,
                font = native.systemFontBold, fontSize = s(32),
            })
            vt.anchorX, vt.anchorY = 0.5, 0.5
            vt:setFillColor(sr, sg, sb)

            local lt = display.newText({
                parent = view, text = st.lbl,
                x = sx, y = sy + s(36),
                font = native.systemFont, fontSize = s(22),
            })
            lt.anchorX, lt.anchorY = 0.5, 0.5
            lt:setFillColor(0.376, 0.490, 0.545)
        end

        -- new best badge
        local badgeY = boxY + s(128)
        if isNewBest then
            local badge = display.newText({
                parent = view, text = "★ 新纪录！★",
                x = cardX, y = badgeY,
                font = native.systemFontBold, fontSize = s(28),
            })
            badge.anchorX, badge.anchorY = 0.5, 0.5
            badge:setFillColor(1, 0.843, 0)
        elseif bestScore > 0 then
            local bestT = display.newText({
                parent = view, text = "最佳: " .. E.formatScore(bestScore),
                x = cardX, y = badgeY,
                font = native.systemFont, fontSize = s(24),
            })
            bestT.anchorX, bestT.anchorY = 0.5, 0.5
            bestT:setFillColor(0.376, 0.490, 0.545)
        end

        -- buttons
        local btnY = cardY + cardH / 2 - s(80)
        local btnW = s(220)
        local btnH = s(80)
        local btnGap = s(24)

        -- Restart button (green)
        local restartBtn = display.newRoundedRect(view,
            cardX - btnW / 2 - btnGap / 2, btnY, btnW, btnH, s(20))
        restartBtn.anchorX, restartBtn.anchorY = 0.5, 0.5
        restartBtn:setFillColor(0.298, 0.686, 0.314)

        local restartLbl = display.newText({
            parent = view, text = "再来",
            x = cardX - btnW / 2 - btnGap / 2, y = btnY,
            font = native.systemFontBold, fontSize = s(32),
        })
        restartLbl.anchorX, restartLbl.anchorY = 0.5, 0.5
        restartLbl:setFillColor(1, 1, 1)

        local function doRestart() onRestart() end
        restartBtn:addEventListener("tap", doRestart)
        restartLbl:addEventListener("tap", doRestart)

        -- Home button (gray)
        local homeBtn = display.newRoundedRect(view,
            cardX + btnW / 2 + btnGap / 2, btnY, btnW, btnH, s(20))
        homeBtn.anchorX, homeBtn.anchorY = 0.5, 0.5
        homeBtn:setFillColor(0.149, 0.216, 0.220)
        homeBtn.strokeWidth = s(2)
        homeBtn:setStrokeColor(0.271, 0.353, 0.392)

        local homeLbl = display.newText({
            parent = view, text = "首页",
            x = cardX + btnW / 2 + btnGap / 2, y = btnY,
            font = native.systemFont, fontSize = s(32),
        })
        homeLbl.anchorX, homeLbl.anchorY = 0.5, 0.5
        homeLbl:setFillColor(0.929, 0.937, 0.945)

        local function doHome() onHome() end
        homeBtn:addEventListener("tap", doHome)
        homeLbl:addEventListener("tap", doHome)
    end,
})

return scene
