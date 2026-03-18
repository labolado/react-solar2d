# Test Infrastructure

HTTP 远程测试基础设施，用于自动化测试和 CI/CD 集成。

## 文件说明

| 文件 | 用途 |
|------|------|
| `test_server.lua` | Solar2D 内置 HTTP 服务器，提供远程测试 API |
| `test_runner_solar2d.lua` | Solar2D 环境测试运行器 |
| `test_client.sh` | 命令行测试客户端 (curl 封装) |
| `test_driver.html` | 浏览器测试控制面板 |

## 快速开始

### 1. 启动模拟器

```bash
/Applications/Corona-b3/Corona\ Simulator.app/Contents/MacOS/Corona\ Simulator -no-console YES examples/main.lua
```

模拟器启动后，HTTP 测试服务器自动运行在端口 9876。

### 2. 命令行测试

```bash
# 使用客户端脚本
cd tests/infra
./test_client.sh status
./test_client.sh run pressable
./test_client.sh tap Forms

# 或直接 curl
curl http://localhost:9876/status
curl -X POST http://localhost:9876/run -d "pattern=all"
```

### 3. 浏览器控制面板

```bash
# 启动本地 HTTP 服务器
python3 -m http.server 8080

# 访问 http://localhost:8080/test_driver.html
```

## API 端点

| 端点 | 方法 | 参数 | 说明 |
|------|------|------|------|
| `/status` | GET | - | 服务器状态 |
| `/run` | POST | `pattern=all\|pressable\|...` | 运行测试 |
| `/exec` | POST | `code=<lua_code>` | 执行 Lua 代码 |
| `/categories` | GET | - | 获取分类列表 |
| `/tap` | POST | `category=<key>` | 模拟分类点击 |
| `/navigate` | POST | `route=<name>` | 导航到路由 |

## CI/CD 集成示例

```yaml
# .github/workflows/test.yml
name: Test
on: [push]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Start Solar2D Simulator
        run: |
          /Applications/Corona\ Simulator.app/Contents/MacOS/Corona\ Simulator -no-console YES examples/main.lua &
          sleep 10
      - name: Run Tests
        run: |
          curl -X POST http://localhost:9876/run -d "pattern=all"
```

## 安全提示

- 生产环境应移除 test_server 代码
- `/exec` 端点可执行任意 Lua 代码，仅用于开发和测试
