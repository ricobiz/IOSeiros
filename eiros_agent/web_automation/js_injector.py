
"""
JavaScript Injection System for advanced browser automation
"""
import asyncio
from typing import Dict, Any, Optional, List, Union
from playwright.async_api import Page
from loguru import logger

from ..core.exceptions import JSInjectionError


class JSInjector:
    """
    Advanced JavaScript injection system for browser automation
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize JS injector"""
        self.config = config
        self.injection_timeout = config.get("injection_timeout", 5000)
        self.max_retries = config.get("max_retries", 3)
        self.enable_stealth = config.get("enable_stealth", True)
        
        # Pre-defined script templates
        self.script_templates = {
            "extract_links": """
                return Array.from(document.querySelectorAll('a[href]')).map(link => ({
                    text: link.textContent.trim(),
                    href: link.href,
                    target: link.target
                }));
            """,
            
            "extract_images": """
                return Array.from(document.querySelectorAll('img[src]')).map(img => ({
                    src: img.src,
                    alt: img.alt,
                    width: img.naturalWidth,
                    height: img.naturalHeight
                }));
            """,
            
            "extract_forms": """
                return Array.from(document.querySelectorAll('form')).map(form => ({
                    action: form.action,
                    method: form.method,
                    fields: Array.from(form.querySelectorAll('input, select, textarea')).map(field => ({
                        name: field.name,
                        type: field.type,
                        value: field.value,
                        required: field.required
                    }))
                }));
            """,
            
            "scroll_to_bottom": """
                return new Promise((resolve) => {
                    let totalHeight = 0;
                    let distance = 100;
                    let timer = setInterval(() => {
                        let scrollHeight = document.body.scrollHeight;
                        window.scrollBy(0, distance);
                        totalHeight += distance;
                        
                        if(totalHeight >= scrollHeight){
                            clearInterval(timer);
                            resolve(totalHeight);
                        }
                    }, 100);
                });
            """,
            
            "infinite_scroll": """
                return new Promise((resolve) => {
                    let lastHeight = document.body.scrollHeight;
                    let attempts = 0;
                    let maxAttempts = arguments[0] || 10;
                    
                    function scroll() {
                        window.scrollTo(0, document.body.scrollHeight);
                        
                        setTimeout(() => {
                            let newHeight = document.body.scrollHeight;
                            if (newHeight > lastHeight && attempts < maxAttempts) {
                                lastHeight = newHeight;
                                attempts++;
                                scroll();
                            } else {
                                resolve({
                                    finalHeight: newHeight,
                                    attempts: attempts
                                });
                            }
                        }, 2000);
                    }
                    
                    scroll();
                });
            """,
            
            "wait_for_element": """
                return new Promise((resolve, reject) => {
                    let selector = arguments[0];
                    let timeout = arguments[1] || 10000;
                    let startTime = Date.now();
                    
                    function check() {
                        let element = document.querySelector(selector);
                        if (element) {
                            resolve({
                                found: true,
                                element: {
                                    tagName: element.tagName,
                                    textContent: element.textContent,
                                    innerHTML: element.innerHTML
                                }
                            });
                        } else if (Date.now() - startTime > timeout) {
                            resolve({found: false, timeout: true});
                        } else {
                            setTimeout(check, 100);
                        }
                    }
                    
                    check();
                });
            """,
            
            "stealth_mode": """
                // Override webdriver detection
                Object.defineProperty(navigator, 'webdriver', {
                    get: () => undefined,
                });
                
                // Override plugins
                Object.defineProperty(navigator, 'plugins', {
                    get: () => [1, 2, 3, 4, 5],
                });
                
                // Override languages
                Object.defineProperty(navigator, 'languages', {
                    get: () => ['en-US', 'en'],
                });
                
                // Override permissions
                const originalQuery = window.navigator.permissions.query;
                window.navigator.permissions.query = (parameters) => (
                    parameters.name === 'notifications' ?
                        Promise.resolve({ state: Notification.permission }) :
                        originalQuery(parameters)
                );
                
                return 'Stealth mode activated';
            """
        }
        
        logger.info("JSInjector initialized")
    
    async def initialize(self) -> None:
        """Initialize JS injector"""
        logger.info("JSInjector ready")
    
    async def execute_script(self, page: Page, script: str, params: Optional[Dict[str, Any]] = None) -> Any:
        """Execute JavaScript code on the page"""
        params = params or {}
        
        try:
            # Check if script is a template name
            if script in self.script_templates:
                script = self.script_templates[script]
            
            # Add stealth mode if enabled
            if self.enable_stealth and not params.get("disable_stealth", False):
                await self._inject_stealth_mode(page)
            
            # Execute script with retries
            for attempt in range(self.max_retries):
                try:
                    # Prepare arguments
                    args = params.get("args", [])
                    
                    # Execute script
                    if args:
                        result = await page.evaluate(script, *args)
                    else:
                        result = await page.evaluate(script)
                    
                    logger.info(f"Script executed successfully on attempt {attempt + 1}")
                    return result
                    
                except Exception as e:
                    logger.warning(f"Script execution attempt {attempt + 1} failed: {e}")
                    if attempt == self.max_retries - 1:
                        raise
                    await asyncio.sleep(1)
            
        except Exception as e:
            logger.error(f"JavaScript execution failed: {e}")
            raise JSInjectionError(f"Script execution failed: {e}")
    
    async def inject_function(self, page: Page, function_name: str, function_code: str) -> None:
        """Inject a JavaScript function into the page"""
        try:
            script = f"""
                window.{function_name} = {function_code};
                return 'Function {function_name} injected successfully';
            """
            
            result = await page.evaluate(script)
            logger.info(f"Function {function_name} injected: {result}")
            
        except Exception as e:
            logger.error(f"Function injection failed: {e}")
            raise JSInjectionError(f"Function injection failed: {e}")
    
    async def inject_library(self, page: Page, library_url: str) -> None:
        """Inject external JavaScript library"""
        try:
            script = f"""
                return new Promise((resolve, reject) => {{
                    const script = document.createElement('script');
                    script.src = '{library_url}';
                    script.onload = () => resolve('Library loaded successfully');
                    script.onerror = () => reject('Failed to load library');
                    document.head.appendChild(script);
                }});
            """
            
            result = await page.evaluate(script)
            logger.info(f"Library injected: {result}")
            
        except Exception as e:
            logger.error(f"Library injection failed: {e}")
            raise JSInjectionError(f"Library injection failed: {e}")
    
    async def extract_data(self, page: Page, extraction_config: Dict[str, Any]) -> Dict[str, Any]:
        """Extract data using configured selectors and scripts"""
        try:
            results = {}
            
            for key, config in extraction_config.items():
                if isinstance(config, str):
                    # Simple selector
                    elements = await page.query_selector_all(config)
                    results[key] = [await elem.text_content() for elem in elements]
                
                elif isinstance(config, dict):
                    selector = config.get("selector")
                    attribute = config.get("attribute")
                    script = config.get("script")
                    
                    if script:
                        # Custom script
                        results[key] = await self.execute_script(page, script)
                    elif selector:
                        # Selector with optional attribute
                        elements = await page.query_selector_all(selector)
                        if attribute:
                            results[key] = [await elem.get_attribute(attribute) for elem in elements]
                        else:
                            results[key] = [await elem.text_content() for elem in elements]
            
            return results
            
        except Exception as e:
            logger.error(f"Data extraction failed: {e}")
            raise JSInjectionError(f"Data extraction failed: {e}")
    
    async def monitor_network(self, page: Page, patterns: List[str]) -> List[Dict[str, Any]]:
        """Monitor network requests matching patterns"""
        captured_requests = []
        
        def handle_request(request):
            for pattern in patterns:
                if pattern in request.url:
                    captured_requests.append({
                        "url": request.url,
                        "method": request.method,
                        "headers": request.headers,
                        "timestamp": asyncio.get_event_loop().time()
                    })
        
        page.on("request", handle_request)
        return captured_requests
    
    async def _inject_stealth_mode(self, page: Page) -> None:
        """Inject stealth mode scripts to avoid detection"""
        try:
            await self.execute_script(page, "stealth_mode", {"disable_stealth": True})
        except Exception as e:
            logger.warning(f"Stealth mode injection failed: {e}")
    
    def get_available_templates(self) -> List[str]:
        """Get list of available script templates"""
        return list(self.script_templates.keys())
    
    def add_template(self, name: str, script: str) -> None:
        """Add a new script template"""
        self.script_templates[name] = script
        logger.info(f"Added script template: {name}")
