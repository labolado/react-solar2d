#!/usr/bin/env python3
"""
全自动 Slider 测试 - 自动导航、检测、验证
"""

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import time
import os
import json
from datetime import datetime
import subprocess


class FullAutoTester:
    """全自动测试 - 包括导航、检测、验证"""

    def __init__(self, output_dir=None):
        self.output_dir = output_dir or os.path.dirname(os.path.abspath(__file__))
        self.reports_dir = os.path.join(self.output_dir, 'reports')
        os.makedirs(self.reports_dir, exist_ok=True)

    def capture(self, name):
        """使用macOS原生截图"""
        # 先激活 Simulator 确保它在前台
        subprocess.run([
            'osascript', '-e',
            'tell application "Corona Simulator" to activate'
        ], capture_output=True)
        time.sleep(0.5)
        path = os.path.join(self.reports_dir, f"{name}.png")
        subprocess.run(['screencapture', '-x', path], check=True)
        return path

    def find_simulator_region(self, img_path):
        """自动定位iPhone Simulator窗口 - 通过黑色边框+屏幕内容特征"""
        img = cv2.imread(img_path)
        if img is None:
            return None

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        _, black_mask = cv2.threshold(gray, 30, 255, cv2.THRESH_BINARY_INV)
        contours, _ = cv2.findContours(black_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        candidates = []
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            aspect = h / w if w > 0 else 0
            area = w * h
            # iPhone Simulator 特征：比例 0.5-2.2，合理的尺寸范围
            # 支持横屏和竖屏 iPhone 模拟器
            if 0.4 < aspect < 2.5 and 500 < w < 1500 and 600 < h < 2500:
                candidates.append((area, x, y, w, h, aspect))

        if candidates:
            # 选择最像 iPhone 的（比例接近 2.0 的优先）
            candidates.sort(key=lambda c: abs(c[5] - 2.0))  # 按与 2.0 的差值排序
            _, x, y, w, h, aspect = candidates[0]
            print(f"   Selected iPhone-like: ({x}, {y}) size {w}x{h} aspect={aspect:.2f}")
            return (x, y, w, h)
        return None

    def detect_screen_state(self, img_path, sim_region):
        """检测当前页面状态"""
        img = cv2.imread(img_path)
        if img is None or sim_region is None:
            return "unknown"

        sx, sy, sw, sh = sim_region
        sim_img = img[sy:sy+sh, sx:sx+sw]

        # 保存调试图
        debug_path = os.path.join(self.reports_dir, 'debug_screen.png')
        cv2.imwrite(debug_path, sim_img)

        # OCR 检测文字来判断页面
        # 简单方法：检测特定颜色的文字区域
        gray = cv2.cvtColor(sim_img, cv2.COLOR_BGR2GRAY)

        # 检测 "Slider" 文字（黄色标题）
        # 检测 "基础" 标签（蓝色背景）
        # 检测列表项（白色背景卡片）

        # 检测底部标签栏
        bottom_region = sim_img[int(sh*0.9):, :]
        blue_tags = self._detect_blue_tags(bottom_region)

        # 检测内容区域是否有 Slider
        content_region = sim_img[int(sh*0.15):int(sh*0.85), :]
        sliders = self._find_sliders_in_region(content_region)

        if len(sliders) >= 3:
            return "slider_page", sliders
        elif blue_tags > 0:
            return "main_menu", []
        else:
            return "unknown", []

    def _detect_blue_tags(self, region):
        """检测底部蓝色标签"""
        # 检测蓝色像素
        lower_blue = np.array([150, 100, 50])
        upper_blue = np.array([255, 200, 150])
        blue_mask = cv2.inRange(region, lower_blue, upper_blue)
        return np.count_nonzero(blue_mask)

    def _find_sliders_in_region(self, region):
        """在区域内寻找 Sliders"""
        # 寻找白色圆形（Slider thumbs）
        lower_white = np.array([200, 200, 200])
        upper_white = np.array([255, 255, 255])
        white_mask = cv2.inRange(region, lower_white, upper_white)

        kernel = np.ones((3,3), np.uint8)
        white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_OPEN, kernel)

        contours, _ = cv2.findContours(white_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        sliders = []
        for c in contours:
            area = cv2.contourArea(c)
            if 50 < area < 500:  # Slider thumb 大小
                x, y, w, h = cv2.boundingRect(c)
                aspect = w / h if h > 0 else 0
                if 0.6 < aspect < 1.5:  # 圆形检查
                    sliders.append({
                        'x': x + w//2,
                        'y': y + h//2,
                        'area': area
                    })

        # 按y坐标排序
        sliders.sort(key=lambda s: s['y'])
        return sliders

    def navigate_to_slider(self, sim_region):
        """自动导航到 Slider 页面 - 使用 HTTP 控制"""
        print("   🧭 Navigating to Slider page via HTTP...")

        # 使用 test server 的 /tap 端点先点击 Basics 类别
        try:
            # Slider 在 Interop 类别里！
            result = subprocess.run([
                'curl', '-s', '-X', 'POST',
                'http://localhost:9876/tap',
                '-d', 'category=Interop'
            ], capture_output=True, text=True, timeout=5)
            print(f"   Tap Interop: {result.stdout.strip()}")
            time.sleep(2)

            # 然后使用 /navigate 导航到 Slider
            result = subprocess.run([
                'curl', '-s', '-X', 'POST',
                'http://localhost:9876/navigate',
                '-d', 'route=Slider'
            ], capture_output=True, text=True, timeout=5)
            print(f"   Navigate to Slider: {result.stdout.strip()}")
            time.sleep(3)
            return True
        except Exception as e:
            print(f"   ⚠️ HTTP navigation failed: {e}")
            return False

    def tap_screen(self, x, y):
        """通过 HTTP 在屏幕坐标点击"""
        try:
            result = subprocess.run([
                'curl', '-s', '-X', 'POST',
                'http://localhost:9876/tap',
                '-d', f'x={x}&y={y}'
            ], capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except:
            return False

    def find_sliders(self, img_path, sim_region):
        """寻找所有 Sliders"""
        img = cv2.imread(img_path)
        if img is None or sim_region is None:
            return []

        sx, sy, sw, sh = sim_region
        content_region = img[sy+int(sh*0.1):sy+int(sh*0.9), sx:sx+sw]

        # 白色圆形检测
        lower_white = np.array([200, 200, 200])
        upper_white = np.array([255, 255, 255])
        white_mask = cv2.inRange(content_region, lower_white, upper_white)

        kernel = np.ones((3,3), np.uint8)
        white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_OPEN, kernel)

        contours, _ = cv2.findContours(white_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        sliders = []
        debug_img = img.copy()
        cv2.rectangle(debug_img, (sx, sy), (sx+sw, sy+sh), (0, 255, 0), 2)

        for c in contours:
            area = cv2.contourArea(c)
            if 100 < area < 2000:  # Slider thumbs 实际大小约 1300
                x, y, w, h = cv2.boundingRect(c)
                aspect = w / h if h > 0 else 0
                if 0.8 < aspect < 1.3:  # 更严格的圆形检查
                    global_x = sx + x + w//2
                    global_y = sy + int(sh*0.1) + y + h//2
                    sliders.append({
                        'x': global_x,
                        'y': global_y,
                        'local_x': x + w//2,
                        'local_y': y + h//2,
                        'area': area
                    })
                    cv2.circle(debug_img, (global_x, global_y), 15, (0, 0, 255), 2)

        # 保存调试图
        debug_path = os.path.join(self.reports_dir, 'debug_sliders.png')
        cv2.imwrite(debug_path, debug_img)

        sliders.sort(key=lambda s: s['y'])
        return sliders

    def generate_report(self, results):
        """生成HTML报告"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_path = os.path.join(self.reports_dir, f'report_{timestamp}.html')

        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Full Auto Slider Test Report</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }}
        h1 {{ color: #333; }}
        .card {{
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin: 15px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .slider-item {{
            display: flex;
            align-items: center;
            padding: 10px;
            margin: 10px 0;
            background: #f8f9fa;
            border-radius: 6px;
        }}
        .status-pass {{ background: #d4edda; color: #155724; padding: 5px 12px; border-radius: 12px; }}
        .status-fail {{ background: #f8d7da; color: #721c24; padding: 5px 12px; border-radius: 12px; }}
        img {{ max-width: 100%; border-radius: 8px; margin: 10px 0; }}
    </style>
</head>
<body>
    <h1>🤖 Full Auto Slider Test Report</h1>
    <div class="timestamp">Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</div>

    <div class="card">
        <h2>Test Results</h2>
        <p>Screen State: <strong>{results.get('screen_state', 'unknown')}</strong></p>
        <p>Sliders Found: <strong>{len(results.get('sliders', []))}</strong></p>
        <p>Navigation: <span class="{'status-pass' if results.get('navigated') else 'status-fail'}">
            {'✅ Success' if results.get('navigated') else '❌ Failed'}
        </span></p>
    </div>
"""

        if results.get('sliders'):
            html += '<div class="card"><h2>Detected Sliders</h2>'
            for i, s in enumerate(results['sliders']):
                html += f'<div class="slider-item">Slider #{i+1}: pos=({s["x"]}, {s["y"]}) area={s["area"]:.0f}</div>'
            html += '</div>'

        html += """
    <div class="card">
        <h2>Screenshots</h2>
        <p>capture.png:</p>
        <img src="capture.png"/>
        <p>debug_sliders.png:</p>
        <img src="debug_sliders.png"/>
    </div>
</body>
</html>
"""

        with open(report_path, 'w') as f:
            f.write(html)
        return report_path

    def run(self):
        """运行完整测试流程"""
        print("=" * 60)
        print("🤖 Full Auto Slider Test")
        print("=" * 60)

        # 1. 截图
        print("\n📸 Capturing screen...")
        capture_path = self.capture('capture')
        print(f"   Saved: {capture_path}")

        # 2. 寻找 Simulator
        print("\n🔍 Finding Simulator...")
        sim_region = self.find_simulator_region(capture_path)
        if not sim_region:
            print("   ❌ Simulator not found!")
            return None
        sx, sy, sw, sh = sim_region
        print(f"   Found at ({sx}, {sy}) size {sw}x{sh}")

        # 3. 检测当前页面状态
        print("\n🧠 Detecting screen state...")
        screen_state, _ = self.detect_screen_state(capture_path, sim_region)
        print(f"   Current state: {screen_state}")

        navigated = False
        if screen_state != "slider_page":
            # 4. 自动导航到 Slider 页面
            print("   🧭 Auto-navigating to Slider page...")
            try:
                self.navigate_to_slider(sim_region)
                navigated = True
                # 重新截图
                time.sleep(1)
                capture_path = self.capture('capture_after_nav')
            except Exception as e:
                print(f"   ⚠️ Navigation error: {e}")

        # 5. 寻找 Sliders
        print("\n🎯 Finding sliders...")
        sliders = self.find_sliders(capture_path, sim_region)
        print(f"   Found {len(sliders)} sliders")
        for i, s in enumerate(sliders):
            print(f"   #{i+1}: ({s['x']}, {s['y']}) area={s['area']:.0f}")

        # 6. 生成报告
        print("\n📝 Generating report...")
        results = {
            'timestamp': datetime.now().isoformat(),
            'sim_region': sim_region,
            'screen_state': screen_state,
            'navigated': navigated,
            'sliders': sliders
        }
        report_path = self.generate_report(results)
        print(f"   Report: {report_path}")

        # 7. 验证结果
        print("\n✅ Test Summary:")
        print(f"   Sliders found: {len(sliders)}")
        print(f"   Auto-navigation: {'Success' if navigated else 'N/A'}")

        print("\n" + "=" * 60)
        return results


def main():
    tester = FullAutoTester()
    print("\n🚀 Starting full auto test...")
    print("This will:")
    print("  1. Capture screen")
    print("  2. Detect Simulator")
    print("  3. Identify current page")
    print("  4. Auto-navigate to Slider page if needed")
    print("  5. Find and analyze all Sliders")
    print("  6. Generate report\n")

    results = tester.run()

    if results:
        print(f"\n📄 Open report: file://{tester.reports_dir}/report_*.html")


if __name__ == "__main__":
    main()
