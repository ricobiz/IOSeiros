
"""
Advanced OCR Manager - orchestrates multiple OCR engines
"""
import asyncio
from typing import Dict, Any, Optional, List, Union
from pathlib import Path
import numpy as np
from PIL import Image
from loguru import logger

from ..core.exceptions import OCRError, OCREngineError
from .engines import EasyOCREngine, PaddleOCREngine, TesseractEngine
from .preprocessor import ImagePreprocessor
from .postprocessor import TextPostprocessor


class AdvancedOCRManager:
    """
    Advanced OCR system with multiple engines and preprocessing
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize OCR manager"""
        self.config = config
        self.engines = {}
        self.primary_engine = config.get("engines", {}).get("primary", "easyocr")
        self.fallback_engine = config.get("engines", {}).get("fallback", "paddleocr")
        
        # Initialize components
        self.preprocessor = ImagePreprocessor(config.get("preprocessing", {}))
        self.postprocessor = TextPostprocessor()
        
        self.is_initialized = False
        logger.info("AdvancedOCRManager initialized")
    
    async def initialize(self) -> None:
        """Initialize OCR engines"""
        try:
            logger.info("Initializing OCR engines...")
            
            # Initialize EasyOCR
            if "easyocr" in [self.primary_engine, self.fallback_engine]:
                easyocr_config = self.config.get("easyocr", {})
                self.engines["easyocr"] = EasyOCREngine(easyocr_config)
                await self.engines["easyocr"].initialize()
            
            # Initialize PaddleOCR
            if "paddleocr" in [self.primary_engine, self.fallback_engine]:
                paddleocr_config = self.config.get("paddleocr", {})
                self.engines["paddleocr"] = PaddleOCREngine(paddleocr_config)
                await self.engines["paddleocr"].initialize()
            
            # Initialize Tesseract
            if "tesseract" in [self.primary_engine, self.fallback_engine]:
                tesseract_config = self.config.get("tesseract", {})
                self.engines["tesseract"] = TesseractEngine(tesseract_config)
                await self.engines["tesseract"].initialize()
            
            self.is_initialized = True
            logger.info("OCR engines initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize OCR engines: {e}")
            raise OCRError(f"OCR initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown OCR engines"""
        logger.info("Shutting down OCR engines...")
        
        for engine_name, engine in self.engines.items():
            try:
                await engine.shutdown()
            except Exception as e:
                logger.error(f"Error shutting down {engine_name}: {e}")
        
        self.engines.clear()
        self.is_initialized = False
        logger.info("OCR engines shutdown complete")
    
    async def extract_text(self, image: Union[str, Path, np.ndarray, Image.Image], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Extract text from image using configured engines"""
        if not self.is_initialized:
            raise OCRError("OCR manager not initialized")
        
        options = options or {}
        
        try:
            logger.info("Starting text extraction")
            
            # Preprocess image
            processed_image = await self.preprocessor.preprocess(image)
            
            # Try primary engine first
            try:
                primary_result = await self._extract_with_engine(processed_image, self.primary_engine, options)
                
                # Post-process results
                processed_result = await self.postprocessor.process(primary_result)
                
                logger.info(f"Text extraction completed with {self.primary_engine}")
                return {
                    "engine": self.primary_engine,
                    "status": "success",
                    "result": processed_result,
                    "fallback_used": False
                }
                
            except Exception as e:
                logger.warning(f"Primary engine {self.primary_engine} failed: {e}")
                
                # Try fallback engine
                if self.fallback_engine and self.fallback_engine != self.primary_engine:
                    try:
                        fallback_result = await self._extract_with_engine(processed_image, self.fallback_engine, options)
                        processed_result = await self.postprocessor.process(fallback_result)
                        
                        logger.info(f"Text extraction completed with fallback {self.fallback_engine}")
                        return {
                            "engine": self.fallback_engine,
                            "status": "success",
                            "result": processed_result,
                            "fallback_used": True,
                            "primary_error": str(e)
                        }
                        
                    except Exception as fallback_error:
                        logger.error(f"Fallback engine {self.fallback_engine} also failed: {fallback_error}")
                        raise OCRError(f"Both engines failed. Primary: {e}, Fallback: {fallback_error}")
                else:
                    raise OCRError(f"Primary engine failed and no fallback configured: {e}")
            
        except Exception as e:
            logger.error(f"Text extraction failed: {e}")
            raise OCRError(f"Text extraction failed: {e}")
    
    async def extract_text_batch(self, images: List[Union[str, Path, np.ndarray, Image.Image]], options: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Extract text from multiple images"""
        if not self.is_initialized:
            raise OCRError("OCR manager not initialized")
        
        logger.info(f"Starting batch text extraction for {len(images)} images")
        
        # Process images concurrently
        tasks = [self.extract_text(image, options) for image in images]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Handle exceptions in results
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                processed_results.append({
                    "index": i,
                    "status": "error",
                    "error": str(result)
                })
            else:
                result["index"] = i
                processed_results.append(result)
        
        logger.info(f"Batch text extraction completed")
        return processed_results
    
    async def extract_structured_data(self, image: Union[str, Path, np.ndarray, Image.Image], structure_config: Dict[str, Any], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Extract structured data from image (forms, tables, etc.)"""
        if not self.is_initialized:
            raise OCRError("OCR manager not initialized")
        
        try:
            logger.info("Starting structured data extraction")
            
            # Extract raw text first
            ocr_result = await self.extract_text(image, options)
            
            # Apply structure extraction
            structured_data = await self._extract_structure(ocr_result["result"], structure_config)
            
            return {
                "engine": ocr_result["engine"],
                "status": "success",
                "raw_result": ocr_result["result"],
                "structured_data": structured_data,
                "structure_config": structure_config
            }
            
        except Exception as e:
            logger.error(f"Structured data extraction failed: {e}")
            raise OCRError(f"Structured data extraction failed: {e}")
    
    async def compare_engines(self, image: Union[str, Path, np.ndarray, Image.Image], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Compare results from all available engines"""
        if not self.is_initialized:
            raise OCRError("OCR manager not initialized")
        
        logger.info("Comparing OCR engines")
        
        # Preprocess image once
        processed_image = await self.preprocessor.preprocess(image)
        
        # Run all engines
        results = {}
        for engine_name in self.engines.keys():
            try:
                result = await self._extract_with_engine(processed_image, engine_name, options)
                processed_result = await self.postprocessor.process(result)
                results[engine_name] = {
                    "status": "success",
                    "result": processed_result
                }
            except Exception as e:
                results[engine_name] = {
                    "status": "error",
                    "error": str(e)
                }
        
        # Calculate comparison metrics
        comparison = await self._compare_results(results)
        
        return {
            "results": results,
            "comparison": comparison,
            "recommendation": comparison.get("best_engine")
        }
    
    async def _extract_with_engine(self, image: Union[np.ndarray, Image.Image], engine_name: str, options: Dict[str, Any]) -> Dict[str, Any]:
        """Extract text using specific engine"""
        if engine_name not in self.engines:
            raise OCREngineError(f"Engine {engine_name} not available")
        
        engine = self.engines[engine_name]
        return await engine.extract_text(image, options)
    
    async def _extract_structure(self, ocr_result: Dict[str, Any], structure_config: Dict[str, Any]) -> Dict[str, Any]:
        """Extract structured data from OCR results"""
        structure_type = structure_config.get("type", "generic")
        
        if structure_type == "form":
            return await self._extract_form_structure(ocr_result, structure_config)
        elif structure_type == "table":
            return await self._extract_table_structure(ocr_result, structure_config)
        elif structure_type == "receipt":
            return await self._extract_receipt_structure(ocr_result, structure_config)
        elif structure_type == "document":
            return await self._extract_document_structure(ocr_result, structure_config)
        else:
            return await self._extract_generic_structure(ocr_result, structure_config)
    
    async def _extract_form_structure(self, ocr_result: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Extract form structure from OCR results"""
        # Implementation for form structure extraction
        fields = config.get("fields", {})
        extracted_fields = {}
        
        text_blocks = ocr_result.get("text_blocks", [])
        
        for field_name, field_config in fields.items():
            pattern = field_config.get("pattern")
            location = field_config.get("location")
            
            # Search for field in text blocks
            for block in text_blocks:
                if pattern and pattern in block.get("text", ""):
                    extracted_fields[field_name] = {
                        "value": block["text"],
                        "confidence": block.get("confidence", 0),
                        "bbox": block.get("bbox")
                    }
                    break
        
        return {
            "type": "form",
            "fields": extracted_fields,
            "total_fields": len(fields),
            "extracted_fields": len(extracted_fields)
        }
    
    async def _extract_table_structure(self, ocr_result: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Extract table structure from OCR results"""
        # Implementation for table structure extraction
        text_blocks = ocr_result.get("text_blocks", [])
        
        # Sort blocks by position to identify rows and columns
        sorted_blocks = sorted(text_blocks, key=lambda x: (x.get("bbox", [0, 0, 0, 0])[1], x.get("bbox", [0, 0, 0, 0])[0]))
        
        # Group into rows based on y-coordinate similarity
        rows = []
        current_row = []
        last_y = None
        y_threshold = config.get("row_threshold", 10)
        
        for block in sorted_blocks:
            bbox = block.get("bbox", [0, 0, 0, 0])
            y = bbox[1]
            
            if last_y is None or abs(y - last_y) <= y_threshold:
                current_row.append(block)
            else:
                if current_row:
                    rows.append(sorted(current_row, key=lambda x: x.get("bbox", [0, 0, 0, 0])[0]))
                current_row = [block]
            
            last_y = y
        
        if current_row:
            rows.append(sorted(current_row, key=lambda x: x.get("bbox", [0, 0, 0, 0])[0]))
        
        # Convert to table format
        table_data = []
        for row in rows:
            row_data = [block.get("text", "") for block in row]
            table_data.append(row_data)
        
        return {
            "type": "table",
            "rows": len(table_data),
            "columns": max(len(row) for row in table_data) if table_data else 0,
            "data": table_data
        }
    
    async def _extract_receipt_structure(self, ocr_result: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Extract receipt structure from OCR results"""
        # Implementation for receipt structure extraction
        text = ocr_result.get("text", "")
        lines = text.split("\n")
        
        receipt_data = {
            "merchant": None,
            "date": None,
            "total": None,
            "items": [],
            "tax": None
        }
        
        # Simple pattern matching for receipt fields
        import re
        
        for line in lines:
            line = line.strip()
            
            # Look for total
            total_match = re.search(r'total[:\s]*\$?(\d+\.?\d*)', line, re.IGNORECASE)
            if total_match and not receipt_data["total"]:
                receipt_data["total"] = total_match.group(1)
            
            # Look for date
            date_match = re.search(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', line)
            if date_match and not receipt_data["date"]:
                receipt_data["date"] = date_match.group(1)
            
            # Look for tax
            tax_match = re.search(r'tax[:\s]*\$?(\d+\.?\d*)', line, re.IGNORECASE)
            if tax_match and not receipt_data["tax"]:
                receipt_data["tax"] = tax_match.group(1)
        
        return {
            "type": "receipt",
            "data": receipt_data
        }
    
    async def _extract_document_structure(self, ocr_result: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Extract document structure from OCR results"""
        # Implementation for document structure extraction
        text_blocks = ocr_result.get("text_blocks", [])
        
        # Identify headers, paragraphs, etc. based on font size and position
        structure = {
            "title": None,
            "headers": [],
            "paragraphs": [],
            "footer": None
        }
        
        # Sort blocks by position
        sorted_blocks = sorted(text_blocks, key=lambda x: (x.get("bbox", [0, 0, 0, 0])[1], x.get("bbox", [0, 0, 0, 0])[0]))
        
        for block in sorted_blocks:
            text = block.get("text", "").strip()
            if not text:
                continue
            
            # Simple heuristics for document structure
            if len(text) < 100 and text.isupper():
                structure["headers"].append(text)
            elif not structure["title"] and len(text) < 200:
                structure["title"] = text
            else:
                structure["paragraphs"].append(text)
        
        return {
            "type": "document",
            "structure": structure
        }
    
    async def _extract_generic_structure(self, ocr_result: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
        """Extract generic structure from OCR results"""
        return {
            "type": "generic",
            "text": ocr_result.get("text", ""),
            "blocks": ocr_result.get("text_blocks", []),
            "confidence": ocr_result.get("confidence", 0)
        }
    
    async def _compare_results(self, results: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
        """Compare results from different engines"""
        successful_results = {k: v for k, v in results.items() if v["status"] == "success"}
        
        if not successful_results:
            return {"best_engine": None, "reason": "No successful results"}
        
        # Simple comparison based on confidence and text length
        best_engine = None
        best_score = 0
        
        for engine_name, result in successful_results.items():
            ocr_result = result["result"]
            confidence = ocr_result.get("confidence", 0)
            text_length = len(ocr_result.get("text", ""))
            
            # Simple scoring: confidence * text_length_factor
            score = confidence * (1 + text_length / 1000)
            
            if score > best_score:
                best_score = score
                best_engine = engine_name
        
        return {
            "best_engine": best_engine,
            "best_score": best_score,
            "successful_engines": list(successful_results.keys()),
            "failed_engines": [k for k, v in results.items() if v["status"] == "error"]
        }
    
    def get_status(self) -> Dict[str, Any]:
        """Get current status"""
        return {
            "initialized": self.is_initialized,
            "primary_engine": self.primary_engine,
            "fallback_engine": self.fallback_engine,
            "available_engines": list(self.engines.keys()),
            "engine_status": {name: engine.get_status() for name, engine in self.engines.items()}
        }
