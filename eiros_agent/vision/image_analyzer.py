
"""
Image Analyzer - advanced image analysis and processing
"""
import asyncio
from typing import Dict, Any, Optional, List, Tuple, Union
import numpy as np
from PIL import Image, ImageStat, ImageFilter, ImageEnhance
import cv2
from loguru import logger

from ..core.exceptions import ImageAnalysisError


class ImageAnalyzer:
    """
    Advanced image analysis system
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize image analyzer"""
        self.config = config
        self.object_detection = config.get("object_detection", True)
        self.text_detection = config.get("text_detection", True)
        self.similarity_threshold = config.get("similarity_threshold", 0.8)
        
        self.is_initialized = False
        logger.info("ImageAnalyzer initialized")
    
    async def initialize(self) -> None:
        """Initialize image analyzer"""
        try:
            logger.info("Initializing image analyzer...")
            
            # Test OpenCV availability
            try:
                cv2.getVersionString()
                self._opencv_available = True
            except Exception:
                logger.warning("OpenCV not available, some features will be limited")
                self._opencv_available = False
            
            self.is_initialized = True
            logger.info("Image analyzer initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize image analyzer: {e}")
            raise ImageAnalysisError(f"Image analyzer initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown image analyzer"""
        logger.info("Shutting down image analyzer...")
        self.is_initialized = False
        logger.info("Image analyzer shutdown complete")
    
    async def basic_analysis(self, image: Image.Image) -> Dict[str, Any]:
        """Perform basic image analysis"""
        if not self.is_initialized:
            raise ImageAnalysisError("Image analyzer not initialized")
        
        try:
            logger.debug("Performing basic image analysis")
            
            # Basic properties
            width, height = image.size
            mode = image.mode
            format_info = image.format or "Unknown"
            
            # File size estimation
            import io
            buffer = io.BytesIO()
            image.save(buffer, format='PNG')
            file_size = buffer.tell()
            
            # Color statistics
            stat = ImageStat.Stat(image)
            
            result = {
                "dimensions": {
                    "width": width,
                    "height": height,
                    "aspect_ratio": width / height if height > 0 else 0
                },
                "properties": {
                    "mode": mode,
                    "format": format_info,
                    "estimated_size_bytes": file_size,
                    "has_transparency": mode in ("RGBA", "LA") or "transparency" in image.info
                },
                "color_stats": {
                    "mean": stat.mean,
                    "median": stat.median,
                    "stddev": stat.stddev,
                    "extrema": stat.extrema
                }
            }
            
            # Additional analysis for RGB images
            if mode in ("RGB", "RGBA"):
                result["color_stats"]["dominant_colors"] = await self._get_dominant_colors(image)
                result["brightness"] = await self._calculate_brightness(image)
                result["contrast"] = await self._calculate_contrast(image)
            
            logger.debug("Basic analysis completed")
            return result
            
        except Exception as e:
            logger.error(f"Basic analysis failed: {e}")
            raise ImageAnalysisError(f"Basic analysis failed: {e}")
    
    async def color_analysis(self, image: Image.Image) -> Dict[str, Any]:
        """Perform detailed color analysis"""
        if not self.is_initialized:
            raise ImageAnalysisError("Image analyzer not initialized")
        
        try:
            logger.debug("Performing color analysis")
            
            # Convert to RGB if needed
            if image.mode != "RGB":
                image = image.convert("RGB")
            
            # Get image as numpy array
            img_array = np.array(image)
            
            # Color histogram
            hist_r = cv2.calcHist([img_array], [0], None, [256], [0, 256]) if self._opencv_available else None
            hist_g = cv2.calcHist([img_array], [1], None, [256], [0, 256]) if self._opencv_available else None
            hist_b = cv2.calcHist([img_array], [2], None, [256], [0, 256]) if self._opencv_available else None
            
            # Color space conversions
            hsv_image = cv2.cvtColor(img_array, cv2.COLOR_RGB2HSV) if self._opencv_available else None
            lab_image = cv2.cvtColor(img_array, cv2.COLOR_RGB2LAB) if self._opencv_available else None
            
            result = {
                "dominant_colors": await self._get_dominant_colors(image, num_colors=5),
                "color_distribution": await self._analyze_color_distribution(image),
                "temperature": await self._estimate_color_temperature(image),
                "saturation": await self._calculate_saturation(image),
                "colorfulness": await self._calculate_colorfulness(img_array)
            }
            
            if self._opencv_available and hsv_image is not None:
                result["hsv_stats"] = {
                    "hue_mean": float(np.mean(hsv_image[:, :, 0])),
                    "saturation_mean": float(np.mean(hsv_image[:, :, 1])),
                    "value_mean": float(np.mean(hsv_image[:, :, 2]))
                }
            
            logger.debug("Color analysis completed")
            return result
            
        except Exception as e:
            logger.error(f"Color analysis failed: {e}")
            raise ImageAnalysisError(f"Color analysis failed: {e}")
    
    async def edge_detection(self, image: Image.Image) -> Dict[str, Any]:
        """Perform edge detection analysis"""
        if not self.is_initialized:
            raise ImageAnalysisError("Image analyzer not initialized")
        
        if not self._opencv_available:
            logger.warning("OpenCV not available, edge detection limited")
            return {"error": "OpenCV not available"}
        
        try:
            logger.debug("Performing edge detection")
            
            # Convert to grayscale
            if image.mode != "L":
                gray_image = image.convert("L")
            else:
                gray_image = image
            
            gray_array = np.array(gray_image)
            
            # Canny edge detection
            edges_canny = cv2.Canny(gray_array, 50, 150)
            
            # Sobel edge detection
            sobel_x = cv2.Sobel(gray_array, cv2.CV_64F, 1, 0, ksize=3)
            sobel_y = cv2.Sobel(gray_array, cv2.CV_64F, 0, 1, ksize=3)
            sobel_combined = np.sqrt(sobel_x**2 + sobel_y**2)
            
            # Laplacian edge detection
            laplacian = cv2.Laplacian(gray_array, cv2.CV_64F)
            
            # Edge statistics
            edge_density = np.sum(edges_canny > 0) / edges_canny.size
            
            # Find contours
            contours, _ = cv2.findContours(edges_canny, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            result = {
                "edge_density": float(edge_density),
                "num_contours": len(contours),
                "edge_strength": {
                    "canny_mean": float(np.mean(edges_canny)),
                    "sobel_mean": float(np.mean(sobel_combined)),
                    "laplacian_mean": float(np.mean(np.abs(laplacian)))
                },
                "contour_stats": {
                    "total_contours": len(contours),
                    "large_contours": len([c for c in contours if cv2.contourArea(c) > 100]),
                    "avg_contour_area": float(np.mean([cv2.contourArea(c) for c in contours])) if contours else 0
                }
            }
            
            logger.debug("Edge detection completed")
            return result
            
        except Exception as e:
            logger.error(f"Edge detection failed: {e}")
            raise ImageAnalysisError(f"Edge detection failed: {e}")
    
    async def detect_text_regions(self, image: Image.Image) -> Dict[str, Any]:
        """Detect potential text regions in image"""
        if not self.is_initialized:
            raise ImageAnalysisError("Image analyzer not initialized")
        
        if not self._opencv_available:
            logger.warning("OpenCV not available, text region detection limited")
            return {"error": "OpenCV not available"}
        
        try:
            logger.debug("Detecting text regions")
            
            # Convert to grayscale
            if image.mode != "L":
                gray_image = image.convert("L")
            else:
                gray_image = image
            
            gray_array = np.array(gray_image)
            
            # Apply morphological operations to find text regions
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
            grad = cv2.morphologyEx(gray_array, cv2.MORPH_GRADIENT, kernel)
            
            # Binarize
            _, bw = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
            
            # Connect horizontally oriented regions
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 1))
            connected = cv2.morphologyEx(bw, cv2.MORPH_CLOSE, kernel)
            
            # Find contours
            contours, _ = cv2.findContours(connected.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            
            # Filter contours that might be text
            text_regions = []
            for contour in contours:
                area = cv2.contourArea(contour)
                if area > 100:  # Minimum area threshold
                    x, y, w, h = cv2.boundingRect(contour)
                    aspect_ratio = w / h if h > 0 else 0
                    
                    # Text regions typically have certain aspect ratios
                    if 0.1 < aspect_ratio < 10:
                        text_regions.append({
                            "bbox": [x, y, w, h],
                            "area": int(area),
                            "aspect_ratio": float(aspect_ratio),
                            "confidence": min(1.0, area / 1000)  # Simple confidence based on area
                        })
            
            result = {
                "num_text_regions": len(text_regions),
                "text_regions": text_regions,
                "text_density": len(text_regions) / (image.width * image.height) * 10000,  # per 10k pixels
                "analysis_method": "morphological"
            }
            
            logger.debug(f"Text region detection completed: {len(text_regions)} regions found")
            return result
            
        except Exception as e:
            logger.error(f"Text region detection failed: {e}")
            raise ImageAnalysisError(f"Text region detection failed: {e}")
    
    async def template_matching(self, image: Image.Image, template: Image.Image, threshold: float = 0.8) -> Optional[Dict[str, Any]]:
        """Find template image within the main image"""
        if not self.is_initialized:
            raise ImageAnalysisError("Image analyzer not initialized")
        
        if not self._opencv_available:
            logger.warning("OpenCV not available, template matching limited")
            return None
        
        try:
            logger.debug("Performing template matching")
            
            # Convert images to grayscale arrays
            main_gray = np.array(image.convert("L"))
            template_gray = np.array(template.convert("L"))
            
            # Perform template matching
            result = cv2.matchTemplate(main_gray, template_gray, cv2.TM_CCOEFF_NORMED)
            
            # Find best match
            min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(result)
            
            if max_val >= threshold:
                # Get template dimensions
                h, w = template_gray.shape
                
                match_result = {
                    "found": True,
                    "confidence": float(max_val),
                    "location": {
                        "x": int(max_loc[0]),
                        "y": int(max_loc[1]),
                        "width": w,
                        "height": h
                    },
                    "center": {
                        "x": int(max_loc[0] + w // 2),
                        "y": int(max_loc[1] + h // 2)
                    }
                }
                
                logger.debug(f"Template found with confidence {max_val:.3f}")
                return match_result
            else:
                logger.debug(f"Template not found (best match: {max_val:.3f})")
                return None
                
        except Exception as e:
            logger.error(f"Template matching failed: {e}")
            raise ImageAnalysisError(f"Template matching failed: {e}")
    
    async def calculate_similarity(self, image1: Image.Image, image2: Image.Image) -> float:
        """Calculate similarity between two images"""
        if not self.is_initialized:
            raise ImageAnalysisError("Image analyzer not initialized")
        
        try:
            logger.debug("Calculating image similarity")
            
            # Resize images to same size if different
            if image1.size != image2.size:
                # Resize to smaller dimensions
                target_size = (
                    min(image1.width, image2.width),
                    min(image1.height, image2.height)
                )
                image1 = image1.resize(target_size, Image.Resampling.LANCZOS)
                image2 = image2.resize(target_size, Image.Resampling.LANCZOS)
            
            # Convert to same mode
            if image1.mode != image2.mode:
                image1 = image1.convert("RGB")
                image2 = image2.convert("RGB")
            
            # Method 1: Pixel-wise comparison
            arr1 = np.array(image1)
            arr2 = np.array(image2)
            
            # Calculate MSE
            mse = np.mean((arr1 - arr2) ** 2)
            
            # Convert MSE to similarity (0-1 scale)
            max_mse = 255 ** 2  # Maximum possible MSE for 8-bit images
            similarity_mse = 1 - (mse / max_mse)
            
            # Method 2: Structural similarity (if OpenCV available)
            if self._opencv_available:
                # Convert to grayscale for SSIM
                gray1 = cv2.cvtColor(arr1, cv2.COLOR_RGB2GRAY) if len(arr1.shape) == 3 else arr1
                gray2 = cv2.cvtColor(arr2, cv2.COLOR_RGB2GRAY) if len(arr2.shape) == 3 else arr2
                
                # Calculate SSIM
                from skimage.metrics import structural_similarity
                ssim_score = structural_similarity(gray1, gray2)
                
                # Combine MSE and SSIM
                similarity = (similarity_mse + ssim_score) / 2
            else:
                similarity = similarity_mse
            
            logger.debug(f"Image similarity calculated: {similarity:.3f}")
            return float(similarity)
            
        except Exception as e:
            logger.error(f"Similarity calculation failed: {e}")
            raise ImageAnalysisError(f"Similarity calculation failed: {e}")
    
    # Helper methods
    async def _get_dominant_colors(self, image: Image.Image, num_colors: int = 3) -> List[Dict[str, Any]]:
        """Get dominant colors from image"""
        try:
            # Convert to RGB
            if image.mode != "RGB":
                image = image.convert("RGB")
            
            # Resize for faster processing
            image = image.resize((150, 150), Image.Resampling.LANCZOS)
            
            # Get pixel data
            pixels = list(image.getdata())
            
            # Use k-means clustering to find dominant colors
            if self._opencv_available:
                import sklearn.cluster
                
                # Convert to numpy array
                pixel_array = np.array(pixels)
                
                # Perform k-means clustering
                kmeans = sklearn.cluster.KMeans(n_clusters=num_colors, random_state=42, n_init=10)
                kmeans.fit(pixel_array)
                
                colors = []
                for i, color in enumerate(kmeans.cluster_centers_):
                    colors.append({
                        "rgb": [int(c) for c in color],
                        "hex": "#{:02x}{:02x}{:02x}".format(int(color[0]), int(color[1]), int(color[2])),
                        "percentage": float(np.sum(kmeans.labels_ == i) / len(kmeans.labels_) * 100)
                    })
                
                return sorted(colors, key=lambda x: x["percentage"], reverse=True)
            else:
                # Fallback: simple color counting
                from collections import Counter
                color_counts = Counter(pixels)
                most_common = color_counts.most_common(num_colors)
                
                total_pixels = len(pixels)
                colors = []
                for color, count in most_common:
                    colors.append({
                        "rgb": list(color),
                        "hex": "#{:02x}{:02x}{:02x}".format(*color),
                        "percentage": float(count / total_pixels * 100)
                    })
                
                return colors
                
        except Exception as e:
            logger.error(f"Dominant color extraction failed: {e}")
            return []
    
    async def _calculate_brightness(self, image: Image.Image) -> float:
        """Calculate average brightness of image"""
        try:
            # Convert to grayscale
            gray = image.convert("L")
            stat = ImageStat.Stat(gray)
            return stat.mean[0] / 255.0  # Normalize to 0-1
        except Exception:
            return 0.0
    
    async def _calculate_contrast(self, image: Image.Image) -> float:
        """Calculate contrast of image"""
        try:
            # Convert to grayscale
            gray = image.convert("L")
            stat = ImageStat.Stat(gray)
            return stat.stddev[0] / 255.0  # Normalize to 0-1
        except Exception:
            return 0.0
    
    async def _analyze_color_distribution(self, image: Image.Image) -> Dict[str, float]:
        """Analyze color distribution"""
        try:
            # Convert to RGB
            if image.mode != "RGB":
                image = image.convert("RGB")
            
            # Get color statistics
            stat = ImageStat.Stat(image)
            
            return {
                "red_mean": stat.mean[0] / 255.0,
                "green_mean": stat.mean[1] / 255.0,
                "blue_mean": stat.mean[2] / 255.0,
                "red_std": stat.stddev[0] / 255.0,
                "green_std": stat.stddev[1] / 255.0,
                "blue_std": stat.stddev[2] / 255.0
            }
        except Exception:
            return {}
    
    async def _estimate_color_temperature(self, image: Image.Image) -> str:
        """Estimate color temperature (warm/cool)"""
        try:
            # Convert to RGB
            if image.mode != "RGB":
                image = image.convert("RGB")
            
            stat = ImageStat.Stat(image)
            red_mean = stat.mean[0]
            blue_mean = stat.mean[2]
            
            # Simple heuristic
            if red_mean > blue_mean * 1.1:
                return "warm"
            elif blue_mean > red_mean * 1.1:
                return "cool"
            else:
                return "neutral"
        except Exception:
            return "unknown"
    
    async def _calculate_saturation(self, image: Image.Image) -> float:
        """Calculate average saturation"""
        try:
            # Convert to HSV
            if self._opencv_available:
                rgb_array = np.array(image.convert("RGB"))
                hsv_array = cv2.cvtColor(rgb_array, cv2.COLOR_RGB2HSV)
                return float(np.mean(hsv_array[:, :, 1]) / 255.0)
            else:
                # Fallback method
                return 0.5
        except Exception:
            return 0.0
    
    async def _calculate_colorfulness(self, image_array: np.ndarray) -> float:
        """Calculate colorfulness metric"""
        try:
            # Split channels
            R, G, B = image_array[:, :, 0], image_array[:, :, 1], image_array[:, :, 2]
            
            # Calculate rg and yb
            rg = R - G
            yb = 0.5 * (R + G) - B
            
            # Calculate standard deviations and means
            std_rg, mean_rg = np.std(rg), np.mean(rg)
            std_yb, mean_yb = np.std(yb), np.mean(yb)
            
            # Calculate colorfulness
            colorfulness = np.sqrt(std_rg**2 + std_yb**2) + 0.3 * np.sqrt(mean_rg**2 + mean_yb**2)
            
            return float(colorfulness)
        except Exception:
            return 0.0
    
    def get_status(self) -> Dict[str, Any]:
        """Get image analyzer status"""
        return {
            "initialized": self.is_initialized,
            "opencv_available": getattr(self, '_opencv_available', False),
            "object_detection": self.object_detection,
            "text_detection": self.text_detection,
            "similarity_threshold": self.similarity_threshold
        }
