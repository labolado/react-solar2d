#!/usr/bin/env python3
"""
AI Visual Validator for react-solar2d
Validates UI changes without controlling mouse
Combines OCR + Image Diff for robust verification
"""

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imagehash
import time
import os
import json
from datetime import datetime

# Try to import PaddleOCR, fallback to simple method
try:
    from paddleocr import PaddleOCR
    PADDLE_AVAILABLE = True
except ImportError:
    PADDLE_AVAILABLE = False
    print("⚠️  PaddleOCR not available, using fallback methods")


class VisualValidator:
    """Validates UI state changes through visual analysis"""

    def __init__(self, output_dir=None):
        self.output_dir = output_dir or os.path.dirname(os.path.abspath(__file__))
        self.results = []

        # Initialize OCR if available
        if PADDLE_AVAILABLE:
            print("🔄 Initializing PaddleOCR...")
            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                try:
                    self.ocr = PaddleOCR(lang='en')
                except Exception as e:
                    print(f"   ⚠️  PaddleOCR init failed: {e}")
                    self.ocr = None
        else:
            self.ocr = None

    def capture(self, name):
        """Capture screenshot using screencapture (macOS native)"""
        import subprocess

        path = os.path.join(self.output_dir, f"{name}.png")

        # Use macOS screencapture for better performance
        subprocess.run(['screencapture', '-x', path], check=True)

        return path

    def read_text(self, image_path):
        """Extract text from image using OCR"""
        if not self.ocr:
            return []

        try:
            result = self.ocr.predict(image_path)
            texts = []
            if result and 'ocr' in result and 'words' in result['ocr']:
                for word in result['ocr']['words']:
                    texts.append({
                        'text': word.get('text', ''),
                        'confidence': word.get('confidence', 0),
                        'bbox': word.get('bbox', [])
                    })
            return texts
        except Exception as e:
            print(f"   OCR error: {e}")
            return []

    def extract_slider_values(self, texts):
        """Extract slider values from OCR results"""
        values = []
        for item in texts:
            text = item['text']
            # Look for patterns like:
            # "Basic (0-1): 0.50"
            # "Range 0-100: 50"
            # "0.50", "50", "Value: 70"

            import re

            # Pattern 1: "Basic (0-1): 0.50"
            match = re.search(r'Basic\s*\([^)]*\):\s*([0-9.]+)', text)
            if match:
                values.append({'type': 'basic', 'value': float(match.group(1)), 'raw': text})
                continue

            # Pattern 2: "Range 0-100: 50"
            match = re.search(r'Range\s*\d+-\d+:\s*(\d+)', text)
            if match:
                values.append({'type': 'range', 'value': int(match.group(1)), 'raw': text})
                continue

            # Pattern 3: Standalone numbers that look like slider values
            match = re.search(r'^[\s:]*([0-9.]+)\s*$', text)
            if match:
                val = float(match.group(1))
                if 0 <= val <= 100:  # Reasonable slider range
                    values.append({'type': 'numeric', 'value': val, 'raw': text})

        return values

    def compute_image_diff(self, img1_path, img2_path, threshold=30):
        """
        Compute pixel-level difference between two images
        Returns: (diff_percentage, diff_mask_path)
        """
        img1 = cv2.imread(img1_path)
        img2 = cv2.imread(img2_path)

        if img1 is None or img2 is None:
            return 0, None

        # Resize to same size
        h, w = min(img1.shape[0], img2.shape[0]), min(img1.shape[1], img2.shape[1])
        img1 = cv2.resize(img1, (w, h))
        img2 = cv2.resize(img2, (w, h))

        # Convert to grayscale
        gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
        gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)

        # Compute absolute difference
        diff = cv2.absdiff(gray1, gray2)

        # Threshold to ignore small differences (noise)
        _, thresh = cv2.threshold(diff, threshold, 255, cv2.THRESH_BINARY)

        # Count changed pixels
        changed_pixels = np.count_nonzero(thresh)
        total_pixels = thresh.size
        diff_percentage = (changed_pixels / total_pixels) * 100

        # Save diff visualization
        diff_path = os.path.join(self.output_dir, "diff_visualization.png")

        # Create colored diff image
        diff_color = cv2.cvtColor(diff, cv2.COLOR_GRAY2BGR)
        diff_color[thresh > 0] = [0, 0, 255]  # Red for changes

        # Blend with original
        blended = cv2.addWeighted(img2, 0.7, diff_color, 0.3, 0)
        cv2.imwrite(diff_path, blended)

        return diff_percentage, diff_path

    def compute_hash_similarity(self, img1_path, img2_path):
        """Compute perceptual hash similarity"""
        hash1 = imagehash.phash(Image.open(img1_path))
        hash2 = imagehash.phash(Image.open(img2_path))

        # Hamming distance
        distance = hash1 - hash2
        max_distance = 64  # pHash is 64 bits

        # Convert to similarity (0-1)
        similarity = 1 - (distance / max_distance)

        return similarity, distance

    def validate_slider_drag(self, before_path, after_path, expected_change='increase'):
        """
        Validate that a slider drag operation worked

        Args:
            before_path: Screenshot before drag
            after_path: Screenshot after drag
            expected_change: 'increase', 'decrease', or 'any'

        Returns:
            dict with validation results
        """
        print(f"\n🔍 Validating slider drag...")
        print(f"   Before: {os.path.basename(before_path)}")
        print(f"   After: {os.path.basename(after_path)}")

        result = {
            'timestamp': datetime.now().isoformat(),
            'before_image': before_path,
            'after_image': after_path,
            'tests_passed': 0,
            'tests_total': 0,
            'details': {}
        }

        # Test 1: OCR Value Change
        print("\n   Test 1: Checking OCR value change...")
        before_texts = self.read_text(before_path)
        after_texts = self.read_text(after_path)

        before_values = self.extract_slider_values(before_texts)
        after_values = self.extract_slider_values(after_texts)

        print(f"      Before values: {[v['value'] for v in before_values]}")
        print(f"      After values: {[v['value'] for v in after_values]}")

        ocr_passed = False
        if before_values and after_values:
            # Compare first value
            before_val = before_values[0]['value']
            after_val = after_values[0]['value']

            if expected_change == 'increase':
                ocr_passed = after_val > before_val
            elif expected_change == 'decrease':
                ocr_passed = after_val < before_val
            else:
                ocr_passed = after_val != before_val

            result['details']['ocr'] = {
                'before': before_val,
                'after': after_val,
                'passed': ocr_passed
            }

        result['tests_total'] += 1
        if ocr_passed:
            result['tests_passed'] += 1
            print(f"      ✅ OCR: {before_val} → {after_val}")
        else:
            print(f"      ⚠️  OCR check inconclusive")

        # Test 2: Image Diff
        print("\n   Test 2: Checking visual changes...")
        diff_pct, diff_path = self.compute_image_diff(before_path, after_path)

        # Should have some change but not too much (not a screen switch)
        diff_passed = 0.1 < diff_pct < 50  # Between 0.1% and 50%

        result['details']['image_diff'] = {
            'percentage': diff_pct,
            'passed': diff_passed,
            'visualization': diff_path
        }

        result['tests_total'] += 1
        if diff_passed:
            result['tests_passed'] += 1
            print(f"      ✅ Visual change: {diff_pct:.2f}%")
        else:
            print(f"      ⚠️  Visual change: {diff_pct:.2f}% (expected 0.1-50%)")

        # Test 3: Perceptual Hash
        print("\n   Test 3: Checking perceptual similarity...")
        similarity, distance = self.compute_hash_similarity(before_path, after_path)

        # Should be similar but not identical (same screen, different state)
        hash_passed = 0.8 < similarity < 0.99

        result['details']['phash'] = {
            'similarity': similarity,
            'hamming_distance': distance,
            'passed': hash_passed
        }

        result['tests_total'] += 1
        if hash_passed:
            result['tests_passed'] += 1
            print(f"      ✅ Similarity: {similarity:.3f}")
        else:
            print(f"      ⚠️  Similarity: {similarity:.3f} (expected 0.8-0.99)")

        # Overall result
        result['success'] = result['tests_passed'] >= 2  # At least 2/3 tests pass

        print(f"\n   📊 Result: {result['tests_passed']}/{result['tests_total']} tests passed")

        return result

    def generate_report(self, results, output_path=None):
        """Generate HTML report"""
        if output_path is None:
            output_path = os.path.join(self.output_dir, "validation_report.html")

        html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>react-solar2d Validation Report</title>
            <style>
                body { font-family: -apple-system, sans-serif; padding: 20px; max-width: 1200px; margin: 0 auto; }
                h1 { color: #333; }
                .test { border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin: 10px 0; }
                .pass { border-left: 4px solid #4CAF50; }
                .fail { border-left: 4px solid #f44336; }
                .warning { border-left: 4px solid #ff9800; }
                img { max-width: 100%; border-radius: 4px; margin: 10px 0; }
                .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
                code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
            </style>
        </head>
        <body>
            <h1>🧪 react-solar2d Visual Validation Report</h1>
            <p>Generated: {}</p>
        """.format(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

        for i, r in enumerate(results):
            status_class = 'pass' if r['success'] else 'fail'
            status_emoji = '✅' if r['success'] else '❌'

            html += f"""
            <div class="test {status_class}">
                <h3>{status_emoji} Test #{i+1}</h3>
                <p>Time: {r['timestamp']}</p>
                <p>Passed: {r['tests_passed']}/{r['tests_total']}</p>

                <div class="grid">
                    <div>
                        <h4>Before</h4>
                        <img src="{os.path.basename(r['before_image'])}" />
                    </div>
                    <div>
                        <h4>After</h4>
                        <img src="{os.path.basename(r['after_image'])}" />
                    </div>
                </div>
            """

            if 'diff' in r['details'] and r['details']['diff'].get('visualization'):
                html += f"""
                <h4>Difference Visualization</h4>
                <img src="{os.path.basename(r['details']['diff']['visualization'])}" />
                """

            html += "</div>"

        html += "</body></html>"

        with open(output_path, 'w') as f:
            f.write(html)

        print(f"\n📄 Report saved: {output_path}")
        return output_path


def demo():
    """Demo usage"""
    print("=" * 60)
    print("Visual Validator Demo")
    print("=" * 60)

    validator = VisualValidator()

    # Check for existing images
    output_dir = validator.output_dir
    before_img = os.path.join(output_dir, "full_01_start.png")
    after_img = os.path.join(output_dir, "full_02_end.png")

    if not os.path.exists(before_img) or not os.path.exists(after_img):
        print("\n⚠️  Need before/after screenshots")
        print("   Run: python3 full_demo.py")
        print("   Or manually capture screenshots")
        return

    # Validate
    result = validator.validate_slider_drag(before_img, after_img)

    # Generate report
    validator.generate_report([result])

    print("\n" + "=" * 60)
    if result['success']:
        print("✅ Validation PASSED")
    else:
        print("❌ Validation FAILED")
    print("=" * 60)


if __name__ == "__main__":
    demo()
