#!/usr/bin/env python3
"""
AI GUI Automation Demo for react-solar2d Slider
Demonstrates dragging a slider in Solar2D Simulator
"""

import pyautogui
import cv2
import numpy as np
from PIL import Image
import time
import subprocess
import os
import sys

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.3

class SliderDemo:
    def __init__(self):
        self.width, self.height = pyautogui.size()
        print(f"📱 Screen: {self.width}x{self.height}")
        self.output_dir = os.path.dirname(os.path.abspath(__file__))

    def capture(self, name):
        """Capture and save screenshot"""
        path = os.path.join(self.output_dir, f"{name}.png")
        screenshot = pyautogui.screenshot()
        screenshot.save(path)
        print(f"  📸 Screenshot saved: {path}")
        return path

    def find_blue_slider(self):
        """Find iOS blue slider (#007AFF)"""
        print("  🔍 Searching for blue slider...")
        screenshot = pyautogui.screenshot()
        img = np.array(screenshot)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        # iOS blue: #007AFF = (0, 122, 255) in RGB, (255, 122, 0) in BGR
        target_bgr = (255, 122, 0)
        tolerance = 50

        lower = np.array([max(0, c - tolerance) for c in target_bgr])
        upper = np.array([min(255, c + tolerance) for c in target_bgr])
        mask = cv2.inRange(img, lower, upper)

        # Find contours
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if not contours:
            return None

        # Filter by size (slider thumb is usually 20x20)
        valid_contours = [c for c in contours if 15 < cv2.contourArea(c) < 100]

        if not valid_contours:
            return None

        # Get the first valid contour
        c = valid_contours[0]
        x, y, w, h = cv2.boundingRect(c)
        center_x = x + w // 2
        center_y = y + h // 2

        return (center_x, center_y, w, h)

    def highlight_and_drag(self, x, y, drag_distance=100):
        """Highlight the slider and drag it"""
        print(f"  🎯 Found slider at ({x}, {y})")

        # Move to position
        pyautogui.moveTo(x, y, duration=0.5)
        print(f"  ✋ Moving to slider position...")
        time.sleep(0.5)

        # Drag
        end_x = x + drag_distance
        print(f"  🖱️  Dragging from ({x}, {y}) to ({end_x}, {y})...")
        pyautogui.mouseDown()
        pyautogui.moveTo(end_x, y, duration=0.5)
        pyautogui.mouseUp()
        print(f"  ✅ Drag completed!")
        time.sleep(0.5)

    def run(self):
        """Run the demo"""
        print("\n" + "="*60)
        print("  🚀 react-solar2d Slider Automation Demo")
        print("="*60)

        # Step 1: Initial screenshot
        print("\n[Step 1] Capturing initial state...")
        self.capture("01_initial")

        # Step 2: Find slider
        print("\n[Step 2] Looking for blue slider thumb...")
        result = self.find_blue_slider()

        if not result:
            print("  ❌ Slider not found!")
            print("  💡 Tips:")
            print("     - Make sure Solar2D Simulator is running")
            print("     - Navigate to Forms > Slider screen")
            print("     - Slider should be visible on screen")
            return False

        x, y, w, h = result

        # Step 3: Drag slider
        print("\n[Step 3] Performing drag operation...")
        self.highlight_and_drag(x, y, drag_distance=80)

        # Step 4: Final screenshot
        print("\n[Step 4] Capturing final state...")
        self.capture("02_after_drag")

        print("\n" + "="*60)
        print("  ✨ Demo completed successfully!")
        print("="*60)
        print(f"\n📁 Screenshots saved in: {self.output_dir}")
        print("   - 01_initial.png")
        print("   - 02_after_drag.png")
        return True


def main():
    # Safety check
    print("\n⚠️  Safety: Move mouse to screen corner to abort")
    print("⏳ Starting in 2 seconds...\n")
    time.sleep(2)

    demo = SliderDemo()
    success = demo.run()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
