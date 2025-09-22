#!/usr/bin/env python3
"""
Test script for Qwen2-VL integration
"""

import base64
import json
import requests
import time
from PIL import Image, ImageDraw
import io

def create_test_image():
    """Create a simple test image with UI elements"""
    # Create a 400x600 image (typical mobile screen aspect ratio)
    img = Image.new('RGB', (400, 600), color='white')
    draw = ImageDraw.Draw(img)
    
    # Draw some UI elements
    # Header
    draw.rectangle([0, 0, 400, 80], fill='#007AFF')
    draw.text((20, 30), "Test App", fill='white')
    
    # Button
    draw.rectangle([50, 200, 350, 250], fill='#34C759', outline='#30B855')
    draw.text((180, 220), "Login", fill='white')
    
    # Text field
    draw.rectangle([50, 300, 350, 340], fill='white', outline='#C7C7CC')
    draw.text((60, 315), "Enter username", fill='#999999')
    
    # Another button
    draw.rectangle([50, 400, 350, 450], fill='#FF3B30', outline='#FF2D20')
    draw.text((170, 420), "Cancel", fill='white')
    
    return img

def test_server_health():
    """Test server health endpoint"""
    try:
        response = requests.get('http://localhost:8888/health', timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Server health: {data}")
            return True
        else:
            print(f"❌ Server health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Server health check error: {e}")
        return False

def test_model_status():
    """Test model status endpoint"""
    try:
        response = requests.get('http://localhost:8888/model_status', timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"📊 Model status: {data}")
            return data.get('loaded', False)
        else:
            print(f"❌ Model status check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Model status check error: {e}")
        return False

def test_image_analysis():
    """Test image analysis endpoint"""
    try:
        # Create test image
        test_image = create_test_image()
        
        # Convert to base64
        buffer = io.BytesIO()
        test_image.save(buffer, format='JPEG', quality=80)
        image_data = buffer.getvalue()
        base64_image = base64.b64encode(image_data).decode('utf-8')
        
        # Test different task types
        test_cases = [
            {
                "prompt": "Find all buttons on this screen",
                "task_type": "findButton"
            },
            {
                "prompt": "Extract all text from this screen",
                "task_type": "extractText"
            },
            {
                "prompt": "Describe this mobile app screen",
                "task_type": "describeScreen"
            }
        ]
        
        for i, test_case in enumerate(test_cases, 1):
            print(f"\n🧪 Test {i}: {test_case['task_type']}")
            
            payload = {
                "image": base64_image,
                "prompt": test_case["prompt"],
                "task_type": test_case["task_type"]
            }
            
            response = requests.post(
                'http://localhost:8888/analyze',
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    print(f"✅ Success! Confidence: {data.get('confidence', 0):.2f}")
                    print(f"📝 Response: {data.get('response', '')[:100]}...")
                    print(f"⏱️  Processing time: {data.get('processing_time', 0):.2f}s")
                    
                    # Show parsed response if available
                    if 'parsed_response' in data:
                        parsed = data['parsed_response']
                        if 'elements' in parsed and parsed['elements']:
                            print(f"🎯 Found {len(parsed['elements'])} UI elements")
                        if 'text_content' in parsed and parsed['text_content']:
                            print(f"📄 Extracted text: {parsed['text_content'][:50]}...")
                else:
                    print(f"❌ Analysis failed: {data.get('error', 'Unknown error')}")
            else:
                print(f"❌ HTTP error: {response.status_code}")
                print(f"Response: {response.text[:200]}")
        
        return True
        
    except Exception as e:
        print(f"❌ Image analysis test error: {e}")
        return False

def wait_for_model_load(max_wait=120):
    """Wait for model to load on server"""
    print("⏳ Waiting for model to load...")
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        if test_model_status():
            print("✅ Model loaded successfully!")
            return True
        
        print("⏳ Still loading... waiting 5 seconds")
        time.sleep(5)
    
    print("❌ Model loading timeout")
    return False

def main():
    print("🚀 Testing Qwen2-VL Integration")
    print("=" * 50)
    
    # Test 1: Server health
    print("\n1️⃣ Testing server health...")
    if not test_server_health():
        print("❌ Server is not running. Please start qwen2vl_server.py")
        return
    
    # Test 2: Wait for model to load
    print("\n2️⃣ Checking model status...")
    if not test_model_status():
        if not wait_for_model_load():
            print("❌ Model failed to load. Check server logs.")
            return
    
    # Test 3: Image analysis
    print("\n3️⃣ Testing image analysis...")
    if test_image_analysis():
        print("\n🎉 All tests passed! Integration is working correctly.")
    else:
        print("\n❌ Image analysis tests failed.")

if __name__ == "__main__":
    main()
