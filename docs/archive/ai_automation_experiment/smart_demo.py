#!/usr/bin/env python3
"""
Smart AI GUI Automation for react-solar2d
Automatically activates Solar2D Simulator and tests Slider
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


class SmartSliderDemo:
    def __init__(self):
        self.output_dir = os.path.dirname(os.path.abspath(__file__))
        print(f"📁 Output directory: {self.output_dir}")

    def activate_simulator(self):
        """Activate Solar2D Simulator using AppleScript"""
        print("  🔄 Activating Solar2D Simulator...")

        script = '''
        tell application "Corona Simulator"
            activate
        end tell
        '''

        try:
            subprocess.run(['osascript', '-e', script], check=True)
            time.sleep(1)
            print("  ✅ Simulator activated")
            return True
        except subprocess.CalledProcessError:
            print("  ❌ Failed to activate Simulator")
            return False

    def capture(self, name):
        """Capture and save screenshot"""
        path = os.path.join(self.output_dir, f"{name}.png")
        screenshot = pyautogui.screenshot()
        screenshot.save(path)
        print(f"  📸 Screenshot: {name}.png")
        return path

    def find_slider_by_color(self, target_color, tolerance=40):
        """Find UI element by color"""
        screenshot = pyautogui.screenshot()
        img = np.array(screenshot)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        # Convert RGB to BGR for OpenCV
        target_bgr = (target_color[2], target_color[1], target_color[0])

        lower = np.array([max(0, c - tolerance) for c in target_bgr])
        upper = np.array([min(255, c + tolerance) for c in target_bgr])
        mask = cv2.inRange(img, lower, upper)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        valid_contours = [c for c in contours if 10 < cv2.contourArea(c) < 500]

        if not valid_contours:
            return None

        c = max(valid_contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(c)
        return (x + w // 2, y + h // 2, w, h)

    def find_text_button(self, text):
        """Find button by text color pattern (+ and - buttons are blue)"""
        # Look for blue text (iOS button color #007AFF)
        return self.find_slider_by_color((0, 122, 255), tolerance=30)

    def demo(self):
        """Run the full demo"""
        print("\n" + "="*60)
        print("  🤖 AI Automation Demo for react-solar2d")
        print("="*60)

        # Step 1: Activate Simulator
        print("\n[Step 1] Activating Solar2D Simulator...")
        if not self.activate_simulator():
            print("\n⚠️  Please manually switch to Solar2D Simulator")
            print("⏳ Waiting 3 seconds...")
            time.sleep(3)

        # Step 2: Initial state
        print("\n[Step 2] Capturing initial state...")
        self.capture("demo_01_start")

        # Step 3: Find and drag slider
        print("\n[Step 3] Looking for blue slider...")

        # Try to find blue slider thumb
        slider = self.find_slider_by_color((0, 122, 255), tolerance=50)

        if slider:
            x, y, w, h = slider
            print(f"  🎯 Found blue element at ({x}, {y})")

            # Drag it
            print(f"  🖱️  Dragging slider...")
            pyautogui.moveTo(x, y, duration=0.3)
            pyautogui.mouseDown()
            pyautogui.moveTo(x + 100, y, duration=0.5)
            pyautogui.mouseUp()
            print("  ✅ Drag completed")
        else:
            print("  ⚠️  Blue slider not found, trying alternative colors...")

            # Try other common slider colors
            colors = [
                (52, 199, 89),   # Green
                (255, 59, 48),   # Red
                (255, 204, 0),   # Yellow
                (175, 82, 222),  # Purple
            ]

            for color in colors:
                result = self.find_slider_by_color(color, tolerance=40)
                if result:
                    x, y, w, h = result
                    print(f"  🎯 Found slider (color {color}) at ({x}, {y})")
                    pyautogui.moveTo(x, y, duration=0.3)
                    pyautogui.mouseDown()
                    pyautogui.moveTo(x + 80, y, duration=0.5)
                    pyautogui.mouseUp()
                    break
            else:
                print("  ❌ No slider found")
                print("  💡 Please navigate to Forms > Slider screen first")
                return False

        # Step 4: Final state
        time.sleep(0.5)
        print("\n[Step 4] Capturing final state...")
        self.capture("demo_02_end")

        # Step 5: Optional - click the + button
        print("\n[Step 5] Looking for + button...")
        plus_btn = self.find_slider_by_color((0, 122, 255), tolerance=30)
        if plus_btn:
            x, y, w, h = plus_btn
            # Look for a second blue element (the + button)
            pyautogui.click(x + 50, y)  # Offset to find + button
            print("  👆 Clicked + button")
            time.sleep(0.3)
            self.capture("demo_03_after_click")

        print("\n" + "="*60)
        print("  ✨ Demo completed!")
        print("="*60)
        print(f"\n📁 Screenshots saved:")
        for f in ["demo_01_start.png", "demo_02_end.png", "demo_03_after_click.png"]:
            path = os.path.join(self.output_dir, f)
            if os.path.exists(path):
                print(f"   - {f}")

        return True


def main():
    print("\n⚠️  Safety: Move mouse to screen corner to abort")
    print("⏳ Starting in 2 seconds...\n")
    time.sleep(2)

    demo = SmartSliderDemo()
    success = demo.demo()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
