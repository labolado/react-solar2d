# Solar2D UI Automation Server

通用的 Solar2D 应用自动化测试框架。任何 Solar2D 项目接入只需一行代码。

## 快速开始

### 接入

```lua
-- 在 main.lua 中
local testServer = require("tests.infra.test_server")
testServer.start(9876)
```

启动后右上角出现橙色 **TEST** 角标，表示自动化服务已就绪。

### 验证

```bash
curl http://localhost:9876/status
# {"running":true,"time":1711500000,"screen":{"width":414,"height":896},"platform":"Mac OS X"}
```

## API 参考

### 元信息

#### `GET /status`
返回服务器状态和屏幕尺寸。

```bash
curl http://localhost:9876/status
```

### 触摸操作

#### `POST /tap` — 坐标点击
```bash
curl -X POST http://localhost:9876/tap -d "x=200&y=300"
```

#### `POST /tap-text` — 按文字查找并点击
查找屏幕上包含指定文字的元素，点击第 N 个匹配（默认第 1 个）。
```bash
# 点击 "Start" 按钮
curl -X POST http://localhost:9876/tap-text -d "text=Start"

# 点击第 2 个 "OK"
curl -X POST http://localhost:9876/tap-text -d "text=OK&index=2"
```

#### `POST /longpress` — 长按
```bash
# 在 (200,300) 长按 800ms
curl -X POST http://localhost:9876/longpress -d "x=200&y=300&ms=800"
```

#### `POST /drag` — 拖拽手势
模拟完整的 touch began → moved → ended 序列。
```bash
# 从 (200,400) 向上拖 200px，耗时 300ms
curl -X POST http://localhost:9876/drag -d "x=200&y=400&dx=0&dy=-200&ms=300"

# 横向拖拽
curl -X POST http://localhost:9876/drag -d "x=100&y=300&dx=150&dy=0"
```

#### `POST /scroll` — 滚轮滚动
模拟鼠标滚轮事件（Mac trackpad 双指滚动）。
```bash
# 向下滚动 5 个单位
curl -X POST http://localhost:9876/scroll -d "x=200&y=400&dy=5"
```

### 元素查询

#### `GET /find` — 按文字搜索元素
返回匹配元素的坐标、bounds 和是否可点击。
```bash
curl "http://localhost:9876/find?text=Submit"
# {"results":[{"text":"Submit","x":207,"y":450,"bounds":{"xMin":170,"yMin":440,"xMax":244,"yMax":460},"hasOnPress":true}],"count":1}
```

#### `GET /tree` — 显示层级树
导出整个 display 层级结构，用于调试。
```bash
# 默认深度 8
curl http://localhost:9876/tree

# 只看前 3 层
curl "http://localhost:9876/tree?depth=3"
```

返回 JSON 树，每个节点包含：
- `text` — 文字内容（如有）
- `type` — 组件类型（View / ScrollView）
- `bounds` — `[xMin, yMin, xMax, yMax]`
- `pressable` — 是否可点击
- `children` — 子节点

#### `POST /wait` — 等待元素出现
轮询直到指定文字的元素出现，或超时。
```bash
# 等待 "Loading..." 消失后 "Ready" 出现，最多等 10 秒
curl -X POST http://localhost:9876/wait -d "text=Ready&timeout=10000"
# {"found":true,"elapsed":2300,"result":{"text":"Ready","x":200,"y":100,...}}
```

### 截图

#### `GET /screenshot` — 全屏截图
异步捕获，返回 base64 编码的 PNG。
```bash
# 默认文件名
curl http://localhost:9876/screenshot

# 指定标签（影响文件名）
curl "http://localhost:9876/screenshot?label=login_page"
```

响应：
```json
{
  "success": true,
  "filename": "login_page.png",
  "base64": "iVBORw0KGgo...",
  "size": 156832
}
```

> **原理：** 使用 `display.save(display.currentStage, ...)` 截图。Solar2D 也支持对单个 group 截图：`display.save(someGroup, ...)`。

### 代码执行

#### `POST /exec` — 执行 Lua 代码
在 Solar2D 主线程中执行任意 Lua 代码。
```bash
# 打印信息
curl -X POST http://localhost:9876/exec -d "code=print('hello')"

# 获取组件数量
curl -X POST http://localhost:9876/exec -d "code=print(display.currentStage.numChildren)"

# 对指定 group 截图
curl -X POST http://localhost:9876/exec -d "code=display.save(display.currentStage[2],{filename='component.png',baseDir=system.TemporaryDirectory})"
```

## 自定义路由

App 可以通过 `route()` 注册自己的端点：

```lua
local ts = require("tests.infra.test_server")
ts.start(9876)

-- 注册导航路由
ts.route("POST", "/navigate", function(params)
    local page = params.page
    if not page then return ts.err("Missing page") end
    myApp.navigateTo(page)
    return ts.ok({navigated = page})
end)

-- 注册页面列表
ts.route("GET", "/pages", function()
    return ts.ok({pages = myApp.getAllPages()})
end)
```

### 工具函数

自定义 handler 可使用框架暴露的工具：

| 函数 | 用途 |
|------|------|
| `ts.ok(data)` | 返回 200 JSON 响应 |
| `ts.err(msg)` | 返回 400 错误响应 |
| `ts.findByText(text, limit)` | 搜索 display 树中的文字 |
| `ts.simulateTapAt(x, y)` | 程序化点击 |
| `ts.simulateDrag(x, y, dx, dy, ms)` | 程序化拖拽 |
| `ts.dumpTree(group, depth)` | 导出层级树 |
| `ts.jsonEncode(obj)` | JSON 编码 |

## 自动化测试脚本示例

### Python：逐页截图

```python
import requests, time, base64, os

BASE = "http://localhost:9876"
OUT = "./screenshots"
os.makedirs(OUT, exist_ok=True)

# 获取页面列表（app-specific，需 main.lua 注册 /pages）
pages = requests.get(f"{BASE}/pages").json().get("pages", [])

for cat in pages:
    for page in cat["pages"]:
        # 导航
        requests.post(f"{BASE}/navigate", data={"route": page})
        time.sleep(1.5)

        # 截图
        r = requests.get(f"{BASE}/screenshot", params={"label": f"{cat['category']}_{page}"})
        data = r.json()
        if data.get("base64"):
            with open(f"{OUT}/{data['filename']}", "wb") as f:
                f.write(base64.b64decode(data["base64"]))
            print(f"✅ {cat['category']}/{page}")
        else:
            print(f"❌ {cat['category']}/{page}: {data.get('error')}")
```

### Bash：快速交互

```bash
#!/bin/bash
BASE="http://localhost:9876"

# 等待服务器就绪
until curl -s $BASE/status > /dev/null 2>&1; do sleep 1; done
echo "Server ready"

# 查找所有 "Button" 文字
curl -s "$BASE/find?text=Button" | python3 -m json.tool

# 点击第一个
curl -s -X POST "$BASE/tap-text" -d "text=Button"

# 等待 "Success" 出现
curl -s -X POST "$BASE/wait" -d "text=Success&timeout=5000"

# 截图
curl -s "$BASE/screenshot?label=after_click" -o response.json
```

### 自动化脚本集成

```bash
# 通过 /tree 理解界面结构
curl -s "http://localhost:9876/tree?depth=4" | python3 -m json.tool

# 通过 /find 定位元素
curl -s "http://localhost:9876/find?text=DateTimePicker"

# 通过 /tap-text 交互
curl -s -X POST "http://localhost:9876/tap-text" -d "text=DateTimePicker"

# 通过 /screenshot 验证结果
curl -s "http://localhost:9876/screenshot?label=verify"
```

## 架构

```
┌─────────────────────────────────────────┐
│  Solar2D App                            │
│  ┌───────────────────────────────────┐  │
│  │  test_server (port 9876)          │  │
│  │  ├── Generic endpoints            │  │
│  │  │   /tap /drag /find /tree ...   │  │
│  │  └── Custom routes (app-specific) │  │
│  │      /navigate /pages ...         │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  display.currentStage             │  │
│  │  ├── App UI groups                │  │
│  │  └── TEST badge overlay           │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
        ↕ HTTP (localhost:9876)
┌─────────────────────────────────────────┐
│  External Test Runner                   │
│  (Python / Bash / CI)                   │
└─────────────────────────────────────────┘
```

## 注意事项

- **截图** 使用 `display.save()`，比 `display.captureScreen()` 更可靠
- **坐标系** 是 Solar2D content 坐标，不是像素坐标
- **异步操作** (`/screenshot`, `/wait`, `/tree`) 会延迟响应，client 需等待
- **端口冲突**：同一端口只能一个实例，重启 app 需确保旧进程已退出
- 触摸模拟通过 `dispatchEvent` 实现，与真实触摸行为有细微差异
- `/exec` 可执行任意代码，仅用于开发/测试环境
