
"""
Advanced web automation examples
"""
import asyncio
from eiros_agent.web_automation import WebAutomationManager


async def form_automation_example():
    """Advanced form automation example"""
    print("=== Advanced Form Automation ===")
    
    config = {
        "browser": {
            "type": "chromium",
            "headless": False,  # Show browser for demo
            "timeout": 30000
        },
        "javascript": {
            "enable_stealth": True
        },
        "forms": {
            "auto_fill": True,
            "validation": True
        }
    }
    
    web_manager = WebAutomationManager(config)
    
    try:
        await web_manager.initialize()
        
        # Create page
        page = await web_manager.create_page("form_demo")
        
        # Navigate to form demo page
        await web_manager.navigation_manager.navigate(
            page, 
            "https://httpbin.org/forms/post"
        )
        
        # Fill complex form
        form_data = {
            "custname": "John Doe",
            "custtel": "+1-555-123-4567",
            "custemail": "john.doe@example.com",
            "size": "large",
            "topping": ["bacon", "cheese"],
            "delivery": "19:00",
            "comments": "Please ring the doorbell twice"
        }
        
        result = await web_manager.form_handler.fill_form(page, form_data)
        print(f"Form filled: {result['filled_count']}/{result['total_fields']} fields")
        
        # Submit form
        submit_result = await web_manager.form_handler.submit_form(page)
        print(f"Form submitted: {submit_result['status']}")
        
        # Wait and capture result
        await asyncio.sleep(2)
        
    finally:
        await web_manager.shutdown()


async def javascript_injection_example():
    """Advanced JavaScript injection example"""
    print("\n=== JavaScript Injection Example ===")
    
    config = {
        "browser": {"type": "chromium", "headless": False},
        "javascript": {"enable_stealth": True}
    }
    
    web_manager = WebAutomationManager(config)
    
    try:
        await web_manager.initialize()
        
        page = await web_manager.create_page("js_demo")
        
        # Navigate to a page with content
        await web_manager.navigation_manager.navigate(
            page, 
            "https://example.com"
        )
        
        # Extract all links
        links = await web_manager.js_injector.execute_script(page, "extract_links")
        print(f"Found {len(links)} links")
        
        # Extract all images
        images = await web_manager.js_injector.execute_script(page, "extract_images")
        print(f"Found {len(images)} images")
        
        # Custom data extraction
        extraction_config = {
            "title": "title",
            "headings": {"selector": "h1, h2, h3", "attribute": "textContent"},
            "meta_description": {"selector": "meta[name='description']", "attribute": "content"}
        }
        
        extracted_data = await web_manager.js_injector.extract_data(page, extraction_config)
        print(f"Extracted data: {extracted_data}")
        
        # Inject custom function
        custom_function = """
        function(selector) {
            const elements = document.querySelectorAll(selector);
            return Array.from(elements).map(el => ({
                tag: el.tagName,
                text: el.textContent.trim(),
                visible: el.offsetParent !== null
            }));
        }
        """
        
        await web_manager.js_injector.inject_function(page, "analyzeElements", custom_function)
        
        # Use injected function
        analysis = await web_manager.js_injector.execute_script(
            page, 
            "return window.analyzeElements('p, div, span');",
            {"disable_stealth": True}
        )
        print(f"Element analysis: {len(analysis)} elements analyzed")
        
    finally:
        await web_manager.shutdown()


async def multi_page_automation():
    """Multi-page automation example"""
    print("\n=== Multi-Page Automation ===")
    
    config = {
        "browser": {"type": "chromium", "headless": True},
        "javascript": {"enable_stealth": True}
    }
    
    web_manager = WebAutomationManager(config)
    
    try:
        await web_manager.initialize()
        
        # Create multiple pages
        pages = {}
        urls = [
            "https://httpbin.org/get",
            "https://httpbin.org/user-agent",
            "https://httpbin.org/headers"
        ]
        
        # Navigate all pages concurrently
        tasks = []
        for i, url in enumerate(urls):
            page_id = f"page_{i}"
            page = await web_manager.create_page(page_id)
            pages[page_id] = page
            
            task = web_manager.navigation_manager.navigate(page, url)
            tasks.append(task)
        
        # Wait for all navigations to complete
        await asyncio.gather(*tasks)
        
        # Extract data from all pages
        for page_id, page in pages.items():
            try:
                # Extract page content
                content = await web_manager.js_injector.execute_script(
                    page,
                    "return document.body.textContent;"
                )
                print(f"{page_id}: {len(content)} characters extracted")
                
            except Exception as e:
                print(f"Failed to extract from {page_id}: {e}")
        
        # Close all pages
        for page_id in pages.keys():
            await web_manager.close_page(page_id)
        
    finally:
        await web_manager.shutdown()


async def browser_context_example():
    """Browser context management example"""
    print("\n=== Browser Context Management ===")
    
    config = {
        "browser": {"type": "chromium", "headless": True}
    }
    
    web_manager = WebAutomationManager(config)
    
    try:
        await web_manager.initialize()
        
        # Create different contexts for different scenarios
        contexts = {
            "mobile": {
                "viewport": {"width": 375, "height": 667},
                "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)"
            },
            "desktop": {
                "viewport": {"width": 1920, "height": 1080},
                "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            }
        }
        
        for context_name, options in contexts.items():
            # Create context
            context = await web_manager.browser_controller.create_context(
                context_name, 
                options
            )
            
            # Create page in context
            page = await context.new_page()
            
            # Navigate and test
            await page.goto("https://httpbin.org/user-agent")
            
            # Extract user agent
            user_agent_info = await page.evaluate("""
                () => {
                    const pre = document.querySelector('pre');
                    return pre ? JSON.parse(pre.textContent) : {};
                }
            """)
            
            print(f"{context_name} context - User Agent: {user_agent_info.get('user-agent', 'Unknown')}")
            
            await page.close()
            await web_manager.browser_controller.close_context(context_name)
        
    finally:
        await web_manager.shutdown()


async def main():
    """Run all advanced web automation examples"""
    print("Advanced Web Automation Examples")
    print("===============================")
    
    try:
        await form_automation_example()
        await javascript_injection_example()
        await multi_page_automation()
        await browser_context_example()
        
        print("\n=== All Advanced Examples Completed ===")
        
    except Exception as e:
        print(f"Advanced example failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
