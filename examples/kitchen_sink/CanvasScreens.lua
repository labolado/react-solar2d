-- examples/kitchen_sink/CanvasScreens.lua
local React = require("react")
local ce = React.createElement
local useState = React.useState
local useCallback = React.useCallback
local T = require("kitchen_sink.theme")
local RN = require("react_solar2d")
local ImperativeCanvas = require("components.ImperativeCanvas")
local SceneCanvas = require("components.SceneCanvas")
local SceneAdapter = require("components.SceneAdapter")
local Section = T.Section
local DemoPage = T.DemoPage

-- Card wrapper for each demo
local function DemoCard(props)
    return ce("View", {
        style = {
            backgroundColor = T.surface,
            borderRadius = T.radius,
            padding = T.pad,
            marginBottom = T.gap,
            borderWidth = 1,
            borderColor = T.border,
        },
    },
        ce("Text", {
            style = { fontSize = 16, color = T.textPrimary, fontWeight = "bold", marginBottom = 4 },
        }, props.title),
        ce("Text", {
            style = { fontSize = 12, color = T.textSecondary, marginBottom = 12 },
        }, props.description),
        props.children
    )
end

-- Demo 1: Basic Drawing with touch interaction
local function BasicDrawingDemo()
    local circlesRef = React.useRef({})
    local nextIdRef = React.useRef(1)

    local onDraw = useCallback(function(surface, w, h)
        -- Background
        local bg = display.newRect(surface, w / 2, h / 2, w, h)
        bg:setFillColor(0.05, 0.05, 0.08)

        -- Static rectangles
        local rect1 = display.newRect(surface, 60, 50, 80, 60)
        rect1:setFillColor(0.9, 0.3, 0.3)
        rect1.cornerRadius = 8

        local rect2 = display.newRect(surface, w - 60, 50, 80, 60)
        rect2:setFillColor(0.3, 0.7, 0.9)
        rect2.cornerRadius = 8

        -- Static circles
        for i = 1, 3 do
            local circle = display.newCircle(surface, 50 + i * 60, 120, 20)
            circle:setFillColor(0.2 + i * 0.2, 0.8, 0.4)
        end

        -- Touch to add circles
        local touchArea = display.newRect(surface, w / 2, h / 2, w, h)
        touchArea:setFillColor(0, 0, 0, 0) -- invisible
        touchArea.isHitTestable = true

        touchArea:addEventListener("tap", function(event)
            local id = nextIdRef.current
            nextIdRef.current = id + 1
            local newCircle = display.newCircle(surface, event.x, event.y, 15 + math.random() * 15)
            local r, g, b = math.random() * 0.5 + 0.5, math.random() * 0.5 + 0.5, math.random() * 0.5 + 0.5
            newCircle:setFillColor(r, g, b)
            circlesRef.current[id] = newCircle
        end)

        surface._touchArea = touchArea
    end, {})

    return ce(DemoCard, {
        title = "基础绘图",
        description = "彩色圆圈和矩形，触摸 canvas 添加新圆圈",
    },
        ce(ImperativeCanvas, {
            style = { width = 300, height = 180 },
            onDraw = onDraw,
        })
    )
end

-- Demo 2: Animation with onFrame
local function AnimationDemo()
    local onDraw = useCallback(function(surface, w, h)
        -- Background
        local bg = display.newRect(surface, w / 2, h / 2, w, h)
        bg:setFillColor(0.08, 0.08, 0.12)

        -- Rotating box
        local box = display.newRect(surface, w / 2 - 60, h / 2, 50, 50)
        box:setFillColor(0.9, 0.5, 0.2)
        surface._box = box

        -- Bouncing ball
        local ball = display.newCircle(surface, w / 2 + 60, h / 2, 25)
        ball:setFillColor(0.3, 0.8, 0.5)
        surface._ball = ball
        surface._ballDir = 1
        surface._ballY = h / 2
    end, {})

    local onFrame = useCallback(function(surface, dt)
        -- Rotate box
        if surface._box then
            surface._box.rotation = (surface._box.rotation or 0) + 90 * dt
        end

        -- Bounce ball
        if surface._ball then
            local speed = 120
            surface._ballY = surface._ballY + surface._ballDir * speed * dt
            if surface._ballY > 140 then
                surface._ballY = 140
                surface._ballDir = -1
            elseif surface._ballY < 40 then
                surface._ballY = 40
                surface._ballDir = 1
            end
            surface._ball.y = surface._ballY
        end
    end, {})

    return ce(DemoCard, {
        title = "动画 (onFrame)",
        description = "旋转方块 + 弹跳球，使用 onFrame 回调",
    },
        ce(ImperativeCanvas, {
            style = { width = 300, height = 180 },
            onDraw = onDraw,
            onFrame = onFrame,
        })
    )
end

-- Demo 3: Scene Switching with SceneCanvas
local function SceneSwitchingDemo()
    local currentScene, setCurrentScene = useState("A")

    -- Scene A: Blue background with moving circle
    local sceneA = React.useMemo(function()
        local scene = SceneAdapter.newScene()
        local circle = nil
        local circleX = 50
        local direction = 1

        scene:addEventListener("create", {
            create = function(self, event)
                local view = event.view
                local bg = display.newRect(view, 150, 90, 300, 180)
                bg:setFillColor(0.15, 0.35, 0.65)

                circle = display.newCircle(view, 50, 90, 30)
                circle:setFillColor(0.9, 0.9, 0.3)
            end,
        })

        scene:addEventListener("show", {
            show = function(self, event)
                if event.phase == "did" then
                    Runtime:addEventListener("enterFrame", function(e)
                        if not circle then return end
                        circleX = circleX + direction * 2
                        if circleX > 250 then
                            circleX = 250
                            direction = -1
                        elseif circleX < 50 then
                            circleX = 50
                            direction = 1
                        end
                        circle.x = circleX
                    end)
                end
            end,
        })

        return scene
    end, {})

    -- Scene B: Green background with rotating square
    local sceneB = React.useMemo(function()
        local scene = SceneAdapter.newScene()
        local square = nil

        scene:addEventListener("create", {
            create = function(self, event)
                local view = event.view
                local bg = display.newRect(view, 150, 90, 300, 180)
                bg:setFillColor(0.2, 0.55, 0.3)

                square = display.newRect(view, 150, 90, 60, 60)
                square:setFillColor(0.9, 0.4, 0.3)
            end,
        })

        scene:addEventListener("show", {
            show = function(self, event)
                if event.phase == "did" then
                    Runtime:addEventListener("enterFrame", function(e)
                        if square then
                            square.rotation = (square.rotation or 0) + 3
                        end
                    end)
                end
            end,
        })

        return scene
    end, {})

    local activeScene = currentScene == "A" and sceneA or sceneB

    return ce(DemoCard, {
        title = "Scene 切换",
        description = "SceneCanvas + SceneAdapter，点击按钮切换场景",
    },
        ce("View", {},
            -- SceneCanvas with key to trigger full unmount/mount
            ce(SceneCanvas, {
                key = currentScene,
                scene = activeScene,
                style = { width = 300, height = 180 },
            }),
            -- Switch buttons
            ce("View", {
                style = { flexDirection = "row", gap = 12, marginTop = 12, justifyContent = "center" },
            },
                ce(RN.Button, {
                    title = "场景 A",
                    color = currentScene == "A" and T.accent or T.border,
                    onPress = function() setCurrentScene("A") end,
                }),
                ce(RN.Button, {
                    title = "场景 B",
                    color = currentScene == "B" and T.accent or T.border,
                    onPress = function() setCurrentScene("B") end,
                })
            )
        )
    )
end

-- Main Canvas Demo Page
local function CanvasDemoPage()
    return ce(DemoPage, {},
        ce(BasicDrawingDemo),
        ce(AnimationDemo),
        ce(SceneSwitchingDemo)
    )
end

-- Tetris full-screen demo (SceneCanvas architecture)
local TetrisApp = require("TetrisApp")

local function TetrisPage(props)
    return ce(TetrisApp)
end

return {
    { name = "Canvas", component = CanvasDemoPage, description = "ImperativeCanvas & SceneCanvas", icon = "C" },
    { name = "Tetris", component = TetrisPage, description = "SceneCanvas 场景架构俄罗斯方块", icon = "T" },
}
