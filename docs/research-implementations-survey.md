# Research: Existing React-like Lua Implementations Survey

> **Version:** 1.0 | **Date:** 2026-03-15 | **Status:** Active

## Executive Summary

通过 GitHub 代码搜索和项目分析，发现了 **8 个** React-like Lua 实现。其中 3 个对 react-solar2d 有高参考价值。**没有任何项目针对 Solar2D**，确认我们的方向是独一无二的。

## Tier 1: 高价值参考 (直接可借鉴)

### 1. Solyd (emmachase/Solyd) — 推荐度: ★★★★★

- **LOC:** 562 行纯 Lua
- **平台:** ComputerCraft (Lua 5.1 兼容!)
- **特点:**
  - 两阶段渲染: `_render()` 树展开 + `_cleanDirty()` 脏节点清理
  - 完整 hooks: useState, useRef, useMemo, useCallback, useEffect, useContext, useSyncExternalStore
  - 深度 prop diffing，无外部依赖
  - Context API 带自动消费者追踪
  - 底向上卸载确保正确的生命周期
  - 键控子节点 (keyed children) 支持

**关键借鉴:**
- 脏状态追踪比 Fiber 调度更适合游戏引擎（同步、可预测）
- `__hook[key]` 存储模式 + `__volatile` 渲染元数据分离
- `propsChanged()` 递归比较，带 `__opaque` 跳过标记

### 2. react.wow (mixxorz/react.wow) — 推荐度: ★★★★

- **LOC:** 348 行单文件
- **平台:** World of Warcraft (Lua 5.1)
- **特点:**
  - 标准 Fiber 架构 (React 16+ 风格)
  - 两阶段 render/commit 分离
  - Effect tags: UPDATE, PLACEMENT, DELETION
  - 深度优先遍历: child → sibling → uncle

**关键借鉴:**
- Fiber 树结构和遍历模式
- reconcileChildren 算法清晰简洁
- 属性自动重置模式

### 3. ReactJIT Love2D (captnocap/reactjit) — 推荐度: ★★★★

- **LOC:** 大型项目，Love2D 版含完整 React + Flexbox
- **平台:** Love2D → 后来移植到 Zig
- **特点:**
  - **纯 Lua Flexbox 布局引擎** (~600行，后移植到 Zig)
  - React 组件: Box, Text, Image, Pressable, ScrollView
  - 事件系统 (onPress, hover, keyboard)
  - 带溢出裁剪的 ScrollView

**关键借鉴:**
- Lua Flexbox 实现是最接近我们需求的参考
- 组件 API (Box/Text/Image/Pressable) 与 RN 高度一致
- Love2D 渲染器模式可映射到 Solar2D

## Tier 2: 中等价值参考

### 4. Luact (lxsmnsyc/luact)

- **特点:** Renderer-agnostic, hooks, Love2D reconciler
- **价值:** 渲染器无关设计模式，host config 抽象层
- **限制:** 仍在开发中

### 5. lua-reactor (talldan/lua-reactor)

- **特点:** React 组件系统, PropType 验证, Context 支持
- **价值:** 学习用参考
- **限制:** 较老的 class-based 组件模型

### 6. johnnyjoy/ui

- **特点:** 模块化架构，引擎抽象模式
- **价值:** 动态元素注册，解耦渲染器设计
- **限制:** Minetest 专用，init.lua 只是加载器

## Tier 3: 低价值 (平台锁定或不完整)

### 7. react-lua / react-luau (jsdotlua/react-lua, Roblox)

- 完整 React 17 port，但 Luau 语法，~5000 行 reconciler
- 可作为 API 参考，不适合直接移植

### 8. FlexLove (mikefreno/FlexLove)

- Love2D Flexbox GUI 库
- 立即/保留模式双支持，9patch 主题
- 可参考 Flexbox 实现

## 重大发现: luaYoga

- **williamwen1986/luaYoga** — Meta Yoga 引擎的 Lua C 绑定
- **用户确认: Solar2D 能加载原生 C 插件**
- 这意味着可以直接使用 Yoga C 库做布局，获得完整 Flexbox 规范支持
- 备选方案: 先用纯 Lua 简化版，性能不够再切 Yoga C

## 对计划的影响

| 发现 | 对计划的影响 | 建议动作 |
|------|-------------|---------|
| Solyd 562行实现 | 我们的 reconciler 可以更简化 | 参考 Solyd 的脏追踪替代 Fiber 调度 |
| react.wow Fiber 模式 | 验证了我们的 Fiber 方案可行 | 保持当前方案，参考 effect tag 模式 |
| ReactJIT Lua Flexbox | 有现成的纯 Lua Flexbox 参考 | 获取其 Flexbox 实现对比我们的版本 |
| luaYoga C 绑定 | Solar2D 可用原生 Yoga | 作为 Phase 2 性能优化选项 |
| 零 Solar2D 竞品 | 确认项目独特性 | 继续当前方向 |

## Sources

- [Solyd](https://github.com/emmachase/Solyd) — ComputerCraft React framework
- [react.wow](https://github.com/mixxorz/react.wow) — WoW React framework
- [ReactJIT](https://github.com/captnocap/reactjit) — React + Flexbox for Love2D → native
- [Luact](https://github.com/lxsmnsyc/luact) — Renderer-agnostic Lua React
- [lua-reactor](https://github.com/talldan/lua-reactor) — React component system for Lua
- [johnnyjoy/ui](https://github.com/johnnyjoy/ui) — Modular Lua UI framework
- [react-lua](https://github.com/jsdotlua/react-lua) — Roblox React 17 port
- [FlexLove](https://github.com/mikefreno/FlexLove) — Love2D Flexbox GUI
- [luaYoga](https://github.com/williamwen1986/luaYoga) — Yoga C bindings for Lua
- [Didact](https://github.com/pomber/didact) — Build your own React (JS, 教学用)
- [awesome-react-lua](https://github.com/YetAnotherClown/awesome-react-lua) — React Lua 生态索引
