
"""
Browser Controller - manages browser instances and contexts
"""
import asyncio
from typing import Dict, Any, Optional, List
from playwright.async_api import Browser, BrowserContext, Page
from loguru import logger

from ..core.exceptions import BrowserError


class BrowserController:
    """
    Controls browser instances and manages contexts
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize browser controller"""
        self.config = config
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.contexts: Dict[str, BrowserContext] = {}
        
        logger.info("BrowserController initialized")
    
    async def initialize(self, browser: Browser, default_context: BrowserContext) -> None:
        """Initialize with browser and default context"""
        self.browser = browser
        self.context = default_context
        self.contexts["default"] = default_context
        
        logger.info("BrowserController ready")
    
    async def create_context(self, context_id: str, options: Optional[Dict[str, Any]] = None) -> BrowserContext:
        """Create a new browser context"""
        if not self.browser:
            raise BrowserError("Browser not initialized")
        
        if context_id in self.contexts:
            logger.warning(f"Context {context_id} already exists")
            return self.contexts[context_id]
        
        try:
            context_options = options or {}
            
            # Apply default viewport if not specified
            if "viewport" not in context_options:
                viewport = self.config.get("viewport", {"width": 1920, "height": 1080})
                context_options["viewport"] = viewport
            
            # Apply user agent if configured
            user_agent = self.config.get("user_agent")
            if user_agent and "user_agent" not in context_options:
                context_options["user_agent"] = user_agent
            
            context = await self.browser.new_context(**context_options)
            self.contexts[context_id] = context
            
            logger.info(f"Created browser context: {context_id}")
            return context
            
        except Exception as e:
            logger.error(f"Failed to create context {context_id}: {e}")
            raise BrowserError(f"Context creation failed: {e}")
    
    async def close_context(self, context_id: str) -> None:
        """Close a browser context"""
        if context_id not in self.contexts:
            logger.warning(f"Context {context_id} not found")
            return
        
        try:
            context = self.contexts[context_id]
            await context.close()
            del self.contexts[context_id]
            
            logger.info(f"Closed browser context: {context_id}")
            
        except Exception as e:
            logger.error(f"Failed to close context {context_id}: {e}")
            raise BrowserError(f"Context closure failed: {e}")
    
    async def set_cookies(self, context_id: str, cookies: List[Dict[str, Any]]) -> None:
        """Set cookies for a context"""
        if context_id not in self.contexts:
            raise BrowserError(f"Context {context_id} not found")
        
        try:
            context = self.contexts[context_id]
            await context.add_cookies(cookies)
            
            logger.info(f"Set {len(cookies)} cookies for context {context_id}")
            
        except Exception as e:
            logger.error(f"Failed to set cookies: {e}")
            raise BrowserError(f"Cookie setting failed: {e}")
    
    async def get_cookies(self, context_id: str, urls: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Get cookies from a context"""
        if context_id not in self.contexts:
            raise BrowserError(f"Context {context_id} not found")
        
        try:
            context = self.contexts[context_id]
            cookies = await context.cookies(urls)
            
            logger.info(f"Retrieved {len(cookies)} cookies from context {context_id}")
            return cookies
            
        except Exception as e:
            logger.error(f"Failed to get cookies: {e}")
            raise BrowserError(f"Cookie retrieval failed: {e}")
    
    async def set_geolocation(self, context_id: str, latitude: float, longitude: float) -> None:
        """Set geolocation for a context"""
        if context_id not in self.contexts:
            raise BrowserError(f"Context {context_id} not found")
        
        try:
            context = self.contexts[context_id]
            await context.set_geolocation({"latitude": latitude, "longitude": longitude})
            
            logger.info(f"Set geolocation for context {context_id}: {latitude}, {longitude}")
            
        except Exception as e:
            logger.error(f"Failed to set geolocation: {e}")
            raise BrowserError(f"Geolocation setting failed: {e}")
    
    async def set_permissions(self, context_id: str, origin: str, permissions: List[str]) -> None:
        """Set permissions for a context"""
        if context_id not in self.contexts:
            raise BrowserError(f"Context {context_id} not found")
        
        try:
            context = self.contexts[context_id]
            await context.grant_permissions(permissions, origin=origin)
            
            logger.info(f"Set permissions for context {context_id}: {permissions}")
            
        except Exception as e:
            logger.error(f"Failed to set permissions: {e}")
            raise BrowserError(f"Permission setting failed: {e}")
    
    def get_context(self, context_id: str = "default") -> Optional[BrowserContext]:
        """Get a browser context by ID"""
        return self.contexts.get(context_id)
    
    def list_contexts(self) -> List[str]:
        """List all context IDs"""
        return list(self.contexts.keys())
