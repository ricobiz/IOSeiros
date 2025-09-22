
"""
Vision Manager - orchestrates vision and screen capture systems
"""
import asyncio
from typing import Dict, Any, Optional, List, Union, Tuple
from pathlib import Path
import numpy as np
from PIL import Image
from loguru import logger

from ..core.exceptions import VisionError, ScreenCaptureError
from .screen_capture import ScreenCaptureManager
from .image_analyzer import ImageAnalyzer
from .object_detector import ObjectDetector
from .qwen2vl_analyzer import Qwen2VLAnalyzer


class VisionManager:
    """
    Advanced vision system manager
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize vision manager"""
        self.config = config
        
        # Initialize components
        self.screen_capture = ScreenCaptureManager(config.get("screen_capture", {}))
        self.image_analyzer = ImageAnalyzer(config.get("analysis", {}))
        self.object_detector = ObjectDetector(config.get("object_detection", {}))
        self.qwen2vl_analyzer = Qwen2VLAnalyzer(config.get("qwen2vl", {}))
        
        self.is_initialized = False
        logger.info("VisionManager initialized")
    
    async def initialize(self) -> None:
        """Initialize vision system"""
        try:
            logger.info("Initializing vision system...")
            
            # Initialize components
            await self.screen_capture.initialize()
            await self.image_analyzer.initialize()
            await self.object_detector.initialize()
            await self.qwen2vl_analyzer.initialize()
            
            self.is_initialized = True
            logger.info("Vision system initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize vision system: {e}")
            raise VisionError(f"Vision system initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown vision system"""
        logger.info("Shutting down vision system...")
        
        try:
            await self.screen_capture.shutdown()
            await self.image_analyzer.shutdown()
            await self.object_detector.shutdown()
            await self.qwen2vl_analyzer.shutdown()
            
            self.is_initialized = False
            logger.info("Vision system shutdown complete")
            
        except Exception as e:
            logger.error(f"Error during vision system shutdown: {e}")
    
    async def capture_screen(self, region: Optional[Dict[str, int]] = None, save_path: Optional[str] = None) -> Image.Image:
        """Capture screen or region"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Capturing screen")
            
            screenshot = await self.screen_capture.capture_screen(region)
            
            if save_path:
                screenshot.save(save_path)
                logger.info(f"Screenshot saved to: {save_path}")
            
            return screenshot
            
        except Exception as e:
            logger.error(f"Screen capture failed: {e}")
            raise ScreenCaptureError(f"Screen capture failed: {e}")
    
    async def capture_window(self, window_title: str, save_path: Optional[str] = None) -> Optional[Image.Image]:
        """Capture specific window"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info(f"Capturing window: {window_title}")
            
            screenshot = await self.screen_capture.capture_window(window_title)
            
            if screenshot and save_path:
                screenshot.save(save_path)
                logger.info(f"Window screenshot saved to: {save_path}")
            
            return screenshot
            
        except Exception as e:
            logger.error(f"Window capture failed: {e}")
            raise ScreenCaptureError(f"Window capture failed: {e}")
    
    async def analyze_image(self, image: Union[str, Path, np.ndarray, Image.Image], analysis_types: Optional[List[str]] = None) -> Dict[str, Any]:
        """Analyze image with various techniques"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Analyzing image")
            
            # Load image if path provided
            if isinstance(image, (str, Path)):
                image = Image.open(image)
            elif isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            
            analysis_types = analysis_types or ["basic", "colors", "edges", "text_regions"]
            
            results = {}
            
            for analysis_type in analysis_types:
                if analysis_type == "basic":
                    results["basic"] = await self.image_analyzer.basic_analysis(image)
                elif analysis_type == "colors":
                    results["colors"] = await self.image_analyzer.color_analysis(image)
                elif analysis_type == "edges":
                    results["edges"] = await self.image_analyzer.edge_detection(image)
                elif analysis_type == "text_regions":
                    results["text_regions"] = await self.image_analyzer.detect_text_regions(image)
                elif analysis_type == "objects":
                    results["objects"] = await self.object_detector.detect_objects(image)
                elif analysis_type == "faces":
                    results["faces"] = await self.object_detector.detect_faces(image)
                elif analysis_type == "similarity":
                    # Requires reference image
                    pass
            
            logger.info("Image analysis completed")
            return results
            
        except Exception as e:
            logger.error(f"Image analysis failed: {e}")
            raise VisionError(f"Image analysis failed: {e}")
    
    async def detect_objects(self, image: Union[str, Path, np.ndarray, Image.Image], object_types: Optional[List[str]] = None) -> Dict[str, Any]:
        """Detect objects in image"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Detecting objects in image")
            
            # Load image if path provided
            if isinstance(image, (str, Path)):
                image = Image.open(image)
            elif isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            
            results = await self.object_detector.detect_objects(image, object_types)
            
            logger.info(f"Object detection completed: {len(results.get('objects', []))} objects found")
            return results
            
        except Exception as e:
            logger.error(f"Object detection failed: {e}")
            raise VisionError(f"Object detection failed: {e}")
    
    async def find_image_on_screen(self, template_image: Union[str, Path, Image.Image], threshold: float = 0.8, region: Optional[Dict[str, int]] = None) -> Optional[Dict[str, Any]]:
        """Find template image on screen"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Searching for image on screen")
            
            # Capture screen
            screenshot = await self.capture_screen(region)
            
            # Load template
            if isinstance(template_image, (str, Path)):
                template_image = Image.open(template_image)
            
            # Find template in screenshot
            result = await self.image_analyzer.template_matching(screenshot, template_image, threshold)
            
            if result:
                logger.info(f"Template found at: {result}")
            else:
                logger.info("Template not found on screen")
            
            return result
            
        except Exception as e:
            logger.error(f"Image search failed: {e}")
            raise VisionError(f"Image search failed: {e}")
    
    async def wait_for_image(self, template_image: Union[str, Path, Image.Image], timeout: float = 30.0, check_interval: float = 1.0, threshold: float = 0.8, region: Optional[Dict[str, int]] = None) -> Optional[Dict[str, Any]]:
        """Wait for image to appear on screen"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        logger.info(f"Waiting for image to appear (timeout: {timeout}s)")
        
        start_time = asyncio.get_event_loop().time()
        
        while True:
            try:
                result = await self.find_image_on_screen(template_image, threshold, region)
                if result:
                    logger.info("Image found!")
                    return result
                
                # Check timeout
                elapsed = asyncio.get_event_loop().time() - start_time
                if elapsed >= timeout:
                    logger.info("Timeout waiting for image")
                    return None
                
                # Wait before next check
                await asyncio.sleep(check_interval)
                
            except Exception as e:
                logger.error(f"Error while waiting for image: {e}")
                return None
    
    async def monitor_screen_changes(self, region: Optional[Dict[str, int]] = None, threshold: float = 0.1, callback: Optional[callable] = None) -> None:
        """Monitor screen for changes"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        logger.info("Starting screen change monitoring")
        
        try:
            previous_screenshot = await self.capture_screen(region)
            
            while True:
                await asyncio.sleep(1)  # Check every second
                
                current_screenshot = await self.capture_screen(region)
                
                # Calculate difference
                similarity = await self.image_analyzer.calculate_similarity(previous_screenshot, current_screenshot)
                
                if similarity < (1.0 - threshold):  # Change detected
                    change_info = {
                        "timestamp": asyncio.get_event_loop().time(),
                        "similarity": similarity,
                        "change_detected": True,
                        "region": region
                    }
                    
                    logger.info(f"Screen change detected: {similarity:.3f} similarity")
                    
                    if callback:
                        if asyncio.iscoroutinefunction(callback):
                            await callback(change_info)
                        else:
                            callback(change_info)
                
                previous_screenshot = current_screenshot
                
        except Exception as e:
            logger.error(f"Screen monitoring failed: {e}")
            raise VisionError(f"Screen monitoring failed: {e}")
    
    async def create_visual_automation_script(self, actions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Create and execute visual automation script"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        logger.info("Executing visual automation script")
        
        results = []
        
        try:
            for i, action in enumerate(actions):
                action_type = action.get("type")
                params = action.get("params", {})
                
                logger.info(f"Executing action {i+1}: {action_type}")
                
                if action_type == "capture_screen":
                    result = await self.capture_screen(
                        region=params.get("region"),
                        save_path=params.get("save_path")
                    )
                    results.append({"action": action_type, "result": "screenshot_captured"})
                
                elif action_type == "find_image":
                    template = params.get("template")
                    threshold = params.get("threshold", 0.8)
                    region = params.get("region")
                    
                    result = await self.find_image_on_screen(template, threshold, region)
                    results.append({"action": action_type, "result": result})
                
                elif action_type == "wait_for_image":
                    template = params.get("template")
                    timeout = params.get("timeout", 30.0)
                    threshold = params.get("threshold", 0.8)
                    region = params.get("region")
                    
                    result = await self.wait_for_image(template, timeout, 1.0, threshold, region)
                    results.append({"action": action_type, "result": result})
                
                elif action_type == "analyze_image":
                    image_path = params.get("image")
                    analysis_types = params.get("analysis_types")
                    
                    result = await self.analyze_image(image_path, analysis_types)
                    results.append({"action": action_type, "result": result})
                
                elif action_type == "detect_objects":
                    image_path = params.get("image")
                    object_types = params.get("object_types")
                    
                    result = await self.detect_objects(image_path, object_types)
                    results.append({"action": action_type, "result": result})
                
                else:
                    logger.warning(f"Unknown action type: {action_type}")
                    results.append({"action": action_type, "result": "unknown_action"})
                
                # Add delay if specified
                delay = action.get("delay", 0)
                if delay > 0:
                    await asyncio.sleep(delay)
            
            logger.info("Visual automation script completed")
            
            return {
                "status": "success",
                "actions_executed": len(actions),
                "results": results
            }
            
        except Exception as e:
            logger.error(f"Visual automation script failed: {e}")
            return {
                "status": "error",
                "error": str(e),
                "actions_executed": len(results),
                "results": results
            }
    
    async def get_screen_info(self) -> Dict[str, Any]:
        """Get screen information"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        return await self.screen_capture.get_screen_info()
    
    async def list_windows(self) -> List[Dict[str, Any]]:
        """List all available windows"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        return await self.screen_capture.list_windows()
    
    # Qwen2VL Integration Methods
    async def analyze_with_qwen2vl(self, image: Union[str, Path, np.ndarray, Image.Image], prompt: Optional[str] = None, analysis_type: str = "comprehensive") -> Dict[str, Any]:
        """Analyze image using Qwen2VL multimodal capabilities"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Analyzing image with Qwen2VL")
            
            # Load image if path provided
            if isinstance(image, (str, Path)):
                image = Image.open(image)
            elif isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            
            result = await self.qwen2vl_analyzer.analyze_image(image, prompt, analysis_type)
            
            logger.info("Qwen2VL analysis completed")
            return result
            
        except Exception as e:
            logger.error(f"Qwen2VL analysis failed: {e}")
            raise VisionError(f"Qwen2VL analysis failed: {e}")
    
    async def describe_screen_with_qwen2vl(self, region: Optional[Dict[str, int]] = None, detail_level: str = "detailed") -> Dict[str, Any]:
        """Capture screen and describe it using Qwen2VL"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Capturing and describing screen with Qwen2VL")
            
            # Capture screen
            screenshot = await self.capture_screen(region)
            
            # Analyze with Qwen2VL
            result = await self.qwen2vl_analyzer.describe_scene(screenshot, detail_level)
            
            logger.info("Screen description completed")
            return result
            
        except Exception as e:
            logger.error(f"Screen description failed: {e}")
            raise VisionError(f"Screen description failed: {e}")
    
    async def analyze_ui_with_qwen2vl(self, image: Union[str, Path, np.ndarray, Image.Image], ui_type: str = "general") -> Dict[str, Any]:
        """Analyze UI elements using Qwen2VL"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Analyzing UI with Qwen2VL")
            
            # Load image if path provided
            if isinstance(image, (str, Path)):
                image = Image.open(image)
            elif isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            
            result = await self.qwen2vl_analyzer.analyze_ui_elements(image, ui_type)
            
            logger.info("UI analysis completed")
            return result
            
        except Exception as e:
            logger.error(f"UI analysis failed: {e}")
            raise VisionError(f"UI analysis failed: {e}")
    
    async def extract_text_with_qwen2vl(self, image: Union[str, Path, np.ndarray, Image.Image], language: str = "auto") -> Dict[str, Any]:
        """Extract text using Qwen2VL"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Extracting text with Qwen2VL")
            
            # Load image if path provided
            if isinstance(image, (str, Path)):
                image = Image.open(image)
            elif isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            
            result = await self.qwen2vl_analyzer.extract_text(image, language)
            
            logger.info("Text extraction completed")
            return result
            
        except Exception as e:
            logger.error(f"Text extraction failed: {e}")
            raise VisionError(f"Text extraction failed: {e}")
    
    async def visual_reasoning_with_qwen2vl(self, image: Union[str, Path, np.ndarray, Image.Image], question: str) -> Dict[str, Any]:
        """Perform visual reasoning using Qwen2VL"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info("Performing visual reasoning with Qwen2VL")
            
            # Load image if path provided
            if isinstance(image, (str, Path)):
                image = Image.open(image)
            elif isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            
            result = await self.qwen2vl_analyzer.visual_reasoning(image, question)
            
            logger.info("Visual reasoning completed")
            return result
            
        except Exception as e:
            logger.error(f"Visual reasoning failed: {e}")
            raise VisionError(f"Visual reasoning failed: {e}")
    
    async def batch_analyze_with_qwen2vl(self, images: List[Union[str, Path, np.ndarray, Image.Image]], prompts: Optional[List[str]] = None, analysis_type: str = "comprehensive") -> List[Dict[str, Any]]:
        """Batch analyze multiple images with Qwen2VL"""
        if not self.is_initialized:
            raise VisionError("Vision system not initialized")
        
        try:
            logger.info(f"Batch analyzing {len(images)} images with Qwen2VL")
            
            # Process images
            processed_images = []
            for image in images:
                if isinstance(image, (str, Path)):
                    processed_images.append(Image.open(image))
                elif isinstance(image, np.ndarray):
                    processed_images.append(Image.fromarray(image))
                else:
                    processed_images.append(image)
            
            result = await self.qwen2vl_analyzer.batch_analyze(processed_images, prompts, analysis_type)
            
            logger.info("Batch analysis completed")
            return result
            
        except Exception as e:
            logger.error(f"Batch analysis failed: {e}")
            raise VisionError(f"Batch analysis failed: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get vision system status"""
        return {
            "initialized": self.is_initialized,
            "screen_capture": self.screen_capture.get_status(),
            "image_analyzer": self.image_analyzer.get_status(),
            "object_detector": self.object_detector.get_status(),
            "qwen2vl_analyzer": self.qwen2vl_analyzer.get_status()
        }
