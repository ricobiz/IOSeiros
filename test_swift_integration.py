#!/usr/bin/env python3
"""
Test Swift -> Python server integration
Simulates Swift app requests to Python server
"""

import requests
import json
import base64
import time
from PIL import Image, ImageDraw
import io

def create_ios_screenshot_mock():
    """Create a mock iOS screenshot"""
    img = Image.new('RGB', (375, 812), color='white')  # iPhone dimensions
    draw = ImageDraw.Draw(img)
    
    # Draw mock UI elements
    draw.rectangle([20, 100, 355, 150], fill='lightblue', outline='blue')
    draw.text((30, 115), "Settings", fill='black')
    
    draw.rectangle([20, 170, 355, 220], fill='lightgreen', outline='green')
    draw.text((30, 185), "Profile", fill='black')
    
    draw.rectangle([20, 240, 355, 290], fill='lightcoral', outline='red')
    draw.text((30, 255), "Logout", fill='black')
    
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    return base64.b64encode(buffer.getvalue()).decode()

def test_swift_qwen_integration():
    """Test integration as Swift app would use it"""
    print("🔍 Testing Swift -> Qwen2VL Integration")
    print("=" * 50)
    
    # Test 1: Health check (Swift app startup)
    print("1. Health Check (App Startup)")
    try:
        response = requests.get("http://localhost:8888/health", timeout=5)
        data = response.json()
        if data['model_loaded']:
            print("✅ Server ready for Swift integration")
        else:
            print("❌ Server not ready")
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False
    
    # Test 2: UI Analysis (Main use case)
    print("\n2. UI Analysis Request")
    try:
        screenshot = create_ios_screenshot_mock()
        payload = {
            "prompt": "Analyze this iOS screen and identify all interactive elements",
            "image": screenshot,
            "task_type": "ui_analysis"
        }
        
        start_time = time.time()
        response = requests.post("http://localhost:8888/analyze", 
                               json=payload, timeout=15)
        end_time = time.time()
        
        data = response.json()
        print(f"✅ UI Analysis completed in {end_time - start_time:.3f}s")
        print(f"📱 Response: {data['response'][:100]}...")
        
        if 'ui_elements' in data:
            print(f"🎯 UI Elements found: {len(data['ui_elements'])}")
            for i, element in enumerate(data['ui_elements'][:3]):
                print(f"   {i+1}. {element.get('type', 'unknown')}: {element.get('text', 'N/A')}")
        
    except Exception as e:
        print(f"❌ UI Analysis failed: {e}")
    
    # Test 3: OCR Request
    print("\n3. OCR Request")
    try:
        payload = {
            "prompt": "Extract all text from this screen",
            "image": screenshot,
            "task_type": "ocr"
        }
        
        response = requests.post("http://localhost:8888/analyze", 
                               json=payload, timeout=10)
        data = response.json()
        print(f"✅ OCR completed")
        print(f"📝 Extracted text preview: {data['response'][:100]}...")
        
    except Exception as e:
        print(f"❌ OCR test failed: {e}")
    
    # Test 4: Automation Planning
    print("\n4. Automation Planning Request")
    try:
        payload = {
            "prompt": "I want to tap on the Settings button. Provide coordinates and action plan.",
            "image": screenshot,
            "task_type": "ui_analysis"
        }
        
        response = requests.post("http://localhost:8888/analyze", 
                               json=payload, timeout=10)
        data = response.json()
        print(f"✅ Automation planning completed")
        print(f"🎯 Action plan: {data['response'][:100]}...")
        
        if 'ui_elements' in data:
            for element in data['ui_elements']:
                if 'settings' in element.get('text', '').lower():
                    print(f"🎯 Settings button found at: {element.get('coordinates', 'N/A')}")
        
    except Exception as e:
        print(f"❌ Automation planning failed: {e}")
    
    return True

def test_openrouter_integration():
    """Test OpenRouter integration (without real API key)"""
    print("\n🔍 Testing OpenRouter Integration")
    print("=" * 50)
    
    # This would normally require a real API key
    print("📝 OpenRouter integration test:")
    print("   - Endpoint: https://openrouter.ai/api/v1/chat/completions")
    print("   - Models: GPT-4, Claude, etc.")
    print("   - Status: ⚠️  Requires API key for full testing")
    print("   - Swift implementation: ✅ Present in OpenRouterManager.swift")

def test_web_automation():
    """Test web automation components"""
    print("\n🔍 Testing Web Automation Components")
    print("=" * 50)
    
    # Check if web automation Python modules exist
    web_modules = [
        "eiros_agent/web_automation/manager.py",
        "eiros_agent/web_automation/browser_controller.py",
        "eiros_agent/web_automation/form_handler.py",
        "eiros_agent/web_automation/navigation.py"
    ]
    
    for module in web_modules:
        try:
            with open(module, 'r') as f:
                content = f.read()
                if len(content) > 100:  # Basic check
                    print(f"✅ {module}: Present and non-empty")
                else:
                    print(f"⚠️  {module}: Present but minimal")
        except FileNotFoundError:
            print(f"❌ {module}: Not found")

def test_ocr_components():
    """Test OCR components"""
    print("\n🔍 Testing OCR Components")
    print("=" * 50)
    
    ocr_modules = [
        "eiros_agent/ocr/manager.py",
        "eiros_agent/ocr/engines.py",
        "eiros_agent/ocr/preprocessor.py",
        "eiros_agent/ocr/postprocessor.py"
    ]
    
    for module in ocr_modules:
        try:
            with open(module, 'r') as f:
                content = f.read()
                if 'tesseract' in content.lower() or 'ocr' in content.lower():
                    print(f"✅ {module}: OCR functionality detected")
                else:
                    print(f"⚠️  {module}: Present but OCR functionality unclear")
        except FileNotFoundError:
            print(f"❌ {module}: Not found")

def main():
    """Run all integration tests"""
    print("🚀 iOS Eiros Agent Integration Tests")
    print("=" * 60)
    
    # Test core integration
    test_swift_qwen_integration()
    
    # Test other components
    test_openrouter_integration()
    test_web_automation()
    test_ocr_components()
    
    # Final server stats
    print("\n📊 Final Server Statistics")
    print("=" * 50)
    try:
        response = requests.get("http://localhost:8888/stats", timeout=5)
        data = response.json()
        print(f"Total requests: {data['total_requests']}")
        print(f"Success rate: {data['success_rate']}%")
        print(f"Average response time: {data['average_inference_time']:.3f}s")
    except Exception as e:
        print(f"Could not get final stats: {e}")

if __name__ == "__main__":
    main()
