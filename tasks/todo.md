# React-Solar2D 架构修复 TODO

> 计划执行时间：2026-03-29 凌晨 3:00+
> 修复完成后：让 kimi 再做一次深度 review，coordinator 验证结果

## 🔴 P0 — 严重 Bug

### 1. 修复 `Reconciler.unmount` 清理路径
- **文件**: `react/Reconciler.lua:347-355`
- **问题**: `unmount` 直接 `removeSelf()` display objects，不走 fiber 清理路径，导致 useEffect cleanup、ref cleanup、useSyncExternalStore unsubscribe 全部丢失
- **修复**: 让 unmount 走正常的 reconciler 路径——将 root fiber 标记为 DELETION，调用 `commitDeletion`，确保所有 effect cleanup 和 ref 清理被执行
- [ ] 修复代码
- [ ] 补充测试（验证 unmount 后 useEffect cleanup 被调用）

### 2. 修复 `commitDeletion` 不清理 useEffect cleanup
- **文件**: `react/Reconciler.lua:221-246`
- **问题**: `commitDeletion` 只清理 `_storeCleanups` 和 `ref`，不遍历 `fiber._hooks` 执行 useEffect 的 cleanup 函数
- **修复**: 在 commitDeletion 中遍历 function fiber 的 `_hooks`，对所有带 `cleanup` 字段的 hook 执行清理
- [ ] 修复代码
- [ ] 补充测试（验证组件删除后 useEffect cleanup 被调用）

## 🟡 P1 — 中等问题

### 3. Fragment reconciler 支持
- **文件**: `react/Reconciler.lua` performUnitOfWork
- **问题**: `React.Fragment = "$$react.fragment"` 声明了但 reconciler 无处理，当 host component 创建了多余 group
- **修复**: 在 performUnitOfWork 中增加 Fragment 分支，直接 `reconcileChildren(fiber, fiber.props.children)`
- [ ] 修复代码
- [ ] 补充测试

### 4. 组件级 React.memo 支持
- **文件**: `react/Reconciler.lua` reconcileChildren + `react/init.lua`
- **问题**: 无 memo 支持，每次 state 更新全树遍历
- **修复**: 实现 `React.memo(component, areEqual)`，在 reconcileChildren 中对 memo 组件做 props 浅比较，未变化时跳过子树
- [ ] 实现 React.memo
- [ ] 实现 shallowEqual
- [ ] 补充测试

### 5. updateInstance 动态属性缺失
- **文件**: `renderer/HostConfig.lua:839+`
- **问题**: backgroundColor 从无到有、borderRadius 变化等不会动态创建/重建 _bg
- **修复**: updateInstance 中检测 _bg 需要创建/重建的情况
- [ ] 修复代码
- [ ] 补充测试

### 6. StackNavigator 内存优化
- **文件**: `navigation/StackNavigator.lua`
- **问题**: 渲染所有屏幕只隐藏非活跃的，深层导航栈内存线性增长
- **修复**: 增加 `unmountOnBlur` 选项或默认只保留最近 N 个 screen
- [ ] 修复代码
- [ ] 补充测试

## 🟢 P2 — 改善项

### 7. 开发模式错误边界
- performUnitOfWork 用 pcall 包裹 render，打印 fiber 路径
- createInstance 对未知类型打印 warning
- hooks 数量变化检测
- [ ] 实现

### 8. Image 网络层增强
- URL hash 做文件名（替代 math.random）
- 本地缓存复用
- onError 回调
- [ ] 实现

### 9. Modal Portal 机制
- 让 Modal 渲染到 root container 而不是局部树
- [ ] 设计方案
- [ ] 实现

### 10. 布局计算按需触发
- flushUpdates 中判断是否有 style/结构变化，没有则跳过 runLayoutPass
- [ ] 实现

---

## 🟢 P2 — 新功能

### 11. WebView 组件
- **文件**: `components/WebView.lua` + `renderer/HostConfig.lua`
- **说明**: 简单包装 `native.newWebView()`，不解决 native 层级限制，但提供 React 风格 API
- **API**:
  ```lua
  ce(WebView, {
      source = { uri = "https://..." },  -- 或 { html = "<h1>Hi</h1>" }
      style = { width = 300, height = 400 },
      onLoad = function(e) end,
      onError = function(e) end,
      onMessage = function(e) end,  -- JS→Lua
  })
  ```
- **已知限制**: native 对象在最顶层，不能被遮挡/裁剪/放在 ScrollView 里
- [ ] 实现组件
- [ ] 补充测试
- [ ] 文档说明限制

---

## 不做的事项（已评估，投入产出比不合理）

- **自绘 TextInput**: Solar2D 不暴露字符级度量 API（glyph x,y），无法实现光标定位和选区。除非写 C 插件调 FreeType/CoreText，工程量大
- **富文本编辑器**: 浏览器内核级工作，不现实
- **WebView 自绘**: 需要集成 CEF/Ultralight，太重

---

## 执行计划

1. 先修 P0（#1 + #2），这两个是内存泄漏，必须修
2. 再做 #3 Fragment + #4 memo，提升正确性和性能
3. #5 updateInstance 动态属性
4. 跑全量测试确认 314+ 全过
5. 让 kimi 再做一次深度 review（关注修复质量 + 之前未发现的问题 + 架构建议）
6. coordinator 验证 kimi 的 review 结果，必要时修改
7. commit + push
8. P2: WebView 组件简单包装
