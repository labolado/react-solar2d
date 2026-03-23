#!/usr/bin/env python3
"""
全自动视觉验证系统 - 无需人工干预
自动截图、分析、生成报告
"""

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imagehash
import time
import os
import json
from datetime import datetime
import subprocess


class AutoValidator:
    """全自动视觉验证 - 不控制鼠标，只观察分析"""

    def __init__(self, output_dir=None):
        self.output_dir = output_dir or os.path.dirname(os.path.abspath(__file__))
        self.reports_dir = os.path.join(self.output_dir, 'reports')
        os.makedirs(self.reports_dir, exist_ok=True)

    def capture(self, name):
        """使用macOS原生截图"""
        path = os.path.join(self.reports_dir, f"{name}.png")
        subprocess.run(['screencapture', '-x', path], check=True)
        return path

    def find_simulator_region(self, img_path):
        """自动定位Simulator窗口位置"""
        img = cv2.imread(img_path)
        if img is None:
            return None

        # 转换为灰度
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # 寻找iPhone形状（黑色圆角矩形）
        # 黑色区域
        _, black_mask = cv2.threshold(gray, 30, 255, cv2.THRESH_BINARY_INV)

        # 寻找大轮廓
        contours, _ = cv2.findContours(black_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # 寻找iPhone形状（比例约 9:19.5，尺寸合理）
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            aspect = h / w if w > 0 else 0

            # iPhone比例检查 (包括带边框的Simulator窗口)
            if 1.0 < aspect < 2.5 and w > 300 and h > 600:
                return (x, y, w, h)

        return None

    def find_sliders(self, img_path, sim_region):
        """在Simulator区域内寻找Slider"""
        img = cv2.imread(img_path)
        if img is None or sim_region is None:
            return []

        sx, sy, sw, sh = sim_region

        # 裁剪Simulator区域
        sim_img = img[sy:sy+sh, sx:sx+sw]

        # 保存调试图
        debug_path = os.path.join(self.reports_dir, 'debug_sim_region.png')
        cv2.imwrite(debug_path, sim_img)

        # 寻找白色圆形（Slider thumbs）
        # 白色在BGR中是(255,255,255)
        lower_white = np.array([200, 200, 200])
        upper_white = np.array([255, 255, 255])
        white_mask = cv2.inRange(sim_img, lower_white, upper_white)

        # 形态学操作去噪
        kernel = np.ones((3,3), np.uint8)
        white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_OPEN, kernel)

        contours, _ = cv2.findContours(white_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        sliders = []
        for c in contours:
            area = cv2.contourArea(c)
            # Slider thumb大小范围
            if 30 < area < 300:
                x, y, w, h = cv2.boundingRect(c)
                aspect = w / h if h > 0 else 0

                # 圆形检查
                if 0.7 < aspect < 1.4:
                    # 转换回全局坐标
                    global_x = sx + x + w//2
                    global_y = sy + y + h//2
                    sliders.append({
                        'x': global_x,
                        'y': global_y,
                        'local_x': x + w//2,
                        'local_y': y + h//2,
                        'area': area
                    })

        # 按y坐标排序（从上到下）
        sliders.sort(key=lambda s: s['y'])
        return sliders

    def analyze_slider_values(self, img_path, sliders, sim_region):
        """分析Slider数值（通过颜色条长度估算）"""
        img = cv2.imread(img_path)
        if img is None:
            return []

        sx, sy, sw, sh = sim_region
        results = []

        for i, slider in enumerate(sliders):
            # 在thumb左侧寻找已填充的颜色条
            # 检查蓝色（iOS蓝色 #007AFF = BGR 255,122,0）
            local_y = slider['local_y']

            # 在thumb水平位置，向左扫描
            blue_pixels = 0
            total_pixels = slider['local_x']

            if total_pixels > 10:
                for x in range(max(0, slider['local_x'] - 200), slider['local_x']):
                    # 检查这一列的蓝色像素
                    col = img[sy + local_y - 5 : sy + local_y + 5, sx + x]
                    if len(col) > 0 and len(col.shape) == 3:
                        # 检查蓝色范围 (BGR格式)
                        blue_mask = (col[:,:,0] > 200) & (col[:,:,1] < 150) & (col[:,:,2] < 100)
                        if np.any(blue_mask):
                            blue_pixels += 1

                # 估算百分比
                percentage = min(100, int((blue_pixels / 150) * 100)) if blue_pixels > 0 else 0
            else:
                percentage = 0

            results.append({
                'id': i,
                'position': percentage,
                'thumb_pos': (slider['x'], slider['y'])
            })

        return results

    def generate_report(self, results):
        """生成HTML报告"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_path = os.path.join(self.reports_dir, f'report_{timestamp}.html')

        html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Slider Auto-Validation Report</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }}
        h1 {{ color: #333; }}
        .timestamp {{ color: #666; margin-bottom: 20px; }}
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
        .slider-bar {{
            flex: 1;
            height: 20px;
            background: #e9ecef;
            border-radius: 10px;
            margin: 0 15px;
            position: relative;
            overflow: hidden;
        }}
        .slider-fill {{
            height: 100%;
            background: linear-gradient(90deg, #007AFF, #34C759);
            border-radius: 10px;
            transition: width 0.3s;
        }}
        .slider-value {{
            font-weight: bold;
            color: #007AFF;
            min-width: 50px;
        }}
        img {{
            max-width: 100%;
            border-radius: 8px;
            margin: 10px 0;
        }}
        .status {{
            display: inline-block;
            padding: 5px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: bold;
        }}
        .status-found {{ background: #d4edda; color: #155724; }}
        .status-notfound {{ background: #f8d7da; color: #721c24; }}
    </style>
</head>
<body>
    <h1>🎯 Slider Auto-Validation Report</h1>
    <div class="timestamp">Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</div>

    <div class="card">
        <h2>Summary</h2>
        <p>Sliders detected: <strong>{len(results.get('sliders', []))}</strong></p>
        <p>Simulator region: {'Found' if results.get('sim_region') else 'Not found'}</p>
    </div>
"""

        if results.get('sliders'):
            html += """
    <div class="card">
        <h2>Detected Sliders</h2>
"""
            for slider in results['sliders']:
                html += f"""
        <div class="slider-item">
            <span>Slider #{slider['id'] + 1}</span>
            <div class="slider-bar">
                <div class="slider-fill" style="width: {slider['position']}%"></div>
            </div>
            <span class="slider-value">{slider['position']}%</span>
            <span class="status status-found">Detected</span>
        </div>
"""
            html += "    </div>\n"

        # Add screenshots
        html += """
    <div class="card">
        <h2>Screenshots</h2>
"""
        for img_name in ['capture.png', 'debug_sim_region.png']:
            img_path = os.path.join(self.reports_dir, img_name)
            if os.path.exists(img_path):
                html += f'        <p>{img_name}:</p>\n'
                html += f'        <img src="{img_name}" alt="{img_name}"/>\n'

        html += """
    </div>
</body>
</html>
"""

        with open(report_path, 'w') as f:
            f.write(html)

        return report_path

    def run(self):
        """运行完整验证流程"""
        print("=" * 60)
        print("🚀 Auto Slider Validator")
        print("=" * 60)
        print("\n📸 Capturing screen...")

        # 截图
        capture_path = self.capture('capture')
        print(f"   Saved: {capture_path}")

        # 寻找Simulator
        print("\n🔍 Finding Simulator window...")
        sim_region = self.find_simulator_region(capture_path)

        if sim_region:
            x, y, w, h = sim_region
            print(f"   Found at ({x}, {y}) size {w}x{h}")
        else:
            print("   ⚠️ Simulator not found! Make sure it's visible.")
            return None

        # 寻找Sliders
        print("\n🎯 Finding sliders...")
        sliders = self.find_sliders(capture_path, sim_region)
        print(f"   Found {len(sliders)} slider thumbs")

        for i, s in enumerate(sliders):
            print(f"   #{i+1}: ({s['x']}, {s['y']}) area={s['area']:.0f}")

        # 分析数值
        print("\n📊 Analyzing values...")
        values = self.analyze_slider_values(capture_path, sliders, sim_region)

        for v in values:
            print(f"   Slider #{v['id']+1}: ~{v['position']}%")

        # 生成报告
        print("\n📝 Generating report...")
        results = {
            'timestamp': datetime.now().isoformat(),
            'sim_region': sim_region,
            'sliders': values
        }

        report_path = self.generate_report(results)
        print(f"   Report: {report_path}")

        print("\n" + "=" * 60)
        print(f"✅ Done! Found {len(sliders)} sliders")
        print("=" * 60)

        return results


def main():
    """主入口"""
    validator = AutoValidator()

    # 连续截图对比（演示变化检测）
    print("\n📋 Running auto-validation...")
    print("This will capture and analyze the current screen state.")
    print("Make sure Solar2D Simulator with Slider screen is visible!\n")

    results = validator.run()

    if results:
        print(f"\n📄 Open this file to see the report:")
        print(f"   file://{validator.reports_dir}/report_*.html")


if __name__ == "__main__":
    main()
