# UI 自动化测试

test_server 是一个通用的 Solar2D UI 自动化服务器。接入任何 Solar2D 项目只需两行代码，即可通过 HTTP 远程控制 app：点击、拖拽、截图、查询元素、执行代码。

## 接入

在 `main.lua` 中添加：

```lua
local testServer = require("tests.infra.test_server")
testServer.start(9876)
```

启动后屏幕底部中央出现 **红色圆点**，表示服务已就绪。

验证：
```bash
curl http://localhost:9876/status
# {"running":true,"screen":{"width":375,"height":812},...}
```

## API

### 触摸

```bash
# 坐标点击
curl -X POST localhost:9876/tap -d "x=200&y=300"

# 按文字点击（自动查找元素）
curl -X POST localhost:9876/tap-text -d "text=Submit"

# 按文字点击第 N 个匹配
curl -X POST localhost:9876/tap-text -d "text=OK&index=2"

# 长按
curl -X POST localhost:9876/longpress -d "x=200&y=300&ms=800"

# 拖拽（从 (x,y) 移动 (dx,dy)，耗时 ms）
curl -X POST localhost:9876/drag -d "x=200&y=400&dx=0&dy=-200&ms=300"

# 滚轮滚动
curl -X POST localhost:9876/scroll -d "x=200&y=400&dy=5"
```

### 查询

```bash
# 按文字搜索元素（返回坐标、bounds、是否可点击）
curl "localhost:9876/find?text=Submit"

# 等待元素出现（轮询至超时）
curl -X POST localhost:9876/wait -d "text=Ready&timeout=5000"

# 导出 display 层级树
curl "localhost:9876/tree?depth=4"
```

### 截图

```bash
# 全屏截图（返回 base64 PNG）
curl "localhost:9876/screenshot?label=home"

# 按文字截取元素区域
curl "localhost:9876/screenshot-element?text=Button&label=btn"

# 按坐标截取区域
curl "localhost:9876/screenshot-element?x=0&y=100&w=375&h=200&label=header"
```

### 代码执行

```bash
# 在 Solar2D 主线程执行 Lua（结果 print 到控制台）
curl -X POST localhost:9876/exec -d "code=print(display.contentWidth)"
```

## 自定义路由

为你的 app 注册专用端点：

```lua
local ts = require("tests.infra.test_server")
ts.start(9876)

-- 注册导航路由
ts.route("POST", "/go-to", function(params)
    myApp.navigateTo(params.page)
    return ts.ok({navigated = params.page})
end)

-- 注册状态查询
ts.route("GET", "/app-state", function()
    return ts.ok({screen = myApp.currentScreen, user = myApp.currentUser})
end)
```

handler 中可用的工具函数：

| 函数 | 用途 |
|------|------|
| `ts.ok(data)` | 返回 200 JSON |
| `ts.err(msg)` | 返回 400 错误 |
| `ts.findByText(text, limit)` | 搜索 display 树中的文字 |
| `ts.simulateTapAt(x, y)` | 程序化点击 |
| `ts.simulateDrag(x, y, dx, dy, ms)` | 程序化拖拽 |
| `ts.dumpTree(group, depth)` | 导出层级树 |

## 实战示例

### 登录流程测试（Bash）

```bash
#!/bin/bash
BASE="http://localhost:9876"

# 等待 app 启动
until curl -s $BASE/status > /dev/null 2>&1; do sleep 1; done

# 输入用户名密码
curl -X POST "$BASE/tap-text" -d "text=Username"
curl -X POST "$BASE/input" -d "text=testuser"
curl -X POST "$BASE/tap-text" -d "text=Password"
curl -X POST "$BASE/input" -d "text=123456"

# 点击登录
curl -X POST "$BASE/tap-text" -d "text=Login"

# 等待跳转
curl -X POST "$BASE/wait" -d "text=Welcome&timeout=5000"

# 截图验证
curl -s "$BASE/screenshot?label=after_login" | python3 -c "
import sys, json, base64
d = json.load(sys.stdin)
open('after_login.png', 'wb').write(base64.b64decode(d['base64']))
"
```

### 逐页截图（Python）

```python
import requests, time, base64, os

BASE = "http://localhost:9876"
pages = ["Home", "Settings", "Profile"]

os.makedirs("screenshots", exist_ok=True)
for page in pages:
    requests.post(f"{BASE}/go-to", data={"page": page})
    time.sleep(1)
    r = requests.get(f"{BASE}/screenshot", params={"label": page})
    data = r.json()
    if data.get("base64"):
        with open(f"screenshots/{data['filename']}", "wb") as f:
            f.write(base64.b64decode(data["base64"]))
        print(f"OK: {page}")
```

### 回归测试（Python）

```python
import requests, time

BASE = "http://localhost:9876"

def tap(text):
    r = requests.post(f"{BASE}/tap-text", data={"text": text})
    time.sleep(0.5)
    return r.json()

def wait_for(text, timeout=3000):
    r = requests.post(f"{BASE}/wait", data={"text": text, "timeout": timeout})
    return r.json().get("found", False)

def find(text):
    r = requests.get(f"{BASE}/find", params={"text": text})
    return r.json().get("results", [])

# 测试：点击 "Add" 按钮后列表新增一项
tap("Add")
assert wait_for("Item 1"), "Item 1 should appear after tap"

tap("Add")
results = find("Item")
assert len(results) == 2, f"Expected 2 items, got {len(results)}"

tap("Delete All")
results = find("Item")
assert len(results) == 0, "All items should be deleted"

print("All tests passed")
```

## 注意事项

- **坐标系** — 使用 Solar2D content 坐标，不是屏幕像素
- **触摸模拟** — 通过 `dispatchEvent` 实现，与真实触摸有细微差异
- **端口冲突** — 同一端口只能一个实例，重启 app 前确保旧进程已退出
- **`/exec`** — 可执行任意 Lua 代码，仅用于开发/测试环境，勿暴露到公网
- **截图** — 使用 `display.save(stage)` 截取，异步返回，客户端需等待响应

---

# 框架开发者专区

以下内容仅适用于 react-solar2d 框架本身的开发和维护。

## 单元测试

```bash
lua run_tests.lua               # 全部测试
lua run_tests.lua scrollview    # 按名称模糊匹配
make test                       # 同上
```

测试目录：
```
tests/
├── react/          # createElement, hooks, reconciler
├── renderer/       # HostConfig, 渲染管线
├── components/     # Button, Pressable, Switch 等
├── navigation/     # Stack, Tab, Drawer 导航
├── style/          # StyleSheet
├── animated/       # 动画
├── integration/    # 完整渲染流程
└── helpers/        # mock_display, test_runner
```

添加测试：
```lua
-- tests/components/test_example.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

T.describe("MyComponent", function()
    T.it("works", function()
        T.expect(1 + 1).toBe(2)
    end)
end)

T.summary()
```

然后在 `run_tests.lua` 的 testFiles 中添加路径。

## iOS 真机构建

```bash
make device      # 构建 + 重签名 + 安装
make build       # 仅构建
make install     # 仅安装
make uninstall   # 卸载
```

流程：CoronaBuilder 编译（`liveBuild=true`）→ dev profile 重签名 → `xcrun devicectl` 安装。安装后编辑 Lua 文件会通过 WiFi 自动同步到设备。

Makefile 顶部变量需根据环境修改（`DEVICE`, `SIGN_ID`, `TEAM_ID` 等）。

## 浏览器控制面板

```bash
cd tests/infra && python3 -m http.server 8080
# 打开 http://localhost:8080/test_driver.html
```

## KitchenSink 专用路由

```bash
curl -X POST localhost:9876/tap-category -d "category=Overlay"
curl -X POST localhost:9876/navigate -d "route=Alert"
```
