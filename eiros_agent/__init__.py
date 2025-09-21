
"""
EirosAgent - Advanced Web Automation and OCR System
==================================================

A comprehensive automation framework featuring:
- Advanced web automation with JavaScript injection
- Enhanced OCR with multiple engine support
- Task scheduling and macro system
- Visual recognition and screen capture
"""

__version__ = "2.0.0"
__author__ = "EirosAgent Team"

from .core import EirosAgent
from .web_automation import WebAutomationManager
from .ocr import AdvancedOCRManager
from .scheduler import TaskScheduler
from .vision import VisionManager

__all__ = [
    "EirosAgent",
    "WebAutomationManager", 
    "AdvancedOCRManager",
    "TaskScheduler",
    "VisionManager"
]
