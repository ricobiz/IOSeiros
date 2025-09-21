
"""
Object Detector - detects objects, faces, and other elements in images
"""
import asyncio
from typing import Dict, Any, Optional, List, Tuple, Union
import numpy as np
from PIL import Image
import cv2
from loguru import logger

from ..core.exceptions import VisionError


class ObjectDetector:
    """
    Advanced object detection system
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize object detector"""
        self.config = config
        self.confidence_threshold = config.get("confidence_threshold", 0.5)
        self.nms_threshold = config.get("nms_threshold", 0.4)
        
        # Model paths (would be configured in real implementation)
        self.yolo_weights = config.get("yolo_weights")
        self.yolo_config = config.get("yolo_config")
        self.yolo_classes = config.get("yolo_classes")
        
        self.face_cascade_path = config.get("face_cascade_path")
        
        # Runtime objects
        self.yolo_net = None
        self.face_cascade = None
        self.is_initialized = False
        
        logger.info("ObjectDetector initialized")
    
    async def initialize(self) -> None:
        """Initialize object detector"""
        try:
            logger.info("Initializing object detector...")
            
            # Test OpenCV availability
            try:
                cv2.getVersionString()
                self._opencv_available = True
            except Exception:
                logger.warning("OpenCV not available, object detection will be limited")
                self._opencv_available = False
                self.is_initialized = True
                return
            
            # Initialize YOLO if configured
            if self.yolo_weights and self.yolo_config:
                try:
                    self.yolo_net = cv2.dnn.readNet(self.yolo_weights, self.yolo_config)
                    logger.info("YOLO model loaded successfully")
                except Exception as e:
                    logger.warning(f"Failed to load YOLO model: {e}")
            
            # Initialize face cascade
            if self.face_cascade_path:
                try:
                    self.face_cascade = cv2.CascadeClassifier(self.face_cascade_path)
                    logger.info("Face cascade loaded successfully")
                except Exception as e:
                    logger.warning(f"Failed to load face cascade: {e}")
            else:
                # Try to load default face cascade
                try:
                    self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
                    logger.info("Default face cascade loaded")
                except Exception as e:
                    logger.warning(f"Failed to load default face cascade: {e}")
            
            self.is_initialized = True
            logger.info("Object detector initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize object detector: {e}")
            raise VisionError(f"Object detector initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown object detector"""
        logger.info("Shutting down object detector...")
        self.yolo_net = None
        self.face_cascade = None
        self.is_initialized = False
        logger.info("Object detector shutdown complete")
    
    async def detect_objects(self, image: Union[Image.Image, np.ndarray], object_types: Optional[List[str]] = None) -> Dict[str, Any]:
        """Detect objects in image"""
        if not self.is_initialized:
            raise VisionError("Object detector not initialized")
        
        if not self._opencv_available:
            return {"error": "OpenCV not available", "objects": []}
        
        try:
            logger.debug("Detecting objects in image")
            
            # Convert PIL Image to OpenCV format
            if isinstance(image, Image.Image):
                image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            else:
                image_cv = image
            
            objects = []
            
            # Use YOLO if available
            if self.yolo_net is not None:
                objects.extend(await self._detect_with_yolo(image_cv, object_types))
            
            # Fallback to simple detection methods
            if not objects:
                objects.extend(await self._detect_with_contours(image_cv))
            
            result = {
                "objects": objects,
                "num_objects": len(objects),
                "detection_method": "yolo" if self.yolo_net else "contours",
                "confidence_threshold": self.confidence_threshold
            }
            
            logger.debug(f"Object detection completed: {len(objects)} objects found")
            return result
            
        except Exception as e:
            logger.error(f"Object detection failed: {e}")
            raise VisionError(f"Object detection failed: {e}")
    
    async def detect_faces(self, image: Union[Image.Image, np.ndarray]) -> Dict[str, Any]:
        """Detect faces in image"""
        if not self.is_initialized:
            raise VisionError("Object detector not initialized")
        
        if not self._opencv_available or self.face_cascade is None:
            return {"error": "Face detection not available", "faces": []}
        
        try:
            logger.debug("Detecting faces in image")
            
            # Convert PIL Image to OpenCV format
            if isinstance(image, Image.Image):
                image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            else:
                image_cv = image
            
            # Convert to grayscale for face detection
            gray = cv2.cvtColor(image_cv, cv2.COLOR_BGR2GRAY)
            
            # Detect faces
            faces = self.face_cascade.detectMultiScale(
                gray,
                scaleFactor=1.1,
                minNeighbors=5,
                minSize=(30, 30)
            )
            
            face_list = []
            for (x, y, w, h) in faces:
                face_info = {
                    "bbox": [int(x), int(y), int(w), int(h)],
                    "center": [int(x + w//2), int(y + h//2)],
                    "area": int(w * h),
                    "confidence": 0.8  # Haar cascades don't provide confidence scores
                }
                face_list.append(face_info)
            
            result = {
                "faces": face_list,
                "num_faces": len(face_list),
                "detection_method": "haar_cascade"
            }
            
            logger.debug(f"Face detection completed: {len(face_list)} faces found")
            return result
            
        except Exception as e:
            logger.error(f"Face detection failed: {e}")
            raise VisionError(f"Face detection failed: {e}")
    
    async def detect_text_elements(self, image: Union[Image.Image, np.ndarray]) -> Dict[str, Any]:
        """Detect text elements (buttons, labels, etc.)"""
        if not self.is_initialized:
            raise VisionError("Object detector not initialized")
        
        if not self._opencv_available:
            return {"error": "OpenCV not available", "text_elements": []}
        
        try:
            logger.debug("Detecting text elements")
            
            # Convert PIL Image to OpenCV format
            if isinstance(image, Image.Image):
                image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            else:
                image_cv = image
            
            # Convert to grayscale
            gray = cv2.cvtColor(image_cv, cv2.COLOR_BGR2GRAY)
            
            # Use EAST text detector if available, otherwise use morphological operations
            text_elements = await self._detect_text_with_morphology(gray)
            
            result = {
                "text_elements": text_elements,
                "num_text_elements": len(text_elements),
                "detection_method": "morphological"
            }
            
            logger.debug(f"Text element detection completed: {len(text_elements)} elements found")
            return result
            
        except Exception as e:
            logger.error(f"Text element detection failed: {e}")
            raise VisionError(f"Text element detection failed: {e}")
    
    async def detect_ui_elements(self, image: Union[Image.Image, np.ndarray]) -> Dict[str, Any]:
        """Detect UI elements (buttons, forms, etc.)"""
        if not self.is_initialized:
            raise VisionError("Object detector not initialized")
        
        if not self._opencv_available:
            return {"error": "OpenCV not available", "ui_elements": []}
        
        try:
            logger.debug("Detecting UI elements")
            
            # Convert PIL Image to OpenCV format
            if isinstance(image, Image.Image):
                image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            else:
                image_cv = image
            
            ui_elements = []
            
            # Detect rectangular elements (buttons, forms)
            rectangles = await self._detect_rectangles(image_cv)
            ui_elements.extend(rectangles)
            
            # Detect circular elements (buttons, icons)
            circles = await self._detect_circles(image_cv)
            ui_elements.extend(circles)
            
            result = {
                "ui_elements": ui_elements,
                "num_ui_elements": len(ui_elements),
                "detection_method": "shape_based"
            }
            
            logger.debug(f"UI element detection completed: {len(ui_elements)} elements found")
            return result
            
        except Exception as e:
            logger.error(f"UI element detection failed: {e}")
            raise VisionError(f"UI element detection failed: {e}")
    
    # Private methods
    async def _detect_with_yolo(self, image_cv: np.ndarray, object_types: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Detect objects using YOLO"""
        try:
            height, width = image_cv.shape[:2]
            
            # Create blob from image
            blob = cv2.dnn.blobFromImage(image_cv, 1/255.0, (416, 416), swapRB=True, crop=False)
            
            # Set input to the network
            self.yolo_net.setInput(blob)
            
            # Run forward pass
            layer_names = self.yolo_net.getLayerNames()
            output_layers = [layer_names[i[0] - 1] for i in self.yolo_net.getUnconnectedOutLayers()]
            outputs = self.yolo_net.forward(output_layers)
            
            # Process outputs
            boxes = []
            confidences = []
            class_ids = []
            
            for output in outputs:
                for detection in output:
                    scores = detection[5:]
                    class_id = np.argmax(scores)
                    confidence = scores[class_id]
                    
                    if confidence > self.confidence_threshold:
                        # Object detected
                        center_x = int(detection[0] * width)
                        center_y = int(detection[1] * height)
                        w = int(detection[2] * width)
                        h = int(detection[3] * height)
                        
                        # Rectangle coordinates
                        x = int(center_x - w / 2)
                        y = int(center_y - h / 2)
                        
                        boxes.append([x, y, w, h])
                        confidences.append(float(confidence))
                        class_ids.append(class_id)
            
            # Apply non-maximum suppression
            indices = cv2.dnn.NMSBoxes(boxes, confidences, self.confidence_threshold, self.nms_threshold)
            
            objects = []
            if len(indices) > 0:
                for i in indices.flatten():
                    x, y, w, h = boxes[i]
                    objects.append({
                        "class_id": int(class_ids[i]),
                        "class_name": f"object_{class_ids[i]}",  # Would map to actual class names
                        "confidence": confidences[i],
                        "bbox": [x, y, w, h],
                        "center": [x + w//2, y + h//2],
                        "area": w * h
                    })
            
            return objects
            
        except Exception as e:
            logger.error(f"YOLO detection failed: {e}")
            return []
    
    async def _detect_with_contours(self, image_cv: np.ndarray) -> List[Dict[str, Any]]:
        """Simple object detection using contours"""
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(image_cv, cv2.COLOR_BGR2GRAY)
            
            # Apply threshold
            _, thresh = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
            
            # Find contours
            contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            objects = []
            for i, contour in enumerate(contours):
                area = cv2.contourArea(contour)
                if area > 500:  # Minimum area threshold
                    x, y, w, h = cv2.boundingRect(contour)
                    objects.append({
                        "class_id": -1,
                        "class_name": "unknown_object",
                        "confidence": 0.5,
                        "bbox": [int(x), int(y), int(w), int(h)],
                        "center": [int(x + w//2), int(y + h//2)],
                        "area": int(area)
                    })
            
            return objects
            
        except Exception as e:
            logger.error(f"Contour detection failed: {e}")
            return []
    
    async def _detect_text_with_morphology(self, gray_image: np.ndarray) -> List[Dict[str, Any]]:
        """Detect text regions using morphological operations"""
        try:
            # Apply morphological operations
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
            grad = cv2.morphologyEx(gray_image, cv2.MORPH_GRADIENT, kernel)
            
            # Binarize
            _, bw = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
            
            # Connect horizontally oriented regions
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 1))
            connected = cv2.morphologyEx(bw, cv2.MORPH_CLOSE, kernel)
            
            # Find contours
            contours, _ = cv2.findContours(connected.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            
            text_elements = []
            for contour in contours:
                area = cv2.contourArea(contour)
                if area > 100:
                    x, y, w, h = cv2.boundingRect(contour)
                    aspect_ratio = w / h if h > 0 else 0
                    
                    # Text regions typically have certain aspect ratios
                    if 0.1 < aspect_ratio < 10:
                        text_elements.append({
                            "type": "text_region",
                            "bbox": [int(x), int(y), int(w), int(h)],
                            "center": [int(x + w//2), int(y + h//2)],
                            "area": int(area),
                            "aspect_ratio": float(aspect_ratio),
                            "confidence": min(1.0, area / 1000)
                        })
            
            return text_elements
            
        except Exception as e:
            logger.error(f"Text detection with morphology failed: {e}")
            return []
    
    async def _detect_rectangles(self, image_cv: np.ndarray) -> List[Dict[str, Any]]:
        """Detect rectangular UI elements"""
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(image_cv, cv2.COLOR_BGR2GRAY)
            
            # Edge detection
            edges = cv2.Canny(gray, 50, 150, apertureSize=3)
            
            # Find contours
            contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            rectangles = []
            for contour in contours:
                # Approximate contour
                epsilon = 0.02 * cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, epsilon, True)
                
                # Check if it's roughly rectangular (4 corners)
                if len(approx) == 4:
                    area = cv2.contourArea(contour)
                    if area > 200:  # Minimum area
                        x, y, w, h = cv2.boundingRect(contour)
                        rectangles.append({
                            "type": "rectangle",
                            "subtype": "button" if 50 < w < 200 and 20 < h < 60 else "panel",
                            "bbox": [int(x), int(y), int(w), int(h)],
                            "center": [int(x + w//2), int(y + h//2)],
                            "area": int(area),
                            "confidence": 0.7
                        })
            
            return rectangles
            
        except Exception as e:
            logger.error(f"Rectangle detection failed: {e}")
            return []
    
    async def _detect_circles(self, image_cv: np.ndarray) -> List[Dict[str, Any]]:
        """Detect circular UI elements"""
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(image_cv, cv2.COLOR_BGR2GRAY)
            
            # Detect circles using HoughCircles
            circles = cv2.HoughCircles(
                gray,
                cv2.HOUGH_GRADIENT,
                dp=1,
                minDist=30,
                param1=50,
                param2=30,
                minRadius=10,
                maxRadius=100
            )
            
            circle_elements = []
            if circles is not None:
                circles = np.round(circles[0, :]).astype("int")
                
                for (x, y, r) in circles:
                    circle_elements.append({
                        "type": "circle",
                        "subtype": "button" if r < 30 else "icon",
                        "bbox": [int(x-r), int(y-r), int(2*r), int(2*r)],
                        "center": [int(x), int(y)],
                        "radius": int(r),
                        "area": int(np.pi * r * r),
                        "confidence": 0.6
                    })
            
            return circle_elements
            
        except Exception as e:
            logger.error(f"Circle detection failed: {e}")
            return []
    
    def get_status(self) -> Dict[str, Any]:
        """Get object detector status"""
        return {
            "initialized": self.is_initialized,
            "opencv_available": getattr(self, '_opencv_available', False),
            "yolo_available": self.yolo_net is not None,
            "face_cascade_available": self.face_cascade is not None,
            "confidence_threshold": self.confidence_threshold,
            "nms_threshold": self.nms_threshold
        }
