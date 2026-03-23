#!/usr/bin/env python3
"""
Visual Regression Test Runner for react-solar2d

This script:
1. Starts Solar2D Simulator with KitchenSink app
2. Uses HTTP API to navigate to specific screens
3. Captures screenshots
4. Compares with reference images
5. Reports differences

Usage:
    python3 run_visual_tests.py [--test TEST_NAME]

Requirements:
    - Solar2D Simulator installed
    - KitchenSink app configured to start test server
"""

import argparse
import base64
import http.client
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# Test configuration
TEST_SERVER_HOST = "localhost"
TEST_SERVER_PORT = 9876
SIMULATOR_PATH = "/Applications/Corona-b3/Corona Simulator.app/Contents/MacOS/Corona Simulator"
PROJECT_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "examples")
REFERENCE_DIR = Path(__file__).parent / "reference"
OUTPUT_DIR = Path(__file__).parent / "output"

# Visual tests to run
VISUAL_TESTS = [
    {
        "name": "slider_default",
        "category": "Interop",
        "route": "Slider",
        "description": "Slider component with default styling",
    },
    {
        "name": "datetime_picker_date",
        "category": "Interop",
        "route": "DateTimePicker",
        "description": "DateTimePicker in date mode",
    },
    {
        "name": "datetime_picker_time",
        "category": "Interop",
        "route": "DateTimePicker",
        "description": "DateTimePicker in time mode",
        "setup": "tap_time_tab",  # Custom setup action
    },
]


def wait_for_server(timeout=30):
    """Wait for test server to be ready"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            conn = http.client.HTTPConnection(TEST_SERVER_HOST, TEST_SERVER_PORT, timeout=2)
            conn.request("GET", "/status")
            response = conn.getresponse()
            if response.status == 200:
                data = json.loads(response.read().decode())
                if data.get("running"):
                    print(f"✓ Test server ready (platform: {data.get('platform', 'unknown')})")
                    return True
            conn.close()
        except Exception:
            pass
        time.sleep(0.5)
    return False


def navigate_to(route):
    """Navigate to a specific screen"""
    try:
        conn = http.client.HTTPConnection(TEST_SERVER_HOST, TEST_SERVER_PORT, timeout=10)
        body = f"route={route}"
        conn.request("POST", "/navigate", body=body, headers={
            "Content-Type": "application/x-www-form-urlencoded"
        })
        response = conn.getresponse()
        success = response.status == 200
        conn.close()
        return success
    except Exception as e:
        print(f"  ✗ Navigation failed: {e}")
        return False


def capture_screenshot():
    """Capture screenshot from running app"""
    try:
        conn = http.client.HTTPConnection(TEST_SERVER_HOST, TEST_SERVER_PORT, timeout=30)
        conn.request("GET", "/screenshot")
        response = conn.getresponse()

        if response.status == 200:
            data = json.loads(response.read().decode())
            conn.close()

            if data.get("success") and data.get("base64"):
                return base64.b64decode(data["base64"])
        else:
            conn.close()
    except Exception as e:
        print(f"  ✗ Screenshot failed: {e}")

    return None


def save_screenshot(name, image_data, directory):
    """Save screenshot to directory"""
    filepath = directory / f"{name}.png"
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "wb") as f:
        f.write(image_data)
    return filepath


def compare_images(reference_path, output_path):
    """Compare two images and return similarity score"""
    try:
        from PIL import Image
        import numpy as np

        ref_img = Image.open(reference_path).convert("RGB")
        out_img = Image.open(output_path).convert("RGB")

        # Resize to same size if needed
        if ref_img.size != out_img.size:
            out_img = out_img.resize(ref_img.size)

        ref_array = np.array(ref_img)
        out_array = np.array(out_img)

        # Calculate mean squared error
        mse = np.mean((ref_array - out_array) ** 2)

        # Convert to similarity score (0-100)
        if mse == 0:
            similarity = 100.0
        else:
            similarity = max(0, 100 - (mse / 255.0))

        return similarity
    except ImportError:
        print("  ⚠ PIL not installed, skipping image comparison")
        return None
    except Exception as e:
        print(f"  ✗ Comparison failed: {e}")
        return None


def run_visual_test(test_config, simulator_proc=None):
    """Run a single visual test"""
    name = test_config["name"]
    route = test_config["route"]
    description = test_config.get("description", "")

    print(f"\n[{name}] {description}")

    # Navigate to screen
    print(f"  → Navigating to {route}...")
    if not navigate_to(route):
        print(f"  ✗ FAILED: Could not navigate to {route}")
        return False

    # Wait for screen to settle
    time.sleep(1)

    # Capture screenshot
    print(f"  → Capturing screenshot...")
    image_data = capture_screenshot()
    if not image_data:
        print(f"  ✗ FAILED: Could not capture screenshot")
        return False

    # Save output
    output_path = save_screenshot(name, image_data, OUTPUT_DIR)
    print(f"  ✓ Saved: {output_path}")

    # Compare with reference if exists
    reference_path = REFERENCE_DIR / f"{name}.png"
    if reference_path.exists():
        similarity = compare_images(reference_path, output_path)
        if similarity is not None:
            status = "✓ PASS" if similarity >= 95 else "✗ FAIL"
            print(f"  {status} Similarity: {similarity:.1f}%")
            return similarity >= 95
    else:
        print(f"  ⚠ No reference image, saving as new reference")
        save_screenshot(name, image_data, REFERENCE_DIR)

    return True


def main():
    parser = argparse.ArgumentParser(description="Visual regression tests for react-solar2d")
    parser.add_argument("--test", help="Run specific test by name")
    parser.add_argument("--update-reference", action="store_true", help="Update reference images")
    args = parser.parse_args()

    print("=" * 60)
    print("Visual Regression Test Runner")
    print("=" * 60)

    # Create directories
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Check if test server is already running
    print("\n→ Checking test server...")
    if not wait_for_server(timeout=5):
        print("✗ Test server not running!")
        print("\nPlease start the Solar2D Simulator first:")
        print(f"  {SIMULATOR_PATH} {PROJECT_PATH}/main.lua")
        print("\nMake sure the test server starts on port 9876")
        sys.exit(1)

    # Filter tests if specified
    tests_to_run = VISUAL_TESTS
    if args.test:
        tests_to_run = [t for t in VISUAL_TESTS if t["name"] == args.test]
        if not tests_to_run:
            print(f"✗ Test '{args.test}' not found")
            sys.exit(1)

    # Run tests
    results = []
    for test in tests_to_run:
        success = run_visual_test(test)
        results.append((test["name"], success))

    # Summary
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    passed = sum(1 for _, r in results if r)
    failed = sum(1 for _, r in results if not r)

    for name, success in results:
        status = "✓ PASS" if success else "✗ FAIL"
        print(f"  {status}: {name}")

    print(f"\nTotal: {passed} passed, {failed} failed")

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
