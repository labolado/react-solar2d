#!/usr/bin/env python3
"""
Debug version - shows exactly what is being detected and clicked
"""

import pyautogui
import cv2
import numpy as np
from PIL import Image, ImageDraw
import time
import os

pyautogui.FAILSAFE = True

def debug_find_and_drag():
    output_dir = os.path.dirname(os.path.abspath(__file__))

    print("=" * 60)
    print("DEBUG: Finding blue slider elements")
    print("=" * 60)

    # Take screenshot
    print("\n1. Taking screenshot...")
    screenshot = pyautogui.screenshot()
    screenshot.save(os.path.join(output_dir, "debug_01_full.png"))
    print(f"   Saved: debug_01_full.png ({screenshot.size})")

    # Convert for OpenCV
    img = np.array(screenshot)
    img_bgr = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

    # Look for iOS blue (#007AFF = RGB 0,122,255 = BGR 255,122,0)
    print("\n2. Searching for iOS blue color...")
    target_bgr = (255, 122, 0)
    tolerance = 50

    lower = np.array([max(0, c - tolerance) for c in target_bgr])
    upper = np.array([min(255, c + tolerance) for c in target_bgr])
    mask = cv2.inRange(img_bgr, lower, upper)

    # Find contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    print(f"   Found {len(contours)} blue contours")

    # Draw all contours on debug image
    debug_img = img_bgr.copy()
    cv2.drawContours(debug_img, contours, -1, (0, 255, 0), 2)

    # Filter and rank by position
    candidates = []
    for i, c in enumerate(contours):
        area = cv2.contourArea(c)
        if area < 20:  # Skip tiny elements
            continue

        x, y, w, h = cv2.boundingRect(c)
        center_x = x + w // 2
        center_y = y + h // 2

        candidates.append({
            'id': i,
            'area': area,
            'x': x, 'y': y, 'w': w, 'h': h,
            'cx': center_x, 'cy': center_y,
            'aspect': w/h if h > 0 else 0
        })

        # Draw rectangle and label
        cv2.rectangle(debug_img, (x, y), (x+w, y+h), (0, 0, 255), 2)
        cv2.putText(debug_img, f"#{i} ({center_x},{center_y})", (x, y-5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1)

    cv2.imwrite(os.path.join(output_dir, "debug_02_contours.png"), debug_img)
    print(f"   Saved: debug_02_contours.png with {len(candidates)} candidates")

    # Print all candidates
    print("\n3. All blue elements found:")
    for c in sorted(candidates, key=lambda x: x['area'], reverse=True)[:10]:
        print(f"   #{c['id']}: area={c['area']:.0f}, pos=({c['cx']},{c['cy']}), size={c['w']}x{c['h']}")

    # Try to find best slider candidate
    # Sliders are typically: right side of screen, medium size, roughly circular
    print("\n4. Selecting best candidate...")

    # Filter for reasonable slider thumb size and shape
    good_candidates = [
        c for c in candidates
        if 50 < c['area'] < 500 and 0.7 < c['aspect'] < 1.3
    ]

    if not good_candidates:
        print("   ❌ No good slider candidates found!")
        return

    # Pick the one with largest area that is on the right side of screen
    # (Slider thumbs are usually in the middle-right of the slider track)
    screen_w, screen_h = screenshot.size
    best = max(good_candidates, key=lambda c: c['area'] + c['cx'] * 0.1)

    print(f"   ✅ Selected: #{best['id']} at ({best['cx']}, {best['cy']})")

    # Mark the target
    target_img = img_bgr.copy()
    cv2.circle(target_img, (best['cx'], best['cy']), 20, (0, 255, 255), 3)
    cv2.circle(target_img, (best['cx'], best['cy']), 5, (0, 0, 255), -1)
    cv2.putText(target_img, "TARGET", (best['cx'] - 40, best['cy'] - 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    cv2.imwrite(os.path.join(output_dir, "debug_03_target.png"), target_img)
    print(f"   Saved: debug_03_target.png")

    # PERFORM THE DRAG
    print("\n5. PERFORMING DRAG:")
    print(f"   Moving mouse to ({best['cx']}, {best['cy']})")
    pyautogui.moveTo(best['cx'], best['cy'], duration=0.5)
    time.sleep(0.3)

    print(f"   Pressing mouse down...")
    pyautogui.mouseDown()
    time.sleep(0.2)

    drag_to_x = best['cx'] + 100
    print(f"   Dragging to ({drag_to_x}, {best['cy']})")
    pyautogui.moveTo(drag_to_x, best['cy'], duration=0.5)
    time.sleep(0.2)

    print(f"   Releasing mouse...")
    pyautogui.mouseUp()

    print("\n6. Drag completed!")
    time.sleep(0.5)

    # Final screenshot
    final = pyautogui.screenshot()
    final.save(os.path.join(output_dir, "debug_04_final.png"))
    print(f"   Saved: debug_04_final.png")

    print("\n" + "=" * 60)
    print("DEBUG IMAGES SAVED:")
    for f in ["debug_01_full.png", "debug_02_contours.png",
              "debug_03_target.png", "debug_04_final.png"]:
        print(f"  - {f}")
    print("=" * 60)

if __name__ == "__main__":
    print("\n⚠️  Move mouse to corner to abort")
    print("⏳ Starting in 3 seconds...\n")
    time.sleep(3)
    debug_find_and_drag()
