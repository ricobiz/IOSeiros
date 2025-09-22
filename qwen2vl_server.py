#!/usr/bin/env python3
"""
Qwen2-VL-2B HTTP Server for iOS Integration
Provides REST API for vision-language model inference
"""

import asyncio
import base64
import io
import json
import logging
import time
from typing import Dict, Any, Optional

from flask import Flask, request, jsonify, Response
from PIL import Image
import threading
import queue

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global model variables
model = None
processor = None
model_loaded = False
loading_progress = 0.0

# Request queue for handling concurrent requests
request_queue = queue.Queue()
response_dict = {}

class Qwen2VLServer:
    def __init__(self):
        self.model = None
        self.processor = None
        self.model_loaded = False
        self.loading_progress = 0.0
        self.inference_times = []
        self.total_requests = 0
        self.successful_requests = 0
        
    async def load_model(self):
        """Load the Qwen2-VL-2B model"""
        try:
            logger.info("🔄 Loading Qwen2-VL-2B model...")
            self.loading_progress = 0.1
            
            # Import MLX VLM
            from mlx_vlm import load
            
            self.loading_progress = 0.3
            logger.info("📦 Downloading model from HuggingFace...")
            
            # Load the 4-bit quantized model for better performance
            model_path = "mlx-community/Qwen2-VL-2B-4bit"
            self.model, self.processor = load(model_path)
            
            self.loading_progress = 0.9
            logger.info("🧠 Model loaded successfully!")
            
            # Test the model with a simple prompt
            await self.test_model()
            
            self.loading_progress = 1.0
            self.model_loaded = True
            logger.info("✅ Qwen2-VL-2B ready for inference!")
            
        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            self.model_loaded = False
            raise
    
    async def test_model(self):
        """Test the model with a simple inference"""
        try:
            # Create a simple test image (white square)
            test_image = Image.new('RGB', (100, 100), color='white')
            test_prompt = "Describe this image briefly."
            
            from mlx_vlm import generate
            response = generate(self.model, self.processor, test_image, test_prompt, verbose=False)
            logger.info(f"🧪 Model test successful: {response[:50]}...")
            
        except Exception as e:
            logger.warning(f"⚠️ Model test failed: {e}")
    
    def analyze_image(self, image: Image.Image, prompt: str, task_type: str = "general") -> Dict[str, Any]:
        """Analyze image with Qwen2-VL model"""
        if not self.model_loaded:
            return {
                "success": False,
                "error": "Model not loaded",
                "response": "",
                "confidence": 0.0,
                "processing_time": 0.0
            }
        
        start_time = time.time()
        self.total_requests += 1
        
        try:
            from mlx_vlm import generate
            
            # Create task-specific prompt
            enhanced_prompt = self.create_enhanced_prompt(prompt, task_type)
            
            # Generate response
            response = generate(self.model, self.processor, image, enhanced_prompt, verbose=False)
            
            processing_time = time.time() - start_time
            self.inference_times.append(processing_time)
            self.successful_requests += 1
            
            # Keep only last 100 inference times
            if len(self.inference_times) > 100:
                self.inference_times = self.inference_times[-100:]
            
            # Parse response for UI automation tasks
            parsed_response = self.parse_response_for_ui_automation(response, task_type)
            
            logger.info(f"✅ Inference completed in {processing_time:.2f}s")
            
            return {
                "success": True,
                "error": None,
                "response": response,
                "parsed_response": parsed_response,
                "confidence": self.calculate_confidence(response),
                "processing_time": processing_time,
                "task_type": task_type
            }
            
        except Exception as e:
            processing_time = time.time() - start_time
            logger.error(f"❌ Inference failed: {e}")
            
            return {
                "success": False,
                "error": str(e),
                "response": "",
                "confidence": 0.0,
                "processing_time": processing_time
            }
    
    def create_enhanced_prompt(self, base_prompt: str, task_type: str) -> str:
        """Create enhanced prompt based on task type"""
        system_prompts = {
            "findElement": """You are a UI automation expert. Analyze this mobile screen and find UI elements.
Focus on identifying buttons, text fields, labels, and interactive elements.
Provide precise descriptions and approximate coordinates if possible.""",
            
            "clickElement": """You are a UI automation expert. Find clickable elements on this mobile screen.
Identify buttons, links, and interactive elements that can be tapped.
Describe their location using relative positions (top, bottom, left, right, center).""",
            
            "extractText": """You are an OCR expert. Extract all readable text from this mobile screen.
Organize the text by sections and maintain the reading order.
Include button labels, menu items, and any visible text content.""",
            
            "describeScreen": """You are a mobile UI analyst. Provide a comprehensive description of this screen.
Include layout structure, main elements, navigation options, and overall purpose.
Describe the visual hierarchy and user interaction possibilities.""",
            
            "findButton": """You are a UI automation expert focused on finding buttons.
Identify all button-like elements including: buttons, tabs, menu items, and clickable icons.
Describe their appearance, text labels, and approximate positions.""",
            
            "findTextField": """You are a UI automation expert focused on text input fields.
Identify all text input elements including: text fields, search boxes, and editable areas.
Describe their labels, placeholder text, and current content if visible.""",
            
            "general": """You are a vision-language AI assistant. Analyze this image and respond to the user's request accurately and helpfully."""
        }
        
        system_prompt = system_prompts.get(task_type, system_prompts["general"])
        
        return f"{system_prompt}\n\nUser request: {base_prompt}"
    
    def parse_response_for_ui_automation(self, response: str, task_type: str) -> Dict[str, Any]:
        """Parse model response for UI automation tasks"""
        parsed = {
            "elements": [],
            "text_content": "",
            "description": response,
            "coordinates": [],
            "suggestions": []
        }
        
        # Extract text content for OCR tasks
        if task_type == "extractText":
            # Simple text extraction - in production, this would be more sophisticated
            lines = response.split('\n')
            text_lines = [line.strip() for line in lines if line.strip() and not line.startswith('The')]
            parsed["text_content"] = '\n'.join(text_lines)
        
        # Extract element information for UI tasks
        if task_type in ["findElement", "clickElement", "findButton", "findTextField"]:
            # Simple parsing - in production, this would use more sophisticated NLP
            if "button" in response.lower():
                parsed["elements"].append({
                    "type": "button",
                    "description": "Button element found",
                    "confidence": 0.8
                })
            
            if "text field" in response.lower() or "input" in response.lower():
                parsed["elements"].append({
                    "type": "textField",
                    "description": "Text input field found",
                    "confidence": 0.8
                })
        
        return parsed
    
    def calculate_confidence(self, response: str) -> float:
        """Calculate confidence score based on response quality"""
        if not response or len(response) < 10:
            return 0.1
        
        # Simple heuristic - in production, this would be more sophisticated
        confidence = 0.7  # Base confidence
        
        # Increase confidence for detailed responses
        if len(response) > 100:
            confidence += 0.1
        
        # Increase confidence for specific UI terms
        ui_terms = ["button", "text field", "label", "menu", "icon", "screen", "tap", "click"]
        term_count = sum(1 for term in ui_terms if term in response.lower())
        confidence += min(term_count * 0.05, 0.2)
        
        return min(confidence, 1.0)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get server statistics"""
        avg_inference_time = sum(self.inference_times) / len(self.inference_times) if self.inference_times else 0
        success_rate = (self.successful_requests / self.total_requests * 100) if self.total_requests > 0 else 0
        
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
server = Qwen2VLServer()

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

@app.route('/load_model', methods=['POST'])
def load_model_endpoint():
    """Load model endpoint"""
    if server.model_loaded:
        return jsonify({"success": True, "message": "Model already loaded"})
    
    # Start model loading in background
    def load_model_background():
        asyncio.run(server.load_model())
    
    thread = threading.Thread(target=load_model_background)
    thread.daemon = True
    thread.start()
    
    return jsonify({"success": True, "message": "Model loading started"})

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
    logger.info(f"🚀 Starting Qwen2-VL server on {host}:{port}")
    
    # Load model on startup
    def load_model_on_startup():
        time.sleep(1)  # Give server time to start
        asyncio.run(server.load_model())
    
    thread = threading.Thread(target=load_model_on_startup)
    thread.daemon = True
    thread.start()
    
    app.run(host=host, port=port, debug=debug, threaded=True)

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Qwen2-VL-2B HTTP Server')
    parser.add_argument('--host', default='localhost', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8888, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    
    args = parser.parse_args()
    
    print("🚀 Qwen2-VL-2B HTTP Server")
    print("=" * 50)
    print(f"📡 Server: http://{args.host}:{args.port}")
    print("🔗 Endpoints:")
    print(f"  • Health: http://{args.host}:{args.port}/health")
    print(f"  • Stats: http://{args.host}:{args.port}/stats")
    print(f"  • Analyze: http://{args.host}:{args.port}/analyze (POST)")
    print(f"  • Load Model: http://{args.host}:{args.port}/load_model (POST)")
    print("=" * 50)
    
    start_server(args.host, args.port, args.debug)
