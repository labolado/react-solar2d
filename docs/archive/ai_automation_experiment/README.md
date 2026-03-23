# AI自动化测试方案总结

## 已调研的方案

### 1. Midscene.js ⭐ 推荐
**GitHub**: `web-infra-dev/midscene` (12.2k stars)

**特点**:
- AI驱动、视觉感知
- 支持多平台：Web、Desktop、Android、iOS
- 自然语言控制："拖动Slider到中间"
- 字节跳动出品，活跃维护

**平台支持**:
| 平台 | 包名 | 安装命令 |
|------|------|----------|
| Desktop (macOS/Win/Linux) | @midscene/computer | `npm i -g @midscene/computer` |
| Android | @midscene/android | `npm i -g @midscene/android` |
| iOS | @midscene/ios | `npm i -g @midscene/ios` |
| Web | @midscene/web | `npm i -g @midscene/web` |

**使用方法**:
```javascript
import { agentFromComputer } from '@midscene/computer';

const agent = await agentFromComputer();
await agent.aiAct('drag the slider to the right');
const value = await agent.aiQuery('What is the slider value?');
```

**要求**:
- 需要AI Provider API Key (OpenAI/Anthropic等)
- macOS需要Xcode Command Line Tools

---

### 2. 自建Python方案 ✅ 已实现
**文件**: `slider_test.py`, `validator.py`

**特点**:
- 基于OpenCV颜色识别
- 不依赖外部AI服务
- 可检测白色Slider thumb并拖动

**使用方法**:
```bash
# 鼠标控制版本（需要焦点）
python3 slider_test.py

# 纯视觉验证（不占用鼠标）
python3 validator.py
```

---

### 3. ShowUI
**GitHub**: `showlab/ShowUI` (1.7k stars, CVPR 2025)

**特点**:
- 端到端视觉-语言-动作模型
- 支持本地运行（需要GPU）
- 支持拖拽操作

---

## 针对react-solar2d的建议

### 方案A: 快速验证（使用现有Python脚本）
```bash
cd tests/ai_automation
python3 slider_test.py
```

### 方案B: 生产环境（使用Midscene）
1. 设置AI Provider API Key
2. 安装 `@midscene/computer`
3. 编写自然语言测试脚本

### 方案C: 视觉回归测试（使用validator.py）
- 定期截图对比
- 检测UI变化
- 生成测试报告

---

## 文件清单

```
tests/ai_automation/
├── gui_agent.py          # 基础鼠标控制
├── smart_demo.py         # 自动激活Simulator
├── full_demo.py          # 多策略检测
├── slider_test.py        # 专门针对Slider
├── validator.py          # AI视觉验证
├── midscene_test.mjs     # Midscene测试脚本
├── test_slider.lua       # Solar2D内置测试
└── README.md             # 本文档
```

---

## 下一步

1. **试用Midscene**: 配置API Key后运行 `midscene_test.mjs`
2. **完善验证器**: 改进OCR读取小字体Slider数值
3. **集成CI/CD**: 将视觉验证集成到自动化测试流程
