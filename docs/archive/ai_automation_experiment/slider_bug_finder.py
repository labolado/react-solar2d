#!/usr/bin/env python3
"""
Slider Bug 自动发现器 - 检测布局、交互、数值问题
"""

import cv2
import numpy as np
import subprocess
import time
import os
from datetime import datetime


class SliderBugFinder:
    """自动发现 Slider 组件的各种问题"""

    def __init__(self, output_dir=None):
        self.output_dir = output_dir or os.path.dirname(os.path.abspath(__file__))
        self.reports_dir = os.path.join(self.output_dir, 'reports')
        os.makedirs(self.reports_dir, exist_ok=True)
        self.bugs = []

    def capture(self, name):
        """截图"""
        subprocess.run([
            'osascript', '-e', 'tell application "Corona Simulator" to activate'
        ], capture_output=True)
        time.sleep(0.3)
        path = os.path.join(self.reports_dir, f"{name}.png")
        subprocess.run(['screencapture', '-x', path], check=True)
        return path

    def find_simulator(self, img_path):
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

    def analyze_sliders(self, img_path, sim_region):
        """分析 Sliders 并检测问题"""
        img = cv2.imread(img_path)
        if img is None or sim_region is None:
            return []

        sx, sy, sw, sh = sim_region
        sim_img = img[sy:sy+sh, sx:sx+sw]

        results = []

        # 1. 检测白色 Slider thumbs
        lower_white = np.array([180, 180, 180])
        upper_white = np.array([255, 255, 255])
        white_mask = cv2.inRange(sim_img, lower_white, upper_white)
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
                    sliders.append({
                        'local_x': x + w//2,
                        'local_y': y + h//2,
                        'global_x': sx + x + w//2,
                        'global_y': sy + y + h//2,
                        'area': area,
                        'size': (w, h)
                    })

        sliders.sort(key=lambda s: s['local_y'])

        # 2. 分析每个 Slider
        for i, slider in enumerate(sliders):
            slider_info = {
                'id': i + 1,
                'position': slider,
                'bugs': []
            }

            # Bug 检测 1: 检查 track 颜色（蓝色/绿色部分）
            track_info = self._analyze_track(sim_img, slider)
            slider_info['track'] = track_info

            # Bug 检测 2: 检查是否有 +/- 按钮
            buttons = self._find_plus_minus_buttons(sim_img, slider)
            slider_info['buttons'] = buttons

            # Bug 检测 3: 检查布局对齐
            if i > 0:
                prev = sliders[i-1]
                x_diff = abs(slider['local_x'] - prev['local_x'])
                if x_diff > 20:
                    slider_info['bugs'].append({
                        'type': 'misalignment',
                        'severity': 'minor',
                        'description': f'Slider {i+1} not aligned with Slider {i} (offset: {x_diff}px)'
                    })

            # Bug 检测 4: 检查 thumb 大小一致性
            if slider['size'][0] < 30 or slider['size'][1] < 30:
                slider_info['bugs'].append({
                    'type': 'size',
                    'severity': 'warning',
                    'description': f'Slider {i+1} thumb too small: {slider["size"]}'
                })

            results.append(slider_info)

        return results, sliders

    def _analyze_track(self, sim_img, slider):
        """分析 Slider track 的颜色和填充"""
        y = slider['local_y']
        x = slider['local_x']

        # 向左扫描 track
        left_colors = []
        for lx in range(max(0, x-300), x, 5):
            color = sim_img[y, lx]
            left_colors.append(color)

        # 向右扫描 track
        right_colors = []
        for rx in range(x, min(sim_img.shape[1], x+300), 5):
            color = sim_img[y, rx]
            right_colors.append(color)

        # 检测蓝色 (BGR: ~255, 122, 0 for iOS blue)
        blue_pixels = sum(1 for c in left_colors if c[0] > 200 and c[1] < 150)
        green_pixels = sum(1 for c in left_colors if c[1] > 150 and c[0] < 100)

        total_left = len(left_colors) if left_colors else 1
        fill_percent = (blue_pixels + green_pixels) / total_left * 100

        return {
            'fill_percent': fill_percent,
            'has_blue': blue_pixels > 5,
            'has_green': green_pixels > 5,
            'track_length_left': len(left_colors),
            'track_length_right': len(right_colors)
        }

    def _find_plus_minus_buttons(self, sim_img, slider):
        """寻找 +/- 按钮"""
        y = slider['local_y']

        # 检测蓝色 +/- 按钮
        lower_blue = np.array([200, 100, 0])
        upper_blue = np.array([255, 200, 150])
        blue_mask = cv2.inRange(sim_img[max(0,y-20):min(sim_img.shape[0],y+20), :], lower_blue, upper_blue)

        # 在 slider 左右两侧找蓝色区域
        left_region = blue_mask[:, :slider['local_x']]
        right_region = blue_mask[:, slider['local_x']:]

        left_blue = np.count_nonzero(left_region)
        right_blue = np.count_nonzero(right_region)

        return {
            'has_minus': left_blue > 50,
            'has_plus': right_blue > 50,
            'minus_area': left_blue,
            'plus_area': right_blue
        }

    def test_slider_interaction(self, sim_region, slider_index=0):
        """测试 Slider 交互 - 拖动后检查值是否变化"""
        # 截图 "拖动前"
        before = self.capture('slider_before_drag')

        # 使用 HTTP 触发拖动（如果支持）
        # 或者模拟点击不同位置

        # 截图 "拖动后"
        time.sleep(0.5)
        after = self.capture('slider_after_drag')

        # 对比两个截图
        before_img = cv2.imread(before)
        after_img = cv2.imread(after)

        if before_img is not None and after_img is not None:
            diff = cv2.absdiff(before_img, after_img)
            diff_gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
            changed_pixels = np.count_nonzero(diff_gray > 30)

            return {
                'changed_pixels': changed_pixels,
                'has_change': changed_pixels > 100
            }
        return None

    def generate_bug_report(self, slider_results, interaction_test=None):
        """生成 Bug 报告"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_path = os.path.join(self.reports_dir, f'bug_report_{timestamp}.html')

        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Slider Bug Report</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; background: #f5f5f5; }}
        .card {{ background: white; border-radius: 8px; padding: 20px; margin: 15px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .bug-critical {{ background: #f8d7da; color: #721c24; padding: 10px; border-radius: 4px; margin: 5px 0; }}
        .bug-warning {{ background: #fff3cd; color: #856404; padding: 10px; border-radius: 4px; margin: 5px 0; }}
        .bug-minor {{ background: #d1ecf1; color: #0c5460; padding: 10px; border-radius: 4px; margin: 5px 0; }}
        .slider-item {{ background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 6px; }}
        h1 {{ color: #333; }}
        h2 {{ color: #555; border-bottom: 2px solid #007AFF; padding-bottom: 5px; }}
        .success {{ color: #28a745; }}
        .error {{ color: #dc3545; }}
        img {{ max-width: 100%; border-radius: 8px; margin: 10px 0; border: 1px solid #ddd; }}
        table {{ width: 100%; border-collapse: collapse; margin: 10px 0; }}
        th, td {{ padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }}
        th {{ background: #f8f9fa; }}
    </style>
</head>
<body>
    <h1>🐛 Slider Bug Report</h1>
    <div class="timestamp">Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</div>

    <div class="card">
        <h2>Summary</h2>
        <p>Sliders Detected: <strong>{len(slider_results)}</strong></p>
        <p>Total Bugs Found: <strong>{sum(len(s['bugs']) for s in slider_results)}</strong></p>
        {f'<p class="error">Critical Issues: {sum(1 for s in slider_results for b in s["bugs"] if b["severity"] == "critical")}</p>' if any(b['severity'] == 'critical' for s in slider_results for b in s['bugs']) else '<p class="success">No Critical Issues</p>'}
    </div>
"""

        # 详细的 Slider 分析
        for slider in slider_results:
            html += f"""
    <div class="card">
        <h2>Slider #{slider['id']}</h2>
        <div class="slider-item">
            <table>
                <tr><th>Property</th><th>Value</th></tr>
                <tr><td>Position</td><td>({slider['position']['local_x']}, {slider['position']['local_y']})</td></tr>
                <tr><td>Size</td><td>{slider['position']['size']}</td></tr>
                <tr><td>Track Fill</td><td>{slider['track']['fill_percent']:.1f}%</td></tr>
                <tr><td>Has Blue Track</td><td>{'✅' if slider['track']['has_blue'] else '❌'}</td></tr>
                <tr><td>Has Green Track</td><td>{'✅' if slider['track']['has_green'] else '❌'}</td></tr>
                <tr><td>Minus Button</td><td>{'✅' if slider['buttons']['has_minus'] else '❌'}</td></tr>
                <tr><td>Plus Button</td><td>{'✅' if slider['buttons']['has_plus'] else '❌'}</td></tr>
            </table>
        </div>
"""

            if slider['bugs']:
                html += '<h3>Issues Found:</h3>'
                for bug in slider['bugs']:
                    css_class = f"bug-{bug['severity']}"
                    html += f'<div class="{css_class}"><strong>{bug["type"].upper()}</strong>: {bug["description"]}</div>'
            else:
                html += '<p class="success">✅ No issues detected</p>'

            html += '</div>'

        # 交互测试结果
        if interaction_test:
            html += f"""
    <div class="card">
        <h2>Interaction Test</h2>
        <p>Changed Pixels: {interaction_test['changed_pixels']}</p>
        <p>Result: {'<span class="success">✅ Slider responds to interaction</span>' if interaction_test['has_change'] else '<span class="error">❌ Slider may not respond</span>'}</p>
    </div>
"""

        html += """
    <div class="card">
        <h2>Screenshots</h2>
        <p>Capture:</p>
        <img src="capture.png"/>
    </div>
</body>
</html>
"""

        with open(report_path, 'w') as f:
            f.write(html)
        return report_path

    def run(self):
        """运行完整的 Bug 检测流程"""
        print("=" * 70)
        print("🔍 Slider Bug Finder - 自动发现 Slider 问题")
        print("=" * 70)

        # 1. 导航到 Slider 页面
        print("\n🧭 Navigating to Slider page...")
        subprocess.run(['curl', '-s', '-X', 'POST', 'http://localhost:9876/tap', '-d', 'category=Basics'], capture_output=True)
        time.sleep(1)
        subprocess.run(['curl', '-s', '-X', 'POST', 'http://localhost:9876/navigate', '-d', 'route=Slider'], capture_output=True)
        time.sleep(2)

        # 2. 截图并分析
        print("\n📸 Capturing and analyzing...")
        capture_path = self.capture('capture')
        sim_region = self.find_simulator(capture_path)

        if not sim_region:
            print("❌ Simulator not found!")
            return None

        print(f"   Simulator found at {sim_region}")

        # 3. 分析 Sliders
        print("\n🔍 Analyzing Sliders...")
        slider_results, sliders = self.analyze_sliders(capture_path, sim_region)
        print(f"   Found {len(sliders)} sliders")

        for slider in slider_results:
            print(f"\n   Slider #{slider['id']}:")
            print(f"      Position: ({slider['position']['local_x']}, {slider['position']['local_y']})")
            print(f"      Track fill: {slider['track']['fill_percent']:.1f}%")
            print(f"      +/- buttons: -{'✅' if slider['buttons']['has_minus'] else '❌'} +{'✅' if slider['buttons']['has_plus'] else '❌'}")

            if slider['bugs']:
                for bug in slider['bugs']:
                    print(f"      🐛 [{bug['severity'].upper()}] {bug['description']}")
            else:
                print(f"      ✅ No issues")

        # 4. 交互测试（可选）
        print("\n🖱️  Testing interaction...")
        interaction = self.test_slider_interaction(sim_region)
        if interaction:
            print(f"   Changed pixels: {interaction['changed_pixels']}")
            print(f"   Result: {'✅ Responsive' if interaction['has_change'] else '❌ May be stuck'}")

        # 5. 生成报告
        print("\n📝 Generating bug report...")
        report_path = self.generate_bug_report(slider_results, interaction)
        print(f"   Report: {report_path}")

        # 6. 总结
        total_bugs = sum(len(s['bugs']) for s in slider_results)
        print("\n" + "=" * 70)
        print(f"✅ Analysis Complete!")
        print(f"   Sliders found: {len(sliders)}")
        print(f"   Bugs found: {total_bugs}")
        print(f"   Report: file://{report_path}")
        print("=" * 70)

        return slider_results


def main():
    finder = SliderBugFinder()
    finder.run()


if __name__ == "__main__":
    main()
