#!/usr/bin/env python3
"""
Full automation: navigate to Slider and test dragging
Uses multiple strategies to find elements
"""

import pyautogui
import cv2
import numpy as np
from PIL import Image
import time
import os

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.3

def take_screenshot(name):
    """Take and save screenshot"""
    output_dir = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(output_dir, f"{name}.png")
    screenshot = pyautogui.screenshot()
    screenshot.save(path)
    return np.array(screenshot), path

def find_text_by_color(img, text_color=(100, 200, 255), tolerance=30):
    """
    Find text elements by color (for finding "表单" / Forms button)
    """
    img_bgr = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

    # Light blue text color (BGR format)
    target_bgr = (text_color[2], text_color[1], text_color[0])
    lower = np.array([max(0, c - tolerance) for c in target_bgr])
    upper = np.array([min(255, c + tolerance) for c in target_bgr])
    mask = cv2.inRange(img_bgr, lower, upper)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Return rightmost candidate (Forms button is on the right side)
    candidates = []
    for c in contours:
        area = cv2.contourArea(c)
        if area > 50:
            x, y, w, h = cv2.boundingRect(c)
            candidates.append((x + w//2, y + h//2, area))

    if candidates:
        # Return rightmost
        return max(candidates, key=lambda x: x[0])
    return None

def find_white_circles(img):
    """
    Find white circles (Slider thumbs)
    """
    img_bgr = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

    # Look for white/light gray circles
    lower = np.array([200, 200, 200])
    upper = np.array([255, 255, 255])
    mask = cv2.inRange(img_bgr, lower, upper)

    # Find circles using Hough transform
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    circles = cv2.HoughCircles(gray, cv2.HOUGH_GRADIENT, 1, 20,
                               param1=50, param2=30, minRadius=10, maxRadius=30)

    if circles is not None:
        circles = np.uint16(np.around(circles))
        # Return the first circle found
        x, y, r = circles[0][0]
        return (int(x), int(y), int(r))
    return None

def main():
    print("=" * 60)
    print("Full Slider Automation Demo")
    print("=" * 60)

    output_dir = os.path.dirname(os.path.abspath(__file__))

    print("\n⚠️  Make sure Solar2D Simulator is visible with Slider screen!")
    print("⏳ Starting in 3 seconds...")
    time.sleep(3)

    # Step 1: Take initial screenshot
    print("\n[Step 1] Capturing initial state...")
    img, path = take_screenshot("full_01_start")
    h, w = img.shape[:2]
    print(f"   Screen: {w}x{h}")

    # Step 2: Find Slider thumb (white circle)
    print("\n[Step 2] Looking for Slider thumb (white circle)...")

    # Try multiple color strategies
    strategies = [
        ("white circle", lambda i: find_white_circles(i)),
        ("iOS blue", lambda i: find_ios_blue(i)),
        ("green track", lambda i: find_green_element(i)),
    ]

    slider_pos = None
    for name, strategy in strategies:
        print(f"   Trying {name}...")
        result = strategy(img)
        if result:
            if len(result) == 3:  # (x, y, r) or (x, y, area)
                slider_pos = (result[0], result[1])
            else:
                slider_pos = result
            print(f"   ✅ Found with {name}: {slider_pos}")
            break

    if not slider_pos:
        print("\n   ❌ Could not find Slider!")
        print("   💡 Please manually navigate to Forms > Slider screen first")
        return

    x, y = slider_pos

    # Step 3: Perform drag
    print(f"\n[Step 3] Dragging from ({x}, {y})...")
    pyautogui.moveTo(x, y, duration=0.5)
    pyautogui.mouseDown()
    pyautogui.moveTo(x + 100, y, duration=0.5)
    pyautogui.mouseUp()
    print("   ✅ Drag completed")

    time.sleep(0.5)

    # Step 4: Final screenshot
    print("\n[Step 4] Capturing final state...")
    take_screenshot("full_02_end")

    print("\n" + "=" * 60)
    print("Demo completed!")
    print(f"Screenshots saved in: {output_dir}")
    print("=" * 60)

def find_ios_blue(img):
    """Find iOS blue elements"""
    img_bgr = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    target_bgr = (255, 122, 0)  # iOS blue in BGR
    tolerance = 50

    lower = np.array([max(0, c - tolerance) for c in target_bgr])
    upper = np.array([min(255, c + tolerance) for c in target_bgr])
    mask = cv2.inRange(img_bgr, lower, upper)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Filter for reasonable slider size
    for c in sorted(contours, key=cv2.contourArea, reverse=True):
        area = cv2.contourArea(c)
        if 50 < area < 500:
            x, y, w, h = cv2.boundingRect(c)
            return (x + w//2, y + h//2, area)
    return None

def find_green_element(img):
    """Find green elements (third slider track)"""
    img_bgr = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    # Green in BGR
    lower = np.array([0, 150, 0])
    upper = np.array([100, 255, 100])
    mask = cv2.inRange(img_bgr, lower, upper)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    for c in sorted(contours, key=cv2.contourArea, reverse=True):
        area = cv2.contourArea(c)
        if 100 < area < 1000:
            x, y, w, h = cv2.boundingRect(c)
            return (x + w//2, y + h//2, area)
    return None

if __name__ == "__main__":
    main()
