# React-Solar2D 自动化测试指南

## 测试架构

```
tests/
├── infra/              # 测试基础设施
│   ├── test_server.lua         # HTTP 测试服务器
│   ├── test_runner_solar2d.lua # Solar2D 测试运行器
│   ├── test_client.sh          # 命令行测试客户端
│   └── test_driver.html        # 浏览器测试控制面板
├── helpers/            # 测试辅助工具
│   ├── mock_display.lua        # display API 模拟
│   └── test_runner.lua         # 基础测试框架
├── components/         # 组件测试
├── react/              # React 核心测试
├── renderer/           # 渲染器测试
├── navigation/         # 导航测试
├── style/              # 样式测试
├── integration/        # 集成测试
├── solar2d/            # Solar2D 环境测试
└── animated/           # 动画测试
```

## 1. 本地单元测试 (Lua 5.1+)

运行所有测试：
```bash
lua run_tests.lua
```

运行特定测试：
```bash
lua run_tests.lua pressable    # Pressable 组件测试
lua run_tests.lua renderer     # 渲染器测试
lua run_tests.lua hooks        # Hooks 测试
```

## 2. Solar2D 模拟器测试

### 启动时自动测试

创建 `.test` 文件：
```bash
# 运行所有测试
echo "all" > examples/.test

# 或运行特定测试
echo "pressable" > examples/.test
```

启动模拟器：
```bash
/Applications/Corona-b3/Corona\ Simulator.app/Contents/MacOS/Corona\ Simulator -no-console YES examples/main.lua
```

### HTTP 远程测试 (端口 9876)

模拟器启动后自动启动 HTTP 测试服务器。

#### 命令行客户端
```bash
# 检查服务器状态
curl http://localhost:9876/status

# 运行测试
curl -X POST http://localhost:9876/run -d "pattern=pressable"

# 切换 KitchenSink 分类
curl -X POST http://localhost:9876/tap -d "category=Forms"

# 执行 Lua 代码
curl -X POST http://localhost:9876/exec --data-urlencode "code=print('hello')"
```

#### 浏览器控制面板

启动本地 HTTP 服务器：
```bash
cd tests/infra
python3 -m http.server 8080
```

访问 http://localhost:8080/test_driver.html

功能：
- 可视化分类切换
- 自动测试序列（可调速度）
- 单元测试执行
- Lua 代码执行

## 3. CI/CD 集成

GitHub Actions 示例：
```yaml
name: Test
on: [push, pull_request]
jobs:
  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: leafo/gh-actions-lua@v10
        with:
          luaVersion: "5.1"
      - run: lua run_tests.lua
```

## 4. 添加新测试

参考模板：
```lua
-- tests/components/test_example.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local React = require("react")
local Component = require("components.YourComponent")

T.describe("YourComponent", function()
    T.it("does something", function()
        local result = Component.someFunction()
        T.expect(result).toBe("expected")
    end)
end)

T.summary()
```

添加到 `run_tests.lua`：
```lua
local testFiles = {
    -- ... 其他测试
    "tests/components/test_example.lua",
}
```

## 5. 测试类型说明

| 测试类型 | 目录 | 说明 |
|---------|------|------|
| 单元测试 | `tests/react/`, `tests/components/` | 纯逻辑，无需 Solar2D 环境 |
| 渲染测试 | `tests/renderer/` | 测试 HostConfig 和渲染逻辑 |
| 集成测试 | `tests/integration/` | 完整渲染流程 |
| Solar2D 测试 | `tests/solar2d/` | 需要真实/模拟 Solar2D 环境 |
| HTTP 测试 | `tests/infra/` | 远程控制和自动化 |

## 6. 调试技巧

### 查看测试日志
```bash
# 在 Solar2D 模拟器中查看 Console 输出
# 或使用 test_server 的 exec 端点
curl -X POST http://localhost:9876/exec --data-urlencode "code=return tostring(display.contentWidth)"
```

### 快速验证修复
```bash
# 只运行相关测试
lua run_tests.lua pressable
lua tests/components/test_pressable.lua
```

## 7. 已知限制

1. **物理点击测试**：Solar2D 模拟器中的手动 tap 事件仍需调试
2. **Yoga 布局**：需要 C 插件，单元测试中跳过
3. **网络图片**：Image 组件的远程加载在单元测试中模拟
