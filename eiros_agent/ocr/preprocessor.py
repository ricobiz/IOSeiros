
"""
Image Preprocessor for OCR optimization
"""
import asyncio
from typing import Dict, Any, Optional, Union, Tuple
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
import cv2
from loguru import logger

from ..core.exceptions import ImageProcessingError


class ImagePreprocessor:
    """
    Advanced image preprocessing for OCR optimization
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize image preprocessor"""
        self.config = config
        
        # Preprocessing options
        self.enhance_contrast = config.get("enhance_contrast", True)
        self.denoise = config.get("denoise", True)
        self.resize_factor = config.get("resize_factor", 2.0)
        self.binarize = config.get("binarize", False)
        self.deskew = config.get("deskew", False)
        self.remove_shadows = config.get("remove_shadows", False)
        
        logger.info("ImagePreprocessor initialized")
    
    async def preprocess(self, image: Union[str, Path, np.ndarray, Image.Image], options: Optional[Dict[str, Any]] = None) -> Image.Image:
        """Preprocess image for optimal OCR"""
        options = options or {}
        
        try:
            # Load image
            if isinstance(image, (str, Path)):
                image = Image.open(image)
            elif isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            elif not isinstance(image, Image.Image):
                raise ImageProcessingError(f"Unsupported image type: {type(image)}")
            
            # Convert to RGB if needed
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Apply preprocessing steps
            processed_image = image.copy()
            
            # Resize image
            if options.get("resize", self.resize_factor != 1.0):
                processed_image = await self._resize_image(processed_image, options.get("resize_factor", self.resize_factor))
            
            # Enhance contrast
            if options.get("enhance_contrast", self.enhance_contrast):
                processed_image = await self._enhance_contrast(processed_image, options)
            
            # Denoise
            if options.get("denoise", self.denoise):
                processed_image = await self._denoise_image(processed_image, options)
            
            # Remove shadows
            if options.get("remove_shadows", self.remove_shadows):
                processed_image = await self._remove_shadows(processed_image, options)
            
            # Deskew
            if options.get("deskew", self.deskew):
                processed_image = await self._deskew_image(processed_image, options)
            
            # Binarize
            if options.get("binarize", self.binarize):
                processed_image = await self._binarize_image(processed_image, options)
            
            logger.info("Image preprocessing completed")
            return processed_image
            
        except Exception as e:
            logger.error(f"Image preprocessing failed: {e}")
            raise ImageProcessingError(f"Preprocessing failed: {e}")
    
    async def _resize_image(self, image: Image.Image, factor: float) -> Image.Image:
        """Resize image by factor"""
        try:
            if factor == 1.0:
                return image
            
            new_width = int(image.width * factor)
            new_height = int(image.height * factor)
            
            # Use high-quality resampling
            resized = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
            
            logger.debug(f"Image resized from {image.size} to {resized.size}")
            return resized
            
        except Exception as e:
            logger.error(f"Image resize failed: {e}")
            return image
    
    async def _enhance_contrast(self, image: Image.Image, options: Dict[str, Any]) -> Image.Image:
        """Enhance image contrast"""
        try:
            # Auto contrast
            if options.get("auto_contrast", True):
                from PIL import ImageOps
                image = ImageOps.autocontrast(image)
            
            # Manual contrast enhancement
            contrast_factor = options.get("contrast_factor", 1.2)
            if contrast_factor != 1.0:
                enhancer = ImageEnhance.Contrast(image)
                image = enhancer.enhance(contrast_factor)
            
            # Brightness adjustment
            brightness_factor = options.get("brightness_factor", 1.0)
            if brightness_factor != 1.0:
                enhancer = ImageEnhance.Brightness(image)
                image = enhancer.enhance(brightness_factor)
            
            # Sharpness enhancement
            sharpness_factor = options.get("sharpness_factor", 1.1)
            if sharpness_factor != 1.0:
                enhancer = ImageEnhance.Sharpness(image)
                image = enhancer.enhance(sharpness_factor)
            
            logger.debug("Contrast enhancement applied")
            return image
            
        except Exception as e:
            logger.error(f"Contrast enhancement failed: {e}")
            return image
    
    async def _denoise_image(self, image: Image.Image, options: Dict[str, Any]) -> Image.Image:
        """Remove noise from image"""
        try:
            # Convert to OpenCV format
            cv_image = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            
            # Apply denoising
            denoising_method = options.get("denoising_method", "fastNlMeans")
            
            if denoising_method == "fastNlMeans":
                denoised = cv2.fastNlMeansDenoisingColored(
                    cv_image,
                    None,
                    h=options.get("h", 10),
                    hColor=options.get("hColor", 10),
                    templateWindowSize=options.get("templateWindowSize", 7),
                    searchWindowSize=options.get("searchWindowSize", 21)
                )
            elif denoising_method == "bilateral":
                denoised = cv2.bilateralFilter(
                    cv_image,
                    d=options.get("d", 9),
                    sigmaColor=options.get("sigmaColor", 75),
                    sigmaSpace=options.get("sigmaSpace", 75)
                )
            elif denoising_method == "gaussian":
                kernel_size = options.get("kernel_size", (5, 5))
                denoised = cv2.GaussianBlur(cv_image, kernel_size, 0)
            else:
                # Fallback to PIL filter
                return image.filter(ImageFilter.MedianFilter(size=3))
            
            # Convert back to PIL
            denoised_rgb = cv2.cvtColor(denoised, cv2.COLOR_BGR2RGB)
            result = Image.fromarray(denoised_rgb)
            
            logger.debug(f"Denoising applied: {denoising_method}")
            return result
            
        except Exception as e:
            logger.error(f"Denoising failed: {e}")
            # Fallback to simple PIL filter
            return image.filter(ImageFilter.MedianFilter(size=3))
    
    async def _remove_shadows(self, image: Image.Image, options: Dict[str, Any]) -> Image.Image:
        """Remove shadows from image"""
        try:
            # Convert to OpenCV format
            cv_image = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            
            # Convert to LAB color space
            lab = cv2.cvtColor(cv_image, cv2.COLOR_BGR2LAB)
            l, a, b = cv2.split(lab)
            
            # Apply CLAHE to L channel
            clahe = cv2.createCLAHE(
                clipLimit=options.get("clip_limit", 3.0),
                tileGridSize=options.get("tile_grid_size", (8, 8))
            )
            l = clahe.apply(l)
            
            # Merge channels
            lab = cv2.merge([l, a, b])
            
            # Convert back to RGB
            result_bgr = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)
            result_rgb = cv2.cvtColor(result_bgr, cv2.COLOR_BGR2RGB)
            result = Image.fromarray(result_rgb)
            
            logger.debug("Shadow removal applied")
            return result
            
        except Exception as e:
            logger.error(f"Shadow removal failed: {e}")
            return image
    
    async def _deskew_image(self, image: Image.Image, options: Dict[str, Any]) -> Image.Image:
        """Deskew image to correct rotation"""
        try:
            # Convert to OpenCV format
            cv_image = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2GRAY)
            
            # Find skew angle using Hough transform
            edges = cv2.Canny(cv_image, 50, 150, apertureSize=3)
            lines = cv2.HoughLines(edges, 1, np.pi/180, threshold=options.get("hough_threshold", 100))
            
            if lines is not None:
                angles = []
                for rho, theta in lines[:, 0]:
                    angle = theta * 180 / np.pi
                    if angle < 45:
                        angles.append(angle)
                    elif angle > 135:
                        angles.append(angle - 180)
                
                if angles:
                    # Calculate median angle
                    skew_angle = np.median(angles)
                    
                    # Only correct if angle is significant
                    if abs(skew_angle) > options.get("min_angle", 0.5):
                        # Rotate image
                        rotated = image.rotate(-skew_angle, expand=True, fillcolor='white')
                        logger.debug(f"Image deskewed by {skew_angle:.2f} degrees")
                        return rotated
            
            return image
            
        except Exception as e:
            logger.error(f"Deskewing failed: {e}")
            return image
    
    async def _binarize_image(self, image: Image.Image, options: Dict[str, Any]) -> Image.Image:
        """Convert image to binary (black and white)"""
        try:
            # Convert to grayscale first
            gray = image.convert('L')
            
            binarization_method = options.get("binarization_method", "otsu")
            
            if binarization_method == "otsu":
                # Use OpenCV for Otsu's thresholding
                cv_gray = np.array(gray)
                _, binary = cv2.threshold(cv_gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
                result = Image.fromarray(binary).convert('RGB')
                
            elif binarization_method == "adaptive":
                # Adaptive thresholding
                cv_gray = np.array(gray)
                binary = cv2.adaptiveThreshold(
                    cv_gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY,
                    blockSize=options.get("block_size", 11),
                    C=options.get("C", 2)
                )
                result = Image.fromarray(binary).convert('RGB')
                
            else:
                # Simple threshold
                threshold = options.get("threshold", 128)
                binary = gray.point(lambda x: 255 if x > threshold else 0)
                result = binary.convert('RGB')
            
            logger.debug(f"Binarization applied: {binarization_method}")
            return result
            
        except Exception as e:
            logger.error(f"Binarization failed: {e}")
            return image
    
    async def auto_crop_text_regions(self, image: Image.Image, options: Optional[Dict[str, Any]] = None) -> List[Image.Image]:
        """Automatically crop text regions from image"""
        options = options or {}
        
        try:
            # Convert to OpenCV format
            cv_image = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            gray = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)
            
            # Apply morphological operations to find text regions
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
            grad = cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, kernel)
            
            # Binarize
            _, bw = cv2.threshold(grad, 0.0, 255.0, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
            
            # Connect horizontally oriented regions
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 1))
            connected = cv2.morphologyEx(bw, cv2.MORPH_CLOSE, kernel)
            
            # Find contours
            contours, _ = cv2.findContours(connected.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            
            # Filter and crop regions
            text_regions = []
            min_area = options.get("min_area", 1000)
            
            for contour in contours:
                area = cv2.contourArea(contour)
                if area > min_area:
                    x, y, w, h = cv2.boundingRect(contour)
                    
                    # Add padding
                    padding = options.get("padding", 10)
                    x = max(0, x - padding)
                    y = max(0, y - padding)
                    w = min(image.width - x, w + 2 * padding)
                    h = min(image.height - y, h + 2 * padding)
                    
                    # Crop region
                    region = image.crop((x, y, x + w, y + h))
                    text_regions.append(region)
            
            logger.debug(f"Found {len(text_regions)} text regions")
            return text_regions
            
        except Exception as e:
            logger.error(f"Auto crop failed: {e}")
            return [image]
    
    async def enhance_for_ocr(self, image: Image.Image, text_type: str = "printed") -> Image.Image:
        """Apply OCR-specific enhancements based on text type"""
        try:
            if text_type == "handwritten":
                # Optimizations for handwritten text
                options = {
                    "enhance_contrast": True,
                    "contrast_factor": 1.3,
                    "denoise": True,
                    "denoising_method": "bilateral",
                    "binarize": True,
                    "binarization_method": "adaptive"
                }
            elif text_type == "low_quality":
                # Optimizations for low quality images
                options = {
                    "resize_factor": 2.0,
                    "enhance_contrast": True,
                    "auto_contrast": True,
                    "denoise": True,
                    "denoising_method": "fastNlMeans",
                    "remove_shadows": True,
                    "deskew": True
                }
            elif text_type == "screenshot":
                # Optimizations for screenshots
                options = {
                    "enhance_contrast": True,
                    "contrast_factor": 1.1,
                    "sharpness_factor": 1.2,
                    "denoise": False
                }
            else:
                # Default for printed text
                options = {
                    "enhance_contrast": True,
                    "denoise": True,
                    "deskew": True
                }
            
            return await self.preprocess(image, options)
            
        except Exception as e:
            logger.error(f"OCR enhancement failed: {e}")
            return image
