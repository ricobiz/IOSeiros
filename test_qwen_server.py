#!/usr/bin/env python3
"""
Comprehensive test suite for Qwen2VL Demo Server
"""

import requests
import json
import base64
import time
from PIL import Image, ImageDraw
import io

def create_test_image():
    """Create a simple test image"""
    img = Image.new('RGB', (200, 100), color='white')
    draw = ImageDraw.Draw(img)
    draw.text((10, 10), "Test Image", fill='black')
    draw.rectangle([50, 30, 150, 80], outline='blue', width=2)
    
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    return base64.b64encode(buffer.getvalue()).decode()

def test_health_endpoint():
    """Test health endpoint"""
    print("🔍 Testing /health endpoint...")
    try:
        response = requests.get("http://localhost:8888/health", timeout=5)
        data = response.json()
        print(f"✅ Health Status: {data['status']}")
        print(f"📊 Model Loaded: {data['model_loaded']}")
        print(f"📈 Loading Progress: {data['loading_progress']}")
        return True
    except Exception as e:
        print(f"❌ Health test failed: {e}")
        return False

def test_stats_endpoint():
    """Test stats endpoint"""
    print("\n🔍 Testing /stats endpoint...")
    try:
        response = requests.get("http://localhost:8888/stats", timeout=5)
        data = response.json()
        print(f"✅ Total Requests: {data['total_requests']}")
        print(f"📊 Success Rate: {data['success_rate']}%")
        print(f"⏱️ Average Inference Time: {data['average_inference_time']:.3f}s")
        return True
    except Exception as e:
        print(f"❌ Stats test failed: {e}")
        return False

def test_analyze_text_only():
    """Test analyze endpoint with text only"""
    print("\n🔍 Testing /analyze endpoint (text only)...")
    try:
        payload = {
            "prompt": "Explain what artificial intelligence is",
            "task_type": "general"
        }
        
        start_time = time.time()
        response = requests.post("http://localhost:8888/analyze", 
                               json=payload, timeout=10)
        end_time = time.time()
        
        data = response.json()
        print(f"✅ Response received in {end_time - start_time:.3f}s")
        print(f"📝 Response length: {len(data['response'])} characters")
        print(f"🎯 Task type: {data['task_type']}")
        print(f"📊 Confidence: {data['confidence']}")
        return True
    except Exception as e:
        print(f"❌ Text analysis test failed: {e}")
        return False

def test_analyze_with_image():
    """Test analyze endpoint with image"""
    print("\n🔍 Testing /analyze endpoint (with image)...")
    try:
        test_image_b64 = create_test_image()
        
        payload = {
            "prompt": "Describe what you see in this image",
            "image": test_image_b64,
            "task_type": "ui_analysis"
        }
        
        start_time = time.time()
        response = requests.post("http://localhost:8888/analyze", 
                               json=payload, timeout=15)
        end_time = time.time()
        
        data = response.json()
        print(f"✅ Image analysis completed in {end_time - start_time:.3f}s")
        print(f"📝 Response: {data['response'][:100]}...")
        print(f"🎯 Task type: {data['task_type']}")
        print(f"📊 Confidence: {data['confidence']}")
        
        if 'ui_elements' in data:
            print(f"🔍 UI Elements detected: {len(data['ui_elements'])}")
            
        return True
    except Exception as e:
        print(f"❌ Image analysis test failed: {e}")
        return False

def test_different_task_types():
    """Test different task types"""
    print("\n🔍 Testing different task types...")
    
    task_types = [
        ("ui_analysis", "Analyze the UI elements in this screenshot"),
        ("ocr", "Extract all text from this image"),
        ("object_detection", "Identify all objects in this image"),
        ("general", "What do you see in this image?")
    ]
    
    test_image_b64 = create_test_image()
    results = {}
    
    for task_type, prompt in task_types:
        try:
            payload = {
                "prompt": prompt,
                "image": test_image_b64,
                "task_type": task_type
            }
            
            response = requests.post("http://localhost:8888/analyze", 
                                   json=payload, timeout=10)
            data = response.json()
            
            results[task_type] = {
                "success": True,
                "confidence": data['confidence'],
                "response_length": len(data['response'])
            }
            print(f"✅ {task_type}: confidence={data['confidence']}")
            
        except Exception as e:
            results[task_type] = {"success": False, "error": str(e)}
            print(f"❌ {task_type}: {e}")
    
    return results

def test_error_handling():
    """Test error handling"""
    print("\n🔍 Testing error handling...")
    
    # Test invalid JSON
    try:
        response = requests.post("http://localhost:8888/analyze", 
                               data="invalid json", timeout=5)
        print(f"✅ Invalid JSON handled: {response.status_code}")
    except Exception as e:
        print(f"❌ Invalid JSON test failed: {e}")
    
    # Test missing prompt
    try:
        response = requests.post("http://localhost:8888/analyze", 
                               json={"task_type": "general"}, timeout=5)
        print(f"✅ Missing prompt handled: {response.status_code}")
    except Exception as e:
        print(f"❌ Missing prompt test failed: {e}")
    
    # Test invalid image
    try:
        response = requests.post("http://localhost:8888/analyze", 
                               json={
                                   "prompt": "test",
                                   "image": "invalid_base64",
                                   "task_type": "general"
                               }, timeout=5)
        print(f"✅ Invalid image handled: {response.status_code}")
    except Exception as e:
        print(f"❌ Invalid image test failed: {e}")

def main():
    """Run all tests"""
    print("🚀 Starting Qwen2VL Demo Server Tests")
    print("=" * 50)
    
    results = {
        "health": test_health_endpoint(),
        "stats": test_stats_endpoint(),
        "text_analysis": test_analyze_text_only(),
        "image_analysis": test_analyze_with_image(),
        "task_types": test_different_task_types(),
    }
    
    test_error_handling()
    
    print("\n" + "=" * 50)
    print("📊 TEST SUMMARY")
    print("=" * 50)
    
    for test_name, result in results.items():
        if isinstance(result, bool):
            status = "✅ PASSED" if result else "❌ FAILED"
            print(f"{test_name}: {status}")
        elif isinstance(result, dict):
            print(f"{test_name}:")
            for sub_test, sub_result in result.items():
                if isinstance(sub_result, dict) and 'success' in sub_result:
                    status = "✅ PASSED" if sub_result['success'] else "❌ FAILED"
                    print(f"  {sub_test}: {status}")
    
    # Final stats check
    print("\n🔍 Final server stats:")
    try:
        response = requests.get("http://localhost:8888/stats", timeout=5)
        data = response.json()
        print(f"Total requests processed: {data['total_requests']}")
        print(f"Success rate: {data['success_rate']}%")
        print(f"Average response time: {data['average_inference_time']:.3f}s")
    except Exception as e:
        print(f"Could not get final stats: {e}")

if __name__ == "__main__":
    main()
