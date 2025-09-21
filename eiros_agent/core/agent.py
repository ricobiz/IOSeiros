
"""
Main EirosAgent class - orchestrates all components
"""
import asyncio
from typing import Dict, Any, Optional, List
from pathlib import Path
import yaml
from loguru import logger

from .config import Config
from .exceptions import EirosAgentError
from ..web_automation import WebAutomationManager
from ..ocr import AdvancedOCRManager
from ..scheduler import TaskScheduler
from ..vision import VisionManager


class EirosAgent:
    """
    Main EirosAgent class that coordinates all subsystems
    """
    
    def __init__(self, config_path: Optional[str] = None):
        """Initialize EirosAgent with configuration"""
        self.config = Config(config_path)
        self.is_initialized = False
        
        # Initialize managers
        self.web_automation: Optional[WebAutomationManager] = None
        self.ocr_manager: Optional[AdvancedOCRManager] = None
        self.scheduler: Optional[TaskScheduler] = None
        self.vision_manager: Optional[VisionManager] = None
        
        logger.info("EirosAgent initialized")
    
    async def initialize(self) -> None:
        """Initialize all subsystems"""
        try:
            logger.info("Initializing EirosAgent subsystems...")
            
            # Initialize web automation
            self.web_automation = WebAutomationManager(self.config.web_automation)
            await self.web_automation.initialize()
            
            # Initialize OCR manager
            self.ocr_manager = AdvancedOCRManager(self.config.ocr)
            await self.ocr_manager.initialize()
            
            # Initialize vision manager
            self.vision_manager = VisionManager(self.config.vision)
            await self.vision_manager.initialize()
            
            # Initialize scheduler
            self.scheduler = TaskScheduler(self.config.scheduler)
            await self.scheduler.initialize()
            
            self.is_initialized = True
            logger.info("EirosAgent initialization complete")
            
        except Exception as e:
            logger.error(f"Failed to initialize EirosAgent: {e}")
            raise EirosAgentError(f"Initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown all subsystems gracefully"""
        logger.info("Shutting down EirosAgent...")
        
        if self.scheduler:
            await self.scheduler.shutdown()
        if self.web_automation:
            await self.web_automation.shutdown()
        if self.ocr_manager:
            await self.ocr_manager.shutdown()
        if self.vision_manager:
            await self.vision_manager.shutdown()
            
        self.is_initialized = False
        logger.info("EirosAgent shutdown complete")
    
    async def execute_macro(self, macro_path: str, variables: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a macro file"""
        if not self.is_initialized:
            raise EirosAgentError("Agent not initialized")
            
        logger.info(f"Executing macro: {macro_path}")
        
        try:
            with open(macro_path, 'r', encoding='utf-8') as f:
                macro_config = yaml.safe_load(f)
            
            return await self.scheduler.execute_macro(macro_config, variables or {})
            
        except Exception as e:
            logger.error(f"Macro execution failed: {e}")
            raise EirosAgentError(f"Macro execution failed: {e}")
    
    async def capture_and_analyze_screen(self, region: Optional[Dict[str, int]] = None) -> Dict[str, Any]:
        """Capture screen and perform OCR analysis"""
        if not self.is_initialized:
            raise EirosAgentError("Agent not initialized")
            
        # Capture screen
        screenshot = await self.vision_manager.capture_screen(region)
        
        # Perform OCR
        ocr_result = await self.ocr_manager.extract_text(screenshot)
        
        # Analyze image
        analysis = await self.vision_manager.analyze_image(screenshot)
        
        return {
            "screenshot": screenshot,
            "ocr_result": ocr_result,
            "analysis": analysis
        }
    
    async def automate_web_task(self, task_config: Dict[str, Any]) -> Dict[str, Any]:
        """Execute web automation task"""
        if not self.is_initialized:
            raise EirosAgentError("Agent not initialized")
            
        return await self.web_automation.execute_task(task_config)
    
    def get_status(self) -> Dict[str, Any]:
        """Get current status of all subsystems"""
        return {
            "initialized": self.is_initialized,
            "web_automation": self.web_automation.get_status() if self.web_automation else None,
            "ocr_manager": self.ocr_manager.get_status() if self.ocr_manager else None,
            "scheduler": self.scheduler.get_status() if self.scheduler else None,
            "vision_manager": self.vision_manager.get_status() if self.vision_manager else None
        }
