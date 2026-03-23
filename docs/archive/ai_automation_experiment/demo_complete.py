#!/usr/bin/env python3
"""
完整演示 - 使用已有截图展示AI视觉验证能力
"""

import cv2
import numpy as np
from PIL import Image, ImageDraw
import os


def demo_slider_detection():
    """演示Slider检测完整流程"""
    print("=" * 60)
    print("🎯 AI Slider Detection Demo")
    print("=" * 60)

    output_dir = os.path.dirname(os.path.abspath(__file__))

    # 使用之前的截图进行演示
    test_images = [
        ('slider_debug.png', 'Simulator with detected slider'),
        ('full_01_start.png', 'Before drag'),
        ('full_02_end.png', 'After drag'),
    ]

    for img_name, description in test_images:
        img_path = os.path.join(output_dir, img_name)
        if not os.path.exists(img_path):
            print(f"\n⚠️  {img_name} not found, skipping...")
            continue

        print(f"\n📸 Processing: {img_name} ({description})")

        # 1. 加载图片
        img = cv2.imread(img_path)
        if img is None:
            print(f"   ❌ Failed to load image")
            continue

        h, w = img.shape[:2]
        print(f"   Image size: {w}x{h}")

        # 2. 寻找Simulator区域（iPhone形状）
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        _, black_mask = cv2.threshold(gray, 30, 255, cv2.THRESH_BINARY_INV)
        contours, _ = cv2.findContours(black_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        sim_region = None
        for c in contours:
            x, y, cw, ch = cv2.boundingRect(c)
            aspect = ch / cw if cw > 0 else 0
            if 1.8 < aspect < 2.5 and cw > 200 and ch > 400:
                sim_region = (x, y, cw, ch)
                print(f"   ✅ Simulator found at ({x}, {y}) {cw}x{ch}")
                break

        if not sim_region:
            print(f"   ⚠️  Simulator not detected in this image")
            continue

        # 3. 在Simulator区域内寻找白色Slider thumbs
        sx, sy, sw, sh = sim_region
        sim_img = img[sy:sy+sh, sx:sx+sw]

        lower_white = np.array([200, 200, 200])
        upper_white = np.array([255, 255, 255])
        white_mask = cv2.inRange(sim_img, lower_white, upper_white)

        kernel = np.ones((3,3), np.uint8)
        white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_OPEN, kernel)

        contours, _ = cv2.findContours(white_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        sliders = []
        debug_img = img.copy()
        cv2.rectangle(debug_img, (sx, sy), (sx+sw, sy+sh), (0, 255, 0), 2)

        for c in contours:
            area = cv2.contourArea(c)
            if 30 < area < 300:
                x, y, cw, ch = cv2.boundingRect(c)
                aspect = cw / ch if ch > 0 else 0
                if 0.7 < aspect < 1.4:
                    global_x = sx + x + cw//2
                    global_y = sy + y + ch//2
                    sliders.append({
                        'x': global_x,
                        'y': global_y,
                        'area': area
                    })
                    cv2.circle(debug_img, (global_x, global_y), 15, (0, 0, 255), 2)

        sliders.sort(key=lambda s: s['y'])
        print(f"   ✅ Found {len(sliders)} slider thumbs")

        for i, s in enumerate(sliders):
            print(f"      #{i+1}: ({s['x']}, {s['y']}) area={s['area']:.0f}")

        # 4. 保存调试图
        debug_path = os.path.join(output_dir, f'demo_{img_name}')
        cv2.imwrite(debug_path, debug_img)
        print(f"   📝 Debug image saved: {debug_path}")

    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print(f"📁 Check debug images in: {output_dir}")
    print("=" * 60)


def compare_before_after():
    """对比拖动前后的变化"""
    print("\n" + "=" * 60)
    print("🔍 Before/After Comparison")
    print("=" * 60)

    output_dir = os.path.dirname(os.path.abspath(__file__))
    before_path = os.path.join(output_dir, 'full_01_start.png')
    after_path = os.path.join(output_dir, 'full_02_end.png')

    if not os.path.exists(before_path) or not os.path.exists(after_path):
        print("⚠️  Before/after images not found")
        return

    before = cv2.imread(before_path)
    after = cv2.imread(after_path)

    if before is None or after is None:
        print("❌ Failed to load images")
        return

    # 调整大小一致
    h = min(before.shape[0], after.shape[0])
    w = min(before.shape[1], after.shape[1])
    before = cv2.resize(before, (w, h))
    after = cv2.resize(after, (w, h))

    # 计算差异
    diff = cv2.absdiff(before, after)
    gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 30, 255, cv2.THRESH_BINARY)

    changed = np.count_nonzero(thresh)
    total = thresh.size
    percent = (changed / total) * 100

    print(f"\n📊 Pixel-level comparison:")
    print(f"   Changed pixels: {changed:,} / {total:,} ({percent:.2f}%)")

    # 可视化差异
    diff_color = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    diff_color[thresh > 0] = [0, 0, 255]  # Red for changes
    blended = cv2.addWeighted(after, 0.7, diff_color, 0.3, 0)

    diff_path = os.path.join(output_dir, 'demo_diff_visualization.png')
    cv2.imwrite(diff_path, blended)
    print(f"   📝 Diff visualization: {diff_path}")

    if percent > 1:
        print(f"   ✅ Significant change detected!")
    else:
        print(f"   ⚠️  Minimal change")


if __name__ == "__main__":
    demo_slider_detection()
    compare_before_after()
