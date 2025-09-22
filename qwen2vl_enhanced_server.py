
#!/usr/bin/env python3
"""
Enhanced Qwen2-VL HTTP Server with MLX Support and Fallback
Provides REST API for vision-language model inference with automatic platform detection
"""

import asyncio
import base64
import io
import json
import logging
import time
import platform
from typing import Dict, Any, Optional

from flask import Flask, request, jsonify, Response
from PIL import Image
import threading
import queue

# Import our custom modules
from mlx_loader import model_loader, get_platform_info, PlatformDetector
from mock_fallback import mock_loader, MockQwen2VLProcessor

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global server state
server_state = {
    "model_loaded": False,
    "loading_progress": 0.0,
    "platform_info": None,
    "use_mlx": False,
    "use_mock": False,
    "model_type": "unknown",
    "loader": None,
    "processor": None
}

# Request statistics
stats = {
    "total_requests": 0,
    "successful_requests": 0,
    "failed_requests": 0,
    "inference_times": [],
    "start_time": time.time()
}

class EnhancedQwen2VLServer:
    def __init__(self):
        self.platform_info = get_platform_info()
        self.use_mlx = False
        self.use_mock = False
        self.loader = None
        self.processor = None
        self.model_loaded = False
        self.loading_progress = 0.0
        
        # Determine which backend to use
        self._initialize_backend()
        
    def _initialize_backend(self):
        """Initialize the appropriate backend based on platform capabilities"""
        logger.info("🔍 Detecting platform capabilities...")
        
        # Check MLX compatibility
        if self.platform_info["mlx_compatible"]:
            try:
                # Try to import MLX
                import mlx.core as mx
                import mlx_vlm
                self.use_mlx = True
                self.loader = model_loader
                logger.info("✅ MLX backend available - using hardware acceleration")
            except ImportError as e:
                logger.warning(f"⚠️ MLX import failed: {e}")
                self.use_mock = True
                self.processor = MockQwen2VLProcessor()
                logger.info("🔄 Falling back to mock processor")
        else:
            self.use_mock = True
            self.processor = MockQwen2VLProcessor()
            logger.info("📱 Non-Apple Silicon detected - using mock processor")
            
            # Log compatibility issues
            for issue in self.platform_info["compatibility_issues"]:
                logger.info(f"  • {issue}")
        
        # Update global server state
        server_state.update({
            "platform_info": self.platform_info,
            "use_mlx": self.use_mlx,
            "use_mock": self.use_mock,
            "model_type": "mlx" if self.use_mlx else "mock",
            "loader": self.loader,
            "processor": self.processor
        })
    
    async def load_model(self, model_name: str = "auto"):
        """Load the appropriate model based on backend"""
        try:
            logger.info(f"🔄 Loading model: {model_name}")
            self.loading_progress = 0.1
            server_state["loading_progress"] = 0.1
            
            if self.use_mlx and self.loader:
                # Use MLX backend
                logger.info("🚀 Loading MLX model...")
                self.loading_progress = 0.3
                server_state["loading_progress"] = 0.3
                
                success = await self.loader.load_model(model_name)
                if success:
                    self.loading_progress = 0.9
                    server_state["loading_progress"] = 0.9
                    
                    # Test the model
                    await self._test_model()
                    
                    self.model_loaded = True
                    self.loading_progress = 1.0
                    server_state.update({
                        "model_loaded": True,
                        "loading_progress": 1.0
                    })
                    logger.info("✅ MLX model loaded successfully!")
                else:
                    raise Exception("MLX model loading failed")
                    
            elif self.use_mock and self.processor:
                # Use mock backend
                logger.info("🧪 Initializing mock processor...")
                self.loading_progress = 0.5
                server_state["loading_progress"] = 0.5
                
                # Simulate loading time
                await asyncio.sleep(1.0)
                
                self.model_loaded = True
                self.loading_progress = 1.0
                server_state.update({
                    "model_loaded": True,
                    "loading_progress": 1.0
                })
                logger.info("✅ Mock processor ready!")
            else:
                raise Exception("No suitable backend available")
                
        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            self.model_loaded = False
            self.loading_progress = 0.0
            server_state.update({
                "model_loaded": False,
                "loading_progress": 0.0
            })
            raise
    
    async def _test_model(self):
        """Test the loaded model"""
        try:
            # Create a simple test image
            test_image = Image.new('RGB', (100, 100), color='white')
            test_prompt = "Describe this image briefly."
            
            if self.use_mlx and self.loader:
                response = self.loader.generate_response(test_image, test_prompt)
                logger.info(f"🧪 MLX model test successful: {response[:50]}...")
            elif self.use_mock and self.processor:
                result = self.processor.analyze_image(test_image, test_prompt, "general")
                logger.info(f"🧪 Mock processor test successful: {result['response'][:50]}...")
                
        except Exception as e:
            logger.warning(f"⚠️ Model test failed: {e}")
    
    def analyze_image(self, image: Image.Image, prompt: str, task_type: str = "general") -> Dict[str, Any]:
        """Analyze image using the appropriate backend"""
        if not self.model_loaded:
            return {
                "success": False,
                "error": "Model not loaded",
                "response": "",
                "confidence": 0.0,
                "processing_time": 0.0,
                "backend": "none"
            }
        
        start_time = time.time()
        stats["total_requests"] += 1
        
        try:
            if self.use_mlx and self.loader:
                # Use MLX backend
                enhanced_prompt = self._create_enhanced_prompt(prompt, task_type)
                response = self.loader.generate_response(image, enhanced_prompt)
                
                processing_time = time.time() - start_time
                stats["inference_times"].append(processing_time)
                stats["successful_requests"] += 1
                
                # Parse response for UI automation
                parsed_response = self._parse_response_for_ui_automation(response, task_type)
                confidence = self._calculate_confidence(response)
                
                logger.info(f"✅ MLX inference completed in {processing_time:.2f}s")
                
                return {
                    "success": True,
                    "error": None,
                    "response": response,
                    "parsed_response": parsed_response,
                    "confidence": confidence,
                    "processing_time": processing_time,
                    "task_type": task_type,
                    "backend": "mlx",
                    "model_info": self.loader.get_model_info()
                }
                
            elif self.use_mock and self.processor:
                # Use mock backend
                result = self.processor.analyze_image(image, prompt, task_type)
                
                processing_time = time.time() - start_time
                stats["inference_times"].append(processing_time)
                stats["successful_requests"] += 1
                
                logger.info(f"✅ Mock inference completed in {processing_time:.2f}s")
                
                result["backend"] = "mock"
                return result
            else:
                raise Exception("No backend available")
                
        except Exception as e:
            processing_time = time.time() - start_time
            stats["failed_requests"] += 1
            logger.error(f"❌ Inference failed: {e}")
            
            return {
                "success": False,
                "error": str(e),
                "response": "",
                "confidence": 0.0,
                "processing_time": processing_time,
                "backend": "error"
            }
    
    def _create_enhanced_prompt(self, base_prompt: str, task_type: str) -> str:
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
    
    def _parse_response_for_ui_automation(self, response: str, task_type: str) -> Dict[str, Any]:
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
            lines = response.split('\n')
            text_lines = [line.strip() for line in lines if line.strip() and not line.startswith('The')]
            parsed["text_content"] = '\n'.join(text_lines)
        
        # Extract element information for UI tasks
        if task_type in ["findElement", "clickElement", "findButton", "findTextField"]:
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
    
    def _calculate_confidence(self, response: str) -> float:
        """Calculate confidence score based on response quality"""
        if not response or len(response) < 10:
            return 0.1
        
        confidence = 0.7  # Base confidence
        
        if len(response) > 100:
            confidence += 0.1
        
        ui_terms = ["button", "text field", "label", "menu", "icon", "screen", "tap", "click"]
        term_count = sum(1 for term in ui_terms if term in response.lower())
        confidence += min(term_count * 0.05, 0.2)
        
        return min(confidence, 1.0)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get comprehensive server statistics"""
        uptime = time.time() - stats["start_time"]
        avg_inference_time = sum(stats["inference_times"]) / len(stats["inference_times"]) if stats["inference_times"] else 0
        success_rate = (stats["successful_requests"] / stats["total_requests"] * 100) if stats["total_requests"] > 0 else 0
        
        # Keep only last 100 inference times
        if len(stats["inference_times"]) > 100:
            stats["inference_times"] = stats["inference_times"][-100:]
        
        base_stats = {
            "model_loaded": self.model_loaded,
            "loading_progress": self.loading_progress,
            "backend": "mlx" if self.use_mlx else "mock",
            "platform_info": self.platform_info,
            "total_requests": stats["total_requests"],
            "successful_requests": stats["successful_requests"],
            "failed_requests": stats["failed_requests"],
            "success_rate": success_rate,
            "average_inference_time": avg_inference_time,
            "recent_inference_times": stats["inference_times"][-10:] if stats["inference_times"] else [],
            "uptime_seconds": uptime
        }
        
        # Add model-specific info
        if self.use_mlx and self.loader:
            model_info = self.loader.get_model_info()
            if model_info:
                base_stats["model_info"] = model_info
        elif self.use_mock and self.processor:
            base_stats["model_info"] = self.processor.get_model_info()
        
        return base_stats

# Global server instance
server = EnhancedQwen2VLServer()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "model_loaded": server.model_loaded,
        "loading_progress": server.loading_progress,
        "backend": "mlx" if server.use_mlx else "mock",
        "platform": server.platform_info["platform"],
        "mlx_compatible": server.platform_info["mlx_compatible"]
    })

@app.route('/platform', methods=['GET'])
def get_platform():
    """Get detailed platform information"""
    return jsonify(server.platform_info)

@app.route('/stats', methods=['GET'])
def get_stats():
    """Get comprehensive server statistics"""
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
            "processing_time": 0.0,
            "backend": "error"
        }), 500

@app.route('/load_model', methods=['POST'])
def load_model_endpoint():
    """Load model endpoint"""
    if server.model_loaded:
        return jsonify({"success": True, "message": "Model already loaded"})
    
    data = request.get_json() or {}
    model_name = data.get('model_name', 'auto')
    
    # Start model loading in background
    def load_model_background():
        asyncio.run(server.load_model(model_name))
    
    thread = threading.Thread(target=load_model_background)
    thread.daemon = True
    thread.start()
    
    return jsonify({
        "success": True, 
        "message": f"Model loading started: {model_name}",
        "backend": "mlx" if server.use_mlx else "mock"
    })

@app.route('/model_status', methods=['GET'])
def model_status():
    """Get model loading status"""
    return jsonify({
        "loaded": server.model_loaded,
        "progress": server.loading_progress,
        "backend": "mlx" if server.use_mlx else "mock",
        "platform_compatible": server.platform_info["mlx_compatible"],
        "stats": server.get_stats()
    })

@app.route('/models', methods=['GET'])
def list_models():
    """List available models"""
    if server.use_mlx and server.loader:
        available_models = server.loader.get_available_models()
        recommended = server.loader.recommend_model()
        
        return jsonify({
            "backend": "mlx",
            "available_models": {name: {
                "name": config.name,
                "size_gb": config.size_gb,
                "min_ram_gb": config.min_ram_gb,
                "quantization": config.quantization,
                "description": config.description
            } for name, config in available_models.items()},
            "recommended": recommended,
            "platform_info": server.platform_info
        })
    else:
        return jsonify({
            "backend": "mock",
            "available_models": {
                "mock": {
                    "name": "Mock Qwen2-VL",
                    "size_gb": 0.0,
                    "min_ram_gb": 1,
                    "quantization": "none",
                    "description": "Mock processor for testing and non-Apple Silicon systems"
                }
            },
            "recommended": "mock",
            "platform_info": server.platform_info
        })

def start_server(host='localhost', port=8888, debug=False):
    """Start the Flask server"""
    logger.info(f"🚀 Starting Enhanced Qwen2-VL server on {host}:{port}")
    logger.info(f"🔧 Backend: {'MLX' if server.use_mlx else 'Mock'}")
    logger.info(f"💻 Platform: {server.platform_info['platform']} ({server.platform_info['machine']})")
    
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
    
    parser = argparse.ArgumentParser(description='Enhanced Qwen2-VL HTTP Server with MLX Support')
    parser.add_argument('--host', default='localhost', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8888, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--model', default='auto', help='Model to load (auto, qwen2-vl-2b-4bit, etc.)')
    
    args = parser.parse_args()
    
    print("🚀 Enhanced Qwen2-VL HTTP Server with MLX Support")
    print("=" * 60)
    print(f"📡 Server: http://{args.host}:{args.port}")
    print(f"🔧 Backend: {'MLX' if server.use_mlx else 'Mock Fallback'}")
    print(f"💻 Platform: {server.platform_info['platform']} ({server.platform_info['machine']})")
    print(f"🧠 MLX Compatible: {server.platform_info['mlx_compatible']}")
    print("🔗 Endpoints:")
    print(f"  • Health: http://{args.host}:{args.port}/health")
    print(f"  • Platform: http://{args.host}:{args.port}/platform")
    print(f"  • Stats: http://{args.host}:{args.port}/stats")
    print(f"  • Models: http://{args.host}:{args.port}/models")
    print(f"  • Analyze: http://{args.host}:{args.port}/analyze (POST)")
    print(f"  • Load Model: http://{args.host}:{args.port}/load_model (POST)")
    print("=" * 60)
    
    if not server.platform_info["mlx_compatible"]:
        print("⚠️  MLX Compatibility Issues:")
        for issue in server.platform_info["compatibility_issues"]:
            print(f"   • {issue}")
        print("🔄 Using mock fallback processor for testing")
        print("=" * 60)
    
    start_server(args.host, args.port, args.debug)
