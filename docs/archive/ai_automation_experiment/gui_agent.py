#!/usr/bin/env python3
"""
AI-assisted GUI Automation for react-solar2d
Uses screenshot + simple CV to control Solar2D Simulator
"""

import pyautogui
import cv2
import numpy as np
from PIL import Image
import time
import subprocess
import os

# Safety settings
pyautogui.FAILSAFE = True  # Move mouse to corner to abort
pyautogui.PAUSE = 0.5

class Solar2DAgent:
    """Simple AI agent for controlling Solar2D Simulator"""

    def __init__(self):
        self.screen_width, self.screen_height = pyautogui.size()
        print(f"Screen size: {self.screen_width}x{self.screen_height}")

    def screenshot(self, filename="screenshot.png"):
        """Take a screenshot"""
        screenshot = pyautogui.screenshot()
        screenshot.save(filename)
        return filename

    def find_color(self, target_color, tolerance=30):
        """
        Find a color on screen (e.g., blue slider track)
        target_color: (R, G, B) tuple
        """
        screenshot = pyautogui.screenshot()
        img = np.array(screenshot)
        # Convert RGB to BGR for OpenCV
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        # Create mask for target color
        lower = np.array([max(0, c - tolerance) for c in target_color])
        upper = np.array([min(255, c + tolerance) for c in target_color])
        mask = cv2.inRange(img, lower, upper)

        # Find contours
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if contours:
            # Get largest contour
            largest = max(contours, key=cv2.contourArea)
            x, y, w, h = cv2.boundingRect(largest)
            center_x = x + w // 2
            center_y = y + h // 2
            return (center_x, center_y, w, h)
        return None

    def click_text(self, text):
        """Click on text (using OCR) - requires pytesseract"""
        try:
            import pytesseract
            screenshot = pyautogui.screenshot()
            data = pytesseract.image_to_data(screenshot, output_type=pytesseract.Output.DICT)

            for i, word in enumerate(data['text']):
                if text.lower() in word.lower():
                    x = data['left'][i] + data['width'][i] // 2
                    y = data['top'][i] + data['height'][i] // 2
                    self.click(x, y)
                    return True
            return False
        except ImportError:
            print("pytesseract not installed, using coordinates instead")
            return False

    def click(self, x, y):
        """Click at coordinates"""
        print(f"Clicking at ({x}, {y})")
        pyautogui.click(x, y)
        time.sleep(0.3)

    def drag(self, start_x, start_y, end_x, end_y, duration=0.5):
        """Drag from start to end"""
        print(f"Dragging from ({start_x}, {start_y}) to ({end_x}, {end_y})")
        pyautogui.moveTo(start_x, start_y)
        pyautogui.mouseDown()
        pyautogui.moveTo(end_x, end_y, duration=duration)
        pyautogui.mouseUp()
        time.sleep(0.3)

    def find_and_drag_slider(self, color=(0, 122, 255), track_width=200):
        """
        Find a slider by color and drag it
        Default color is iOS blue: #007AFF = (0, 122, 255)
        """
        result = self.find_color(color, tolerance=40)
        if result:
            x, y, w, h = result
            print(f"Found slider at ({x}, {y}), size {w}x{h}")

            # Drag from current position to the right
            start_x = x
            start_y = y
            end_x = x + track_width // 2  # Drag halfway
            end_y = y

            self.drag(start_x, start_y, end_x, end_y)
            return True
        else:
            print("Slider not found")
            return False

    def launch_simulator(self, project_path=None):
        """Launch Solar2D Simulator"""
        simulator_path = "/Applications/Corona-b3/Corona Simulator.app/Contents/MacOS/Corona Simulator"

        if not os.path.exists(simulator_path):
            print(f"Simulator not found at {simulator_path}")
            # Try to find it
            result = subprocess.run(
                ["mdfind", "kMDItemCFBundleIdentifier == 'com.coronalabs.Corona_Simulator'"],
                capture_output=True, text=True
            )
            if result.stdout.strip():
                simulator_path = result.stdout.strip().replace(".app", ".app/Contents/MacOS/Corona Simulator")
                print(f"Found simulator at: {simulator_path}")

        if project_path:
            cmd = [simulator_path, project_path]
        else:
            cmd = [simulator_path]

        print(f"Launching: {' '.join(cmd)}")
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(3)  # Wait for launch

    def run_test(self):
        """Run a simple test"""
        print("=" * 50)
        print("react-solar2d AI Automation Test")
        print("=" * 50)

        # Step 1: Screenshot
        print("\n1. Taking screenshot...")
        self.screenshot("test_initial.png")

        # Step 2: Try to find and drag a blue slider
        print("\n2. Looking for blue slider...")
        slider_dragged = self.find_and_drag_slider(color=(0, 122, 255))

        if slider_dragged:
            print("✅ Slider test passed!")
        else:
            print("❌ Slider not found - may need to navigate to Forms screen first")

        # Step 3: Take final screenshot
        print("\n3. Taking final screenshot...")
        self.screenshot("test_final.png")

        return slider_dragged


def main():
    """Main entry point"""
    agent = Solar2DAgent()

    # Check if simulator is running
    result = subprocess.run(
        ["pgrep", "-f", "Corona Simulator"],
        capture_output=True
    )

    if result.returncode != 0:
        print("Solar2D Simulator not running. Launching...")
        # Try to launch with examples/main.lua
        project_path = os.path.expanduser("~/data/dev/app/react-solar2d/examples/main.lua")
        if os.path.exists(project_path):
            agent.launch_simulator(project_path)
        else:
            agent.launch_simulator()
    else:
        print("Solar2D Simulator is already running")

    print("\nWaiting 3 seconds for you to switch to Simulator window...")
    time.sleep(3)

    # Run the test
    success = agent.run_test()

    print("\n" + "=" * 50)
    if success:
        print("Test completed successfully!")
    else:
        print("Test completed with warnings")
    print("Screenshots saved: test_initial.png, test_final.png")
    print("=" * 50)


if __name__ == "__main__":
    main()
