# React-Solar2D 开发指南

面向 AI agent 和开发者的实操手册。覆盖模拟器、测试、构建、调试等日常工作流。

---

## 目录

1. [项目结构](#项目结构)
2. [环境准备](#环境准备)
3. [Solar2D 模拟器](#solar2d-模拟器)
4. [运行示例](#运行示例)
5. [单元测试](#单元测试)
6. [Test Server 远程测试](#test-server-远程测试)
7. [UI 冒烟测试](#ui-冒烟测试)
8. [查看模拟器日志](#查看模拟器日志)
9. [构建真机版本](#构建真机版本)
10. [SafeArea 使用](#safearea-使用)
11. [Animated 动画](#animated-动画)
12. [ScrollView 注意事项](#scrollview-注意事项)
13. [触摸系统](#触摸系统)
14. [常见坑点](#常见坑点)

---

## 项目结构

```
react-solar2d/
├── react/              # React 核心 (createElement, hooks, reconciler)
├── renderer/           # Solar2D 渲染器 (HostConfig, ScrollViewFactory)
├── components/         # RN 兼容组件 (SafeAreaView, DraggableView 等)
├── layout/             # Yoga C 插件桥接
├── animated/           # 动画系统 (Animated.Value, timing, spring, loop)
├── navigation/         # 导航系统 (Stack, Tab, Drawer)
├── style/              # StyleSheet 系统
├── lib/                # 额外库 (slider, datetime-picker, safe-area 等)
├── tests/              # 单元 + 集成测试
├── examples/           # 示例应用 (KitchenSink, Showcase 等)
├── scripts/            # 构建/测试脚本
├── plugins/            # Yoga C 插件源码 + 编译产物
├── docs/               # 文档
├── config.lua          # Solar2D 配置 (1536x2048, adaptive, 60fps)
├── build.settings      # Solar2D 构建设置 (插件、权限、排除规则)
├── Makefile            # iOS 真机构建
└── run_tests.lua       # 测试入口
```

---

## 环境准备

### 必需

| 工具 | 用途 | 安装 |
|------|------|------|
| Lua 5.1+ | 运行测试 | `brew install lua` |
| Solar2D Simulator | 运行示例、UI 测试 | [solar2d.com](https://solar2d.com) 下载 |
| Yoga C 插件 | 布局引擎 | 已预编译在 `plugins/yoga/build-solar2d/` |

### 可选

| 工具 | 用途 |
|------|------|
| CoronaBuilder | iOS 真机构建 (`/Applications/Corona/Native/`) |
| Xcode + devicectl | iOS 真机安装 |
| Android SDK | Android 构建 (通过 Solar2D 的 Build 菜单) |
| curl / Python | 驱动 test server |

---

## Solar2D 模拟器

### 打开模拟器

**方式 1：GUI 打开**
1. 打开 Solar2D Simulator.app（通常在 `/Applications/Corona/` 或 `/Applications/Solar2D/`）
2. File → Open Project → 选择 `examples/main.lua`

**方式 2：命令行打开**
```bash
# 路径可能因版本不同而变化，常见路径：
SIMULATOR="/Applications/Corona/Corona Simulator.app/Contents/MacOS/Corona Simulator"
# 或
SIMULATOR="/Applications/Solar2D/Solar2D Simulator.app/Contents/MacOS/Solar2D Simulator"

# 启动
"$SIMULATOR" ~/data/dev/app/react-solar2d/examples/main.lua &
```

> **注意：** 模拟器路径因安装版本不同会有变化。用 `ls /Applications/ | grep -i corona` 或 `ls /Applications/ | grep -i solar` 找到实际路径。

### 切换示例页面

`examples/main.lua` 启动一个 5 Tab 底部导航应用：

| Tab | 内容 |
|-----|------|
| 热点 | NewsApp 新闻列表 |
| 问答 | QuizApp 答题 |
| 游戏 | TetrisApp 俄罗斯方块 |
| 组件 | KitchenSink 组件大全 (~50 页) |
| 炫酷 | Showcase 炫酷演示 (SwipeDeck 等) |

### 控制默认打开的 Tab

在 `examples/` 目录创建 `.route` 文件，内容为路由名：

```bash
echo "showcase" > examples/.route   # 默认打开 Showcase
echo "sink" > examples/.route       # 默认打开 KitchenSink
echo "news" > examples/.route       # 默认打开 News
```

### Live Reload

Solar2D 模拟器会监控文件变化。修改 Lua 文件后按 **Cmd+R** 刷新。

---

## 运行示例

### 示例结构

```
examples/
├── main.lua              # 入口，5 Tab 导航
├── ShowcaseApp.lua       # 炫酷演示导航
├── showcase/             # 各个 Showcase 演示
│   ├── SwipeDeck.lua
│   ├── NeonDashboard.lua
│   ├── MusicPlayer.lua
│   └── OnboardingFlow.lua
├── kitchen_sink/         # KitchenSink 各页面
├── config.lua            # 与根目录相同
└── build.settings        # 与根目录相同
```

### 添加新示例

1. 在 `examples/showcase/` 创建 `MyDemo.lua`，导出一个 React 函数组件
2. 在 `examples/ShowcaseApp.lua` 的 `DEMOS` 数组中添加条目
3. Cmd+R 刷新模拟器即可看到

---

## 单元测试

### 运行全部测试

```bash
lua run_tests.lua
```

输出示例：
```
  PASS  tests/react/test_hooks.lua (55 tests)
  PASS  tests/renderer/test_hostConfig.lua (42 tests)
  ...
  Total: 322 passed, 0 failed (39 files)
```

### 按名称过滤

```bash
lua run_tests.lua scrollview      # 运行文件名包含 "scrollview" 的测试
lua run_tests.lua hooks           # 运行 hooks 相关测试
```

### 测试编写规范

```lua
-- tests/mymodule/test_example.lua

-- 1. 设置 package.path（所有测试文件都需要）
package.path = package.path .. ";../?.lua;../lib/?.lua;../lib/?/init.lua"

-- 2. Mock Solar2D 全局变量（headless 环境没有 Solar2D）
display = require("tests.helpers.mock_display")
display.contentWidth = 1536
display.contentHeight = 2048
native = { systemFont = "systemFont", systemFontBold = "systemFontBold" }
timer = { performWithDelay = function() return {} end, cancel = function() end }
system = { getTimer = function() return 0 end }
Runtime = { addEventListener = function() end, removeEventListener = function() end }

-- 3. 导入测试框架
local T = require("tests.helpers.test_runner")

-- 4. 写测试
T.describe("MyModule", function()
    T.it("should do X", function()
        local result = someFunction()
        T.expect(result).toBe(42)
    end)
end)

-- 5. 必须调用 summary（run_tests.lua 解析这行输出）
T.summary()
```

### 可用断言

| 方法 | 说明 |
|------|------|
| `T.expect(v).toBe(x)` | 严格相等 `==` |
| `T.expect(v).toNotBe(x)` | 不等 |
| `T.expect(v).toEqual(x)` | 深度比较（table） |
| `T.expect(v).toBeTruthy()` | 非 nil 且非 false |
| `T.expect(v).toBeFalsy()` | nil 或 false |
| `T.expect(v).toBeNil()` | 是 nil |
| `T.expect(v).toBeType("string")` | type 检查 |

### 关键 Mock 文件

| 文件 | 用途 |
|------|------|
| `tests/helpers/mock_display.lua` | Solar2D display API 的纯 Lua 模拟 |
| `tests/helpers/mock_hooks.lua` | React hooks fiber 上下文模拟 |

### 添加新测试到跑批

在 `run_tests.lua` 的文件列表中添加路径：

```lua
local testFiles = {
    ...
    "tests/mymodule/test_example.lua",   -- 添加这行
}
```

---

## Test Server 远程测试

Test Server 是一个运行在 Solar2D 进程内的 HTTP 服务器，允许外部脚本远程控制模拟器/真机上的应用。

### 启动

模拟器打开 `examples/main.lua` 后，test server 自动在 500ms 后启动。启动成功标志：
- 屏幕底部出现**红色小圆点**
- 右上角出现橙色 **"TEST"** 标记

默认端口：**9876**

### 验证连接

```bash
curl http://localhost:9876/status
```

返回：
```json
{"server":"test_server","screenWidth":1536,"screenHeight":2048,"platform":"macos"}
```

### 常用 API

#### 截图

```bash
# 全屏截图
curl "http://localhost:9876/screenshot?label=home" | python3 -c "
import json,base64,sys
d=json.load(sys.stdin)
open('home.png','wb').write(base64.b64decode(d['base64']))
"

# 按文字定位元素截图
curl "http://localhost:9876/screenshot-element?text=Submit&label=btn"

# 按坐标区域截图
curl "http://localhost:9876/screenshot-element?x=100&y=200&w=300&h=400&label=region"
```

#### 交互

```bash
# 点击坐标
curl -X POST http://localhost:9876/tap -d '{"x":200,"y":300}'

# 按文字点击元素
curl -X POST http://localhost:9876/tap-text -d '{"text":"Submit"}'

# 长按
curl -X POST http://localhost:9876/longpress -d '{"x":200,"y":300,"ms":1000}'

# 拖动
curl -X POST http://localhost:9876/drag -d '{"x":200,"y":500,"dx":0,"dy":-300,"ms":500}'

# 鼠标滚轮
curl -X POST http://localhost:9876/scroll -d '{"x":400,"y":600,"dx":0,"dy":-5}'
```

#### 检查 UI 树

```bash
# 导出显示层级
curl "http://localhost:9876/tree?depth=5"

# 搜索元素
curl "http://localhost:9876/find?text=Submit"
```

#### 导航 KitchenSink

```bash
# 导航到指定页面
curl -X POST http://localhost:9876/navigate -d '{"route":"Slider"}'

# 查看所有可用页面
curl http://localhost:9876/pages
```

#### 执行任意 Lua 代码

```bash
curl -X POST http://localhost:9876/exec -d '{"code":"print(display.contentWidth)"}'
```

#### 等待元素出现

```bash
curl -X POST http://localhost:9876/wait -d '{"text":"Loading complete","timeout":5000}'
```

### 注册自定义路由

在你的 `main.lua` 中：
```lua
local testServer = require("tests.infra.test_server")
testServer.start(9876)

testServer.route("POST", "/my-action", function(body)
    -- body 是解析后的 JSON table
    doSomething(body.param)
    return { success = true }
end)
```

### 截图注意事项

- `display.save()` 无法正确捕获 Container 内的子元素（Solar2D stencil buffer 问题），test server 已自动绕过（临时将 Container 转换为 Group）
- 截图是**异步**的，服务器内部有 50ms 延迟 + 轮询机制
- 超时 10 秒未完成会返回 500 错误

### 命令行客户端

```bash
# 快捷客户端（在 tests/infra/test_client.sh）
bash tests/infra/test_client.sh status
bash tests/infra/test_client.sh nav Slider
bash tests/infra/test_client.sh exec 'print("hello")'
```

---

## UI 冒烟测试

自动遍历所有 KitchenSink 页面，截图 + 点击按钮。

### 前置条件

模拟器已运行且 test server 可用（`curl localhost:9876/status` 有响应）。

### 运行

```bash
bash scripts/ui-smoke-test.sh
```

### 产出

- 截图保存到 `./test-results/YYYYMMDD-HHMMSS/`
- 每个页面：首屏截图 + 交互后截图
- 报告：访问页数、截图数、错误数

> **注意：** 这是视觉冒烟测试，没有自动像素对比。截图用于人工审查。

---

## 查看模拟器日志

### macOS 模拟器

**方式 1：模拟器控制台**
- 模拟器菜单 → Window → Console（或按 Cmd+/）
- 所有 `print()` 输出和运行时错误都显示在这里

**方式 2：系统日志**
```bash
# 实时查看（Solar2D 的 print 输出到 stderr）
log stream --predicate 'process == "Corona Simulator" OR process == "Solar2D Simulator"' --level debug
```

**方式 3：临时文件日志**
```lua
-- 在代码中写日志到文件
local path = system.pathForFile("debug.log", system.DocumentsDirectory)
local f = io.open(path, "a")
f:write(os.date() .. " " .. message .. "\n")
f:close()
```

### iOS 真机

```bash
# 通过 Xcode 的 Console.app 或 devicectl
xcrun devicectl device log --device <DEVICE_UUID>
```

### Android

```bash
adb logcat | grep -i corona
```

### 通过 Test Server 查看

```bash
# 远程执行 print，结果出现在模拟器控制台
curl -X POST http://localhost:9876/exec -d '{"code":"print(display.contentWidth)"}'
```

---

## 构建真机版本

### iOS 真机（推荐方式）

#### 1. 配置签名信息

```bash
cp Makefile.local.example Makefile.local
```

编辑 `Makefile.local`：
```makefile
DEVICE = 00008xxx-xxxx      # xcrun devicectl list devices 获取
SIGN_ID = Apple Development: Your Name (XXXXXXXXXX)
TEAM_ID = XXXXXXXXXX
BUNDLE_ID = com.yourcompany.reactsolar2d
PROFILE = /path/to/your.mobileprovision
```

#### 2. 一键构建 + 安装

```bash
make device
```

这会依次执行：
- `make build` — CoronaBuilder 编译 iOS .app（启用 Live Build）
- `make resign` — 用你的开发证书重签名
- `make install` — 通过 `xcrun devicectl` 安装到真机

#### 3. Live Build

构建时启用了 `liveBuild=true`，安装后修改 Lua 文件会自动同步到设备（需要同一 WiFi）。

### iOS 模拟器

通过 Solar2D Simulator 的 Build 菜单：
- File → Build → iOS
- 选择 target: "Xcode Simulator"
- Build 完成后自动在 iOS Simulator 中打开

### Android

通过 Solar2D Simulator 的 Build 菜单：
- File → Build → Android
- 填写 keystore 路径和密码
- 生成 `.apk` 文件
- 通过 `adb install` 或直接传到设备安装

```bash
# 安装到 Android 设备
adb install -r /path/to/output.apk
```

### 构建排除规则

`build.settings` 自动排除不需要的文件：
```lua
excludeFiles = {
    all = { "tests/**", "plugins/**", "docs/**", "tasks/**",
            "*.md", ".git**", ".claude**", "run_tests.lua" }
}
```

---

## SafeArea 使用

### 方式 1：SafeAreaView 组件（推荐）

自动为 notch、状态栏、Home Indicator 添加 padding：

```lua
local RN = require("react_solar2d")
local ce = RN.createElement

local function App()
    return ce(RN.SafeAreaView, {
        style = { flex = 1, backgroundColor = "#FFF" },
    },
        ce("Text", {}, "内容自动避开刘海和底部横条")
    )
end
```

`SafeAreaView` 内部读取 Solar2D 的安全区域属性，自动设置 `paddingTop` 和 `paddingBottom`。

### 方式 2：手动获取 Insets

```lua
local insets = RN.getSafeAreaInsets()
-- insets.top    -- 状态栏/刘海高度
-- insets.bottom -- Home Indicator 高度
-- insets.left   -- 0（除非横屏）
-- insets.right  -- 0

-- 手动应用
ce("View", {
    style = { paddingTop = insets.top, paddingBottom = insets.bottom },
}, ...)
```

### 方式 3：Hook 风格

```lua
local SafeArea = require("lib.safe-area")
local insets = SafeArea.useSafeAreaInsets()
```

### 注意事项

- 模拟器上 safe area insets 通常为 0（取决于模拟的设备型号）
- 真机上（iPhone X+）top ≈ 44-59, bottom ≈ 34
- `getSafeAreaInsets()` 读取 `display.safeScreenOriginY` 等属性，需要 Solar2D 运行环境
- 横屏模式下 left/right 也会有值

---

## Animated 动画

### 基本用法

```lua
local Animated = RN.Animated

-- 1. 创建值（必须用 useRef 持久化）
local opacityRef = useRef(nil)
if not opacityRef.current then opacityRef.current = Animated.Value(1) end
local opacity = opacityRef.current

-- 2. 启动动画
Animated.timing(opacity, { toValue = 0, duration = 500 }).start()

-- 3. 应用到组件
ce(Animated.View, { style = { opacity = opacity } }, ...)
```

### 支持的动画属性

| 属性 | 说明 |
|------|------|
| `opacity` | 透明度 |
| `translateX` / `translateY` | 位移偏移（叠加在 Yoga 布局位置上） |
| `scaleX` / `scaleY` | 缩放 |
| `rotation` | 旋转（度数） |
| `width` / `height` | 尺寸（有限制，见下文） |

### 动画类型

```lua
-- 线性/缓动
Animated.timing(value, { toValue = 100, duration = 300, easing = easing.outQuad })

-- 弹簧
Animated.spring(value, { toValue = 100 })

-- 序列
Animated.sequence({ anim1, anim2 })

-- 并行
Animated.parallel({ anim1, anim2 })

-- 循环
Animated.loop(anim, { iterations = -1 })  -- -1 = 无限

-- 组合值
Animated.multiply(valueA, valueB)
Animated.add(valueA, 100)
```

### 性能注意事项

- 每个 `Animated.timing` 创建一个 `transition.to` + 一个 `enterFrame` 监听器
- **大量并发动画**（如 12 个 EqBar）应改用单个 `enterFrame` 驱动，而非每个元素各跑一个 `Animated.loop`
- 动画 `width`/`height` 时，`borderRadius > 0` 的 roundedRect 调整 `path.width` 不可靠 — 用 key 强制重建
- `transform: { rotate = 15 }` — 裸数字当度数处理，也接受 `"15deg"`, `"0.5rad"`

---

## ScrollView 注意事项

### 基本用法

```lua
ce(RN.ScrollView, {
    style = { flex = 1 },
    contentContainerStyle = { padding = 16, paddingBottom = 40 },
    horizontal = false,           -- 默认竖向滚动
    onScroll = function(e)        -- 滚动回调
        print(e.contentOffset.y)
    end,
    contentInset = { bottom = 80 },  -- 额外滚动空间（如底部 tab bar）
    onRefresh = function() end,   -- 启用下拉刷新
    refreshing = false,
},
    ce("View", {}, ...),
    ce("View", {}, ...),
)
```

### 内容尺寸计算

ScrollView 通过遍历直接子元素的 `y + layoutHeight` 计算可滚动范围。以下情况可能导致滚不到底：

- 子元素没有明确高度且 `layoutHeight` 未被 Yoga 计算
- `contentContainerStyle.paddingBottom` 确保通过 `_contentPaddingBottom` 加到滚动范围中

### 嵌套 ScrollView

- 同方向嵌套自动工作 — 触摸先派发给最深层的 ScrollView
- **不同方向嵌套**（垂直内嵌水平）：目前不支持自动切换

### 框架限制

- ScrollView 使用 **Container**（`anchorChildren=false`）实现视口裁剪 — 超出滚动区域的内容被隐藏
- 每个 ScrollView 消耗 1 层 mask（Solar2D 限制最多 3 层嵌套），深度嵌套 ScrollView 需注意
- 鼠标滚轮支持：Mac trackpad 双指滚动自动映射

---

## 触摸系统

### TouchRegistry

全局手指所有权管理，防止两个组件抢同一根手指：

```lua
local TouchRegistry = require("lib.TouchRegistry")

-- 检查手指是否可用
if TouchRegistry.canFocus(event.id, myView) then
    TouchRegistry.claim(event.id, myView)   -- 抢占
    -- ... 处理触摸 ...
    TouchRegistry.release(event.id, myView) -- 释放
end
```

### TrackDot 模式

Solar2D 的 `setFocus(target, event.id)` 对同一显示对象的多次调用不可靠。框架用 **TrackDot** 模式：每根手指创建一个不可见的 `display.newCircle` 代理，`setFocus` 对代理调用。

### 触摸监听器放哪里

- 放在 `view._bg`（背景 rect）上，**不要**放在 group 上
- Group 不能可靠地在所有设备上接收触摸事件
- 有 `onPress` 属性的 View 会自动创建透明点击区域（`_pendingBg`）

### Direct Manipulation

如果你的组件需要直接修改 `instance.x/y`（如拖拽、物理驱动）：

```lua
instance._directManipulation = true   -- 禁止 Yoga 覆盖位置
-- ... 自由修改 instance.x, instance.y ...
instance._directManipulation = false  -- 恢复 Yoga 控制
```

**忘记清除这个标志**会导致元素永远停在手动设置的位置。

---

## 常见坑点

### Solar2D 层面

| 坑 | 说明 |
|----|------|
| 颜色值 0-1 | `{1, 0, 0}` 是红色，`{255, 0, 0}` 是白色（被 clamp）。框架自动转换 #hex |
| Anchor 默认居中 | Solar2D 默认 (0.5, 0.5)，框架设为 (0, 0)，手动创建的显示对象要注意 |
| Container 嵌套限制 | 最多 3 层 mask 嵌套。ScrollView 消耗 1 层，ImperativeCanvas(`clip=true`) 消耗 1 层 |
| `removeSelf()` 不 nil 变量 | 必须手动 `obj = nil` |
| `native.*` 渲染最顶层 | TextField、WebView 永远在最上面，无法被遮挡 |
| `display.newRoundedRect` 缩放不可靠 | `path.width` 修改不稳定，框架用 key 重建 |
| 触摸事件必须 `return true` | 否则事件穿透到下层 |

### 框架层面

| 坑 | 说明 |
|----|------|
| `group.contentWidth` ≠ 布局宽 | 用 `instance.layoutWidth`（Yoga 计算值）而非 `contentWidth` |
| Hook 的 Lua 返回值 | `local val, setVal = useState(init)` — 多返回值，不是解构 |
| Animated.Value 必须 useRef | 否则每次渲染创建新值，动画失效 |
| `letterSpacing` 不支持 | Solar2D 没有字符间距 API |
| `lineHeight` 仅存储 | 不会视觉上应用（Solar2D 限制） |
| `pointerEvents: "none"` 不支持 | 无法让组件透传触摸事件 |
| 稀疏数组崩溃 | children 中的 nil/false 必须过滤 |
| Root fiber 位置 | `applyLayout` 跳过 root 的 x/y 以保持 `screenOriginY` 偏移 |

### AI Agent 常犯的错

| 错误 | 正确做法 |
|------|----------|
| 在 example 层面绕过框架 bug | 找到根因，修复框架 |
| 用 `contentHeight` 测量布局 | 用 `layoutHeight`（Yoga 计算值） |
| 动画太多 Animated.loop | 大量同类动画用单个 enterFrame |
| 忘记 `_directManipulation = false` | 拖拽/手势结束后必须清除 |
| Mock 不完整导致测试假通过 | 检查 mock_display 是否覆盖用到的 API |
| 修改后不跑测试 | `lua run_tests.lua` 必须 322 全过 |

---

## 快速参考卡

```bash
# 跑测试
lua run_tests.lua

# 打开模拟器（根据你的安装路径调整）
open -a "Solar2D Simulator" examples/main.lua

# 检查 test server
curl localhost:9876/status

# 全屏截图保存为 PNG
curl -s "localhost:9876/screenshot?label=test" | python3 -c "
import json,base64,sys; d=json.load(sys.stdin)
open('test.png','wb').write(base64.b64decode(d['base64']))"

# 导航到 KitchenSink 页面
curl -X POST localhost:9876/navigate -d '{"route":"Slider"}'

# UI 冒烟测试
bash scripts/ui-smoke-test.sh

# iOS 真机部署
make device

# 打包为 Solar2D 插件
bash scripts/package.sh
```
