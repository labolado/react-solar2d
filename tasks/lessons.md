# React-Solar2D 项目教训

回顾会话中的调试经验，避免重复踩坑。

---

## Text 系统

### Text 重建时不要用旧 display 宽度约束新文字
**日期**: 2026-03-30
**场景**: 分类按钮选中后 fontWeight 从 normal 变 bold，Text 重建后折行
**根因**: `updateInstance` 重建 Text 时用 `oldTextObj.width`（被 Yoga 压缩过的旧显示宽度）作为新 Text 的 `width` 参数。bold 文字更宽但被旧窄宽度约束，被迫换行。
**修法**: 重建 Text 时只用 `style.width`（开发者明确设的），没设就不约束（`renderer/HostConfig.lua:949`）
**教训**: display object 的 `.width` 是渲染结果不是布局意图，不能用作重建的约束条件

### Text reflow 只对长文本触发
**日期**: 2026-03-30
**场景**: 短标签（"Canvas"）被 reflow 逻辑错误换行
**根因**: reflow 对所有 Text 都检查 `naturalW > wrapW`，短文字在 fontWeight 变化后也被触发
**修法**: reflow 只对 `buildLayoutTree` 中标记了 `_naturalTextWidth` 的长文本触发（`renderer/init.lua:185-186`）
**教训**: 文本换行逻辑必须区分"需要换行的段落"和"不应换行的标签"，不能一刀切

### Text 在 Yoga 中不要设固定 width（用 stretch 约束）
**日期**: 2026-03-29
**场景**: ScrollView 内的长文本不换行
**根因**: `buildLayoutTree` 给 Text 设 `node:setWidth(textObj.width)`，Yoga 认为它需要这么宽，整个父链扩展到该宽度，reflow 条件 `textObj.width > w + 1` 永远为 false
**修法**: 长文本（>90% 屏宽）不设 Yoga width，靠 padding-walk 回退计算可用宽度
**教训**: Yoga 的 `setWidth` 是"我需要这么宽"不是"我最宽这么宽"，会撑大所有父容器

---

## ScrollView

### applyLayout 不要覆盖 ScrollView 的 _contentH
**日期**: 2026-03-30
**场景**: 列表滚到底后弹回，最后几项被 tab bar 挡住
**根因**: `applyLayout` 把 Yoga 算的 `maxBottom`（被约束到 ScrollView 高度）写入 `_contentH`，覆盖了 `recalcContentSize` 的正确值，导致 `maxScroll = 0`
**修法**: 只在 Yoga 值更大时更新 `_contentH`，并标记 dirty 让 `recalcContentSize` 重新测量（`renderer/init.lua:261-276`）
**教训**: Yoga 布局值和 display 实际值是两套系统，ScrollView 的内容尺寸应该从实际 display bounds 计算，不能用 Yoga 约束后的值

### ScrollView 需要 contentInset 支持
**日期**: 2026-03-30
**场景**: 底部 tab bar 遮挡滚动内容
**修法**: `ScrollViewFactory` 加 `contentInset = { bottom = N }` 属性，扩展 maxScroll 范围

### 水平 ScrollView 需要 overflow=scroll
**日期**: 2026-03-30
**场景**: 水平滚动分类栏的内容被 Yoga 约束到容器宽度，子元素换行
**修法**: `buildLayoutTree` 对 ScrollView 设 `overflow = "scroll"`，让 Yoga 不约束内容到容器尺寸

---

## native.* 对象

### removeChild 必须递归清理 native 对象
**日期**: 2026-03-29
**场景**: 切换页面后 TextInput 白色横条残留
**根因**: `native.newTextField` 不在 GL display 层级里，父 group 的 `removeSelf()` 不会连带删除它
**修法**: `cleanupNativeFields` 递归遍历 display tree 清理所有 `_inputField`、`_webView`

---

## SceneCanvas / SceneAdapter

### Scene 用工厂模式不用单例
**日期**: 2026-03-29
**场景**: SceneCanvas remount 后 enterFrame 崩溃
**根因**: 单例 scene 的 addEventListener 被覆盖，但旧 timer/enterFrame 回调还在跑
**修法**: 返回工厂函数 `createBoardScene()`，每次 mount 创建新 scene

### enterFrame 回调用 pcall 防护
**日期**: 2026-03-29
**场景**: ImperativeCanvas unmount 后 enterFrame 访问已销毁的 display objects
**修法**: pcall 包裹 onFrame body，失败时设 alive=false 停止渲染

---

## Yoga 布局

### flex:1 不等于等分宽度
**日期**: 2026-03-29
**场景**: 底部 tab bar 按钮不等宽
**根因**: `flex:1` 分配的是**剩余空间**，不是总空间。子节点有不同的固有宽度时分配结果不等宽
**修法**: 用 `width = totalW / count` 明确等分

---

## Worker 管理

### kimi 会越界改不该碰的文件
**日期**: 2026-03-28
**场景**: 让 kimi 做 Canvas demo，他顺手改了 main.lua、TetrisApp.lua、run_tests.lua
**教训**: 派活时明确说"只改指定文件"，训诫后还是重犯。关键文件的修改必须 coordinator 验证

### 反重力 worker 写大文件容易超时
**日期**: 2026-03-28
**场景**: Antigravity Sonnet 写 GameScene.lua（几百行）反复 churn/crunch 超时
**教训**: 大文件拆小任务，或用原生 Claude Code
