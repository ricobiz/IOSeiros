
"""
OCR Engine implementations
"""
import asyncio
from typing import Dict, Any, Optional, List, Union
from pathlib import Path
import numpy as np
from PIL import Image
from loguru import logger

from ..core.exceptions import OCREngineError


class BaseOCREngine:
    """Base class for OCR engines"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize base OCR engine"""
        self.config = config
        self.is_initialized = False
        self.engine_name = "base"
    
    async def initialize(self) -> None:
        """Initialize the OCR engine"""
        raise NotImplementedError
    
    async def shutdown(self) -> None:
        """Shutdown the OCR engine"""
        self.is_initialized = False
    
    async def extract_text(self, image: Union[np.ndarray, Image.Image], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Extract text from image"""
        raise NotImplementedError
    
    def get_status(self) -> Dict[str, Any]:
        """Get engine status"""
        return {
            "engine": self.engine_name,
            "initialized": self.is_initialized,
            "config": self.config
        }


class EasyOCREngine(BaseOCREngine):
    """EasyOCR engine implementation"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize EasyOCR engine"""
        super().__init__(config)
        self.engine_name = "easyocr"
        self.reader = None
        
        self.languages = config.get("languages", ["en"])
        self.gpu = config.get("gpu", True)
        self.confidence_threshold = config.get("confidence_threshold", 0.5)
    
    async def initialize(self) -> None:
        """Initialize EasyOCR"""
        try:
            import easyocr
            
            logger.info(f"Initializing EasyOCR with languages: {self.languages}")
            
            # Initialize in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            self.reader = await loop.run_in_executor(
                None, 
                lambda: easyocr.Reader(self.languages, gpu=self.gpu)
            )
            
            self.is_initialized = True
            logger.info("EasyOCR initialized successfully")
            
        except ImportError:
            raise OCREngineError("EasyOCR not installed. Install with: pip install easyocr")
        except Exception as e:
            logger.error(f"Failed to initialize EasyOCR: {e}")
            raise OCREngineError(f"EasyOCR initialization failed: {e}")
    
    async def extract_text(self, image: Union[np.ndarray, Image.Image], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Extract text using EasyOCR"""
        if not self.is_initialized:
            raise OCREngineError("EasyOCR not initialized")
        
        options = options or {}
        
        try:
            # Convert PIL Image to numpy array if needed
            if isinstance(image, Image.Image):
                image = np.array(image)
            
            # Run OCR in thread pool
            loop = asyncio.get_event_loop()
            results = await loop.run_in_executor(
                None,
                lambda: self.reader.readtext(
                    image,
                    detail=1,
                    paragraph=options.get("paragraph", False),
                    width_ths=options.get("width_ths", 0.7),
                    height_ths=options.get("height_ths", 0.7)
                )
            )
            
            # Process results
            text_blocks = []
            full_text = []
            total_confidence = 0
            
            for bbox, text, confidence in results:
                if confidence >= self.confidence_threshold:
                    text_blocks.append({
                        "text": text,
                        "confidence": confidence,
                        "bbox": bbox
                    })
                    full_text.append(text)
                    total_confidence += confidence
            
            avg_confidence = total_confidence / len(text_blocks) if text_blocks else 0
            
            return {
                "text": " ".join(full_text),
                "text_blocks": text_blocks,
                "confidence": avg_confidence,
                "engine": "easyocr",
                "language": self.languages
            }
            
        except Exception as e:
            logger.error(f"EasyOCR text extraction failed: {e}")
            raise OCREngineError(f"EasyOCR extraction failed: {e}")


class PaddleOCREngine(BaseOCREngine):
    """PaddleOCR engine implementation"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize PaddleOCR engine"""
        super().__init__(config)
        self.engine_name = "paddleocr"
        self.ocr = None
        
        self.languages = config.get("languages", ["en"])
        self.use_angle_cls = config.get("use_angle_cls", True)
        self.use_space_char = config.get("use_space_char", True)
    
    async def initialize(self) -> None:
        """Initialize PaddleOCR"""
        try:
            from paddleocr import PaddleOCR
            
            logger.info(f"Initializing PaddleOCR with languages: {self.languages}")
            
            # Initialize in thread pool
            loop = asyncio.get_event_loop()
            self.ocr = await loop.run_in_executor(
                None,
                lambda: PaddleOCR(
                    lang=self.languages[0] if self.languages else "en",
                    use_angle_cls=self.use_angle_cls,
                    use_space_char=self.use_space_char,
                    show_log=False
                )
            )
            
            self.is_initialized = True
            logger.info("PaddleOCR initialized successfully")
            
        except ImportError:
            raise OCREngineError("PaddleOCR not installed. Install with: pip install paddleocr")
        except Exception as e:
            logger.error(f"Failed to initialize PaddleOCR: {e}")
            raise OCREngineError(f"PaddleOCR initialization failed: {e}")
    
    async def extract_text(self, image: Union[np.ndarray, Image.Image], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Extract text using PaddleOCR"""
        if not self.is_initialized:
            raise OCREngineError("PaddleOCR not initialized")
        
        try:
            # Convert PIL Image to numpy array if needed
            if isinstance(image, Image.Image):
                image = np.array(image)
            
            # Run OCR in thread pool
            loop = asyncio.get_event_loop()
            results = await loop.run_in_executor(
                None,
                lambda: self.ocr.ocr(image, cls=self.use_angle_cls)
            )
            
            # Process results
            text_blocks = []
            full_text = []
            total_confidence = 0
            
            if results and results[0]:
                for line in results[0]:
                    bbox = line[0]
                    text_info = line[1]
                    text = text_info[0]
                    confidence = text_info[1]
                    
                    text_blocks.append({
                        "text": text,
                        "confidence": confidence,
                        "bbox": bbox
                    })
                    full_text.append(text)
                    total_confidence += confidence
            
            avg_confidence = total_confidence / len(text_blocks) if text_blocks else 0
            
            return {
                "text": " ".join(full_text),
                "text_blocks": text_blocks,
                "confidence": avg_confidence,
                "engine": "paddleocr",
                "language": self.languages
            }
            
        except Exception as e:
            logger.error(f"PaddleOCR text extraction failed: {e}")
            raise OCREngineError(f"PaddleOCR extraction failed: {e}")


class TesseractEngine(BaseOCREngine):
    """Tesseract OCR engine implementation"""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize Tesseract engine"""
        super().__init__(config)
        self.engine_name = "tesseract"
        
        self.languages = config.get("languages", "eng")
        self.config_string = config.get("config", "--oem 3 --psm 6")
    
    async def initialize(self) -> None:
        """Initialize Tesseract"""
        try:
            import pytesseract
            from PIL import Image
            
            # Test Tesseract installation
            test_image = Image.new('RGB', (100, 30), color='white')
            await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: pytesseract.image_to_string(test_image)
            )
            
            self.is_initialized = True
            logger.info("Tesseract initialized successfully")
            
        except ImportError:
            raise OCREngineError("pytesseract not installed. Install with: pip install pytesseract")
        except Exception as e:
            logger.error(f"Failed to initialize Tesseract: {e}")
            raise OCREngineError(f"Tesseract initialization failed: {e}")
    
    async def extract_text(self, image: Union[np.ndarray, Image.Image], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Extract text using Tesseract"""
        if not self.is_initialized:
            raise OCREngineError("Tesseract not initialized")
        
        try:
            import pytesseract
            
            # Convert numpy array to PIL Image if needed
            if isinstance(image, np.ndarray):
                image = Image.fromarray(image)
            
            # Run OCR in thread pool
            loop = asyncio.get_event_loop()
            
            # Get text
            text = await loop.run_in_executor(
                None,
                lambda: pytesseract.image_to_string(
                    image,
                    lang=self.languages,
                    config=self.config_string
                )
            )
            
            # Get detailed data
            data = await loop.run_in_executor(
                None,
                lambda: pytesseract.image_to_data(
                    image,
                    lang=self.languages,
                    config=self.config_string,
                    output_type=pytesseract.Output.DICT
                )
            )
            
            # Process detailed results
            text_blocks = []
            total_confidence = 0
            valid_blocks = 0
            
            for i in range(len(data['text'])):
                if int(data['conf'][i]) > 0:  # Filter out low confidence
                    text_blocks.append({
                        "text": data['text'][i],
                        "confidence": int(data['conf'][i]) / 100.0,
                        "bbox": [
                            data['left'][i],
                            data['top'][i],
                            data['left'][i] + data['width'][i],
                            data['top'][i] + data['height'][i]
                        ]
                    })
                    total_confidence += int(data['conf'][i])
                    valid_blocks += 1
            
            avg_confidence = (total_confidence / valid_blocks / 100.0) if valid_blocks > 0 else 0
            
            return {
                "text": text.strip(),
                "text_blocks": text_blocks,
                "confidence": avg_confidence,
                "engine": "tesseract",
                "language": self.languages
            }
            
        except Exception as e:
            logger.error(f"Tesseract text extraction failed: {e}")
            raise OCREngineError(f"Tesseract extraction failed: {e}")
