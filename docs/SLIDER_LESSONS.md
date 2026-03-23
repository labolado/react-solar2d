# Slider 修复经验总结

## 问题现象

Slider 组件完全无法工作：不能拖动、不能点击、+/- 按钮只能用一次、填充色偏移。

## 根因分析：7 层 Bug 叠加

每个 bug 都独立存在，修一个只暴露下一个，造成"怎么改都不对"的感觉。

### Bug 1: `ref` 回调从未执行

**症状**: `useRef` 获取的 display object 始终是 `nil`

**根因**: `ReactElement.createElement` 按照 React 标准把 `ref` 从 props 中剥离（line 15: `k ~= "ref"`），存到 `element.ref` 上。但 reconciler 的 `commitWork` 从未读取 `element.ref` 或调用它。`wireEvents` 中的 `props.ref` 检查是死代码。

**修复**:
- `reconcileChildren`: 将 `element.ref` 传递给 fiber (`newFiber.ref = element.ref`)
- `commitWork`: 在 PLACEMENT/UPDATE 后调用 `fiber.ref(fiber.stateNode)`

**教训**: React 的 `ref` 不是普通 prop，需要框架层面的特殊处理。

---

### Bug 2: ScrollView 吞掉所有触摸事件

**症状**: 触摸监听器已正确添加到 display object，但永远不会触发

**根因**: `ScrollViewFactory` 创建了一个 `touchOverlay` 透明矩形覆盖在所有内容之上（line 16-20），它的 touch 事件处理器在 `began` 阶段返回 `true`，完全拦截了所有触摸。子组件的触摸监听器永远收不到事件。

ScrollView 只支持 `_onPress`（通过 `findPressable` 手动分发 tap），不支持 drag。

**修复**:
- 添加 `findDragChild` 函数：在 `began` 阶段检查触摸点下是否有 `_onDragHandler` 的子组件
- 如果找到，将所有后续触摸事件转发给该子组件，而不是滚动
- Slider 通过 `ref` 回调在 overlay instance 上存储 `_onDragHandler`

**教训**: 自定义 ScrollView 拦截触摸后，必须提供机制让子组件"抢夺"触摸焦点。这类似 Android 的 `requestDisallowInterceptTouchEvent`。

---

### Bug 3: `onPress` 闭包过时（按钮只能用一次）

**症状**: +/- 按钮点第一次有效，之后点击无反应（值不变）

**根因**: `wireEvents` 中 tap 监听器直接捕获了 `props.onPress`：
```lua
instance:addEventListener("tap", function(event)
    props.onPress(event)  -- 捕获的是 createInstance 时的闭包
end)
```
第一次点击后 React 重新渲染，`updateInstance` 被调用但 tap 监听器仍然调用旧的 `props.onPress`（包含旧的 `value`）。

**修复**:
- `wireEvents`: 存储回调到 `instance._onPress`，监听器调用 `instance._onPress`
- `updateInstance`: 刷新 `instance._onPress = newProps.onPress`

**教训**: 所有事件回调必须通过 instance 间接引用，而不是闭包直接捕获。这是 React reconciler 的核心模式。

---

### Bug 4: Drag 回调同样过时

**症状**: 拖动时使用的是旧的回调值

**根因**: 与 Bug 3 相同——`onDrag`/`onDragStart`/`onDragEnd` 在 `wireEvents` 闭包中被捕获，`updateInstance` 不刷新。

**修复**: 同 Bug 3 — 存到 `instance._onDrag` 等，监听器间接引用，`updateInstance` 刷新。

---

### Bug 5: `useEffect` 时序问题（已在本次绕过）

**症状**: `useEffect` 中 ref 是 nil，touch listener 不会被添加

**根因**: 导航系统预渲染所有页面。Slider 在隐藏的页面上渲染时 `useEffect({})` 触发，但此时 `ref` 还未设置（Bug 1）。即使修复了 Bug 1，`deps={}` 意味着 effect 只运行一次，如果首次运行时组件状态不完整就永远错过了。

**绕过**: 不使用 `useEffect` 添加事件。改用 `ref` 回调（在 `commitWork` 中保证 display object 存在时执行）+ ScrollView 的 `_onDragHandler` 协议。

**教训**: `useEffect({})` 不适合设置与 display object 交互的监听器，因为无法保证执行时 display object 已存在。`ref` 回调是更可靠的时机。

---

### Bug 6: `applyLayout` 尺寸不一致

**症状**: 填充色条位置偏移，宽度不匹配

**根因**: `applyLayout` 对 absolute 元素覆盖了 `l`（left）和 `t`（top）从 style，但 `w`（width）和 `h`（height）使用 Yoga 计算值。Yoga 计算值可能和 `style.width` 不同（特别是嵌套 absolute 元素），导致 `_bg.path.width` 被设置为错误的值。

**修复**:
```lua
if style.position == "absolute" then
    if type(style.width) == "number" then w = style.width end
    if type(style.height) == "number" then h = style.height end
end
```

**教训**: layout 引擎的 position 和 size 必须来源一致。如果 position 来自 style，size 也应该来自 style（对于 absolute 元素）。

---

### Bug 7: 直接操作 vs React 渲染冲突

**症状**: 拖动时填充色闪烁跳动

**根因**:
1. 触摸事件中 `updateVisuals` 直接设置 `_bg.path.width = relX`（即时）
2. `onValueChange` 触发 state 更新
3. 下一帧 `enterFrame` → `flushUpdates` → 重渲染 → `applyLayout` 覆盖 `_bg.path.width`

两个值交替出现造成闪烁。

**修复**: 只对 thumb 做直接操作（跟手），filled track 完全由 React 重渲染控制（下一帧更新）。

**教训**: 直接操作 display object 和 React 声明式渲染不能在同一个属性上混用。选一个。

---

## 架构经验

### Solar2D 触摸事件模型

```
触摸事件 → touchOverlay (ScrollView) → 返回 true → 事件结束
                                        ↓ (如果有 _onDragHandler)
                                        转发给子组件
```

- Solar2D 触摸事件不像 DOM 那样冒泡
- `group:addEventListener("touch")` 在 group 有 `touchOverlay` 子组件时可能不生效
- `setFocus(target)` 只把后续事件发送给 target，不发送给 target 的父级

### React reconciler 回调模式

```
❌ 错误: 监听器闭包直接捕获 props
instance:addEventListener("tap", function()
    props.onPress()  -- 永远是 createInstance 时的旧值
end)

✅ 正确: 通过 instance 间接引用
instance._onPress = props.onPress
instance:addEventListener("tap", function()
    instance._onPress()  -- updateInstance 会刷新
end)
```

### ref vs useEffect 时机

```
render cycle:
  walkFiber()     → 组件函数执行, useEffect 排队
  commitWork()    → createInstance, ref 回调执行 ✓ (display object 已存在)
  flushEffects()  → useEffect 执行 ✓ (ref 已设置, 如果 Bug 1 已修复)

enterFrame:
  flushUpdates()  → 处理 setState, 重新渲染 + applyLayout
```

### 直接操作 vs React 的边界

| 场景 | 推荐方式 |
|------|---------|
| 拖动中的位置(thumb) | 直接操作 `instance.x` |
| 值相关的视觉(填充色) | React 重渲染 |
| 动画过渡 | `transition.to` (Solar2D) |
| 一次性事件监听 | `ref` 回调 + `_onDragHandler` |

## 调试方法论

1. **确认回调是否触发**: 在关键位置加 `print()`，从最外层开始排查
2. **确认事件传递链**: ScrollView touchOverlay 是最常见的拦截点
3. **确认闭包是否过时**: `print(tostring(callback))` 看函数引用是否变化
4. **确认 layout 值**: `print(l, t, w, h)` 在 applyLayout 中验证
5. **一次只改一个**: 多个 bug 叠加时，每次只修一个并验证
