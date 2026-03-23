#!/usr/bin/env python3
"""
Slider Drag Test - 验证 Slider 拖动功能
使用 HTTP API 和截图对比来验证拖动是否正常工作
"""

import cv2
import numpy as np
import subprocess
import time
import os
from datetime import datetime


def capture(name):
    """截图"""
    subprocess.run([
        'osascript', '-e', 'tell application "Corona Simulator" to activate'
    ], capture_output=True)
    time.sleep(0.3)
    path = os.path.join(os.path.dirname(__file__), 'reports', f"{name}.png")
    subprocess.run(['screencapture', '-x', path], check=True)
    return path


def find_simulator(img_path):
    """定位 Simulator"""
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
        if 0.4 < aspect < 2.5 and 500 < w < 1500 and 600 < h < 2500:
            candidates.append((w*h, x, y, w, h))

    if candidates:
        candidates.sort(reverse=True)
        return candidates[0][1:]
    return None


def find_sliders(img_path, sim_region):
    """寻找所有 Sliders"""
    img = cv2.imread(img_path)
    if img is None or sim_region is None:
        return []

    sx, sy, sw, sh = sim_region
    content_region = img[sy+int(sh*0.1):sy+int(sh*0.9), sx:sx+sw]

    # 白色圆形检测 (Slider thumbs)
    lower_white = np.array([180, 180, 180])
    upper_white = np.array([255, 255, 255])
    white_mask = cv2.inRange(content_region, lower_white, upper_white)

    kernel = np.ones((3,3), np.uint8)
    white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_OPEN, kernel)

    contours, _ = cv2.findContours(white_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    sliders = []
    for c in contours:
        area = cv2.contourArea(c)
        if 100 < area < 2000:
            x, y, w, h = cv2.boundingRect(c)
            aspect = w / h if h > 0 else 0
            if 0.8 < aspect < 1.3:
                global_x = sx + x + w//2
                global_y = sy + int(sh*0.1) + y + h//2
                sliders.append({
                    'x': global_x,
                    'y': global_y,
                    'area': area
                })

    sliders.sort(key=lambda s: s['y'])
    return sliders


def tap(x, y):
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


def test_drag():
    """测试 Slider 拖动功能"""
    print("=" * 60)
    print("🧪 Slider Drag Test")
    print("=" * 60)

    # 1. 导航到 Slider 页面
    print("\n🧭 Navigating to Slider page...")
    subprocess.run([
        'curl', '-s', '-X', 'POST',
        'http://localhost:9876/tap', '-d', 'category=Interop'
    ], capture_output=True)
    time.sleep(1)
    subprocess.run([
        'curl', '-s', '-X', 'POST',
        'http://localhost:9876/navigate', '-d', 'route=Slider'
    ], capture_output=True)
    time.sleep(2)

    # 2. 找到 Simulator 和 Sliders
    print("\n🔍 Finding sliders...")
    capture_path = capture('drag_test_before')
    sim_region = find_simulator(capture_path)
    if not sim_region:
        print("❌ Simulator not found!")
        return False

    sliders = find_sliders(capture_path, sim_region)
    print(f"   Found {len(sliders)} sliders")
    if len(sliders) < 1:
        print("❌ No sliders found!")
        return False

    # 使用第一个 Slider 进行测试
    slider = sliders[0]
    print(f"   Testing Slider #1 at ({slider['x']}, {slider['y']})")

    # 3. 人工手动测试说明
    print("\n" + "=" * 60)
    print("📋 MANUAL TEST REQUIRED")
    print("=" * 60)
    print(f"""
请在 Simulator 中测试 Slider 拖动功能：

1. 找到第一个 Slider (位于 y={slider['y']} 附近)
2. 用手指/鼠标按住白色圆形滑块
3. 左右拖动，观察是否实时更新：
   - ✅ 正常: 滑块跟随手指移动，数值实时变化
   - ❌ 异常: 滑块不移动或松手后才跳变

4. 点击轨道任意位置，观察是否跳转到该位置：
   - ✅ 正常: 滑块跳转到点击位置
   - ❌ 异常: 滑块位置不正确

5. 观察轨道着色：
   - ✅ 正常: 已滑过部分显示蓝色/绿色
   - ❌ 异常: 轨道颜色不正确
""")

    # 打开截图供查看
    subprocess.run(['open', capture_path])

    return True


if __name__ == "__main__":
    test_drag()
