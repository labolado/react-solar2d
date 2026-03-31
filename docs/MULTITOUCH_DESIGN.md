# React-Solar2D 多点触摸支持设计方案

## 1. 现有项目多点触摸模式分析

### 1.1 分析的 7 个文件

| 文件 | 主要触摸模式 | 核心机制 |
|------|-------------|----------|
| `multitouch_canvas.lua` | 多指同时绘制 | 每手指独立 tracking，TouchManager 管理焦点 |
| `multitouch.lua` | 双指缩放+平移 | Tracking dot 模式，计算中心点和平均旋转/缩放 |
| `finger_transform.lua` | 双指缩放（边界模式） | 四角落锚点，单指拖动缩放 |
| `resize_rotate_tool.lua` | 拖拽+缩放+旋转 | 状态机控制，setFocus 管理 |
| `drag_tool.lua` | 单指拖拽 | 网格吸附，速度检测，undo/redo 支持 |
| `touch_handler.lua` | 基础触摸处理 | 单点绘制，Bezier 插值 |
| `scene_game.lua` | 游戏控制 | 简单按钮 tap 事件 |

### 1.2 总结的 5 种触摸模式

1. **单指拖拽 (Single-finger Pan)**
   - 用途: 移动对象、画布平移
   - 实现: `setFocus(target, id)` + `phase: began/moved/ended`
   - 参考: `drag_tool.lua`, `touch_handler.lua:addDragEvent`

2. **双指缩放 (Pinch Scale)**
   - 用途: 放大/缩小对象或画布
   - 实现: 计算两点距离变化 ratio = currentDistance / startDistance
   - 参考: `multitouch.lua:calcAverageScaling`, `finger_transform.lua`

3. **双指旋转 (Two-finger Rotation)**
   - 用途: 旋转对象
   - 实现: 计算两点角度变化 deltaAngle = currentAngle - startAngle
   - 参考: `multitouch.lua:calcAverageRotation`, `resize_rotate_tool.lua`

4. **多指同时操作 (Concurrent Multi-finger)**
   - 用途: 多用户同时绘制、多点协作
   - 实现: `e.id` 区分不同手指，每手指独立状态机
   - 参考: `multitouch_canvas.lua` - 使用 `fingerIdPool` 管理 64 个手指 ID

5. **复合变换 (Combined Transform)**
   - 用途: 缩放+旋转+平移同时进行
   - 实现: 先计算中心点偏移，再应用缩放和旋转矩阵
   - 参考: `multitouch.lua` 中的 pinch 中心点计算

---

## 2. Solar2D Multitouch API 分析

### 2.1 核心 API

```lua
-- 1. 启用多点触摸（默认单点）
system.activate("multitouch")

-- 2. Touch 事件结构
event = {
    id = 0,           -- 手指唯一标识（多指时递增）
    phase = "began|moved|ended|cancelled",
    x = 100,          -- 全局坐标
    y = 100,
    target = obj,     -- 触摸目标
    time = 123456     -- 时间戳
}

-- 3. 焦点管理（关键！）
display.getCurrentStage():setFocus(target, event.id)  -- 设置焦点
display.getCurrentStage():setFocus(target, nil)       -- 释放焦点
display.getCurrentStage():setFocus(nil)               -- 释放所有焦点

-- 4. 触摸监听器注册
obj:addEventListener("touch", handler)
-- handler 可以是函数或表（表的 touch 方法）
```

### 2.2 与 React Native 手势系统对比

| 特性 | Solar2D | React Native (PanResponder) | React Native (GestureHandler) |
|------|---------|----------------------------|------------------------------|
| 启用方式 | `system.activate("multitouch")` | 默认支持 | 默认支持 |
| 手指标识 | `event.id` (number) | `gestureState.numberActiveTouches` | `handler` 自动管理 |
| 焦点管理 | 手动 `setFocus` | 自动 | 自动 |
| 手势识别 | 手动计算 | PanResponder 封装 | 内置手势识别器 |
| 嵌套处理 | 手动处理 | 需要 `onStartShouldSetResponder` | 自动协调 |
| 原生性能 | 直接 | JS 桥接 | 原生线程 |

### 2.3 React Native PanResponder 等价模式

```javascript
// React Native PanResponder
PanResponder.create({
  onStartShouldSetPanResponder: () => true,
  onMoveShouldSetPanResponder: () => true,
  onPanResponderGrant: (e, gestureState) => {},    // = began
  onPanResponderMove: (e, gestureState) => {},      // = moved  
  onPanResponderRelease: (e, gestureState) => {},   // = ended
  onPanResponderTerminate: (e, gestureState) => {}, // = cancelled
})
```

Solar2D 需要手动实现：
- `onStartShouldSetPanResponder` → 检查 `e.phase == "began"` 和 hit-test
- `gestureState.dx/dy` → 手动计算 `e.x - startX`
- `gestureState.numberActiveTouches` → 维护活跃触摸表

---

## 3. React-Solar2D 多点触摸方案设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    React Component Layer                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Pressable  │  │  PanView    │  │  PinchRotateView    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                   Multitouch Manager                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ TouchRouter │  │ FocusManager│  │ GestureRecognizer   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                    Solar2D Native Layer                      │
│           display.addEventListener("touch")                  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 与现有系统共存策略

当前系统状态：
- `Pressable`: 使用 `tap` 事件（单点）
- `ScrollView`: 使用自定义 `touch` 监听，不调用 `setFocus`
- `Slider/Drag`: 使用 `setFocus` + `takeFocus` 机制

共存方案：
1. **ScrollView 保持现状** - 使用 overlay 捕获触摸，不与 multitouch 冲突
2. **新增 MultitouchView** - 显式启用多点触摸，使用 `setFocus(event.id)`
3. **TouchRouter** - 协调 ScrollView 和 MultitouchView 的触摸冲突

---

## 4. API 设计

### 4.1 新组件: MultitouchView

```lua
-- 组件定义
local MultitouchView = require("components.MultitouchView")

-- 基础用法 - 透传所有触摸事件
React.createElement(MultitouchView, {
    style = { width = 300, height = 300 },
    onTouchStart = function(e) end,   -- e = {id, x, y, phase, target}
    onTouchMove = function(e) end,
    onTouchEnd = function(e) end,
    onTouchCancel = function(e) end,
})

-- 高级用法 - 手势识别
React.createElement(MultitouchView, {
    style = { width = 300, height = 300 },
    
    -- 手势回调
    onPan = function(e)
        -- e = {translationX, translationY, velocityX, velocityY, state}
    end,
    
    onPinch = function(e)
        -- e = {scale, focalX, focalY, velocity, state}
    end,
    
    onRotate = function(e)
        -- e = {rotation, anchorX, anchorY, velocity, state}
    end,
    
    -- 配置
    simultaneousHandlers = {},  -- 允许同时识别的 handler ID 列表
    waitFor = {},              -- 需要等待的其他 handler ID
    enabled = true,            -- 是否启用
    
    -- 与 ScrollView 共存
    scrollViewRef = scrollViewRef,  -- 父级 ScrollView 引用
})
```

### 4.2 Hook: useMultitouch

```lua
local useMultitouch = require("hooks.useMultitouch")

-- 基础用法
local touchProps = useMultitouch({
    onTouchStart = function(e) print("Start", e.id) end,
    onTouchMove = function(e) print("Move", e.id, e.x, e.y) end,
    onTouchEnd = function(e) print("End", e.id) end,
})

return React.createElement("View", {
    style = { width = 200, height = 200 },
    -- 展开 touch 事件处理器
    onTouchStart = touchProps.onTouchStart,
    onTouchMove = touchProps.onTouchMove,
    onTouchEnd = touchProps.onTouchEnd,
})

-- PanResponder 风格用法
local panProps = useMultitouch({
    onGrant = function(e, gestureState)
        gestureState.startX = e.x
        gestureState.startY = e.y
    end,
    onMove = function(e, gestureState)
        local dx = e.x - gestureState.startX
        local dy = e.y - gestureState.startY
        -- 处理移动
    end,
    onRelease = function(e, gestureState) end,
})
```

### 4.3 Hook: usePinchRotate

```lua
local usePinchRotate = require("hooks.usePinchRotate")

local transformProps = usePinchRotate({
    onTransformChange = function(transform)
        -- transform = {x, y, scale, rotation}
        setTransform(transform)
    end,
    onTransformEnd = function(transform) end,
    minScale = 0.5,
    maxScale = 3.0,
})

return React.createElement(MultitouchView, {
    style = { width = 300, height = 300 },
    -- 展开变换处理器
    onTouchStart = transformProps.onTouchStart,
    onTouchMove = transformProps.onTouchMove,
    onTouchEnd = transformProps.onTouchEnd,
})
```

### 4.4 ImperativeCanvas Multitouch 支持

```lua
-- ImperativeCanvas 新增 multitouch 透传
React.createElement(ImperativeCanvas, {
    style = { width = 300, height = 300 },
    
    -- 新增: 启用多点触摸
    multitouch = true,
    
    -- 新增: 触摸事件回调（透传 Solar2D 原生事件）
    onTouchStart = function(e, surface)
        -- e = Solar2D touch event
        -- surface = ImperativeCanvas 创建的 drawTarget
    end,
    onTouchMove = function(e, surface) end,
    onTouchEnd = function(e, surface) end,
    
    -- 新增: 多指绘制支持（参考 multitouch_canvas.lua）
    onMultitouchDraw = function(events, surface)
        -- events = { [id] = {x, y, phase} }
    end,
    
    onDraw = function(surface, w, h)
        -- 原有绘制逻辑
    end,
})
```

### 4.5 Pressable Multitouch 扩展

```lua
-- Pressable 新增多点触摸支持
React.createElement(Pressable, {
    style = { width = 100, height = 100 },
    onPress = function(e) end,           -- 原有单点 tap
    onLongPress = function(e) end,       -- 原有长按
    
    -- 新增: 多点触摸支持
    multitouch = true,
    onMultitouchStart = function(e) end,  -- 第二指按下
    onMultitouchMove = function(e) end,
    onMultitouchEnd = function(e) end,
})
```

### 4.6 ScrollView 协调配置

```lua
-- ScrollView 新增多点触摸协调
React.createElement(ScrollView, {
    style = { flex = 1 },
    
    -- 新增: 允许子元素捕获多点触摸
    allowMultitouch = true,
    
    -- 新增: 触摸冲突解决策略
    touchPolicy = "auto",  -- "auto" | "scrollFirst" | "multitouchFirst"
    
    -- 子元素使用 MultitouchView
}, 
    React.createElement(MultitouchView, {
        style = { width = 300, height = 300 },
        scrollViewRef = scrollViewRef,  -- 引用父 ScrollView
        onPinch = function(e) end,
    })
)
```

---

## 5. 核心实现细节

### 5.1 TouchManager 模块

```lua
-- lib/TouchManager.lua
-- 管理多点触摸的焦点和路由

local TouchManager = {
    activeTouches = {},      -- [id] = {target, x, y, phase}
    focusMap = {},          -- [target] = { [id] = true }
    gestureRecognizers = {}, -- 手势识别器列表
}

function TouchManager:activate()
    system.activate("multitouch")
    Runtime:addEventListener("touch", self)
end

function TouchManager:touch(event)
    local id = event.id
    local phase = event.phase
    
    -- 更新活跃触摸表
    if phase == "began" then
        self.activeTouches[id] = {
            startX = event.x,
            startY = event.y,
            x = event.x,
            y = event.y,
        }
    elseif phase == "moved" then
        local touch = self.activeTouches[id]
        if touch then
            touch.prevX = touch.x
            touch.prevY = touch.y
            touch.x = event.x
            touch.y = event.y
        end
    else -- ended/cancelled
        self.activeTouches[id] = nil
    end
    
    -- 路由到对应识别器
    self:routeEvent(event)
    
    return true
end

function TouchManager:setFocus(target, id)
    display.getCurrentStage():setFocus(target, id)
    if not self.focusMap[target] then
        self.focusMap[target] = {}
    end
    self.focusMap[target][id] = true
end

function TouchManager:unsetFocus(target, id)
    display.getCurrentStage():setFocus(target, nil)
    if self.focusMap[target] then
        self.focusMap[target][id] = nil
    end
end

function TouchManager:getActiveTouchCount()
    local count = 0
    for _ in pairs(self.activeTouches) do count = count + 1 end
    return count
end

function TouchManager:getTouches()
    return self.activeTouches
end
```

### 5.2 GestureRecognizer 基类

```lua
-- lib/GestureRecognizer.lua

local GestureRecognizer = {}
GestureRecognizer.__index = GestureRecognizer

function GestureRecognizer.new(config)
    local self = setmetatable({}, GestureRecognizer)
    self.config = config or {}
    self.state = "possible"  -- possible | began | changed | ended | cancelled
    self.touches = {}
    return self
end

function GestureRecognizer:handleTouch(event)
    local phase = event.phase
    local id = event.id
    
    if phase == "began" then
        self.touches[id] = {x = event.x, y = event.y}
        return self:onTouchBegan(event)
    elseif phase == "moved" then
        if not self.touches[id] then return end
        self.touches[id].x = event.x
        self.touches[id].y = event.y
        return self:onTouchMoved(event)
    else
        local result = self:onTouchEnded(event)
        self.touches[id] = nil
        return result
    end
end

-- 子类实现
function GestureRecognizer:onTouchBegan(event) return false end
function GestureRecognizer:onTouchMoved(event) return false end
function GestureRecognizer:onTouchEnded(event) return false end

return GestureRecognizer
```

### 5.3 PinchGestureRecognizer 实现

```lua
-- lib/PinchGestureRecognizer.lua

local GestureRecognizer = require("lib.GestureRecognizer")
local PinchGestureRecognizer = setmetatable({}, {__index = GestureRecognizer})
PinchGestureRecognizer.__index = PinchGestureRecognizer

function PinchGestureRecognizer.new(config)
    local self = GestureRecognizer.new(config)
    setmetatable(self, PinchGestureRecognizer)
    self.type = "pinch"
    self.startDistance = 0
    self.scale = 1
    return self
end

function PinchGestureRecognizer:onTouchBegan(event)
    local touchCount = self:getTouchCount()
    
    if touchCount == 2 then
        -- 第二指按下，开始识别
        local touches = self:getTouchArray()
        self.startDistance = math.sqrt(
            (touches[2].x - touches[1].x)^2 +
            (touches[2].y - touches[1].y)^2
        )
        self.startScale = self.scale
        self.focalX = (touches[1].x + touches[2].x) / 2
        self.focalY = (touches[1].y + touches[2].y) / 2
        self.state = "began"
        
        if self.config.onPinch then
            self.config.onPinch({
                state = "began",
                scale = 1,
                focalX = self.focalX,
                focalY = self.focalY,
            })
        end
        return true
    end
    
    return false
end

function PinchGestureRecognizer:onTouchMoved(event)
    if self.state ~= "began" and self.state ~= "changed" then
        return false
    end
    
    local touchCount = self:getTouchCount()
    if touchCount < 2 then
        self.state = "ended"
        return false
    end
    
    local touches = self:getTouchArray()
    local distance = math.sqrt(
        (touches[2].x - touches[1].x)^2 +
        (touches[2].y - touches[1].y)^2
    )
    
    if self.startDistance > 0 then
        self.scale = self.startScale * (distance / self.startDistance)
        
        -- 限制缩放范围
        if self.config.minScale then
            self.scale = math.max(self.config.minScale, self.scale)
        end
        if self.config.maxScale then
            self.scale = math.min(self.config.maxScale, self.scale)
        end
        
        self.focalX = (touches[1].x + touches[2].x) / 2
        self.focalY = (touches[1].y + touches[2].y) / 2
        self.state = "changed"
        
        if self.config.onPinch then
            self.config.onPinch({
                state = "changed",
                scale = self.scale,
                focalX = self.focalX,
                focalY = self.focalY,
            })
        end
    end
    
    return true
end

function PinchGestureRecognizer:onTouchEnded(event)
    if self.state == "began" or self.state == "changed" then
        self.state = "ended"
        if self.config.onPinch then
            self.config.onPinch({
                state = "ended",
                scale = self.scale,
            })
        end
    end
    return true
end

function PinchGestureRecognizer:getTouchCount()
    local count = 0
    for _ in pairs(self.touches) do count = count + 1 end
    return count
end

function PinchGestureRecognizer:getTouchArray()
    local arr = {}
    for _, touch in pairs(self.touches) do
        table.insert(arr, touch)
    end
    return arr
end

return PinchGestureRecognizer
```

### 5.4 与 ScrollView 的协调实现

```lua
-- MultitouchView 内部协调逻辑

function MultitouchView:shouldCaptureTouch(event)
    -- 如果有父 ScrollView，根据策略决定是否捕获
    if self.scrollViewRef and self.scrollViewRef.current then
        local scrollView = self.scrollViewRef.current
        local policy = scrollView._touchPolicy or "auto"
        
        if policy == "multitouchFirst" then
            return true
        elseif policy == "scrollFirst" then
            return false
        else -- auto
            -- 双指时捕获，单指时让 ScrollView 处理
            local touchCount = TouchManager:getActiveTouchCount()
            return touchCount >= 2
        end
    end
    return true
end

function MultitouchView:touch(event)
    if event.phase == "began" then
        if not self:shouldCaptureTouch(event) then
            return false
        end
        TouchManager:setFocus(self, event.id)
    end
    
    -- 转发到手势识别器
    for _, recognizer in ipairs(self.gestureRecognizers) do
        recognizer:handleTouch(event)
    end
    
    return true
end
```

---

## 6. 使用示例

### 6.1 图片查看器（Pinch to Zoom）

```lua
local React = require("react")
local MultitouchView = require("components.MultitouchView")
local usePinchRotate = require("hooks.usePinchRotate")

local ImageViewer = function(props)
    local transform, setTransform = React.useState({
        x = 0, y = 0, scale = 1, rotation = 0
    })
    
    local pinchProps = usePinchRotate({
        onTransformChange = setTransform,
        minScale = 0.5,
        maxScale = 5,
    })
    
    return React.createElement(MultitouchView, {
        style = { flex = 1 },
        onTouchStart = pinchProps.onTouchStart,
        onTouchMove = pinchProps.onTouchMove,
        onTouchEnd = pinchProps.onTouchEnd,
    }, 
        React.createElement("Image", {
            source = props.source,
            style = {
                width = "100%",
                height = "100%",
                transform = {
                    { translateX = transform.x },
                    { translateY = transform.y },
                    { scale = transform.scale },
                    { rotate = transform.rotation .. "deg" },
                }
            }
        })
    )
end

return ImageViewer
```

### 6.2 多指签名板（参考 multitouch_canvas.lua）

```lua
local React = require("react")
local ImperativeCanvas = require("components.ImperativeCanvas")

local SignaturePad = function(props)
    local strokesRef = React.useRef({})
    
    local handleMultitouchDraw = function(events, surface)
        for id, event in pairs(events) do
            if event.phase == "began" then
                strokesRef.current[id] = {
                    points = {{x = event.x, y = event.y}}
                }
            elseif event.phase == "moved" then
                local stroke = strokesRef.current[id]
                if stroke then
                    table.insert(stroke.points, {x = event.x, y = event.y})
                    -- 绘制线段
                    local n = #stroke.points
                    if n >= 2 then
                        display.newLine(
                            surface,
                            stroke.points[n-1].x, stroke.points[n-1].y,
                            stroke.points[n].x, stroke.points[n].y
                        )
                    end
                end
            else
                strokesRef.current[id] = nil
            end
        end
    end
    
    return React.createElement(ImperativeCanvas, {
        style = props.style,
        multitouch = true,
        onMultitouchDraw = handleMultitouchDraw,
    })
end

return SignaturePad
```

### 6.3 ScrollView 内嵌 MultitouchView

```lua
local React = require("react")
local ScrollView = require("components.ScrollView")
local MultitouchView = require("components.MultitouchView")

local GalleryScreen = function()
    local scrollViewRef = React.useRef(nil)
    
    return React.createElement(ScrollView, {
        style = { flex = 1 },
        ref = scrollViewRef,
        allowMultitouch = true,
    },
        React.createElement(MultitouchView, {
            style = { width = 300, height = 300 },
            scrollViewRef = scrollViewRef,
            onPinch = function(e)
                print("Pinch scale:", e.scale)
            end,
        },
            React.createElement("Image", {
                source = { uri = "image1.jpg" },
                style = { width = 300, height = 300 }
            })
        ),
        -- 更多图片...
    )
end

return GalleryScreen
```

---

## 7. 实现优先级

| 优先级 | 模块 | 工作量 | 依赖 |
|--------|------|--------|------|
| P0 | TouchManager 基础 | 2d | 无 |
| P0 | GestureRecognizer 基类 | 1d | TouchManager |
| P0 | PinchGestureRecognizer | 2d | GestureRecognizer |
| P0 | MultitouchView 组件 | 2d | TouchManager |
| P1 | useMultitouch Hook | 1d | MultitouchView |
| P1 | usePinchRotate Hook | 1d | PinchGestureRecognizer |
| P1 | ImperativeCanvas 扩展 | 1d | MultitouchView |
| P2 | RotateGestureRecognizer | 1d | GestureRecognizer |
| P2 | PanGestureRecognizer | 1d | GestureRecognizer |
| P2 | ScrollView 协调优化 | 2d | MultitouchView |
| P3 | Pressable 多点支持 | 1d | TouchManager |
| P3 | 手势冲突解决策略 | 2d | 所有识别器 |

---

## 8. 参考代码

### 8.1 距离和角度计算（来自 multitouch.lua）

```lua
local function lengthOf(a, b)
    local width, height = b.x - a.x, b.y - a.y
    return math.sqrt(width * width + height * height)
end

local function angleBetweenPoints(a, b)
    local x, y = b.x - a.x, b.y - a.y
    local radian = math.atan2(y, x)
    local angle = radian * 180 / math.pi
    if angle < 0 then angle = 360 + angle end
    return angle
end

local function smallestAngleDiff(target, source)
    local a = target - source
    if a > 180 then
        a = a - 360
    elseif a < -180 then
        a = a + 360
    end
    return a
end
```

### 8.2 多点变换矩阵（参考 multitouch.lua）

```lua
local function rotateAboutPoint(point, centre, degrees)
    local pt = { x = point.x - centre.x, y = point.y - centre.y }
    local theta = math.rad(degrees)
    local x = pt.x * math.cos(theta) - pt.y * math.sin(theta)
    local y = pt.x * math.sin(theta) + pt.y * math.cos(theta)
    return {
        x = x + centre.x,
        y = y + centre.y
    }
end

-- 应用变换：平移 -> 缩放 -> 旋转
local function applyTransform(obj, centre, prevCentre, scale, rotate)
    -- 1. 计算平移
    local pt = {
        x = obj.x + (centre.x - prevCentre.x),
        y = obj.y + (centre.y - prevCentre.y)
    }
    
    -- 2. 应用缩放（围绕中心点）
    pt.x = centre.x + (pt.x - centre.x) * scale
    pt.y = centre.y + (pt.y - centre.y) * scale
    
    -- 3. 应用旋转（围绕中心点）
    pt = rotateAboutPoint(pt, centre, rotate)
    
    obj.x, obj.y = pt.x, pt.y
    obj.xScale = obj.xScale * scale
    obj.yScale = obj.yScale * scale
    obj.rotation = obj.rotation + rotate
end
```

---

## 9. 注意事项

1. **内存管理**: 多点触摸需要跟踪每个手指的状态，注意及时清理已结束触摸的数据
2. **性能优化**: 频繁触摸移动时（如绘制），考虑使用 `graphics.newTexture` 批量绘制
3. **平台差异**: 不同设备对多点触摸的支持程度不同，建议测试 2-5 指场景
4. **与物理引擎共存**: 如果触摸对象同时有物理 body，注意物理模拟和手动变换的冲突
5. **边界处理**: 缩放和旋转时要考虑对象边界，避免失控

---

*文档版本: 1.0*
*创建日期: 2026-03-31*
*基于 labo_papercut_dinosaur 项目代码分析*
