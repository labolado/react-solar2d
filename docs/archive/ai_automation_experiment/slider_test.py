#!/usr/bin/env python3
"""
Slider-specific test - detects white thumbs in Simulator
"""

import pyautogui
import cv2
import numpy as np
from PIL import Image, ImageDraw
import time
import os

pyautogui.FAILSAFE = True

def main():
    output_dir = os.path.dirname(os.path.abspath(__file__))

    print("=" * 60)
    print("Slider Drag Test")
    print("=" * 60)

    print("\n⏳ Starting in 2 seconds...")
    time.sleep(2)

    # Take screenshot
    print("\n1. Capturing screen...")
    screenshot = pyautogui.screenshot()
    img = np.array(screenshot)
    h, w = img.shape[:2]
    print(f"   Screen: {w}x{h}")

    # The Simulator iPhone is on the right side of screen
    # Based on the screenshot, it's roughly at x=1600-2100, y=300-900
    # Let's crop to that region
    sim_x1, sim_y1 = 1600, 250
    sim_x2, sim_y2 = 2150, 950

    sim_region = img[sim_y1:sim_y2, sim_x1:sim_x2]
    print(f"   Simulator region: ({sim_x1}, {sim_y1}) - ({sim_x2}, {sim_y2})")

    # Save debug image with region marked
    debug_img = img.copy()
    cv2.rectangle(debug_img, (sim_x1, sim_y1), (sim_x2, sim_y2), (255, 0, 0), 3)

    # Look for white circles (slider thumbs) in the simulator region
    sim_bgr = cv2.cvtColor(sim_region, cv2.COLOR_RGB2BGR)

    # White/light gray color range
    lower = np.array([240, 240, 240])
    upper = np.array([255, 255, 255])
    mask = cv2.inRange(sim_bgr, lower, upper)

    # Find contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    print(f"\n2. Found {len(contours)} white regions")

    # Filter for slider thumb size and shape
    thumbs = []
    for i, c in enumerate(contours):
        area = cv2.contourArea(c)
        if area < 30 or area > 300:  # Slider thumb size
            continue

        x, y, bw, bh = cv2.boundingRect(c)
        aspect = bw / bh if bh > 0 else 0

        if 0.6 < aspect < 1.4:  # Roughly circular
            # Convert to global coordinates
            global_x = sim_x1 + x + bw//2
            global_y = sim_y1 + y + bh//2
            thumbs.append({
                'id': i,
                'area': area,
                'local_x': x + bw//2,
                'local_y': y + bh//2,
                'global_x': global_x,
                'global_y': global_y,
                'size': (bw, bh)
            })

            # Draw on debug image
            cv2.circle(debug_img, (global_x, global_y), 15, (0, 255, 0), 2)
            cv2.putText(debug_img, f"T{i}", (global_x-10, global_y-20),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    print(f"   Found {len(thumbs)} potential thumbs:")
    for t in thumbs:
        print(f"     #{t['id']}: ({t['global_x']}, {t['global_y']}), area={t['area']:.0f}")

    # Save debug image
    debug_path = os.path.join(output_dir, "slider_debug.png")
    Image.fromarray(debug_img).save(debug_path)

    if not thumbs:
        print("\n   ❌ No slider thumbs found!")
        return

    # Sort by y position (top to bottom) and pick the first one
    thumbs.sort(key=lambda x: x['global_y'])
    target = thumbs[0]

    print(f"\n3. Targeting thumb at ({target['global_x']}, {target['global_y']})")

    # Perform drag
    x, y = target['global_x'], target['global_y']
    print(f"\n4. Dragging from ({x}, {y}) to ({x+100}, {y})...")

    pyautogui.moveTo(x, y, duration=0.3)
    pyautogui.mouseDown()
    pyautogui.moveTo(x + 100, y, duration=0.5)
    pyautogui.mouseUp()

    print("   ✅ Drag completed!")

    time.sleep(0.5)

    # Final screenshot
    final = pyautogui.screenshot()
    final.save(os.path.join(output_dir, "slider_result.png"))

    print(f"\n5. Debug images saved:")
    print(f"   - slider_debug.png (shows detected thumbs)")
    print(f"   - slider_result.png (after drag)")
    print("=" * 60)

if __name__ == "__main__":
    print("⚠️  Move mouse to corner to abort")
    main()
