# React-Solar2D 架构修复 TODO

> 修复完成后：让 kimi 再做一次深度 review，coordinator 验证结果

## 🔴 P0 — 严重 Bug ✅ 全部完成

### 1. ✅ `Reconciler.unmount` 清理路径
### 2. ✅ `commitDeletion` hooks cleanup

## 🟡 P1 — 中等问题（3/6 完成）

### 3. ✅ Fragment reconciler 支持
### 4. ✅ React.memo
### 5. ✅ updateInstance 动态属性

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

### 6.5 Host Component Registry（第三方库支持）
- **文件**: 新建 `renderer/HostRegistry.lua` + 改造 `renderer/HostConfig.lua`
- **问题**: 当前所有 host 组件逻辑集中在 HostConfig.lua（979行），第三方库无法在不修改核心代码的情况下注册新组件
- **目标**: 提供 `registerComponent` API，让第三方库像 RN 的 `requireNativeComponent` 一样注册自定义 host 类型
- **API 设计**:
  ```lua
  local Registry = require("renderer.HostRegistry")

  -- 第三方库注册
  Registry.register("LottieView", {
      create = function(props)
          local group = display.newGroup()
          -- 初始化
          return group
      end,
      update = function(instance, oldProps, newProps)
          -- 更新
      end,
      remove = function(parent, instance)
          -- 清理
          instance:removeSelf()
      end,
  })

  -- 用户使用
  local LottieView = require("lottie-solar2d")
  ce("LottieView", { source = "anim.json", autoPlay = true })
  -- 或者导出组件字符串
  ce(LottieView.Component, { ... })
  ```
- **实现要点**:
  - HostConfig.createInstance 先查 Registry，有则委托，无则走内置逻辑
  - HostConfig.updateInstance 同理
  - HostConfig.removeChild 支持自定义 remove 回调
  - 内置组件（View/Text/Image/ScrollView 等）也可迁移到 Registry，逐步瘦身 HostConfig
- [ ] 设计 Registry API
- [ ] 实现 HostRegistry.lua
- [ ] 改造 HostConfig 查询 Registry
- [ ] 迁移 1-2 个内置组件验证
- [ ] 文档：如何编写第三方组件库

### 6.6 Text auto-wrap in ScrollView
- **文件**: `renderer/init.lua` buildLayoutTree + applyLayout reflow
- **问题**: ScrollView 内容区域在 Yoga 里没有宽度约束，导致子 Text 节点可以无限扩展，reflow 永远不触发
- **根因**: buildLayoutTree 给 Text 设 `node:setWidth(textObj.width)`，Yoga 允许父容器扩展到该宽度，所以 `w == textObj.width`，条件 `textObj.width > w + 1` 为 false
- **需要**: 让 ScrollView 的 content 区域在 cross-axis 上约束子节点宽度，或在 buildLayoutTree 中不给 Text 设固定 width 而是用 measure function
- [ ] 调研 Yoga 的 measure function 机制
- [ ] 实现

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
