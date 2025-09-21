
"""
Basic usage examples for EirosAgent
"""
import asyncio
from pathlib import Path
from eiros_agent import EirosAgent


async def basic_example():
    """Basic EirosAgent usage example"""
    print("=== Basic EirosAgent Example ===")
    
    # Initialize agent
    agent = EirosAgent("config/default_config.yaml")
    
    try:
        # Initialize all subsystems
        await agent.initialize()
        
        # Get agent status
        status = agent.get_status()
        print(f"Agent Status: {status}")
        
        # Capture and analyze screen
        result = await agent.capture_and_analyze_screen()
        print(f"Screen analysis completed: {len(result['ocr_result']['text'])} characters extracted")
        
    finally:
        # Cleanup
        await agent.shutdown()


async def web_automation_example():
    """Web automation example"""
    print("\n=== Web Automation Example ===")
    
    agent = EirosAgent()
    
    try:
        await agent.initialize()
        
        # Define web automation task
        task_config = {
            "name": "google_search",
            "steps": [
                {
                    "name": "navigate_to_google",
                    "action": "navigate",
                    "params": {"url": "https://www.google.com"}
                },
                {
                    "name": "search_query",
                    "action": "fill",
                    "params": {
                        "selector": "input[name='q']",
                        "value": "EirosAgent automation"
                    }
                },
                {
                    "name": "submit_search",
                    "action": "click",
                    "params": {"selector": "input[name='btnK']"}
                },
                {
                    "name": "wait_for_results",
                    "action": "wait_for_selector",
                    "params": {"selector": "#search"}
                },
                {
                    "name": "extract_results",
                    "action": "inject_js",
                    "params": {
                        "script": "extract_links"
                    }
                }
            ]
        }
        
        # Execute web automation task
        result = await agent.automate_web_task(task_config)
        print(f"Web automation completed: {result['status']}")
        
    finally:
        await agent.shutdown()


async def macro_execution_example():
    """Macro execution example"""
    print("\n=== Macro Execution Example ===")
    
    agent = EirosAgent()
    
    try:
        await agent.initialize()
        
        # Execute example macro
        macro_path = "config/macros/example_macro.yaml"
        variables = {
            "target_url": "https://httpbin.org/get",
            "output_file": "./data/test_output.json"
        }
        
        result = await agent.execute_macro(macro_path, variables)
        print(f"Macro execution completed: {result['status']}")
        
    finally:
        await agent.shutdown()


async def ocr_example():
    """OCR processing example"""
    print("\n=== OCR Processing Example ===")
    
    agent = EirosAgent()
    
    try:
        await agent.initialize()
        
        # Capture screen
        screenshot = await agent.vision_manager.capture_screen()
        
        # Perform OCR with different engines
        ocr_result = await agent.ocr_manager.extract_text(screenshot)
        print(f"OCR completed with {ocr_result['engine']}: {len(ocr_result['result']['text'])} characters")
        
        # Compare engines
        comparison = await agent.ocr_manager.compare_engines(screenshot)
        print(f"Best OCR engine: {comparison['recommendation']}")
        
    finally:
        await agent.shutdown()


async def vision_analysis_example():
    """Vision analysis example"""
    print("\n=== Vision Analysis Example ===")
    
    agent = EirosAgent()
    
    try:
        await agent.initialize()
        
        # Capture screen
        screenshot = await agent.vision_manager.capture_screen()
        
        # Analyze image
        analysis = await agent.vision_manager.analyze_image(
            screenshot, 
            analysis_types=["basic", "colors", "edges", "objects"]
        )
        
        print(f"Image analysis completed:")
        print(f"- Dimensions: {analysis['basic']['dimensions']}")
        print(f"- Dominant colors: {len(analysis['colors']['dominant_colors'])}")
        print(f"- Edge density: {analysis['edges']['edge_density']:.3f}")
        print(f"- Objects detected: {analysis['objects']['num_objects']}")
        
    finally:
        await agent.shutdown()


async def task_scheduling_example():
    """Task scheduling example"""
    print("\n=== Task Scheduling Example ===")
    
    agent = EirosAgent()
    
    try:
        await agent.initialize()
        
        # Schedule a simple task
        task_config = {
            "id": "test_task_1",
            "name": "periodic_screenshot",
            "type": "macro",
            "trigger": {
                "type": "interval",
                "minutes": 5
            },
            "macro": {
                "name": "screenshot_macro",
                "steps": [
                    {
                        "name": "capture_screen",
                        "action": "log",
                        "params": {"message": "Taking periodic screenshot"}
                    }
                ]
            }
        }
        
        # Schedule task
        task_id = await agent.scheduler.schedule_task(task_config)
        print(f"Task scheduled with ID: {task_id}")
        
        # List scheduled tasks
        tasks = await agent.scheduler.list_tasks()
        print(f"Active tasks: {len(tasks)}")
        
        # Wait a bit then cancel
        await asyncio.sleep(2)
        await agent.scheduler.cancel_task(task_id)
        print("Task cancelled")
        
    finally:
        await agent.shutdown()


async def main():
    """Run all examples"""
    print("EirosAgent Examples")
    print("==================")
    
    try:
        await basic_example()
        await web_automation_example()
        await macro_execution_example()
        await ocr_example()
        await vision_analysis_example()
        await task_scheduling_example()
        
        print("\n=== All Examples Completed ===")
        
    except Exception as e:
        print(f"Example failed: {e}")


if __name__ == "__main__":
    asyncio.run(main())
