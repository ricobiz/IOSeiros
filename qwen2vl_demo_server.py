#!/usr/bin/env python3
"""
Qwen2-VL Demo Server for iOS Integration
Lightweight demo version that simulates model responses
"""

import base64
import io
import json
import logging
import time
from typing import Dict, Any

from flask import Flask, request, jsonify
from PIL import Image
import threading

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class Qwen2VLDemoServer:
    def __init__(self):
        self.model_loaded = True  # Demo mode - always loaded
        self.loading_progress = 1.0
        self.inference_times = []
        self.total_requests = 0
        self.successful_requests = 0
        
    def analyze_image(self, image: Image.Image, prompt: str, task_type: str = "general") -> Dict[str, Any]:
        """Simulate image analysis with realistic responses"""
        start_time = time.time()
        self.total_requests += 1
        
        # Simulate processing time
        processing_delay = 0.5 + (hash(prompt) % 100) / 200  # 0.5-1.0 seconds
        time.sleep(processing_delay)
        
        try:
            # Generate task-specific responses
            response = self.generate_response(image, prompt, task_type)
            parsed_response = self.parse_response_for_ui_automation(response, task_type)
            
            processing_time = time.time() - start_time
            self.inference_times.append(processing_time)
            self.successful_requests += 1
            
            # Keep only last 100 inference times
            if len(self.inference_times) > 100:
                self.inference_times = self.inference_times[-100:]
            
            confidence = self.calculate_confidence(response, task_type)
            
            logger.info(f"✅ Demo inference completed in {processing_time:.2f}s")
            
            return {
                "success": True,
                "error": None,
                "response": response,
                "parsed_response": parsed_response,
                "confidence": confidence,
                "processing_time": processing_time,
                "task_type": task_type
            }
            
        except Exception as e:
            processing_time = time.time() - start_time
            logger.error(f"❌ Demo inference failed: {e}")
            
            return {
                "success": False,
                "error": str(e),
                "response": "",
                "confidence": 0.0,
                "processing_time": processing_time
            }
    
    def generate_response(self, image: Image.Image, prompt: str, task_type: str) -> str:
        """Generate realistic responses based on task type"""
        width, height = image.size
        
        responses = {
            "findElement": f"I can see a mobile screen with dimensions {width}x{height}. There are several UI elements visible including buttons, text fields, and labels arranged in a typical mobile app layout.",
            
            "clickElement": f"On this {width}x{height} mobile screen, I can identify several clickable elements. There appears to be a primary action button in the center-bottom area, and navigation elements in the header region.",
            
            "extractText": "I can extract the following text from this mobile screen:\n- App title in the header\n- Button labels like 'Login', 'Cancel', 'Submit'\n- Placeholder text in input fields\n- Navigation menu items",
            
            "describeScreen": f"This appears to be a mobile application screen with dimensions {width}x{height}. The layout follows standard mobile UI patterns with a header section at the top, main content area in the middle, and action buttons towards the bottom. The design uses a clean, modern interface with clear visual hierarchy.",
            
            "findButton": "I can identify several button elements on this screen:\n1. A primary action button (likely 'Login' or 'Submit') in the main content area\n2. A secondary button (possibly 'Cancel') below the primary action\n3. Navigation buttons in the header or tab bar area",
            
            "findTextField": "I can locate text input fields on this screen:\n1. A username/email input field in the upper portion\n2. Possibly a password field below it\n3. The fields appear to have placeholder text and standard mobile input styling",
            
            "navigateToElement": f"To navigate to the requested element on this {width}x{height} screen, I would recommend tapping in the center-lower portion where the main action buttons are typically located.",
            
            "general": f"This is a mobile application screen with dimensions {width}x{height}. The interface appears well-designed with clear visual elements and follows standard mobile UI conventions."
        }
        
        base_response = responses.get(task_type, responses["general"])
        
        # Add some variation based on prompt
        if "login" in prompt.lower():
            base_response += " The screen appears to be a login or authentication interface."
        elif "button" in prompt.lower():
            base_response += " Multiple interactive button elements are visible."
        elif "text" in prompt.lower():
            base_response += " Various text elements and labels are present throughout the interface."
        
        return base_response
    
    def parse_response_for_ui_automation(self, response: str, task_type: str) -> Dict[str, Any]:
        """Parse response for UI automation tasks"""
        parsed = {
            "elements": [],
            "text_content": "",
            "description": response,
            "coordinates": [],
            "suggestions": []
        }
        
        # Generate realistic UI elements based on task type
        if task_type in ["findElement", "findButton", "clickElement"]:
            parsed["elements"] = [
                {
                    "type": "button",
                    "description": "Primary action button",
                    "confidence": 0.9
                },
                {
                    "type": "button", 
                    "description": "Secondary action button",
                    "confidence": 0.8
                }
            ]
        
        elif task_type == "findTextField":
            parsed["elements"] = [
                {
                    "type": "textField",
                    "description": "Username input field",
                    "confidence": 0.85
                },
                {
                    "type": "textField",
                    "description": "Password input field", 
                    "confidence": 0.8
                }
            ]
        
        elif task_type == "extractText":
            parsed["text_content"] = "App Title\nLogin\nEnter username\nPassword\nCancel\nSubmit"
        
        return parsed
    
    def calculate_confidence(self, response: str, task_type: str) -> float:
        """Calculate confidence score"""
        base_confidence = 0.85
        
        # Adjust based on response length and content
        if len(response) > 100:
            base_confidence += 0.05
        
        # Task-specific adjustments
        task_confidence_map = {
            "extractText": 0.9,
            "findButton": 0.88,
            "findTextField": 0.86,
            "describeScreen": 0.92,
            "general": 0.8
        }
        
        return min(task_confidence_map.get(task_type, base_confidence), 1.0)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get server statistics"""
        avg_inference_time = sum(self.inference_times) / len(self.inference_times) if self.inference_times else 0
        success_rate = (self.successful_requests / self.total_requests * 100) if self.total_requests > 0 else 100
        
        return {
            "model_loaded": self.model_loaded,
            "loading_progress": self.loading_progress,
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "success_rate": success_rate,
            "average_inference_time": avg_inference_time,
            "recent_inference_times": self.inference_times[-10:] if self.inference_times else []
        }

# Global server instance
server = Qwen2VLDemoServer()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "model_loaded": server.model_loaded,
        "loading_progress": server.loading_progress
    })

@app.route('/stats', methods=['GET'])
def get_stats():
    """Get server statistics"""
    return jsonify(server.get_stats())

@app.route('/analyze', methods=['POST'])
def analyze_image():
    """Main analysis endpoint"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({"success": False, "error": "No JSON data provided"}), 400
        
        # Decode base64 image
        if 'image' not in data:
            return jsonify({"success": False, "error": "No image data provided"}), 400
        
        try:
            image_data = base64.b64decode(data['image'])
            image = Image.open(io.BytesIO(image_data))
        except Exception as e:
            return jsonify({"success": False, "error": f"Invalid image data: {e}"}), 400
        
        # Get prompt and task type
        prompt = data.get('prompt', 'Describe this image')
        task_type = data.get('task_type', 'general')
        
        # Analyze image
        result = server.analyze_image(image, prompt, task_type)
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Analysis endpoint error: {e}")
        return jsonify({
            "success": False,
            "error": f"Server error: {e}",
            "response": "",
            "confidence": 0.0,
            "processing_time": 0.0
        }), 500

@app.route('/model_status', methods=['GET'])
def model_status():
    """Get model loading status"""
    return jsonify({
        "loaded": server.model_loaded,
        "progress": server.loading_progress,
        "stats": server.get_stats()
    })

def start_server(host='localhost', port=8888, debug=False):
    """Start the Flask server"""
    logger.info(f"🚀 Starting Qwen2-VL Demo Server on {host}:{port}")
    logger.info("📝 This is a demo server that simulates Qwen2-VL responses")
    
    app.run(host=host, port=port, debug=debug, threaded=True)

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Qwen2-VL Demo Server')
    parser.add_argument('--host', default='localhost', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8888, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    
    args = parser.parse_args()
    
    print("🚀 Qwen2-VL Demo Server")
    print("=" * 50)
    print("📝 This is a DEMO server that simulates model responses")
    print("🔗 For production, use qwen2vl_server.py with real model")
    print("=" * 50)
    print(f"📡 Server: http://{args.host}:{args.port}")
    print("🔗 Endpoints:")
    print(f"  • Health: http://{args.host}:{args.port}/health")
    print(f"  • Stats: http://{args.host}:{args.port}/stats")
    print(f"  • Analyze: http://{args.host}:{args.port}/analyze (POST)")
    print("=" * 50)
    
    start_server(args.host, args.port, args.debug)
