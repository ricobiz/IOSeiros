
"""
Web Automation Manager - orchestrates browser automation tasks
"""
import asyncio
from typing import Dict, Any, Optional, List
from playwright.async_api import async_playwright, Browser, BrowserContext, Page
from loguru import logger

from ..core.exceptions import WebAutomationError, BrowserError
from .browser_controller import BrowserController
from .js_injector import JSInjector
from .form_handler import FormHandler
from .navigation import NavigationManager


class WebAutomationManager:
    """
    Manages web automation tasks using Playwright
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize web automation manager"""
        self.config = config
        self.playwright = None
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.pages: Dict[str, Page] = {}
        
        # Initialize components
        self.browser_controller = BrowserController(config.get("browser", {}))
        self.js_injector = JSInjector(config.get("javascript", {}))
        self.form_handler = FormHandler(config.get("forms", {}))
        self.navigation_manager = NavigationManager()
        
        self.is_initialized = False
        logger.info("WebAutomationManager initialized")
    
    async def initialize(self) -> None:
        """Initialize Playwright and browser"""
        try:
            logger.info("Initializing web automation...")
            
            self.playwright = await async_playwright().start()
            
            # Launch browser
            browser_type = self.config.get("browser", {}).get("type", "chromium")
            browser_config = self.config.get("browser", {})
            
            if browser_type == "chromium":
                self.browser = await self.playwright.chromium.launch(
                    headless=browser_config.get("headless", True),
                    args=["--no-sandbox", "--disable-dev-shm-usage"]
                )
            elif browser_type == "firefox":
                self.browser = await self.playwright.firefox.launch(
                    headless=browser_config.get("headless", True)
                )
            elif browser_type == "webkit":
                self.browser = await self.playwright.webkit.launch(
                    headless=browser_config.get("headless", True)
                )
            else:
                raise BrowserError(f"Unsupported browser type: {browser_type}")
            
            # Create context
            viewport = browser_config.get("viewport", {"width": 1920, "height": 1080})
            user_agent = browser_config.get("user_agent")
            
            context_options = {"viewport": viewport}
            if user_agent:
                context_options["user_agent"] = user_agent
            
            self.context = await self.browser.new_context(**context_options)
            
            # Initialize components
            await self.browser_controller.initialize(self.browser, self.context)
            await self.js_injector.initialize()
            await self.form_handler.initialize()
            await self.navigation_manager.initialize()
            
            self.is_initialized = True
            logger.info("Web automation initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize web automation: {e}")
            raise WebAutomationError(f"Initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown browser and cleanup"""
        logger.info("Shutting down web automation...")
        
        try:
            # Close all pages
            for page_id, page in self.pages.items():
                if not page.is_closed():
                    await page.close()
            self.pages.clear()
            
            # Close context and browser
            if self.context:
                await self.context.close()
            if self.browser:
                await self.browser.close()
            if self.playwright:
                await self.playwright.stop()
            
            self.is_initialized = False
            logger.info("Web automation shutdown complete")
            
        except Exception as e:
            logger.error(f"Error during shutdown: {e}")
    
    async def create_page(self, page_id: str = "default") -> Page:
        """Create a new page"""
        if not self.is_initialized:
            raise WebAutomationError("Manager not initialized")
        
        if page_id in self.pages:
            logger.warning(f"Page {page_id} already exists, returning existing page")
            return self.pages[page_id]
        
        page = await self.context.new_page()
        self.pages[page_id] = page
        
        # Setup page defaults
        timeout = self.config.get("browser", {}).get("timeout", 30000)
        page.set_default_timeout(timeout)
        
        logger.info(f"Created new page: {page_id}")
        return page
    
    async def close_page(self, page_id: str) -> None:
        """Close a specific page"""
        if page_id in self.pages:
            page = self.pages[page_id]
            if not page.is_closed():
                await page.close()
            del self.pages[page_id]
            logger.info(f"Closed page: {page_id}")
    
    async def execute_task(self, task_config: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a web automation task"""
        if not self.is_initialized:
            raise WebAutomationError("Manager not initialized")
        
        task_name = task_config.get("name", "unnamed_task")
        logger.info(f"Executing web automation task: {task_name}")
        
        try:
            page_id = task_config.get("page_id", "default")
            page = await self.create_page(page_id)
            
            results = {}
            steps = task_config.get("steps", [])
            
            for i, step in enumerate(steps):
                step_name = step.get("name", f"step_{i}")
                action = step.get("action")
                params = step.get("params", {})
                
                logger.info(f"Executing step: {step_name} ({action})")
                
                try:
                    result = await self._execute_step(page, action, params)
                    results[step_name] = result
                    
                except Exception as e:
                    logger.error(f"Step {step_name} failed: {e}")
                    if task_config.get("stop_on_error", True):
                        raise WebAutomationError(f"Task failed at step {step_name}: {e}")
                    else:
                        results[step_name] = {"error": str(e)}
            
            logger.info(f"Task {task_name} completed successfully")
            return {
                "task_name": task_name,
                "status": "success",
                "results": results
            }
            
        except Exception as e:
            logger.error(f"Task {task_name} failed: {e}")
            return {
                "task_name": task_name,
                "status": "error",
                "error": str(e)
            }
    
    async def _execute_step(self, page: Page, action: str, params: Dict[str, Any]) -> Any:
        """Execute a single automation step"""
        if action == "navigate":
            return await self.navigation_manager.navigate(page, params.get("url"), params)
        
        elif action == "wait_for_selector":
            selector = params.get("selector")
            timeout = params.get("timeout", 30000)
            await page.wait_for_selector(selector, timeout=timeout)
            return {"selector": selector, "found": True}
        
        elif action == "click":
            selector = params.get("selector")
            await page.click(selector)
            return {"clicked": selector}
        
        elif action == "fill":
            selector = params.get("selector")
            value = params.get("value")
            await page.fill(selector, value)
            return {"filled": selector, "value": value}
        
        elif action == "inject_js":
            script = params.get("script")
            return await self.js_injector.execute_script(page, script, params)
        
        elif action == "screenshot":
            path = params.get("path")
            options = params.get("options", {})
            await page.screenshot(path=path, **options)
            return {"screenshot": path}
        
        elif action == "extract_text":
            selector = params.get("selector")
            element = await page.query_selector(selector)
            if element:
                text = await element.text_content()
                return {"text": text, "selector": selector}
            return {"text": None, "selector": selector}
        
        elif action == "fill_form":
            form_data = params.get("form_data", {})
            return await self.form_handler.fill_form(page, form_data, params)
        
        elif action == "submit_form":
            form_selector = params.get("form_selector")
            return await self.form_handler.submit_form(page, form_selector, params)
        
        else:
            raise WebAutomationError(f"Unknown action: {action}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get current status"""
        return {
            "initialized": self.is_initialized,
            "browser_type": self.config.get("browser", {}).get("type"),
            "active_pages": len(self.pages),
            "page_ids": list(self.pages.keys())
        }
