
"""
File utility functions
"""
import os
import shutil
import hashlib
from pathlib import Path
from typing import Optional, List, Union
from loguru import logger


def ensure_directory(path: Union[str, Path]) -> Path:
    """
    Ensure directory exists, create if it doesn't
    
    Args:
        path: Directory path
        
    Returns:
        Path object
    """
    dir_path = Path(path)
    dir_path.mkdir(parents=True, exist_ok=True)
    return dir_path


def safe_filename(filename: str, replacement: str = "_") -> str:
    """
    Create a safe filename by replacing invalid characters
    
    Args:
        filename: Original filename
        replacement: Character to replace invalid characters with
        
    Returns:
        Safe filename
    """
    # Characters that are invalid in filenames
    invalid_chars = '<>:"/\\|?*'
    
    safe_name = filename
    for char in invalid_chars:
        safe_name = safe_name.replace(char, replacement)
    
    # Remove leading/trailing dots and spaces
    safe_name = safe_name.strip('. ')
    
    # Ensure filename is not empty
    if not safe_name:
        safe_name = "unnamed_file"
    
    return safe_name


def get_file_hash(file_path: Union[str, Path], algorithm: str = "md5") -> Optional[str]:
    """
    Calculate hash of a file
    
    Args:
        file_path: Path to file
        algorithm: Hash algorithm (md5, sha1, sha256)
        
    Returns:
        File hash or None if error
    """
    try:
        hash_obj = hashlib.new(algorithm)
        
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_obj.update(chunk)
        
        return hash_obj.hexdigest()
        
    except Exception as e:
        logger.error(f"Failed to calculate hash for {file_path}: {e}")
        return None


def copy_file(src: Union[str, Path], dst: Union[str, Path], overwrite: bool = False) -> bool:
    """
    Copy file from source to destination
    
    Args:
        src: Source file path
        dst: Destination file path
        overwrite: Whether to overwrite existing file
        
    Returns:
        True if successful, False otherwise
    """
    try:
        src_path = Path(src)
        dst_path = Path(dst)
        
        if not src_path.exists():
            logger.error(f"Source file does not exist: {src}")
            return False
        
        if dst_path.exists() and not overwrite:
            logger.warning(f"Destination file exists and overwrite=False: {dst}")
            return False
        
        # Ensure destination directory exists
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        
        shutil.copy2(src_path, dst_path)
        logger.info(f"File copied: {src} -> {dst}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to copy file {src} -> {dst}: {e}")
        return False


def move_file(src: Union[str, Path], dst: Union[str, Path], overwrite: bool = False) -> bool:
    """
    Move file from source to destination
    
    Args:
        src: Source file path
        dst: Destination file path
        overwrite: Whether to overwrite existing file
        
    Returns:
        True if successful, False otherwise
    """
    try:
        src_path = Path(src)
        dst_path = Path(dst)
        
        if not src_path.exists():
            logger.error(f"Source file does not exist: {src}")
            return False
        
        if dst_path.exists() and not overwrite:
            logger.warning(f"Destination file exists and overwrite=False: {dst}")
            return False
        
        # Ensure destination directory exists
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        
        shutil.move(str(src_path), str(dst_path))
        logger.info(f"File moved: {src} -> {dst}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to move file {src} -> {dst}: {e}")
        return False


def delete_file(file_path: Union[str, Path]) -> bool:
    """
    Delete a file
    
    Args:
        file_path: Path to file to delete
        
    Returns:
        True if successful, False otherwise
    """
    try:
        path = Path(file_path)
        
        if path.exists():
            if path.is_file():
                path.unlink()
                logger.info(f"File deleted: {file_path}")
            else:
                logger.warning(f"Path is not a file: {file_path}")
                return False
        else:
            logger.warning(f"File does not exist: {file_path}")
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to delete file {file_path}: {e}")
        return False


def list_files(directory: Union[str, Path], pattern: str = "*", recursive: bool = False) -> List[Path]:
    """
    List files in directory
    
    Args:
        directory: Directory to search
        pattern: File pattern (glob style)
        recursive: Whether to search recursively
        
    Returns:
        List of file paths
    """
    try:
        dir_path = Path(directory)
        
        if not dir_path.exists():
            logger.warning(f"Directory does not exist: {directory}")
            return []
        
        if recursive:
            files = list(dir_path.rglob(pattern))
        else:
            files = list(dir_path.glob(pattern))
        
        # Filter to only files (not directories)
        files = [f for f in files if f.is_file()]
        
        return files
        
    except Exception as e:
        logger.error(f"Failed to list files in {directory}: {e}")
        return []


def get_file_size(file_path: Union[str, Path]) -> Optional[int]:
    """
    Get file size in bytes
    
    Args:
        file_path: Path to file
        
    Returns:
        File size in bytes or None if error
    """
    try:
        return Path(file_path).stat().st_size
    except Exception as e:
        logger.error(f"Failed to get file size for {file_path}: {e}")
        return None


def format_file_size(size_bytes: int) -> str:
    """
    Format file size in human readable format
    
    Args:
        size_bytes: Size in bytes
        
    Returns:
        Formatted size string
    """
    if size_bytes == 0:
        return "0 B"
    
    size_names = ["B", "KB", "MB", "GB", "TB"]
    i = 0
    
    while size_bytes >= 1024 and i < len(size_names) - 1:
        size_bytes /= 1024.0
        i += 1
    
    return f"{size_bytes:.1f} {size_names[i]}"


def cleanup_directory(directory: Union[str, Path], max_age_days: int = 30, pattern: str = "*") -> int:
    """
    Clean up old files in directory
    
    Args:
        directory: Directory to clean
        max_age_days: Maximum age of files to keep
        pattern: File pattern to match
        
    Returns:
        Number of files deleted
    """
    try:
        import time
        
        dir_path = Path(directory)
        if not dir_path.exists():
            return 0
        
        current_time = time.time()
        max_age_seconds = max_age_days * 24 * 60 * 60
        deleted_count = 0
        
        for file_path in dir_path.glob(pattern):
            if file_path.is_file():
                file_age = current_time - file_path.stat().st_mtime
                
                if file_age > max_age_seconds:
                    try:
                        file_path.unlink()
                        deleted_count += 1
                        logger.debug(f"Deleted old file: {file_path}")
                    except Exception as e:
                        logger.error(f"Failed to delete old file {file_path}: {e}")
        
        if deleted_count > 0:
            logger.info(f"Cleaned up {deleted_count} old files from {directory}")
        
        return deleted_count
        
    except Exception as e:
        logger.error(f"Failed to cleanup directory {directory}: {e}")
        return 0
