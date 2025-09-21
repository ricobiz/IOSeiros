
"""
Image utility functions
"""
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from typing import Tuple, Optional, Union
from pathlib import Path
from loguru import logger


def resize_image(image: Image.Image, size: Tuple[int, int], maintain_aspect: bool = True) -> Image.Image:
    """
    Resize image to specified size
    
    Args:
        image: PIL Image object
        size: Target size (width, height)
        maintain_aspect: Whether to maintain aspect ratio
        
    Returns:
        Resized image
    """
    try:
        if maintain_aspect:
            image.thumbnail(size, Image.Resampling.LANCZOS)
            return image
        else:
            return image.resize(size, Image.Resampling.LANCZOS)
            
    except Exception as e:
        logger.error(f"Failed to resize image: {e}")
        return image


def enhance_image(image: Image.Image, brightness: float = 1.0, contrast: float = 1.0, 
                 sharpness: float = 1.0, color: float = 1.0) -> Image.Image:
    """
    Enhance image with various adjustments
    
    Args:
        image: PIL Image object
        brightness: Brightness factor (1.0 = no change)
        contrast: Contrast factor (1.0 = no change)
        sharpness: Sharpness factor (1.0 = no change)
        color: Color saturation factor (1.0 = no change)
        
    Returns:
        Enhanced image
    """
    try:
        enhanced = image.copy()
        
        if brightness != 1.0:
            enhancer = ImageEnhance.Brightness(enhanced)
            enhanced = enhancer.enhance(brightness)
        
        if contrast != 1.0:
            enhancer = ImageEnhance.Contrast(enhanced)
            enhanced = enhancer.enhance(contrast)
        
        if sharpness != 1.0:
            enhancer = ImageEnhance.Sharpness(enhanced)
            enhanced = enhancer.enhance(sharpness)
        
        if color != 1.0:
            enhancer = ImageEnhance.Color(enhanced)
            enhanced = enhancer.enhance(color)
        
        return enhanced
        
    except Exception as e:
        logger.error(f"Failed to enhance image: {e}")
        return image


def crop_image(image: Image.Image, bbox: Tuple[int, int, int, int]) -> Image.Image:
    """
    Crop image to specified bounding box
    
    Args:
        image: PIL Image object
        bbox: Bounding box (left, top, right, bottom)
        
    Returns:
        Cropped image
    """
    try:
        return image.crop(bbox)
    except Exception as e:
        logger.error(f"Failed to crop image: {e}")
        return image


def rotate_image(image: Image.Image, angle: float, expand: bool = True) -> Image.Image:
    """
    Rotate image by specified angle
    
    Args:
        image: PIL Image object
        angle: Rotation angle in degrees
        expand: Whether to expand image to fit rotated content
        
    Returns:
        Rotated image
    """
    try:
        return image.rotate(angle, expand=expand, fillcolor='white')
    except Exception as e:
        logger.error(f"Failed to rotate image: {e}")
        return image


def flip_image(image: Image.Image, horizontal: bool = False, vertical: bool = False) -> Image.Image:
    """
    Flip image horizontally and/or vertically
    
    Args:
        image: PIL Image object
        horizontal: Whether to flip horizontally
        vertical: Whether to flip vertically
        
    Returns:
        Flipped image
    """
    try:
        result = image.copy()
        
        if horizontal:
            result = result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        
        if vertical:
            result = result.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        
        return result
        
    except Exception as e:
        logger.error(f"Failed to flip image: {e}")
        return image


def apply_filter(image: Image.Image, filter_type: str) -> Image.Image:
    """
    Apply filter to image
    
    Args:
        image: PIL Image object
        filter_type: Type of filter ('blur', 'sharpen', 'edge', 'emboss', 'smooth')
        
    Returns:
        Filtered image
    """
    try:
        filter_map = {
            'blur': ImageFilter.BLUR,
            'sharpen': ImageFilter.SHARPEN,
            'edge': ImageFilter.FIND_EDGES,
            'emboss': ImageFilter.EMBOSS,
            'smooth': ImageFilter.SMOOTH,
            'detail': ImageFilter.DETAIL,
            'edge_enhance': ImageFilter.EDGE_ENHANCE,
            'contour': ImageFilter.CONTOUR
        }
        
        if filter_type in filter_map:
            return image.filter(filter_map[filter_type])
        else:
            logger.warning(f"Unknown filter type: {filter_type}")
            return image
            
    except Exception as e:
        logger.error(f"Failed to apply filter: {e}")
        return image


def convert_image_format(image: Image.Image, format: str) -> Image.Image:
    """
    Convert image to specified format
    
    Args:
        image: PIL Image object
        format: Target format ('RGB', 'RGBA', 'L', 'P')
        
    Returns:
        Converted image
    """
    try:
        if image.mode != format:
            return image.convert(format)
        return image
    except Exception as e:
        logger.error(f"Failed to convert image format: {e}")
        return image


def create_thumbnail(image: Image.Image, size: Tuple[int, int] = (128, 128)) -> Image.Image:
    """
    Create thumbnail of image
    
    Args:
        image: PIL Image object
        size: Thumbnail size (width, height)
        
    Returns:
        Thumbnail image
    """
    try:
        thumbnail = image.copy()
        thumbnail.thumbnail(size, Image.Resampling.LANCZOS)
        return thumbnail
    except Exception as e:
        logger.error(f"Failed to create thumbnail: {e}")
        return image


def add_border(image: Image.Image, border_width: int = 5, border_color: str = 'black') -> Image.Image:
    """
    Add border to image
    
    Args:
        image: PIL Image object
        border_width: Width of border in pixels
        border_color: Color of border
        
    Returns:
        Image with border
    """
    try:
        from PIL import ImageOps
        return ImageOps.expand(image, border=border_width, fill=border_color)
    except Exception as e:
        logger.error(f"Failed to add border: {e}")
        return image


def paste_image(base_image: Image.Image, overlay_image: Image.Image, 
               position: Tuple[int, int], alpha: float = 1.0) -> Image.Image:
    """
    Paste one image onto another
    
    Args:
        base_image: Base image
        overlay_image: Image to paste
        position: Position to paste at (x, y)
        alpha: Transparency (0.0 = transparent, 1.0 = opaque)
        
    Returns:
        Combined image
    """
    try:
        result = base_image.copy()
        
        if alpha < 1.0:
            # Create alpha mask
            if overlay_image.mode != 'RGBA':
                overlay_image = overlay_image.convert('RGBA')
            
            # Adjust alpha
            overlay_array = np.array(overlay_image)
            overlay_array[:, :, 3] = (overlay_array[:, :, 3] * alpha).astype(np.uint8)
            overlay_image = Image.fromarray(overlay_array)
        
        if overlay_image.mode == 'RGBA':
            result.paste(overlay_image, position, overlay_image)
        else:
            result.paste(overlay_image, position)
        
        return result
        
    except Exception as e:
        logger.error(f"Failed to paste image: {e}")
        return base_image


def save_image(image: Image.Image, path: Union[str, Path], quality: int = 95, 
              optimize: bool = True) -> bool:
    """
    Save image to file
    
    Args:
        image: PIL Image object
        path: File path to save to
        quality: JPEG quality (1-100)
        optimize: Whether to optimize file size
        
    Returns:
        True if successful, False otherwise
    """
    try:
        file_path = Path(path)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Determine format from extension
        format = file_path.suffix.upper().lstrip('.')
        if format == 'JPG':
            format = 'JPEG'
        
        save_kwargs = {}
        if format == 'JPEG':
            save_kwargs.update({
                'quality': quality,
                'optimize': optimize
            })
            # Convert RGBA to RGB for JPEG
            if image.mode == 'RGBA':
                background = Image.new('RGB', image.size, (255, 255, 255))
                background.paste(image, mask=image.split()[-1])
                image = background
        elif format == 'PNG':
            save_kwargs['optimize'] = optimize
        
        image.save(file_path, format=format, **save_kwargs)
        logger.info(f"Image saved to: {path}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to save image to {path}: {e}")
        return False


def load_image(path: Union[str, Path]) -> Optional[Image.Image]:
    """
    Load image from file
    
    Args:
        path: File path to load from
        
    Returns:
        PIL Image object or None if failed
    """
    try:
        image = Image.open(path)
        logger.debug(f"Image loaded from: {path}")
        return image
    except Exception as e:
        logger.error(f"Failed to load image from {path}: {e}")
        return None


def get_image_info(image: Image.Image) -> dict:
    """
    Get information about image
    
    Args:
        image: PIL Image object
        
    Returns:
        Dictionary with image information
    """
    try:
        return {
            'size': image.size,
            'width': image.width,
            'height': image.height,
            'mode': image.mode,
            'format': image.format,
            'has_transparency': 'transparency' in image.info or image.mode in ('RGBA', 'LA'),
            'info': dict(image.info)
        }
    except Exception as e:
        logger.error(f"Failed to get image info: {e}")
        return {}
