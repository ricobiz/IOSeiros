
"""
Text Postprocessor for OCR results optimization
"""
import re
from typing import Dict, Any, List, Optional, Tuple
from loguru import logger


class TextPostprocessor:
    """
    Advanced text postprocessing for OCR results
    """
    
    def __init__(self):
        """Initialize text postprocessor"""
        # Common OCR error patterns and corrections
        self.common_corrections = {
            # Number/letter confusions
            r'\b0\b': 'O',  # Zero to O in words
            r'\bO\b': '0',  # O to zero in numbers context
            r'\b1\b': 'I',  # 1 to I in words
            r'\bI\b': '1',  # I to 1 in numbers context
            r'\b5\b': 'S',  # 5 to S in words
            r'\bS\b': '5',  # S to 5 in numbers context
            
            # Common character confusions
            r'rn': 'm',     # rn to m
            r'cl': 'd',     # cl to d
            r'li': 'h',     # li to h
            r'vv': 'w',     # vv to w
            
            # Punctuation fixes
            r'\s+([,.!?;:])': r'\1',  # Remove space before punctuation
            r'([,.!?;:])\s*([,.!?;:])': r'\1\2',  # Fix double punctuation
            
            # Common word corrections
            r'\btlie\b': 'the',
            r'\btliat\b': 'that',
            r'\bwlien\b': 'when',
            r'\bwliere\b': 'where',
            r'\bwliich\b': 'which',
            r'\bwitli\b': 'with',
        }
        
        # Language-specific patterns
        self.language_patterns = {
            'en': {
                'currency': r'[\$£€¥][\d,]+\.?\d*',
                'phone': r'[\+]?[\d\s\-\(\)]{10,}',
                'email': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
                'url': r'https?://[^\s]+',
                'date': r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}',
                'time': r'\d{1,2}:\d{2}(?::\d{2})?(?:\s?[AaPp][Mm])?'
            }
        }
        
        logger.info("TextPostprocessor initialized")
    
    async def process(self, ocr_result: Dict[str, Any], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Process OCR results with various improvements"""
        options = options or {}
        
        try:
            processed_result = ocr_result.copy()
            
            # Process main text
            if 'text' in processed_result:
                processed_result['text'] = await self._process_text(
                    processed_result['text'], options
                )
            
            # Process text blocks
            if 'text_blocks' in processed_result:
                processed_blocks = []
                for block in processed_result['text_blocks']:
                    processed_block = block.copy()
                    if 'text' in processed_block:
                        processed_block['text'] = await self._process_text(
                            processed_block['text'], options
                        )
                    processed_blocks.append(processed_block)
                processed_result['text_blocks'] = processed_blocks
            
            # Extract structured information
            if options.get('extract_entities', False):
                processed_result['entities'] = await self._extract_entities(
                    processed_result.get('text', ''), options
                )
            
            # Calculate quality metrics
            if options.get('calculate_metrics', False):
                processed_result['quality_metrics'] = await self._calculate_quality_metrics(
                    processed_result, options
                )
            
            logger.debug("Text postprocessing completed")
            return processed_result
            
        except Exception as e:
            logger.error(f"Text postprocessing failed: {e}")
            return ocr_result
    
    async def _process_text(self, text: str, options: Dict[str, Any]) -> str:
        """Process individual text string"""
        if not text:
            return text
        
        processed_text = text
        
        # Basic cleanup
        if options.get('basic_cleanup', True):
            processed_text = await self._basic_cleanup(processed_text)
        
        # Fix common OCR errors
        if options.get('fix_common_errors', True):
            processed_text = await self._fix_common_errors(processed_text)
        
        # Language-specific corrections
        language = options.get('language', 'en')
        if options.get('language_corrections', True):
            processed_text = await self._apply_language_corrections(processed_text, language)
        
        # Spell checking
        if options.get('spell_check', False):
            processed_text = await self._spell_check(processed_text, language)
        
        # Format text
        if options.get('format_text', True):
            processed_text = await self._format_text(processed_text, options)
        
        return processed_text
    
    async def _basic_cleanup(self, text: str) -> str:
        """Basic text cleanup"""
        # Remove excessive whitespace
        text = re.sub(r'\s+', ' ', text)
        
        # Remove leading/trailing whitespace
        text = text.strip()
        
        # Fix line breaks
        text = re.sub(r'\n\s*\n', '\n\n', text)  # Normalize paragraph breaks
        text = re.sub(r'(?<!\n)\n(?!\n)', ' ', text)  # Join broken lines
        
        # Remove non-printable characters except common ones
        text = re.sub(r'[^\x20-\x7E\n\t]', '', text)
        
        return text
    
    async def _fix_common_errors(self, text: str) -> str:
        """Fix common OCR errors"""
        for pattern, replacement in self.common_corrections.items():
            text = re.sub(pattern, replacement, text)
        
        return text
    
    async def _apply_language_corrections(self, text: str, language: str) -> str:
        """Apply language-specific corrections"""
        # This is a simplified implementation
        # In a real system, you'd use language-specific models
        
        if language == 'en':
            # Fix common English OCR errors
            corrections = {
                r'\btlie\b': 'the',
                r'\btliat\b': 'that',
                r'\bwlien\b': 'when',
                r'\bwliere\b': 'where',
                r'\bwliich\b': 'which',
                r'\bwitli\b': 'with',
                r'\bfrom\b': 'from',
                r'\bform\b': 'form',  # Context dependent
            }
            
            for pattern, replacement in corrections.items():
                text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
        
        return text
    
    async def _spell_check(self, text: str, language: str) -> str:
        """Basic spell checking (placeholder for more advanced implementation)"""
        # This would integrate with a spell checking library like pyspellchecker
        # For now, just return the text as-is
        return text
    
    async def _format_text(self, text: str, options: Dict[str, Any]) -> str:
        """Format text according to options"""
        # Capitalize sentences
        if options.get('capitalize_sentences', True):
            text = re.sub(r'(^|[.!?]\s+)([a-z])', lambda m: m.group(1) + m.group(2).upper(), text)
        
        # Fix spacing around punctuation
        if options.get('fix_punctuation_spacing', True):
            text = re.sub(r'\s+([,.!?;:])', r'\1', text)  # Remove space before
            text = re.sub(r'([,.!?;:])([^\s])', r'\1 \2', text)  # Add space after
        
        # Normalize quotes
        if options.get('normalize_quotes', True):
            text = re.sub(r'["""]', '"', text)
            text = re.sub(r'[''']', "'", text)
        
        return text
    
    async def _extract_entities(self, text: str, options: Dict[str, Any]) -> Dict[str, List[str]]:
        """Extract structured entities from text"""
        entities = {}
        language = options.get('language', 'en')
        
        if language in self.language_patterns:
            patterns = self.language_patterns[language]
            
            for entity_type, pattern in patterns.items():
                matches = re.findall(pattern, text)
                if matches:
                    entities[entity_type] = matches
        
        # Extract custom patterns if provided
        custom_patterns = options.get('custom_patterns', {})
        for entity_type, pattern in custom_patterns.items():
            matches = re.findall(pattern, text)
            if matches:
                entities[entity_type] = matches
        
        return entities
    
    async def _calculate_quality_metrics(self, ocr_result: Dict[str, Any], options: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate quality metrics for OCR results"""
        metrics = {}
        
        text = ocr_result.get('text', '')
        text_blocks = ocr_result.get('text_blocks', [])
        
        # Basic metrics
        metrics['character_count'] = len(text)
        metrics['word_count'] = len(text.split())
        metrics['line_count'] = len(text.split('\n'))
        metrics['block_count'] = len(text_blocks)
        
        # Confidence metrics
        if text_blocks:
            confidences = [block.get('confidence', 0) for block in text_blocks]
            metrics['avg_confidence'] = sum(confidences) / len(confidences)
            metrics['min_confidence'] = min(confidences)
            metrics['max_confidence'] = max(confidences)
        
        # Text quality indicators
        metrics['special_char_ratio'] = len(re.findall(r'[^\w\s]', text)) / len(text) if text else 0
        metrics['digit_ratio'] = len(re.findall(r'\d', text)) / len(text) if text else 0
        metrics['uppercase_ratio'] = len(re.findall(r'[A-Z]', text)) / len(text) if text else 0
        
        # Potential error indicators
        metrics['suspicious_patterns'] = len(re.findall(r'[^\w\s]{3,}', text))  # Long special char sequences
        metrics['broken_words'] = len(re.findall(r'\b\w{1,2}\b', text))  # Very short words
        
        return metrics
    
    async def merge_text_blocks(self, text_blocks: List[Dict[str, Any]], options: Optional[Dict[str, Any]] = None) -> str:
        """Merge text blocks into coherent text"""
        options = options or {}
        
        if not text_blocks:
            return ""
        
        # Sort blocks by position (top to bottom, left to right)
        sorted_blocks = sorted(text_blocks, key=lambda x: (
            x.get('bbox', [0, 0, 0, 0])[1],  # y coordinate
            x.get('bbox', [0, 0, 0, 0])[0]   # x coordinate
        ))
        
        merged_text = []
        last_y = None
        line_threshold = options.get('line_threshold', 10)
        
        for block in sorted_blocks:
            text = block.get('text', '').strip()
            if not text:
                continue
            
            bbox = block.get('bbox', [0, 0, 0, 0])
            current_y = bbox[1]
            
            # Check if this is a new line
            if last_y is not None and abs(current_y - last_y) > line_threshold:
                merged_text.append('\n')
            elif merged_text:  # Add space between words on same line
                merged_text.append(' ')
            
            merged_text.append(text)
            last_y = current_y
        
        return ''.join(merged_text)
    
    async def validate_text_quality(self, text: str, min_confidence: float = 0.5) -> Dict[str, Any]:
        """Validate text quality and suggest improvements"""
        validation = {
            'is_valid': True,
            'issues': [],
            'suggestions': []
        }
        
        # Check for empty or very short text
        if not text or len(text.strip()) < 3:
            validation['is_valid'] = False
            validation['issues'].append('Text too short or empty')
            validation['suggestions'].append('Check image quality and preprocessing')
        
        # Check for excessive special characters
        special_char_ratio = len(re.findall(r'[^\w\s]', text)) / len(text) if text else 0
        if special_char_ratio > 0.3:
            validation['issues'].append('High ratio of special characters')
            validation['suggestions'].append('Image may need better preprocessing')
        
        # Check for broken words
        broken_words = len(re.findall(r'\b\w{1,2}\b', text))
        if broken_words > len(text.split()) * 0.2:
            validation['issues'].append('Many broken words detected')
            validation['suggestions'].append('Consider using different OCR engine or preprocessing')
        
        # Check for suspicious patterns
        suspicious = len(re.findall(r'[^\w\s]{3,}', text))
        if suspicious > 5:
            validation['issues'].append('Suspicious character sequences detected')
            validation['suggestions'].append('Image quality may be poor')
        
        return validation
