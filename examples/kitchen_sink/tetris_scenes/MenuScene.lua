-- tetris_scenes/MenuScene.lua
-- 菜单场景：速度选择 + 最佳记录显示

local SceneAdapter = require("components.SceneAdapter")
local E = require("kitchen_sink.tetris_scenes.engine")

local W = display.contentWidth
local H = display.contentHeight
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

local scene = SceneAdapter.newScene()

scene:addEventListener("create", {
    create = function(self, event)
        local view  = event.view
        local params = event.params or {}
        -- params: { onStart, bestScore, selectedSpeed, setSelectedSpeed }

        local onStart      = params.onStart or function() end
        local bestScore    = params.bestScore or 0
        local selectedSpeed = params.selectedSpeed or 2
        local SPEED_LEVELS = E.SPEED_LEVELS

        -- 背景
        local bg = display.newRect(view, W / 2, H / 2, W, H)
        bg.anchorX, bg.anchorY = 0.5, 0.5
        bg:setFillColor(0.051, 0.067, 0.090)

        -- 方块装饰条
        local blockColors = { "#00BCD4", "#FFEB3B", "#9C27B0", "#F44336" }
        local bSize = s(32)
        local bGap  = s(8)
        local totalDecW = #blockColors * bSize + (#blockColors - 1) * bGap
        local bStartX = W / 2 - totalDecW / 2
        local bY = H * 0.28
        for i, hex in ipairs(blockColors) do
            local bx = bStartX + (i - 1) * (bSize + bGap) + bSize / 2
            local b = display.newRect(view, bx, bY, bSize, bSize)
            b.anchorX, b.anchorY = 0.5, 0.5
            local r, g, bb = E.hexToRGBA(hex)
            b:setFillColor(r, g, bb)
            b.cornerRadius = s(4)
        end

        -- 标题
        local title = display.newText({
            parent = view,
            text   = "TETRIS",
            x      = W / 2,
            y      = H * 0.38,
            font   = native.systemFontBold,
            fontSize = s(96),
        })
        title:setFillColor(1, 1, 1)
        title.anchorX, title.anchorY = 0.5, 0.5

        local subtitle = display.newText({
            parent = view,
            text   = "React-Solar2D",
            x      = W / 2,
            y      = H * 0.38 + s(72),
            font   = native.systemFont,
            fontSize = s(28),
        })
        subtitle:setFillColor(0.329, 0.431, 0.478)
        subtitle.anchorX, subtitle.anchorY = 0.5, 0.5

        -- 速度选择标签
        local selLabel = display.newText({
            parent = view,
            text   = "选择速度",
            x      = W / 2,
            y      = H * 0.56,
            font   = native.systemFont,
            fontSize = s(24),
        })
        selLabel:setFillColor(0.376, 0.490, 0.545)
        selLabel.anchorX, selLabel.anchorY = 0.5, 0.5

        -- 速度按钮
        local btnW = s(320)
        local btnH = s(88)
        local btnGap = s(24)
        local totalBtnW = #SPEED_LEVELS * btnW + (#SPEED_LEVELS - 1) * btnGap
        local bBtnX = W / 2 - totalBtnW / 2

        local speedBtns = {}
        for i, sp in ipairs(SPEED_LEVELS) do
            local bx = bBtnX + (i - 1) * (btnW + btnGap) + btnW / 2
            local by = H * 0.56 + s(48)

            local isSelected = (i == selectedSpeed)
            local sr, sg, sb = E.hexToRGBA(sp.color)

            local btn = display.newRoundedRect(view, bx, by, btnW, btnH, s(16))
            btn.anchorX, btn.anchorY = 0.5, 0.5
            if isSelected then
                btn:setFillColor(sr, sg, sb)
            else
                btn:setFillColor(0.102, 0.137, 0.196)
            end
            btn.strokeWidth = s(2)
            if isSelected then
                btn:setStrokeColor(sr, sg, sb)
            else
                btn:setStrokeColor(0.149, 0.216, 0.220)
            end

            local nameT = display.newText({
                parent = view,
                text   = sp.name,
                x      = bx,
                y      = by - s(12),
                font   = native.systemFontBold,
                fontSize = s(28),
            })
            nameT.anchorX, nameT.anchorY = 0.5, 0.5
            nameT:setFillColor(isSelected and 1 or 0.376, isSelected and 1 or 0.490, isSelected and 1 or 0.545)

            local descT = display.newText({
                parent = view,
                text   = sp.desc,
                x      = bx,
                y      = by + s(16),
                font   = native.systemFont,
                fontSize = s(22),
            })
            descT.anchorX, descT.anchorY = 0.5, 0.5
            descT:setFillColor(isSelected and 0.9 or 0.271, isSelected and 0.9 or 0.353, isSelected and 0.9 or 0.392)

            speedBtns[i] = { btn = btn, nameT = nameT, descT = descT, sp = sp, index = i }

            btn:addEventListener("tap", function()
                -- 视觉更新所有按钮
                for j, sb2 in ipairs(speedBtns) do
                    local sel = (j == i)
                    local r2, g2, b2 = E.hexToRGBA(sb2.sp.color)
                    if sel then
                        sb2.btn:setFillColor(r2, g2, b2)
                        sb2.btn:setStrokeColor(r2, g2, b2)
                        sb2.nameT:setFillColor(1, 1, 1)
                        sb2.descT:setFillColor(0.9, 0.9, 0.9)
                    else
                        sb2.btn:setFillColor(0.102, 0.137, 0.196)
                        sb2.btn:setStrokeColor(0.149, 0.216, 0.220)
                        sb2.nameT:setFillColor(0.376, 0.490, 0.545)
                        sb2.descT:setFillColor(0.271, 0.353, 0.392)
                    end
                end
                selectedSpeed = i
            end)
        end

        -- 开始按钮
        local startY = H * 0.56 + s(48) + btnH / 2 + s(60)
        local sp = SPEED_LEVELS[selectedSpeed]
        local sr, sg, sb = E.hexToRGBA(sp.color)
        local startBtn = display.newRoundedRect(view, W / 2, startY, s(500), s(96), s(28))
        startBtn.anchorX, startBtn.anchorY = 0.5, 0.5
        startBtn:setFillColor(sr, sg, sb)

        local startLabel = display.newText({
            parent = view,
            text   = "START",
            x      = W / 2,
            y      = startY,
            font   = native.systemFontBold,
            fontSize = s(44),
        })
        startLabel.anchorX, startLabel.anchorY = 0.5, 0.5
        startLabel:setFillColor(1, 1, 1)

        startBtn:addEventListener("tap", function()
            onStart(selectedSpeed)
        end)
        startLabel:addEventListener("tap", function()
            onStart(selectedSpeed)
        end)

        -- 最佳记录
        if bestScore and bestScore > 0 then
            local bestY = startY + s(80)
            local bestLbl = display.newText({
                parent = view, text = "最佳记录",
                x = W / 2, y = bestY,
                font = native.systemFont, fontSize = s(22),
            })
            bestLbl.anchorX, bestLbl.anchorY = 0.5, 0.5
            bestLbl:setFillColor(0.271, 0.353, 0.392)

            local bestVal = display.newText({
                parent = view, text = E.formatScore(bestScore),
                x = W / 2, y = bestY + s(36),
                font = native.systemFontBold, fontSize = s(36),
            })
            bestVal.anchorX, bestVal.anchorY = 0.5, 0.5
            bestVal:setFillColor(1, 0.596, 0)
        end

        -- 操作说明
        local hintT = display.newText({
            parent = view,
            text   = "Hold · 左右移动 · 旋转 · 下落",
            x      = W / 2,
            y      = H - s(60),
            font   = native.systemFont,
            fontSize = s(20),
        })
        hintT.anchorX, hintT.anchorY = 0.5, 0.5
        hintT:setFillColor(0.216, 0.278, 0.314)
    end,
})

return scene
