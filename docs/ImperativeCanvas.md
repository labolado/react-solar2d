# ImperativeCanvas / SceneCanvas / SceneAdapter 使用指南

## 概述

React 是声明式的——你描述 UI 应该长什么样，框架负责更新。Solar2D 是命令式的——你调用 `display.newRect`、`transition.to` 来直接操作对象。`ImperativeCanvas` 是两者之间的桥梁：它在 React 树里开辟一块"原生绘图区"，让你可以在 React 管理的布局内运行任意 Solar2D 命令式代码，同时生命周期（挂载/卸载）由 React 自动管理。

---

## ImperativeCanvas 基础用法

最简单的例子：在 React 界面里画一个红色矩形。

```lua
local ImperativeCanvas = require("components.ImperativeCanvas")
local React = require("react")
local ce = React.createElement

local function MyScene()
    return ce(ImperativeCanvas, {
        style = { width = 300, height = 200 },
        onDraw = function(surface, w, h)
            local rect = display.newRect(surface, w / 2, h / 2, w - 20, h - 20)
            rect:setFillColor(0.9, 0.2, 0.2)
        end,
    })
end
```

**参数说明：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `style` | table | 必须包含 `width` 和 `height`，决定绘图区大小 |
| `onDraw` | function | 挂载时调用一次，参数：`(surface, w, h, propsRef)` |
| `onFrame` | function | 每帧调用，参数：`(surface, dt)`，`dt` 单位秒 |
| `onResize` | function | 尺寸变化时调用，参数：`(surface, w, h)` |
| `clip` | boolean | 是否裁剪超出边界的内容（见下文限制） |
| `overlay` | boolean | canvas 是否渲染在 React 子元素上面 |

`onDraw` 里创建的所有 display 对象，插入 `surface` 即可。坐标系以左上角为原点。

**onDraw 可以返回清理函数**——组件卸载时自动调用：

```lua
onDraw = function(surface, w, h)
    local circle = display.newCircle(surface, w / 2, h / 2, 40)
    circle:setFillColor(0.2, 0.6, 1.0)

    -- 返回清理函数（可选）
    return function()
        -- surface 本身会被框架销毁，这里放额外清理
        -- 比如取消 timer、停止音频等
    end
end,
```

---

## 动画（onFrame）

`onFrame` 挂在 `Runtime:addEventListener("enterFrame", ...)` 上，每帧触发。参数 `dt` 是距上一帧的秒数（0.016 ≈ 60fps）。

```lua
local function SpinningBox()
    local angle = 0

    return ce(ImperativeCanvas, {
        style = { width = 200, height = 200 },
        onDraw = function(surface, w, h)
            -- 创建要动画的对象
            local box = display.newRect(surface, w / 2, h / 2, 60, 60)
            box:setFillColor(0.3, 0.8, 0.4)
            -- 把引用存到 surface 上，供 onFrame 访问
            surface._box = box
        end,
        onFrame = function(surface, dt)
            if surface._box then
                surface._box.rotation = surface._box.rotation + 90 * dt
            end
        end,
    })
end
```

`onFrame` 内部通过 `propsRef` 读取最新 props，**不会有 stale closure 问题**，可以直接读父组件传下来的最新状态（见下节）。

---

## Canvas → React 通讯（propsRef 的用法）

Solar2D 事件（touch、collision 等）发生在 canvas 内部，需要通知 React 层。通过回调 prop 传入，在 `onDraw`/`onFrame` 里通过 `propsRef.current` 读取最新版本——这样不管父组件 re-render 多少次，canvas 里永远拿到最新回调，不会读到旧闭包。

```lua
local function TapCounter()
    local count, setCount = React.useState(0)

    local onTap = React.useCallback(function()
        setCount(function(c) return c + 1 end)
    end, {})

    return ce("View", { style = { alignItems = "center" } },
        -- React 层显示计数
        ce("Text", { style = { fontSize = 24 } }, "点击次数: " .. count),

        -- canvas 层捕获 touch，通过 propsRef 回调通知 React
        ce(ImperativeCanvas, {
            style = { width = 200, height = 200 },
            onTap = onTap,  -- 任意自定义 prop 都会在 propsRef 里
            onDraw = function(surface, w, h, propsRef)
                local btn = display.newRect(surface, w / 2, h / 2, 160, 80)
                btn:setFillColor(0.2, 0.5, 0.9)

                btn:addEventListener("tap", function()
                    -- 通过 propsRef.current 读最新回调，避免 stale closure
                    local cb = propsRef.current.onTap
                    if cb then cb() end
                end)
            end,
        })
    )
end
```

**规则：** `onDraw` 里凡是要读父组件数据或回调的地方，一律通过 `propsRef.current.xxx`，不要直接捕获外部变量。

---

## clip 裁剪

`clip = true` 使用 `display.newContainer` 实现超出边界裁剪：

```lua
ce(ImperativeCanvas, {
    style = { width = 200, height = 100 },
    clip = true,
    onDraw = function(surface, w, h)
        -- 画一个超出边界的大圆，只有范围内的部分可见
        local circle = display.newCircle(surface, w / 2, h / 2, 150)
        circle:setFillColor(0.8, 0.4, 0.1)
    end,
})
```

**限制：**
- Solar2D Container 使用 mask，全局最多嵌套 3 层（含 ScrollView 等其他使用 Container 的组件）
- `clip = true` 的 canvas 无法被 `display.save` 截图捕获（Container 内容不参与 bitmap capture）
- 不需要裁剪时，默认 `clip = false` 用 Group，无 mask 消耗

---

## overlay 覆盖

默认情况下 canvas 渲染在 React 子元素**下面**（背景层）。设置 `overlay = true` 则渲染在子元素**上面**：

```lua
-- canvas 作为背景（默认）
ce(ImperativeCanvas, {
    style = { width = 300, height = 200 },
    onDraw = function(surface, w, h)
        -- 背景粒子效果
    end,
},
    ce("Text", {}, "文字显示在粒子上方")
)

-- canvas 作为前景遮罩
ce(ImperativeCanvas, {
    style = { width = 300, height = 200 },
    overlay = true,
    onDraw = function(surface, w, h)
        -- 渲染在 React 子元素上面的遮罩/特效
    end,
},
    ce("Text", {}, "文字被 canvas 遮住")
)
```

---

## SceneCanvas 载入现有 Scene

`SceneCanvas` 让你把已有的 composer scene 嵌入 React，无需大改原始代码。

### 第一步：原始 composer scene

假设你有一个现有 scene `scenes/physics_demo.lua`：

```lua
-- scenes/physics_demo.lua（原始 composer 风格）
local composer = require("composer")
local scene = composer.newScene()

local physicsObjects = {}

function scene:create(event)
    local view = self.view
    -- 创建物理对象
    local ground = display.newRect(view, 160, 450, 320, 20)
    ground:setFillColor(0.4, 0.4, 0.4)
    physics.addBody(ground, "static")
    table.insert(physicsObjects, ground)
end

function scene:show(event)
    if event.phase == "did" then
        physics.start()
    end
end

function scene:hide(event)
    if event.phase == "will" then
        physics.pause()
    end
end

function scene:destroy(event)
    physics.stop()
    physicsObjects = {}
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
```

### 第二步：改用 SceneAdapter

把 `composer.newScene()` 换成 `SceneAdapter.newScene()`，其余保持不变：

```lua
-- scenes/physics_demo.lua（改为 SceneAdapter）
local SceneAdapter = require("components.SceneAdapter")
local scene = SceneAdapter.newScene()

local physicsObjects = {}

function scene:create(event)
    local view = event.view  -- 注意：SceneCanvas 通过 event.view 传入 surface
    local ground = display.newRect(view, 160, 450, 320, 20)
    ground:setFillColor(0.4, 0.4, 0.4)
    physics.addBody(ground, "static")
    table.insert(physicsObjects, ground)
end

function scene:show(event)
    if event.phase == "did" then
        physics.start()
    end
end

function scene:hide(event)
    if event.phase == "will" then
        physics.pause()
    end
end

function scene:destroy(event)
    physics.stop()
    physicsObjects = {}
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
```

### 第三步：在 React 中使用

```lua
local SceneCanvas = require("components.SceneCanvas")
local physicsScene = require("scenes.physics_demo")

local function GameScreen()
    return ce("View", { style = { flex = 1 } },
        -- 顶部 React UI
        ce("View", { style = { height = 60, backgroundColor = "#333" } },
            ce("Text", { style = { color = "#fff", fontSize = 18 } }, "物理演示")
        ),

        -- 嵌入 composer scene
        ce(SceneCanvas, {
            scene = physicsScene,
            params = { level = 1 },  -- 传给 scene:create(event) 的 event.params
            style = { flex = 1 },
        }),

        -- 底部 React UI
        ce("Button", { title = "重置", onPress = function() ... end })
    )
end
```

---

## 生命周期对照表

| composer 事件 | SceneCanvas 触发时机 |
|--------------|---------------------|
| `scene:create` | 组件挂载（mount） |
| `scene:show` phase=`"will"` | 紧跟 create 之后 |
| `scene:show` phase=`"did"` | 紧跟 show will 之后（同帧，非异步） |
| `scene:hide` phase=`"will"` | 组件卸载（unmount）前 |
| `scene:hide` phase=`"did"` | 紧跟 hide will 之后 |
| `scene:destroy` | hide did 之后 |

**注意：** 标准 composer 中 `show:did` 在场景动画结束后触发（异步）；SceneCanvas 中三个初始化事件是同步连续触发的，`show:did` 不等待任何动画。

---

## 限制和注意事项

### 单向嵌入
只支持 **React 包含 Scene**，不支持在 composer scene 里嵌入 React 组件。

### Container 截图限制
`clip = true` 使用 `display.newContainer`，`display.save` 无法捕获其内部内容。如果需要截图功能，去掉 `clip = true`，改用逻辑边界控制。

### mask 嵌套层级
Solar2D 全局最多同时存在 3 层 mask：
- `clip = true` 的 ImperativeCanvas：消耗 1 层
- ScrollView：消耗 1 层
- 三层之后再嵌套会导致裁剪失效（无报错，静默失效）

建议：不需要裁剪时不要开 `clip`，尽量减少 mask 层级。

### onDraw 中的闭包陷阱
`onDraw` 只在挂载时调用一次。如果直接捕获外部变量，会永远读到挂载时刻的值：

```lua
-- 错误：stale closure，count 永远是 0
local count, setCount = React.useState(0)
ce(ImperativeCanvas, {
    onDraw = function(surface, w, h)
        btn:addEventListener("tap", function()
            print(count)  -- 永远是 0！
        end)
    end,
})

-- 正确：通过 propsRef 读最新值
ce(ImperativeCanvas, {
    count = count,  -- 作为 prop 传入
    onDraw = function(surface, w, h, propsRef)
        btn:addEventListener("tap", function()
            print(propsRef.current.count)  -- 永远是最新值
        end)
    end,
})
```

### onFrame 性能
`onFrame` 每帧执行，避免在其中创建新 display 对象或做重 allocation。在 `onDraw` 里创建好对象，`onFrame` 里只更新属性（`.x`、`.rotation` 等）。
