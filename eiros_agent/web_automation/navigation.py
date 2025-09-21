
"""
Navigation Manager - handles page navigation and routing
"""
import asyncio
from typing import Dict, Any, Optional, List, Union
from urllib.parse import urljoin, urlparse
from playwright.async_api import Page, Response
from loguru import logger

from ..core.exceptions import NavigationError


class NavigationManager:
    """
    Manages page navigation with advanced routing capabilities
    """
    
    def __init__(self):
        """Initialize navigation manager"""
        self.navigation_history: List[Dict[str, Any]] = []
        self.current_page_info: Optional[Dict[str, Any]] = None
        
        logger.info("NavigationManager initialized")
    
    async def initialize(self) -> None:
        """Initialize navigation manager"""
        logger.info("NavigationManager ready")
    
    async def navigate(self, page: Page, url: str, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Navigate to a URL with advanced options"""
        options = options or {}
        
        try:
            logger.info(f"Navigating to: {url}")
            
            # Prepare navigation options
            nav_options = {
                "wait_until": options.get("wait_until", "networkidle"),
                "timeout": options.get("timeout", 30000)
            }
            
            # Add referer if specified
            if options.get("referer"):
                nav_options["referer"] = options["referer"]
            
            # Navigate to URL
            response = await page.goto(url, **nav_options)
            
            # Get page information
            page_info = await self._get_page_info(page, response)
            
            # Update navigation history
            self._update_history(page_info)
            self.current_page_info = page_info
            
            # Handle redirects if any
            if response and response.url != url:
                logger.info(f"Redirected to: {response.url}")
                page_info["redirected"] = True
                page_info["original_url"] = url
            
            # Wait for additional conditions if specified
            await self._wait_for_conditions(page, options)
            
            logger.info(f"Navigation completed: {page_info['title']}")
            
            return {
                "status": "success",
                "url": page_info["url"],
                "title": page_info["title"],
                "status_code": page_info["status_code"],
                "redirected": page_info.get("redirected", False),
                "load_time": page_info["load_time"]
            }
            
        except Exception as e:
            logger.error(f"Navigation failed: {e}")
            raise NavigationError(f"Navigation to {url} failed: {e}")
    
    async def go_back(self, page: Page, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Navigate back in history"""
        options = options or {}
        
        try:
            logger.info("Navigating back")
            
            nav_options = {
                "wait_until": options.get("wait_until", "networkidle"),
                "timeout": options.get("timeout", 30000)
            }
            
            response = await page.go_back(**nav_options)
            page_info = await self._get_page_info(page, response)
            
            self.current_page_info = page_info
            
            return {
                "status": "success",
                "url": page_info["url"],
                "title": page_info["title"]
            }
            
        except Exception as e:
            logger.error(f"Go back failed: {e}")
            raise NavigationError(f"Go back failed: {e}")
    
    async def go_forward(self, page: Page, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Navigate forward in history"""
        options = options or {}
        
        try:
            logger.info("Navigating forward")
            
            nav_options = {
                "wait_until": options.get("wait_until", "networkidle"),
                "timeout": options.get("timeout", 30000)
            }
            
            response = await page.go_forward(**nav_options)
            page_info = await self._get_page_info(page, response)
            
            self.current_page_info = page_info
            
            return {
                "status": "success",
                "url": page_info["url"],
                "title": page_info["title"]
            }
            
        except Exception as e:
            logger.error(f"Go forward failed: {e}")
            raise NavigationError(f"Go forward failed: {e}")
    
    async def reload(self, page: Page, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Reload the current page"""
        options = options or {}
        
        try:
            logger.info("Reloading page")
            
            nav_options = {
                "wait_until": options.get("wait_until", "networkidle"),
                "timeout": options.get("timeout", 30000)
            }
            
            response = await page.reload(**nav_options)
            page_info = await self._get_page_info(page, response)
            
            self.current_page_info = page_info
            
            return {
                "status": "success",
                "url": page_info["url"],
                "title": page_info["title"]
            }
            
        except Exception as e:
            logger.error(f"Page reload failed: {e}")
            raise NavigationError(f"Page reload failed: {e}")
    
    async def wait_for_navigation(self, page: Page, trigger_action, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Wait for navigation after triggering an action"""
        options = options or {}
        
        try:
            logger.info("Waiting for navigation after action")
            
            # Set up navigation promise
            nav_promise = page.wait_for_load_state(
                options.get("wait_until", "networkidle"),
                timeout=options.get("timeout", 30000)
            )
            
            # Execute the trigger action
            if asyncio.iscoroutinefunction(trigger_action):
                await trigger_action()
            else:
                trigger_action()
            
            # Wait for navigation to complete
            await nav_promise
            
            page_info = await self._get_page_info(page)
            self.current_page_info = page_info
            
            return {
                "status": "success",
                "url": page_info["url"],
                "title": page_info["title"]
            }
            
        except Exception as e:
            logger.error(f"Wait for navigation failed: {e}")
            raise NavigationError(f"Wait for navigation failed: {e}")
    
    async def navigate_and_wait(self, page: Page, url: str, wait_conditions: List[Dict[str, Any]], options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Navigate and wait for multiple conditions"""
        options = options or {}
        
        try:
            # Navigate to URL
            nav_result = await self.navigate(page, url, options)
            
            # Wait for all conditions
            for condition in wait_conditions:
                await self._wait_for_condition(page, condition)
            
            return nav_result
            
        except Exception as e:
            logger.error(f"Navigate and wait failed: {e}")
            raise NavigationError(f"Navigate and wait failed: {e}")
    
    async def _get_page_info(self, page: Page, response: Optional[Response] = None) -> Dict[str, Any]:
        """Get comprehensive page information"""
        try:
            import time
            start_time = time.time()
            
            # Basic page info
            url = page.url
            title = await page.title()
            
            # Response info
            status_code = response.status if response else None
            headers = dict(response.headers) if response else {}
            
            # Performance info
            load_time = time.time() - start_time
            
            # Page metrics
            metrics = await page.evaluate("""
                () => {
                    const navigation = performance.getEntriesByType('navigation')[0];
                    return {
                        loadTime: navigation ? navigation.loadEventEnd - navigation.loadEventStart : 0,
                        domContentLoaded: navigation ? navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart : 0,
                        firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime || 0,
                        firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime || 0
                    };
                }
            """)
            
            return {
                "url": url,
                "title": title,
                "status_code": status_code,
                "headers": headers,
                "load_time": load_time,
                "metrics": metrics,
                "timestamp": time.time()
            }
            
        except Exception as e:
            logger.error(f"Failed to get page info: {e}")
            return {
                "url": page.url,
                "title": "Unknown",
                "status_code": None,
                "headers": {},
                "load_time": 0,
                "metrics": {},
                "timestamp": time.time()
            }
    
    async def _wait_for_conditions(self, page: Page, options: Dict[str, Any]) -> None:
        """Wait for additional conditions after navigation"""
        conditions = options.get("wait_conditions", [])
        
        for condition in conditions:
            await self._wait_for_condition(page, condition)
    
    async def _wait_for_condition(self, page: Page, condition: Dict[str, Any]) -> None:
        """Wait for a specific condition"""
        condition_type = condition.get("type")
        timeout = condition.get("timeout", 10000)
        
        try:
            if condition_type == "selector":
                selector = condition.get("selector")
                await page.wait_for_selector(selector, timeout=timeout)
                
            elif condition_type == "function":
                function = condition.get("function")
                await page.wait_for_function(function, timeout=timeout)
                
            elif condition_type == "url":
                url_pattern = condition.get("url")
                await page.wait_for_url(url_pattern, timeout=timeout)
                
            elif condition_type == "load_state":
                state = condition.get("state", "networkidle")
                await page.wait_for_load_state(state, timeout=timeout)
                
            elif condition_type == "timeout":
                delay = condition.get("delay", 1000)
                await asyncio.sleep(delay / 1000)
                
            else:
                logger.warning(f"Unknown condition type: {condition_type}")
                
        except Exception as e:
            logger.error(f"Condition wait failed: {e}")
            raise NavigationError(f"Wait condition failed: {e}")
    
    def _update_history(self, page_info: Dict[str, Any]) -> None:
        """Update navigation history"""
        self.navigation_history.append(page_info)
        
        # Keep only last 100 entries
        if len(self.navigation_history) > 100:
            self.navigation_history = self.navigation_history[-100:]
    
    def get_history(self) -> List[Dict[str, Any]]:
        """Get navigation history"""
        return self.navigation_history.copy()
    
    def get_current_page_info(self) -> Optional[Dict[str, Any]]:
        """Get current page information"""
        return self.current_page_info
    
    def clear_history(self) -> None:
        """Clear navigation history"""
        self.navigation_history.clear()
        logger.info("Navigation history cleared")
