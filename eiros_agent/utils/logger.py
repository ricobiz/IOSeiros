
"""
Logger setup and configuration
"""
import sys
from pathlib import Path
from typing import Optional
from loguru import logger


def setup_logger(
    log_file: Optional[str] = None,
    log_level: str = "INFO",
    format_string: Optional[str] = None,
    rotation: str = "1 day",
    retention: str = "30 days"
) -> None:
    """
    Setup logger configuration
    
    Args:
        log_file: Path to log file
        log_level: Logging level
        format_string: Custom format string
        rotation: Log rotation interval
        retention: Log retention period
    """
    
    # Remove default handler
    logger.remove()
    
    # Default format
    if format_string is None:
        format_string = (
            "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
            "<level>{level: <8}</level> | "
            "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> | "
            "<level>{message}</level>"
        )
    
    # Add console handler
    logger.add(
        sys.stdout,
        format=format_string,
        level=log_level,
        colorize=True
    )
    
    # Add file handler if specified
    if log_file:
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        
        logger.add(
            log_file,
            format=format_string,
            level=log_level,
            rotation=rotation,
            retention=retention,
            compression="zip"
        )
    
    logger.info(f"Logger configured - Level: {log_level}, File: {log_file}")


def get_logger(name: str):
    """Get a logger instance with the given name"""
    return logger.bind(name=name)
