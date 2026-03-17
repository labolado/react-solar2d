# React-Solar2D 扩展路线图

## 当前状态 (Core)
- ✅ React Core (createElement, hooks, reconciler)
- ✅ Renderer (Solar2D host)
- ✅ Layout (Yoga Flexbox)
- ✅ Basic Components (View, Text, Image, Button, ScrollView, FlatList, TextInput, Pressable, Modal, etc.)
- ✅ Navigation (Stack, Tab, Drawer)
- ✅ Animation (Animated API)
- ✅ Style System

## Phase 1: Essential Libraries (P0)

### 1. @react-native-async-storage/async-storage
**Purpose**: 本地持久化存储
**Solar2D映射**: `io.*` + JSON + `system.DocumentsDirectory`
**API对齐**: `setItem`, `getItem`, `removeItem`, `mergeItem`
**复杂度**: ⭐
**价值**: ⭐⭐⭐⭐⭐

### 2. @react-native-community/netinfo
**Purpose**: 网络状态检测
**Solar2D映射**: `network.request()` 测试 + 定时轮询
**API对齐**: `fetch`, `addEventListener`
**复杂度**: ⭐⭐
**价值**: ⭐⭐⭐⭐⭐

### 3. react-native-safe-area-context
**Purpose**: 安全区域适配 (刘海屏、灵动岛)
**Solar2D映射**: `display.safeScreenOriginY`, `display.safeActualContentHeight`
**API对齐**: `SafeAreaProvider`, `SafeAreaView`, `useSafeAreaInsets`
**复杂度**: ⭐⭐
**价值**: ⭐⭐⭐⭐

### 4. @react-native-picker/picker
**Purpose**: 选择器组件
**Solar2D映射**: `native.showPicker` 或自定义UI
**API对齐**: `Picker`, `Picker.Item`
**复杂度**: ⭐⭐⭐
**价值**: ⭐⭐⭐⭐

### 5. react-native-vector-icons
**Purpose**: 图标系统
**Solar2D映射**: 字体文件 (ttf) + display.newText
**API对齐**: `Icon`, `Icon.Button`
**复杂度**: ⭐⭐
**价值**: ⭐⭐⭐⭐

## Phase 2: Important Libraries (P1)

### 6. react-native-gesture-handler
**Purpose**: 高级手势处理 (滑动、捏合、旋转)
**Solar2D映射**: Touch events + 自定义手势识别
**API对齐**: `PanGestureHandler`, `PinchGestureHandler`, etc.
**复杂度**: ⭐⭐⭐⭐
**价值**: ⭐⭐⭐⭐

### 7. react-native-reanimated
**Purpose**: 高性能动画
**Solar2D映射**: `transition.to` + `enterFrame` 事件
**API对齐**: `useSharedValue`, `useAnimatedStyle`
**复杂度**: ⭐⭐⭐⭐
**价值**: ⭐⭐⭐⭐

### 8. react-native-svg
**Purpose**: SVG 矢量图
**Solar2D映射**: `display.newLine`, `display.newCircle`, `display.newRect` + 路径解析
**API对齐**: `Svg`, `Path`, `Circle`, `Rect`
**复杂度**: ⭐⭐⭐⭐
**价值**: ⭐⭐⭐

### 9. @react-native-community/slider
**Purpose**: 滑块组件
**Solar2D映射**: 自定义 Group + Rect + 触摸处理
**API对齐**: `Slider`
**复杂度**: ⭐⭐⭐
**价值**: ⭐⭐⭐

### 10. react-native-device-info
**Purpose**: 设备信息
**Solar2D映射**: `system.getInfo`
**API对齐**: `getDeviceId`, `getVersion`, `getBrand`
**复杂度**: ⭐
**价值**: ⭐⭐⭐

## Phase 3: Nice-to-Have (P2)

### 11. @react-native-community/datetimepicker
**Purpose**: 日期时间选择器
**Solar2D映射**: `native.showAlert` 或自定义 UI
**复杂度**: ⭐⭐⭐
**价值**: ⭐⭐⭐

### 12. react-native-permissions
**Purpose**: 权限管理
**Solar2D映射**: Solar2D permissions API
**复杂度**: ⭐⭐
**价值**: ⭐⭐

### 13. react-native-share
**Purpose**: 内容分享
**Solar2D映射**: `native.showPopup`
**复杂度**: ⭐⭐
**价值**: ⭐⭐

### 14. react-native-webview
**Purpose**: 嵌入网页
**Solar2D映射**: `native.newWebView`
**复杂度**: ⭐⭐⭐
**价值**: ⭐⭐

### 15. @react-native-clipboard/clipboard
**Purpose**: 剪贴板
**Solar2D映射**: Solar2D clipboard API
**复杂度**: ⭐
**价值**: ⭐⭐

---

## 开发原则

1. **独立 Lib**: 每个库放在 `lib/<library-name>/`
2. **测试优先**: 每个库配完整单元测试 `lib/<library-name>/tests/`
3. **演示集成**: 添加到 KitchenSink 的 Interop 分类
4. **API 100%**: 保持 React Native API 兼容
5. **渐进增强**: 先 core 功能，再高级特性

## Git 管理

```bash
# 每个库独立 commit
feat: add @react-native-async-storage/async-storage

# 包含
- lib/async-storage/init.lua       # 主实现
- lib/async-storage/index.d.ts    # 类型定义
- lib/async-storage/tests/test.lua # 测试
- examples/kitchen_sink/InteropScreens.lua # 演示
- docs/lib/async-storage.md        # 文档
```
