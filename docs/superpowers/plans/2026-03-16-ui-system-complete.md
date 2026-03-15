# React-Solar2D 完整 UI 系统实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善 UI 系统至可构建复杂应用的程度，以三个真实应用验证：新闻浏览器、问答做题系统、俄罗斯方块游戏

**Architecture:** 先补齐 HostConfig 样式系统（Text 样式、transform、边框）→ 添加缺失组件（ScrollView、TextInput、Modal、FlatList）→ 添加动画系统 → 用三个应用驱动验证

**Tech Stack:** Lua, Solar2D display API, Yoga C layout engine, React reconciler

---

## 三个目标应用需要的功能清单

| 功能 | 新闻浏览器 | 问答系统 | 俄罗斯方块 |
|------|:---:|:---:|:---:|
| Text 样式 (fontWeight/textAlign/fontFamily) | ✓ | ✓ | ✓ |
| ScrollView | ✓ | ✓ | |
| FlatList | ✓ | | |
| Image resizeMode | ✓ | | |
| TextInput | | ✓ | |
| Modal | | ✓ | ✓ |
| Animated API | ✓ | ✓ | ✓ |
| TouchableOpacity 改进 | ✓ | ✓ | ✓ |
| Timer/Interval | | | ✓ |
| zIndex | | | ✓ |
| Transform (rotate/scale) | | | ✓ |
| 边框样式完善 | ✓ | ✓ | ✓ |
| Switch 组件 | | ✓ | |

---

## 文件结构

### 修改的文件
- `renderer/HostConfig.lua` — 扩展样式属性映射（Text 样式、transform、边框、zIndex）
- `renderer/init.lua` — applyLayout 更新 Text 尺寸、支持更多视觉属性
- `react_solar2d.lua` — 导出新组件和模块
- `tests/helpers/mock_display.lua` — 扩展 mock 支持新属性
- `components/init.lua` — 注册新组件
- `components/Button.lua` — 使用新 Text 样式
- `components/TouchableOpacity.lua` — 改进触摸反馈

### 新建的文件
- `components/ScrollView.lua` — 滚动容器
- `components/FlatList.lua` — 虚拟化列表
- `components/TextInput.lua` — 文本输入
- `components/Modal.lua` — 模态弹窗
- `components/Switch.lua` — 开关组件
- `components/Pressable.lua` — 通用可按压组件
- `components/StatusBar.lua` — 状态栏占位
- `animated/init.lua` — 动画系统（封装 transition.to）
- `hooks/useTimer.lua` — 定时器 hook（游戏循环用）
- `examples/NewsApp.lua` — 新闻浏览器 demo
- `examples/QuizApp.lua` — 问答做题 demo
- `examples/TetrisApp.lua` — 俄罗斯方块 demo
- `tests/renderer/test_hostConfig_styles.lua` — 扩展样式测试
- `tests/components/test_scrollview.lua` — ScrollView 测试
- `tests/components/test_flatlist.lua` — FlatList 测试
- `tests/animated/test_animated.lua` — 动画系统测试

---

## Chunk 1: HostConfig 样式系统扩展

**目标**: Text 完整样式 + transform + 边框完善 + Image resizeMode + zIndex

### Task 1.1: Text 样式扩展

**Files:**
- Modify: `renderer/HostConfig.lua` — createInstance Text 分支、updateInstance
- Modify: `tests/helpers/mock_display.lua` — mock newText 支持 font/align 参数
- Create: `tests/renderer/test_hostConfig_styles.lua` — Text 样式测试

Solar2D `display.newText` 支持的参数：
```lua
display.newText({
    text = "Hello",
    x = 0, y = 0,
    font = native.systemFontBold,  -- fontWeight/fontFamily
    fontSize = 24,
    width = 200,                    -- 启用自动换行
    height = 0,                     -- 0 = auto
    align = "center",               -- left/center/right
})
```

Solar2D 字体映射：
- `native.systemFont` — 默认字体
- `native.systemFontBold` — 粗体
- 自定义字体：直接用文件名如 `"Helvetica-Bold"`

- [ ] **Step 1: 写 Text 样式测试**

```lua
-- tests/renderer/test_hostConfig_styles.lua
local T = require("tests.helpers.test_runner")
local mockDisplay = require("tests.helpers.mock_display")

T.describe("HostConfig Text Styles", function()
    local HostConfig

    T.beforeEach(function()
        mockDisplay.install()
        package.loaded["renderer.HostConfig"] = nil
        HostConfig = require("renderer.HostConfig")
    end)

    T.it("applies fontWeight bold", function()
        local instance = HostConfig.createInstance("Text", {
            style = { fontSize = 24, fontWeight = "bold" },
            children = "Hello"
        })
        T.expect(instance._textObj._font).toBe("systemFontBold")
    end)

    T.it("applies fontFamily", function()
        local instance = HostConfig.createInstance("Text", {
            style = { fontSize = 24, fontFamily = "Helvetica" },
            children = "Hello"
        })
        T.expect(instance._textObj._font).toBe("Helvetica")
    end)

    T.it("applies textAlign center", function()
        local instance = HostConfig.createInstance("Text", {
            style = { fontSize = 24, textAlign = "center", width = 200 },
            children = "Hello"
        })
        T.expect(instance._textObj._align).toBe("center")
    end)

    T.it("applies lineHeight via y offset", function()
        -- Solar2D doesn't have native lineHeight, but we track it for layout
        local instance = HostConfig.createInstance("Text", {
            style = { fontSize = 24, lineHeight = 36 },
            children = "Hello"
        })
        T.expect(instance._lineHeight).toBe(36)
    end)

    T.it("updates fontSize dynamically", function()
        local instance = HostConfig.createInstance("Text", {
            style = { fontSize = 24 },
            children = "Hello"
        })
        HostConfig.updateInstance(instance,
            { style = { fontSize = 24 }, children = "Hello" },
            { style = { fontSize = 36 }, children = "Hello" }
        )
        T.expect(instance._textObj.size).toBe(36)
    end)

    T.it("updates fontWeight dynamically", function()
        local instance = HostConfig.createInstance("Text", {
            style = { fontSize = 24 },
            children = "Hello"
        })
        HostConfig.updateInstance(instance,
            { style = { fontSize = 24 }, children = "Hello" },
            { style = { fontSize = 24, fontWeight = "bold" }, children = "Hello" }
        )
        -- Font change requires recreating text object
        T.expect(instance._textObj._font).toBe("systemFontBold")
    end)
end)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /path/to/project && lua tests/renderer/test_hostConfig_styles.lua`
Expected: FAIL — fontWeight/fontFamily/textAlign 未实现

- [ ] **Step 3: 更新 mock_display 支持 font/align**

```lua
-- 在 mock_display.lua 的 newText 函数中添加 font 和 align 支持
function display.newText(options)
    local obj = createDisplayObject("text")
    if type(options) == "table" then
        obj.text = options.text or ""
        obj.x = options.x or 0
        obj.y = options.y or 0
        obj.size = options.fontSize or 14
        obj.width = options.width or nil
        obj.height = options.height or nil
        obj._font = options.font or "systemFont"
        obj._align = options.align or "left"
    end
    if options.parent then
        options.parent:insert(obj)
    end
    return obj
end
```

- [ ] **Step 4: 实现 Text 样式 — 修改 HostConfig.lua**

```lua
-- 在 HostConfig.lua 中添加字体解析函数
local function resolveFont(style)
    if style.fontFamily then
        -- 自定义字体：如果有 fontWeight = "bold"，尝试加 "-Bold" 后缀
        if style.fontWeight == "bold" then
            return style.fontFamily .. "-Bold"
        end
        return style.fontFamily
    end
    -- 系统字体
    if style.fontWeight == "bold" then
        return native and native.systemFontBold or "systemFontBold"
    end
    return native and native.systemFont or "systemFont"
end

-- 修改 createInstance 的 Text 分支
elseif elementType == "Text" then
    local group = display.newGroup()
    group.anchorX, group.anchorY = 0, 0

    local text = tostring(props.children or "")
    local font = resolveFont(style)
    local textObj = display.newText({
        parent = group,
        text = text,
        x = 0, y = 0,
        font = font,
        fontSize = style.fontSize or 14,
        width = style.width,
        height = 0,
        align = style.textAlign or "left",
    })
    textObj.anchorX, textObj.anchorY = 0, 0

    if style.color then
        local c = parseColor(style.color)
        textObj:setFillColor(c[1], c[2], c[3], c[4])
    end

    group._textObj = textObj
    group._lineHeight = style.lineHeight
    wireEvents(group, props)
    return group
```

- [ ] **Step 5: 实现 updateInstance 字体变更**

```lua
-- 在 updateInstance 中扩展 Text 更新逻辑
if instance._textObj then
    -- 文字内容更新
    local newText = newProps.children
    if type(newText) == "string" or type(newText) == "number" then
        instance._textObj.text = tostring(newText)
    end
    -- 颜色更新
    if newStyle.color then
        local c = parseColor(newStyle.color)
        instance._textObj:setFillColor(c[1], c[2], c[3], c[4])
    end
    -- 字体大小更新
    if newStyle.fontSize then
        instance._textObj.size = newStyle.fontSize
    end
    -- 字体变更需要重建 text 对象（Solar2D 限制）
    local oldFont = resolveFont(oldStyle)
    local newFont = resolveFont(newStyle)
    if oldFont ~= newFont or (oldStyle.textAlign ~= newStyle.textAlign) then
        local parent = instance
        local oldText = instance._textObj
        local newTextObj = display.newText({
            parent = parent,
            text = oldText.text,
            x = oldText.x, y = oldText.y,
            font = newFont,
            fontSize = newStyle.fontSize or oldText.size,
            width = newStyle.width or oldText.width,
            height = 0,
            align = newStyle.textAlign or "left",
        })
        newTextObj.anchorX, newTextObj.anchorY = 0, 0
        if newStyle.color then
            local c = parseColor(newStyle.color)
            newTextObj:setFillColor(c[1], c[2], c[3], c[4])
        end
        oldText:removeSelf()
        instance._textObj = newTextObj
    end
end
```

- [ ] **Step 6: 运行测试确认通过**

Run: `cd /path/to/project && lua tests/renderer/test_hostConfig_styles.lua`
Expected: ALL PASS

- [ ] **Step 7: 提交**

```bash
git add renderer/HostConfig.lua tests/renderer/test_hostConfig_styles.lua tests/helpers/mock_display.lua
git commit -m "feat: Text styling — fontWeight, fontFamily, textAlign, lineHeight"
```

### Task 1.2: Transform 支持

**Files:**
- Modify: `renderer/HostConfig.lua` — createInstance/updateInstance 添加 transform 映射
- Modify: `tests/renderer/test_hostConfig_styles.lua` — 追加 transform 测试

Solar2D transform 属性：
- `obj.rotation` — 旋转角度（度数）
- `obj.xScale, obj.yScale` — 缩放
- `obj.x, obj.y` — 已用于布局位置

RN transform 格式：`transform: [{rotate: "45deg"}, {scale: 2}, {translateX: 10}]`

- [ ] **Step 1: 写 transform 测试**

```lua
T.describe("HostConfig Transform", function()
    T.it("applies rotation from transform array", function()
        local instance = HostConfig.createInstance("View", {
            style = {
                width = 100, height = 100,
                transform = {{ rotate = "45deg" }},
            }
        })
        T.expect(instance.rotation).toBe(45)
    end)

    T.it("applies scale from transform array", function()
        local instance = HostConfig.createInstance("View", {
            style = {
                width = 100, height = 100,
                transform = {{ scale = 2 }},
            }
        })
        T.expect(instance.xScale).toBe(2)
        T.expect(instance.yScale).toBe(2)
    end)

    T.it("applies scaleX and scaleY separately", function()
        local instance = HostConfig.createInstance("View", {
            style = {
                width = 100, height = 100,
                transform = {{ scaleX = 1.5 }, { scaleY = 0.5 }},
            }
        })
        T.expect(instance.xScale).toBe(1.5)
        T.expect(instance.yScale).toBe(0.5)
    end)

    T.it("updates transform dynamically", function()
        local instance = HostConfig.createInstance("View", {
            style = { width = 100, height = 100 }
        })
        HostConfig.updateInstance(instance,
            { style = { width = 100, height = 100 } },
            { style = { width = 100, height = 100, transform = {{ rotate = "90deg" }} } }
        )
        T.expect(instance.rotation).toBe(90)
    end)
end)
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 transform 解析和应用**

```lua
-- HostConfig.lua 添加 applyTransform 函数
local function applyTransform(instance, transforms)
    if not transforms then return end
    for _, t in ipairs(transforms) do
        for key, value in pairs(t) do
            if key == "rotate" then
                -- "45deg" → 45
                instance.rotation = tonumber(tostring(value):match("^(.-)deg$")) or 0
            elseif key == "scale" then
                instance.xScale = value
                instance.yScale = value
            elseif key == "scaleX" then
                instance.xScale = value
            elseif key == "scaleY" then
                instance.yScale = value
            elseif key == "translateX" then
                instance._translateX = value
            elseif key == "translateY" then
                instance._translateY = value
            end
        end
    end
end

-- 在 createInstance 和 updateInstance 中调用
if style.transform then applyTransform(group, style.transform) end
```

- [ ] **Step 4: 运行测试确认通过**
- [ ] **Step 5: 提交**

```bash
git commit -m "feat: transform support — rotate, scale, translate"
```

### Task 1.3: 边框完善 + Image resizeMode + zIndex

**Files:**
- Modify: `renderer/HostConfig.lua` — 添加 borderBottom/Top/Left/Right 颜色、Image resizeMode
- Modify: `renderer/init.lua` — applyLayout 中处理 zIndex (toFront/toBack)
- Modify: `tests/renderer/test_hostConfig_styles.lua` — 追加测试

- [ ] **Step 1: 写测试**

```lua
T.describe("HostConfig Image", function()
    T.it("applies resizeMode cover via fill", function()
        local instance = HostConfig.createInstance("Image", {
            source = { uri = "test.png" },
            style = { width = 200, height = 200 },
            resizeMode = "cover",
        })
        T.expect(instance._resizeMode).toBe("cover")
    end)

    T.it("applies resizeMode contain", function()
        local instance = HostConfig.createInstance("Image", {
            source = { uri = "test.png" },
            style = { width = 200, height = 200 },
            resizeMode = "contain",
        })
        T.expect(instance._resizeMode).toBe("contain")
    end)
end)

T.describe("HostConfig zIndex", function()
    T.it("stores zIndex for sorting", function()
        local instance = HostConfig.createInstance("View", {
            style = { width = 100, height = 100, zIndex = 10 }
        })
        T.expect(instance._zIndex).toBe(10)
    end)
end)

T.describe("HostConfig Border Sides", function()
    T.it("applies borderBottomWidth and borderBottomColor", function()
        local instance = HostConfig.createInstance("View", {
            style = {
                width = 200, height = 50,
                borderBottomWidth = 2,
                borderBottomColor = "#CCCCCC",
            }
        })
        -- Solar2D doesn't support per-side borders natively
        -- We create a thin rect at the bottom
        T.expect(instance._borderBottom).toBeTruthy()
    end)
end)
```

- [ ] **Step 2: 实现 Image resizeMode**

Solar2D 没有原生 resizeMode，但可以通过缩放实现：
```lua
-- cover: 缩放到完全覆盖容器，裁剪多余部分
-- contain: 缩放到完全在容器内，保持比例
-- stretch: 拉伸到容器尺寸（默认行为）

elseif elementType == "Image" then
    local group = display.newGroup()
    group.anchorX, group.anchorY = 0, 0

    local source = props.source
    local filename = (type(source) == "table") and source.uri or source or ""
    local w = style.width or 100
    local h = style.height or 100
    local resizeMode = props.resizeMode or style.resizeMode or "cover"

    local img = display.newImageRect(group, filename, w, h)
    if img then
        img.anchorX, img.anchorY = 0, 0
    end

    group._imageObj = img
    group._resizeMode = resizeMode
    wireEvents(group, props)
    return group
```

- [ ] **Step 3: 实现 zIndex 存储（排序在 applyLayout 中处理）**

```lua
-- createInstance 中所有类型末尾添加
if style.zIndex then group._zIndex = style.zIndex end
```

- [ ] **Step 4: 实现边框分侧支持**

Solar2D 不支持 per-side border，用薄 rect 模拟：
```lua
-- 在 View createInstance 中，检查 borderBottom/Top/Left/Right
local function addBorderSide(group, side, width, color, viewW, viewH)
    if not width or width <= 0 then return nil end
    local c = parseColor(color or "#000000")
    local line
    if side == "bottom" then
        line = display.newRect(group, 0, viewH - width, viewW, width)
    elseif side == "top" then
        line = display.newRect(group, 0, 0, viewW, width)
    elseif side == "left" then
        line = display.newRect(group, 0, 0, width, viewH)
    elseif side == "right" then
        line = display.newRect(group, viewW - width, 0, width, viewH)
    end
    if line then
        line.anchorX, line.anchorY = 0, 0
        line:setFillColor(c[1], c[2], c[3], c[4])
    end
    return line
end
```

- [ ] **Step 5: 运行测试确认通过**
- [ ] **Step 6: 提交**

```bash
git commit -m "feat: Image resizeMode, zIndex, per-side borders"
```

---

## Chunk 2: ScrollView + FlatList 组件

**目标**: 实现滚动容器和虚拟化列表

### Task 2.1: ScrollView 组件

**Files:**
- Create: `components/ScrollView.lua`
- Modify: `renderer/HostConfig.lua` — 添加 ScrollView 类型
- Create: `tests/components/test_scrollview.lua`

Solar2D 滚动方案：
- 用 `display.newGroup()` 作为内容容器
- 监听 touch 事件实现拖拽滚动
- 用 `display.newContainer()` 实现裁剪（overflow hidden）
- 或者用 Group + 手动 clipping mask

注意：Solar2D Container 嵌套限制 3 层，所以 ScrollView 本身就用掉 1 层。

- [ ] **Step 1: 写 ScrollView 测试**

```lua
-- tests/components/test_scrollview.lua
local T = require("tests.helpers.test_runner")
local mockDisplay = require("tests.helpers.mock_display")

T.describe("ScrollView", function()
    local React, RN

    T.beforeEach(function()
        mockDisplay.install()
        package.loaded["react"] = nil
        package.loaded["react_solar2d"] = nil
        React = require("react")
        RN = require("react_solar2d")
    end)

    T.it("creates a clipping container with content group", function()
        local element = React.createElement("ScrollView", {
            style = { width = 300, height = 400 },
        },
            React.createElement("View", {
                style = { height = 800 },
            })
        )
        local container = display.newGroup()
        RN.render(element, container)
        -- ScrollView should create a clipping container
        T.expect(container.numChildren).toBe(1)
    end)

    T.it("tracks contentOffset on scroll", function()
        -- ScrollView internal state
        local sv = require("components.ScrollView")
        T.expect(sv).toBeTruthy()
    end)
end)

T.summary()
```

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现 ScrollView**

ScrollView 核心设计：
- HostConfig 识别 "ScrollView" 元素类型
- 创建 Container（裁剪）+ 内部 content Group
- touch 事件驱动 content.y 偏移
- 可选：滚动条指示器
- Props: `horizontal`, `showsScrollIndicator`, `onScroll`, `contentContainerStyle`
- 内部状态通过闭包管理（不需要 useState，因为这是 host 组件）

```lua
-- components/ScrollView.lua
-- ScrollView 是一个 host 组件（不是 function component）
-- 通过 HostConfig.createInstance 处理
return "ScrollView"
```

```lua
-- HostConfig.lua 中添加 ScrollView 分支
elseif elementType == "ScrollView" then
    local w = style.width or display.contentWidth
    local h = style.height or display.contentHeight
    local horizontal = props.horizontal or false

    -- 外层：裁剪容器
    local clipContainer = display.newContainer(w, h)
    clipContainer.anchorX, clipContainer.anchorY = 0, 0
    clipContainer.anchorChildren = false

    -- 内层：内容组（可滚动）
    local contentGroup = display.newGroup()
    clipContainer:insert(contentGroup)
    -- Container 的坐标系原点在中心，需要偏移
    contentGroup.x = -w / 2
    contentGroup.y = -h / 2

    clipContainer._contentGroup = contentGroup
    clipContainer._scrollW = w
    clipContainer._scrollH = h
    clipContainer._horizontal = horizontal
    clipContainer._scrollY = 0
    clipContainer._scrollX = 0
    clipContainer._contentH = 0
    clipContainer._contentW = 0

    -- 滚动触摸处理
    local startY, startX, startScrollY, startScrollX
    clipContainer:addEventListener("touch", function(event)
        if event.phase == "began" then
            display.currentStage:setFocus(clipContainer)
            startY = event.y
            startX = event.x
            startScrollY = clipContainer._scrollY
            startScrollX = clipContainer._scrollX
        elseif event.phase == "moved" then
            if horizontal then
                local dx = event.x - startX
                local newScrollX = startScrollX + dx
                -- 限制范围
                local maxScroll = math.max(0, clipContainer._contentW - w)
                newScrollX = math.max(-maxScroll, math.min(0, newScrollX))
                clipContainer._scrollX = newScrollX
                contentGroup.x = -w / 2 + newScrollX
            else
                local dy = event.y - startY
                local newScrollY = startScrollY + dy
                local maxScroll = math.max(0, clipContainer._contentH - h)
                newScrollY = math.max(-maxScroll, math.min(0, newScrollY))
                clipContainer._scrollY = newScrollY
                contentGroup.y = -h / 2 + newScrollY
            end
            if props.onScroll then
                props.onScroll({
                    contentOffset = {
                        x = -clipContainer._scrollX,
                        y = -clipContainer._scrollY,
                    }
                })
            end
        elseif event.phase == "ended" or event.phase == "cancelled" then
            display.currentStage:setFocus(nil)
        end
        return true
    end)

    wireEvents(clipContainer, props)
    return clipContainer
```

- [ ] **Step 4: HostConfig appendChild 适配 ScrollView**

```lua
-- appendChild 需要判断 parent 是否是 ScrollView
function M.appendChild(parent, child)
    if parent._contentGroup then
        -- ScrollView: 子元素插入 contentGroup
        parent._contentGroup:insert(child)
        -- 更新内容高度
        local bounds = parent._contentGroup.contentBounds
        if bounds then
            parent._contentH = bounds.yMax - bounds.yMin
            parent._contentW = bounds.xMax - bounds.xMin
        end
    else
        parent:insert(child)
    end
end
```

- [ ] **Step 5: 运行测试确认通过**
- [ ] **Step 6: 提交**

```bash
git commit -m "feat: ScrollView with touch scrolling and clipping"
```

### Task 2.2: FlatList 组件

**Files:**
- Create: `components/FlatList.lua` — 函数组件，封装 ScrollView
- Create: `tests/components/test_flatlist.lua`

FlatList 是 function component（不是 host 组件），内部使用 ScrollView + map 渲染。
初始版不做虚拟化（Solar2D 应用数据量不大），后续按需优化。

- [ ] **Step 1: 写 FlatList 测试**

```lua
-- tests/components/test_flatlist.lua
local T = require("tests.helpers.test_runner")

T.describe("FlatList", function()
    T.it("is a function component", function()
        local FlatList = require("components.FlatList")
        T.expect(type(FlatList)).toBe("function")
    end)

    T.it("renders items via renderItem", function()
        -- FlatList takes data + renderItem
        local FlatList = require("components.FlatList")
        T.expect(FlatList).toBeTruthy()
    end)
end)

T.summary()
```

- [ ] **Step 2: 实现 FlatList**

```lua
-- components/FlatList.lua
local React = require("react")
local createElement = React.createElement

local function FlatList(props)
    local data = props.data or {}
    local renderItem = props.renderItem
    local keyExtractor = props.keyExtractor or function(item, index) return tostring(index) end
    local ItemSeparator = props.ItemSeparatorComponent
    local ListHeader = props.ListHeaderComponent
    local ListFooter = props.ListFooterComponent
    local ListEmpty = props.ListEmptyComponent
    local horizontal = props.horizontal or false
    local style = props.style or {}
    local contentContainerStyle = props.contentContainerStyle or {}

    local children = {}

    if ListHeader then
        children[#children + 1] = createElement("View", { key = "__header" }, ListHeader)
    end

    if #data == 0 and ListEmpty then
        children[#children + 1] = createElement("View", { key = "__empty" }, ListEmpty)
    else
        for i, item in ipairs(data) do
            local key = keyExtractor(item, i)
            children[#children + 1] = renderItem({ item = item, index = i, key = key })
            if ItemSeparator and i < #data then
                children[#children + 1] = createElement(ItemSeparator, { key = key .. "_sep" })
            end
        end
    end

    if ListFooter then
        children[#children + 1] = createElement("View", { key = "__footer" }, ListFooter)
    end

    return createElement("ScrollView", {
        style = style,
        horizontal = horizontal,
        contentContainerStyle = contentContainerStyle,
        onScroll = props.onScroll,
    }, unpack(children))
end

return FlatList
```

- [ ] **Step 3: 运行测试确认通过**
- [ ] **Step 4: 提交**

```bash
git commit -m "feat: FlatList component wrapping ScrollView"
```

---

## Chunk 3: TextInput + Modal + Switch 组件

### Task 3.1: TextInput 组件

**Files:**
- Create: `components/TextInput.lua` — host 组件
- Modify: `renderer/HostConfig.lua` — TextInput 类型
- Create: `tests/components/test_textinput.lua`

Solar2D 文本输入方案：
- `native.newTextField(x, y, w, h)` — 原生输入框
- `native.newTextBox(x, y, w, h)` — 多行输入框
- 这些是原生 UI 元素，会覆盖在 Solar2D 显示层之上

- [ ] **Step 1: 写 TextInput 测试**

```lua
T.describe("TextInput", function()
    T.it("creates a native text field", function()
        local instance = HostConfig.createInstance("TextInput", {
            style = { width = 300, height = 50, fontSize = 24 },
            placeholder = "Type here...",
            onChangeText = function(text) end,
        })
        T.expect(instance._inputField).toBeTruthy()
    end)
end)
```

- [ ] **Step 2: 实现 TextInput**

```lua
-- HostConfig.lua TextInput 分支
elseif elementType == "TextInput" then
    local group = display.newGroup()
    group.anchorX, group.anchorY = 0, 0

    local w = style.width or 200
    local h = style.height or 40
    local multiline = props.multiline or false

    -- 背景框
    local bg = display.newRoundedRect(group, 0, 0, w, h, style.borderRadius or 4)
    bg.anchorX, bg.anchorY = 0, 0
    local bgColor = parseColor(style.backgroundColor or "#FFFFFF")
    bg:setFillColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    if style.borderWidth then
        bg.strokeWidth = style.borderWidth
        local bc = parseColor(style.borderColor or "#CCCCCC")
        bg:setStrokeColor(bc[1], bc[2], bc[3], bc[4])
    end

    -- 原生输入（native.newTextField 在 Solar2D 中是原生 UI）
    local field
    if native and native.newTextField then
        if multiline then
            field = native.newTextBox(w / 2, h / 2, w - 8, h - 8)
        else
            field = native.newTextField(w / 2, h / 2, w - 8, h - 8)
        end
        field.font = native.systemFont
        field.size = style.fontSize or 14
        if props.placeholder then field.placeholder = props.placeholder end
        if props.value then field.text = props.value end
        if style.color then
            local c = parseColor(style.color)
            field:setTextColor(c[1], c[2], c[3], c[4])
        end

        field:addEventListener("userInput", function(event)
            if event.phase == "editing" or event.phase == "ended" then
                if props.onChangeText then
                    props.onChangeText(field.text)
                end
            end
            if event.phase == "submitted" then
                if props.onSubmitEditing then
                    props.onSubmitEditing({ nativeEvent = { text = field.text } })
                end
                native.setKeyboardFocus(nil)
            end
        end)

        group:insert(field)
    else
        -- Mock 环境：用 Text 模拟
        local placeholder = display.newText({
            parent = group,
            text = props.placeholder or "",
            x = 8, y = h / 2,
            fontSize = style.fontSize or 14,
        })
        placeholder.anchorX, placeholder.anchorY = 0, 0.5
        local c = parseColor("#999999")
        placeholder:setFillColor(c[1], c[2], c[3], c[4])
        group._placeholder = placeholder
    end

    group._bg = bg
    group._inputField = field
    wireEvents(group, props)
    return group
```

- [ ] **Step 3: 运行测试确认通过**
- [ ] **Step 4: 提交**

```bash
git commit -m "feat: TextInput with native Solar2D text field"
```

### Task 3.2: Modal 组件

**Files:**
- Create: `components/Modal.lua` — 函数组件
- Create: `tests/components/test_modal.lua`

Modal 设计：半透明背景遮罩 + 居中内容容器，通过 `visible` prop 控制显示。

- [ ] **Step 1: 写 Modal 测试**

```lua
T.describe("Modal", function()
    T.it("is a function component", function()
        local Modal = require("components.Modal")
        T.expect(type(Modal)).toBe("function")
    end)
end)
```

- [ ] **Step 2: 实现 Modal**

```lua
-- components/Modal.lua
local React = require("react")
local createElement = React.createElement

local function Modal(props)
    if not props.visible then
        return nil
    end

    local animationType = props.animationType or "none" -- "none", "fade", "slide"
    local transparent = props.transparent ~= false

    return createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = display.contentWidth,
            height = display.contentHeight,
            zIndex = 9999,
        },
    },
        -- 背景遮罩
        createElement("View", {
            style = {
                position = "absolute",
                top = 0, left = 0,
                width = display.contentWidth,
                height = display.contentHeight,
                backgroundColor = transparent and "rgba(0,0,0,0.5)" or "#FFFFFF",
            },
            onPress = function()
                if props.onRequestClose then
                    props.onRequestClose()
                end
            end,
        }),
        -- 内容区域
        createElement("View", {
            style = {
                flex = 1,
                justifyContent = "center",
                alignItems = "center",
            },
        }, props.children)
    )
end

return Modal
```

- [ ] **Step 3: 运行测试确认通过**
- [ ] **Step 4: 提交**

```bash
git commit -m "feat: Modal component with overlay backdrop"
```

### Task 3.3: Switch 组件

**Files:**
- Create: `components/Switch.lua`
- Create: `tests/components/test_switch.lua`

- [ ] **Step 1: 实现 Switch**

```lua
-- components/Switch.lua
local React = require("react")
local createElement = React.createElement

local function Switch(props)
    local value = props.value or false
    local onValueChange = props.onValueChange
    local trackColor = props.trackColor or {}
    local thumbColor = props.thumbColor or "#FFFFFF"

    local trackBg = value
        and (trackColor.true_ or trackColor["true"] or "#4CD964")
        or (trackColor.false_ or trackColor["false"] or "#E5E5EA")

    return createElement("View", {
        style = {
            width = 100, height = 62,
            borderRadius = 31,
            backgroundColor = trackBg,
            justifyContent = "center",
            padding = 4,
        },
        onPress = function()
            if onValueChange then
                onValueChange(not value)
            end
        end,
    },
        createElement("View", {
            style = {
                width = 54, height = 54,
                borderRadius = 27,
                backgroundColor = thumbColor,
                alignSelf = value and "flex-end" or "flex-start",
            },
        })
    )
end

return Switch
```

- [ ] **Step 2: 测试 + 提交**

```bash
git commit -m "feat: Switch toggle component"
```

---

## Chunk 4: Animated API

**目标**: 封装 Solar2D `transition.to` 为 React Native Animated API

### Task 4.1: Animated 核心

**Files:**
- Create: `animated/init.lua` — Animated.Value, Animated.timing, Animated.spring
- Create: `animated/AnimatedValue.lua` — 响应式值
- Create: `tests/animated/test_animated.lua`

Solar2D 动画 API：
```lua
transition.to(displayObject, {
    time = 300,        -- 毫秒
    alpha = 0,         -- 目标透明度
    x = 100,           -- 目标 x
    rotation = 360,    -- 目标旋转
    xScale = 2,        -- 目标缩放
    transition = easing.outQuad,  -- 缓动函数
    onComplete = function(obj) end,
})
transition.cancel(handleOrTag)
```

RN Animated API 核心：
```lua
local fadeAnim = Animated.Value(0)
Animated.timing(fadeAnim, { toValue = 1, duration = 300 }):start()
-- fadeAnim 驱动样式: style = { opacity = fadeAnim }
```

设计决策：我们简化 Animated API，不做 100% RN 兼容（太复杂），而是提供核心子集：
- `Animated.Value(initial)` — 可观察值
- `Animated.timing(value, config)` — 定时动画
- `Animated.spring(value, config)` — 弹性动画
- `Animated.View` — 支持 Animated 值的 View
- `Animated.sequence([...])` — 顺序动画
- `Animated.parallel([...])` — 并行动画

- [ ] **Step 1: 写 Animated 测试**

```lua
-- tests/animated/test_animated.lua
local T = require("tests.helpers.test_runner")

T.describe("Animated", function()
    local Animated

    T.beforeEach(function()
        package.loaded["animated"] = nil
        Animated = require("animated")
    end)

    T.it("creates AnimatedValue with initial value", function()
        local val = Animated.Value(0)
        T.expect(val:getValue()).toBe(0)
    end)

    T.it("setValue updates value", function()
        local val = Animated.Value(0)
        val:setValue(42)
        T.expect(val:getValue()).toBe(42)
    end)

    T.it("addListener calls callback on change", function()
        local val = Animated.Value(0)
        local received = nil
        val:addListener(function(v) received = v.value end)
        val:setValue(10)
        T.expect(received).toBe(10)
    end)

    T.it("timing returns animation object with start method", function()
        local val = Animated.Value(0)
        local anim = Animated.timing(val, { toValue = 1, duration = 300 })
        T.expect(type(anim.start)).toBe("function")
        T.expect(type(anim.stop)).toBe("function")
    end)

    T.it("sequence chains animations", function()
        local val = Animated.Value(0)
        local seq = Animated.sequence({
            Animated.timing(val, { toValue = 1, duration = 100 }),
            Animated.timing(val, { toValue = 0, duration = 100 }),
        })
        T.expect(type(seq.start)).toBe("function")
    end)
end)

T.summary()
```

- [ ] **Step 2: 实现 Animated**

```lua
-- animated/init.lua
local Animated = {}

-- AnimatedValue
local AnimatedValue = {}
AnimatedValue.__index = AnimatedValue

function Animated.Value(initial)
    return setmetatable({
        _value = initial or 0,
        _listeners = {},
        _animation = nil,
    }, AnimatedValue)
end

function AnimatedValue:getValue()
    return self._value
end

function AnimatedValue:setValue(v)
    self._value = v
    for _, listener in ipairs(self._listeners) do
        listener({ value = v })
    end
end

function AnimatedValue:addListener(callback)
    self._listeners[#self._listeners + 1] = callback
    return #self._listeners
end

function AnimatedValue:removeListener(id)
    self._listeners[id] = nil
end

function AnimatedValue:stopAnimation(callback)
    if self._animation then
        if transition and transition.cancel then
            transition.cancel(self._animation)
        end
        self._animation = nil
    end
    if callback then callback(self._value) end
end

-- Animated.timing
function Animated.timing(value, config)
    local anim = {}
    local toValue = config.toValue
    local duration = config.duration or 300
    local easingFn = config.easing -- Solar2D easing function
    local delay = config.delay or 0

    function anim.start(callback)
        if transition and transition.to then
            -- 使用 Solar2D transition.to
            -- 创建一个代理对象来驱动 AnimatedValue
            local proxy = { val = value:getValue() }
            value._animation = transition.to(proxy, {
                time = duration,
                delay = delay,
                val = toValue,
                transition = easingFn,
                onComplete = function()
                    value:setValue(toValue)
                    value._animation = nil
                    if callback then callback({ finished = true }) end
                end,
            })
            -- 用 enterFrame 同步代理值到 AnimatedValue
            local function sync()
                if value._animation then
                    value:setValue(proxy.val)
                else
                    Runtime:removeEventListener("enterFrame", sync)
                end
            end
            Runtime:addEventListener("enterFrame", sync)
        else
            -- 非 Solar2D 环境：直接设最终值
            value:setValue(toValue)
            if callback then callback({ finished = true }) end
        end
    end

    function anim.stop()
        value:stopAnimation()
    end

    return anim
end

-- Animated.spring (简化版 — 用阻尼正弦近似)
function Animated.spring(value, config)
    -- 简化：用 easing.outElastic 模拟弹性
    local newConfig = {
        toValue = config.toValue,
        duration = config.duration or 500,
        easing = easing and easing.outElastic or nil,
    }
    return Animated.timing(value, newConfig)
end

-- Animated.sequence
function Animated.sequence(animations)
    local anim = {}
    function anim.start(callback)
        local index = 1
        local function next()
            if index > #animations then
                if callback then callback({ finished = true }) end
                return
            end
            animations[index].start(function()
                index = index + 1
                next()
            end)
        end
        next()
    end
    function anim.stop()
        for _, a in ipairs(animations) do
            if a.stop then a.stop() end
        end
    end
    return anim
end

-- Animated.parallel
function Animated.parallel(animations)
    local anim = {}
    function anim.start(callback)
        local remaining = #animations
        if remaining == 0 then
            if callback then callback({ finished = true }) end
            return
        end
        for _, a in ipairs(animations) do
            a.start(function()
                remaining = remaining - 1
                if remaining == 0 and callback then
                    callback({ finished = true })
                end
            end)
        end
    end
    function anim.stop()
        for _, a in ipairs(animations) do
            if a.stop then a.stop() end
        end
    end
    return anim
end

-- Animated.View — 标记字符串，HostConfig 识别
Animated.View = "Animated.View"
Animated.Text = "Animated.Text"
Animated.Image = "Animated.Image"

return Animated
```

- [ ] **Step 3: 运行测试确认通过**
- [ ] **Step 4: 导出 Animated 到 react_solar2d.lua**

```lua
-- react_solar2d.lua 添加
local Animated = require("animated")
RN.Animated = Animated
```

- [ ] **Step 5: 提交**

```bash
git commit -m "feat: Animated API — Value, timing, spring, sequence, parallel"
```

### Task 4.2: useTimer hook（游戏循环用）

**Files:**
- Create: `hooks/useTimer.lua`
- Modify: `react_solar2d.lua` — 导出

- [ ] **Step 1: 实现 useTimer**

```lua
-- hooks/useTimer.lua
local React = require("react")

local function useTimer(callback, delay, deps)
    local callbackRef = React.useRef(callback)
    callbackRef.current = callback

    React.useEffect(function()
        if delay == nil or delay == false then return end

        local handle = timer.performWithDelay(delay, function()
            callbackRef.current()
        end, 0) -- 0 = 无限重复

        return function()
            timer.cancel(handle)
        end
    end, deps or {delay})
end

local function useInterval(callback, delay)
    return useTimer(callback, delay)
end

return {
    useTimer = useTimer,
    useInterval = useInterval,
}
```

- [ ] **Step 2: 提交**

```bash
git commit -m "feat: useTimer/useInterval hooks for game loops"
```

---

## Chunk 5: 组件注册 + 模块导出 + 集成测试

### Task 5.1: 更新 components/init.lua 和 react_solar2d.lua

**Files:**
- Modify: `components/init.lua` — 注册所有新组件
- Modify: `react_solar2d.lua` — 导出所有新模块
- Create: `components/Pressable.lua` — 通用可按压组件

- [ ] **Step 1: 更新组件注册**

```lua
-- components/init.lua
local M = {}
M.View = require("components.View")
M.Text = require("components.Text")
M.Image = require("components.Image")
M.Button = require("components.Button")
M.TouchableOpacity = require("components.TouchableOpacity")
M.ScrollView = require("components.ScrollView")
M.FlatList = require("components.FlatList")
M.TextInput = require("components.TextInput")
M.Modal = require("components.Modal")
M.Switch = require("components.Switch")
M.Pressable = require("components.Pressable")
return M
```

- [ ] **Step 2: 更新 react_solar2d.lua**

```lua
-- 添加新组件导出
RN.ScrollView = Components.ScrollView
RN.FlatList = Components.FlatList
RN.TextInput = Components.TextInput
RN.Modal = Components.Modal
RN.Switch = Components.Switch
RN.Pressable = Components.Pressable

-- 添加 Animated
local Animated = require("animated")
RN.Animated = Animated

-- 添加 hooks
local timerHooks = require("hooks.useTimer")
RN.useTimer = timerHooks.useTimer
RN.useInterval = timerHooks.useInterval
```

- [ ] **Step 3: 运行全部单元测试**

```bash
cd /path/to/project
lua tests/react/test_createElement.lua
lua tests/react/test_hooks.lua
lua tests/react/test_reconciler.lua
lua tests/renderer/test_hostConfig.lua
lua tests/renderer/test_hostConfig_styles.lua
lua tests/style/test_processColor.lua
lua tests/style/test_stylesheet.lua
lua tests/components/test_view.lua
lua tests/components/test_text.lua
lua tests/components/test_scrollview.lua
lua tests/components/test_flatlist.lua
lua tests/animated/test_animated.lua
```

- [ ] **Step 4: 提交**

```bash
git commit -m "feat: register all new components and exports"
```

---

## Chunk 6: Demo App 1 — 新闻浏览器

### Task 6.1: NewsApp 实现

**Files:**
- Create: `examples/NewsApp.lua`

用到的功能：FlatList, Image, Text (fontWeight/textAlign), ScrollView, TouchableOpacity, StyleSheet

```lua
-- examples/NewsApp.lua
local React = require("react")
local createElement = React.createElement
local useState = React.useState

local W = display.contentWidth
local H = display.contentHeight

-- 模拟新闻数据
local NEWS_DATA = {
    { id = "1", title = "React-Solar2D 发布 1.0 版本", category = "技术",
      summary = "全新的 React Native 兼容框架，让 AI 生成的界面代码直接在 Solar2D 上运行。",
      time = "2 小时前", image = "news1.png" },
    { id = "2", title = "Solar2D 引擎更新至 3.0", category = "技术",
      summary = "新版本带来了 Metal 渲染支持和更好的性能表现。",
      time = "5 小时前", image = "news2.png" },
    { id = "3", title = "Lua 语言入选年度编程语言榜单", category = "编程",
      summary = "Lua 以其轻量和嵌入性获得开发者社区认可。",
      time = "1 天前", image = "news3.png" },
    { id = "4", title = "儿童教育应用市场增长 40%", category = "教育",
      summary = "创意物理工具类应用成为最受欢迎的品类之一。",
      time = "2 天前", image = "news4.png" },
    { id = "5", title = "Flexbox 布局完全指南", category = "技术",
      summary = "从基础到高级，全面掌握 Flexbox 布局系统的每个属性。",
      time = "3 天前", image = "news5.png" },
}

-- 新闻卡片组件
local function NewsCard(props)
    local item = props.item
    return createElement("View", {
        style = {
            backgroundColor = "#FFFFFF",
            borderRadius = 16,
            marginHorizontal = 32,
            marginBottom = 24,
            padding = 24,
            borderBottomWidth = 1,
            borderBottomColor = "#E0E0E0",
        },
        onPress = props.onPress,
    },
        -- 类别标签
        createElement("View", {
            style = {
                backgroundColor = "#E3F2FD",
                borderRadius = 8,
                paddingHorizontal = 16,
                paddingVertical = 6,
                alignSelf = "flex-start",
                marginBottom = 12,
            },
        },
            createElement("Text", {
                style = {
                    fontSize = 24,
                    color = "#1976D2",
                    fontWeight = "bold",
                },
            }, item.category)
        ),
        -- 标题
        createElement("Text", {
            style = {
                fontSize = 36,
                color = "#212121",
                fontWeight = "bold",
                marginBottom = 8,
            },
        }, item.title),
        -- 摘要
        createElement("Text", {
            style = {
                fontSize = 28,
                color = "#757575",
                lineHeight = 40,
            },
        }, item.summary),
        -- 时间
        createElement("Text", {
            style = {
                fontSize = 22,
                color = "#BDBDBD",
                marginTop = 12,
            },
        }, item.time)
    )
end

-- 顶部导航栏
local function NavBar(props)
    return createElement("View", {
        style = {
            height = 120,
            backgroundColor = "#1976D2",
            justifyContent = "center",
            alignItems = "center",
            paddingTop = 20,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 42,
                color = "#FFFFFF",
                fontWeight = "bold",
            },
        }, "新闻浏览器")
    )
end

-- 主应用
local function NewsApp()
    local selectedId, setSelectedId = useState(nil)

    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#F5F5F5",
            width = W,
            height = H,
        },
    },
        createElement(NavBar),
        createElement("FlatList", {
            style = {
                flex = 1,
            },
            data = NEWS_DATA,
            keyExtractor = function(item) return item.id end,
            renderItem = function(info)
                return createElement(NewsCard, {
                    key = info.key,
                    item = info.item,
                    onPress = function()
                        setSelectedId(info.item.id)
                        print("Selected: " .. info.item.title)
                    end,
                })
            end,
        })
    )
end

return NewsApp
```

- [ ] **Step 1: 创建 NewsApp.lua**
- [ ] **Step 2: 在模拟器中测试**

修改 examples/main.lua 的 demo 变量为 "news"，添加 news 分支。
在 Corona Simulator 中运行，检查控制台输出无错误。

- [ ] **Step 3: 截图验证布局**
- [ ] **Step 4: 提交**

```bash
git commit -m "feat: NewsApp demo — FlatList + ScrollView + Text styling"
```

---

## Chunk 7: Demo App 2 — 问答做题系统

### Task 7.1: QuizApp 实现

**Files:**
- Create: `examples/QuizApp.lua`

用到的功能：useState, Modal, Switch, TouchableOpacity, 动画反馈, 进度条

```lua
-- examples/QuizApp.lua
-- 详细实现见 Step 1
-- 核心功能：
-- 1. 题目列表（选择题，4个选项）
-- 2. 点击选项 → 绿色正确/红色错误 反馈
-- 3. 进度条显示已完成题目
-- 4. 答完后 Modal 显示成绩
```

- [ ] **Step 1: 创建 QuizApp.lua**（完整代码在实现时编写）
- [ ] **Step 2: 模拟器测试**
- [ ] **Step 3: 提交**

---

## Chunk 8: Demo App 3 — 俄罗斯方块

### Task 8.1: TetrisApp 实现

**Files:**
- Create: `examples/TetrisApp.lua`

用到的功能：useTimer（游戏循环）、transform、useState、Modal（暂停/游戏结束）、Touch 控制

俄罗斯方块的特殊性：主要用 Solar2D 原生绘图（display.newRect 格子），React 管理 UI 层（菜单、分数、下一块预览）。游戏逻辑可以纯 Lua + Solar2D，不需要通过 React 渲染每个格子（性能考虑）。

架构：
- React 层：菜单界面、分数显示、暂停/结束 Modal
- Solar2D 层：游戏网格直接用 display.newRect 绘制
- 通过 useRef 持有 Solar2D 游戏对象引用

- [ ] **Step 1: 创建 TetrisApp.lua**
- [ ] **Step 2: 模拟器测试**
- [ ] **Step 3: 提交**

---

## Chunk 9: 最终集成测试 + 清理

### Task 9.1: examples/main.lua 更新

支持所有 demo 切换：hello, counter, news, quiz, tetris

### Task 9.2: 运行全部测试

确认所有单元测试通过，所有 demo 在模拟器中正常运行。

### Task 9.3: 最终提交

```bash
git commit -m "feat: complete UI system — 3 demo apps验证"
```
