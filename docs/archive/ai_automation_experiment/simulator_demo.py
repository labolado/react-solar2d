#!/usr/bin/env python3
"""
AI Automation specifically for Solar2D Simulator
Uses window detection to find Simulator and interact with Slider
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


class SimulatorAgent:
    def __init__(self):
        self.output_dir = os.path.dirname(os.path.abspath(__file__))
        self.simulator_bbox = None  # (x, y, width, height)
        print(f"📁 Output: {self.output_dir}")

    def find_simulator_window(self):
        """Find Corona Simulator window position using AppleScript"""
        script = '''
        tell application "System Events"
            tell process "Corona Simulator"
                set winPos to position of window 1
                set winSize to size of window 1
                return (item 1 of winPos) & "," & (item 2 of winPos) & "," & (item 1 of winSize) & "," & (item 2 of winSize)
            end tell
        end tell
        '''
        try:
            result = subprocess.run(['osascript', '-e', script],
                                    capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                parts = result.stdout.strip().split(',')
                x, y, w, h = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
                self.simulator_bbox = (x, y, w, h)
                print(f"  🎯 Simulator window: ({x}, {y}) {w}x{h}")
                return True
        except Exception as e:
            print(f"  ⚠️  Could not get window position: {e}")

        # Fallback: search for Simulator in screenshot
        return self._find_simulator_by_image()

    def _find_simulator_by_image(self):
        """Find Simulator by looking for its distinctive features"""
        screenshot = pyautogui.screenshot()
        img = np.array(screenshot)

        # Look for iPhone frame (black border) or Solar2D logo
        # This is a simplified version - looks for large black rectangle
        gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)

        # Threshold to find dark areas (iPhone frame)
        _, thresh = cv2.threshold(gray, 50, 255, cv2.THRESH_BINARY_INV)

        # Find contours
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # Look for large rectangular contours (iPhone simulator)
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            # iPhone aspect ratio ~ 9:19.5, reasonable size
            if w > 200 and h > 400 and 0.4 < w/h < 0.6:
                self.simulator_bbox = (x, y, w, h)
                print(f"  🎯 Found Simulator by image: ({x}, {y}) {w}x{h}")
                return True

        return False

    def capture(self, name):
        """Capture full screenshot"""
        path = os.path.join(self.output_dir, f"{name}.png")
        screenshot = pyautogui.screenshot()
        screenshot.save(path)
        print(f"  📸 {name}.png")
        return path

    def find_slider_in_simulator(self):
        """Find blue slider thumb within Simulator window"""
        if not self.simulator_bbox:
            print("  ❌ Simulator window not found")
            return None

        sx, sy, sw, sh = self.simulator_bbox

        # Take screenshot
        screenshot = pyautogui.screenshot()
        img = np.array(screenshot)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        # Crop to simulator region (with some margin)
        margin = 50
        x1 = max(0, sx + margin)
        y1 = max(0, sy + margin)
        x2 = min(img.shape[1], sx + sw - margin)
        y2 = min(img.shape[0], sy + sh - margin)

        sim_region = img[y1:y2, x1:x2]

        # Save debug image
        debug_path = os.path.join(self.output_dir, "sim_region.png")
        cv2.imwrite(debug_path, sim_region)

        # Look for blue slider (iOS blue #007AFF = BGR: 255, 122, 0)
        target_bgr = (255, 122, 0)
        tolerance = 40

        lower = np.array([max(0, c - tolerance) for c in target_bgr])
        upper = np.array([min(255, c + tolerance) for c in target_bgr])
        mask = cv2.inRange(sim_region, lower, upper)

        # Morphological operations to clean up
        kernel = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # Filter by size (slider thumb is circular, ~20-40px)
        valid_contours = []
        for c in contours:
            area = cv2.contourArea(c)
            if 50 < area < 500:  # Reasonable size for slider thumb
                x, y, w, h = cv2.boundingRect(c)
                aspect = w / h if h > 0 else 0
                if 0.7 < aspect < 1.3:  # Roughly circular
                    valid_contours.append((c, x, y, w, h))

        if not valid_contours:
            print(f"  ❌ No slider found in Simulator (found {len(contours)} contours)")
            return None

        # Get the rightmost blue element (likely the slider thumb)
        # Sort by x position, take the one furthest right but not at edge
        valid_contours.sort(key=lambda x: x[2])  # Sort by x

        # Take the rightmost valid contour
        c, x, y, w, h = valid_contours[-1]

        # Convert back to global coordinates
        global_x = x1 + x + w // 2
        global_y = y1 + y + h // 2

        print(f"  🎯 Slider thumb at ({global_x}, {global_y}) in sim region ({x}, {y})")
        return (global_x, global_y, w, h)

    def drag_slider(self, x, y, distance=100):
        """Drag the slider"""
        print(f"  🖱️  Moving to ({x}, {y})...")
        pyautogui.moveTo(x, y, duration=0.3)

        print(f"  ✋ Dragging by {distance}px...")
        pyautogui.mouseDown()
        pyautogui.moveTo(x + distance, y, duration=0.5)
        pyautogui.mouseUp()

        print("  ✅ Drag complete")
        time.sleep(0.5)

    def click_plus_button(self, slider_x, slider_y):
        """Click the + button next to slider"""
        # + button is typically to the right of slider
        plus_x = slider_x + 150
        plus_y = slider_y

        print(f"  👆 Clicking + button at ({plus_x}, {plus_y})...")
        pyautogui.click(plus_x, plus_y)
        time.sleep(0.3)

    def run(self):
        """Run the full test"""
        print("\n" + "=" * 60)
        print("  🤖 Solar2D Simulator AI Automation")
        print("=" * 60)

        # Step 1: Find Simulator
        print("\n[Step 1] Finding Simulator window...")
        if not self.find_simulator_window():
            print("  ❌ Could not find Simulator window")
            print("  💡 Make sure Corona Simulator is running")
            return False

        # Step 2: Initial screenshot
        print("\n[Step 2] Capturing initial state...")
        self.capture("sim_01_start")

        # Step 3: Find slider
        print("\n[Step 3] Looking for slider in Simulator...")
        slider = self.find_slider_in_simulator()

        if not slider:
            print("\n  💡 Tips:")
            print("     - Make sure Slider screen is visible")
            print("     - Check sim_region.png for debug info")
            return False

        x, y, w, h = slider

        # Step 4: Drag slider
        print("\n[Step 4] Dragging slider...")
        self.drag_slider(x, y, distance=80)

        # Step 5: Capture result
        print("\n[Step 5] Capturing result...")
        self.capture("sim_02_dragged")

        # Step 6: Click + button
        print("\n[Step 6] Clicking + button...")
        self.click_plus_button(x, y)
        self.capture("sim_03_clicked")

        print("\n" + "=" * 60)
        print("  ✨ Test completed!")
        print("=" * 60)
        return True


def main():
    print("\n⚠️  Safety: Move mouse to corner to abort")
    print("⏳ Starting in 3 seconds...")
    time.sleep(3)

    agent = SimulatorAgent()
    success = agent.run()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
