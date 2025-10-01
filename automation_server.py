
#!/usr/bin/env python3
"""
IOSeiros Automation Server
Provides REST API for web automation with DECODO proxy support
"""

import asyncio
import json
import logging
import os
import sys
import traceback
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
from datetime import datetime

from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import requests
from urllib.parse import urljoin

# Import our automation modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from eiros_agent.web_automation import WebAutomationManager
    from eiros_agent.web_automation.form_handler import FormHandler
    from eiros_agent.web_automation.browser_controller import BrowserController
    AUTOMATION_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ Automation modules not available: {e}")
    AUTOMATION_AVAILABLE = False

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# DECODO proxy configuration
DECODO_CONFIG = {
    "username": os.getenv("DECODO_USERNAME", ""),
    "password": os.getenv("DECODO_PASSWORD", ""),
    "api_key": os.getenv("DECODO_API_KEY", ""),
    "proxy_url": "proxy.decodo-proxies.com:8080"
}

@dataclass
class AutomationTask:
    """Automation task data structure"""
    id: str
    action: str
    url: str
    target: Optional[str] = None
    data: Optional[Dict] = None
    use_decodo: bool = True
    status: str = "pending"
    result: Optional[Dict] = None
    error: Optional[str] = None
    created_at: datetime = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()

# Global automation manager instance
automation_manager = None
active_tasks: Dict[str, AutomationTask] = {}

def initialize_automation_manager():
    """Initialize the web automation manager"""
    global automation_manager
    
    if not AUTOMATION_AVAILABLE:
        logger.warning("Automation modules not available - running in mock mode")
        return None
    
    try:
        config = {
            "browser": {
                "type": "chromium",
                "headless": True,  # Run headless in server mode
                "timeout": 30000,
                "proxy": None  # Will be set dynamically per request
            },
            "javascript": {
                "enable_stealth": True
            },
            "forms": {
                "auto_fill": True,
                "validation": True
            },
            "decodo": DECODO_CONFIG
        }
        
        automation_manager = WebAutomationManager(config)
        logger.info("✅ Automation manager initialized successfully")
        return automation_manager
        
    except Exception as e:
        logger.error(f"Failed to initialize automation manager: {e}")
        return None

def get_decodo_proxy_settings():
    """Get DECODO proxy settings for requests"""
    if not all([DECODO_CONFIG["username"], DECODO_CONFIG["password"]]):
        return None
    
    return {
        "http": f"http://{DECODO_CONFIG['username']}:{DECODO_CONFIG['password']}@{DECODO_CONFIG['proxy_url']}",
        "https": f"http://{DECODO_CONFIG['username']}:{DECODO_CONFIG['password']}@{DECODO_CONFIG['proxy_url']}"
    }

async def execute_automation_task(task: AutomationTask) -> Dict[str, Any]:
    """Execute an automation task"""
    try:
        task.status = "running"
        
        if not AUTOMATION_AVAILABLE or automation_manager is None:
            # Mock execution for testing
            return await mock_automation_execution(task)
        
        # Real automation execution
        await automation_manager.initialize()
        
        # Configure DECODO proxy if enabled
        if task.use_decodo:
            proxy_settings = get_decodo_proxy_settings()
            if proxy_settings:
                automation_manager.config["browser"]["proxy"] = proxy_settings
        
        page = await automation_manager.create_page(f"task_{task.id}")
        
        result = {}
        
        if task.action == "navigate":
            result = await automation_manager.navigation_manager.navigate(page, task.url)
            
        elif task.action == "fill_form":
            if task.data and task.target:
                result = await automation_manager.form_handler.fill_form(
                    page, task.target, task.data
                )
        
        elif task.action == "click":
            if task.target:
                result = await automation_manager.click_element(page, task.target)
                
        elif task.action == "screenshot":
            result = await automation_manager.take_screenshot(page)
            
        elif task.action == "register_user":
            result = await execute_user_registration(page, task)
            
        else:
            raise ValueError(f"Unknown automation action: {task.action}")
        
        task.status = "completed"
        task.result = result
        
        # Cleanup
        await automation_manager.close_page(f"task_{task.id}")
        
        return result
        
    except Exception as e:
        task.status = "failed"
        task.error = str(e)
        logger.error(f"Automation task failed: {e}")
        logger.error(traceback.format_exc())
        raise

async def execute_user_registration(page, task: AutomationTask) -> Dict[str, Any]:
    """Execute user registration automation"""
    try:
        steps_completed = []
        
        # Step 1: Navigate to site
        nav_result = await automation_manager.navigation_manager.navigate(page, task.url)
        steps_completed.append({
            "step": 1,
            "action": "navigate",
            "url": task.url,
            "success": nav_result.get("success", False),
            "message": f"Navigated to {task.url}"
        })
        
        await asyncio.sleep(2)  # Wait for page load
        
        # Step 2: Find and click registration button/link
        registration_selectors = [
            "a[href*='register']",
            "a[href*='signup']", 
            "button:contains('Sign up')",
            ".signup-btn",
            "[data-testid*='signup']",
            ".register-link"
        ]
        
        registration_clicked = False
        for selector in registration_selectors:
            try:
                click_result = await automation_manager.click_element(page, selector)
                if click_result.get("success"):
                    steps_completed.append({
                        "step": 2,
                        "action": "click_register",
                        "selector": selector,
                        "success": True,
                        "message": "Found and clicked registration button"
                    })
                    registration_clicked = True
                    break
            except:
                continue
        
        if not registration_clicked:
            steps_completed.append({
                "step": 2,
                "action": "click_register",
                "success": False,
                "message": "Registration button not found"
            })
        
        await asyncio.sleep(2)  # Wait for registration form
        
        # Step 3: Fill registration form
        if task.data and registration_clicked:
            form_selectors = ["form", ".registration-form", "#signup-form", ".signup-form"]
            form_filled = False
            
            for form_selector in form_selectors:
                try:
                    form_result = await automation_manager.form_handler.fill_form(
                        page, form_selector, task.data
                    )
                    if form_result.get("success"):
                        steps_completed.append({
                            "step": 3,
                            "action": "fill_form",
                            "selector": form_selector,
                            "success": True,
                            "message": f"Registration form filled with data: {list(task.data.keys())}"
                        })
                        form_filled = True
                        break
                except:
                    continue
            
            if not form_filled:
                steps_completed.append({
                    "step": 3,
                    "action": "fill_form",
                    "success": False,
                    "message": "Registration form not found or could not be filled"
                })
        
        # Step 4: Submit form
        if form_filled:
            submit_selectors = [
                "input[type='submit']",
                "button[type='submit']",
                "button:contains('Register')",
                "button:contains('Sign up')",
                ".submit-btn"
            ]
            
            for submit_selector in submit_selectors:
                try:
                    submit_result = await automation_manager.click_element(page, submit_selector)
                    if submit_result.get("success"):
                        steps_completed.append({
                            "step": 4,
                            "action": "submit_form",
                            "selector": submit_selector,
                            "success": True,
                            "message": "Registration form submitted"
                        })
                        break
                except:
                    continue
        
        # Step 5: Take screenshot of result
        screenshot_result = await automation_manager.take_screenshot(page)
        steps_completed.append({
            "step": 5,
            "action": "screenshot",
            "success": screenshot_result.get("success", False),
            "message": "Final screenshot taken",
            "screenshot_path": screenshot_result.get("path")
        })
        
        success_rate = len([s for s in steps_completed if s.get("success")]) / len(steps_completed)
        
        return {
            "action": "register_user",
            "url": task.url,
            "steps": steps_completed,
            "success_rate": success_rate,
            "status": "completed" if success_rate > 0.6 else "partial_success",
            "user_data": task.data,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"User registration failed: {e}")
        return {
            "action": "register_user",
            "url": task.url,
            "error": str(e),
            "status": "failed",
            "timestamp": datetime.now().isoformat()
        }

async def mock_automation_execution(task: AutomationTask) -> Dict[str, Any]:
    """Mock automation execution for testing"""
    await asyncio.sleep(2)  # Simulate processing time
    
    if task.action == "register_user":
        return {
            "action": "register_user",
            "url": task.url,
            "steps": [
                {
                    "step": 1,
                    "action": "navigate",
                    "success": True,
                    "message": f"✅ Navigated to {task.url}"
                },
                {
                    "step": 2,
                    "action": "find_register_button",
                    "success": True,
                    "message": "✅ Found registration button"
                },
                {
                    "step": 3,
                    "action": "fill_form",
                    "success": True,
                    "message": f"✅ Filled form with user data: {list(task.data.keys()) if task.data else 'no data'}"
                },
                {
                    "step": 4,
                    "action": "submit_form",
                    "success": True,
                    "message": "✅ Form submitted successfully"
                }
            ],
            "success_rate": 1.0,
            "status": "completed",
            "user_data": task.data,
            "timestamp": datetime.now().isoformat(),
            "note": "MOCK EXECUTION - Real browser automation not available"
        }
    
    return {
        "action": task.action,
        "url": task.url,
        "status": "completed",
        "timestamp": datetime.now().isoformat(),
        "note": "MOCK EXECUTION"
    }

# API Routes

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "IOSeiros Automation Server",
        "automation_available": AUTOMATION_AVAILABLE,
        "decodo_configured": bool(DECODO_CONFIG["username"] and DECODO_CONFIG["password"]),
        "timestamp": datetime.now().isoformat()
    })

@app.route('/automation/execute', methods=['POST'])
def execute_automation():
    """Execute automation task"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        # Create automation task
        task_id = f"task_{int(datetime.now().timestamp() * 1000)}"
        task = AutomationTask(
            id=task_id,
            action=data.get("action", ""),
            url=data.get("url", ""),
            target=data.get("target"),
            data=data.get("data"),
            use_decodo=data.get("use_decodo", True)
        )
        
        # Store task
        active_tasks[task_id] = task
        
        # Execute task synchronously for now
        # In production, this should be asynchronous with task queue
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            result = loop.run_until_complete(execute_automation_task(task))
            loop.close()
            
            return jsonify({
                "task_id": task_id,
                "status": task.status,
                "result": result,
                "timestamp": datetime.now().isoformat()
            })
            
        except Exception as e:
            return jsonify({
                "task_id": task_id,
                "status": "failed",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }), 500
        
    except Exception as e:
        logger.error(f"Automation execution error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/automation/status/<task_id>', methods=['GET'])
def get_task_status(task_id):
    """Get automation task status"""
    task = active_tasks.get(task_id)
    
    if not task:
        return jsonify({"error": "Task not found"}), 404
    
    return jsonify({
        "task_id": task_id,
        "status": task.status,
        "result": task.result,
        "error": task.error,
        "created_at": task.created_at.isoformat(),
        "timestamp": datetime.now().isoformat()
    })

@app.route('/automation/tasks', methods=['GET'])
def list_tasks():
    """List all automation tasks"""
    tasks = []
    for task_id, task in active_tasks.items():
        tasks.append({
            "task_id": task_id,
            "action": task.action,
            "url": task.url,
            "status": task.status,
            "created_at": task.created_at.isoformat()
        })
    
    return jsonify({
        "tasks": tasks,
        "total": len(tasks),
        "timestamp": datetime.now().isoformat()
    })

@app.route('/decodo/test', methods=['GET'])
def test_decodo():
    """Test DECODO proxy connection"""
    try:
        proxy_settings = get_decodo_proxy_settings()
        
        if not proxy_settings:
            return jsonify({
                "error": "DECODO credentials not configured",
                "configured": False
            }), 400
        
        # Test proxy connection
        test_url = "https://httpbin.org/ip"
        response = requests.get(test_url, proxies=proxy_settings, timeout=10)
        
        return jsonify({
            "status": "success",
            "proxy_configured": True,
            "test_url": test_url,
            "response": response.json(),
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "proxy_configured": bool(proxy_settings),
            "timestamp": datetime.now().isoformat()
        }), 500

def start_server(host='localhost', port=8001, debug=False):
    """Start the automation server"""
    logger.info(f"🚀 Starting IOSeiros Automation Server on {host}:{port}")
    
    # Initialize automation manager
    automation_manager = initialize_automation_manager()
    
    if automation_manager:
        logger.info("✅ Automation manager ready")
    else:
        logger.warning("⚠️ Automation manager not available - running in mock mode")
    
    # Check DECODO configuration
    if DECODO_CONFIG["username"] and DECODO_CONFIG["password"]:
        logger.info("✅ DECODO proxy configured")
    else:
        logger.warning("⚠️ DECODO proxy not configured")
    
    print("\n" + "="*60)
    print("🚀 IOSeiros Automation Server")
    print("="*60)
    print(f"📡 Server: http://{host}:{port}")
    print(f"🔧 Automation: {'Available' if AUTOMATION_AVAILABLE else 'Mock Mode'}")
    print(f"🌐 DECODO Proxy: {'Configured' if DECODO_CONFIG['username'] else 'Not Configured'}")
    print("\nEndpoints:")
    print(f"  • Health: http://{host}:{port}/health")
    print(f"  • Execute: http://{host}:{port}/automation/execute (POST)")
    print(f"  • Status: http://{host}:{port}/automation/status/<task_id> (GET)")
    print(f"  • Tasks: http://{host}:{port}/automation/tasks (GET)")
    print(f"  • Test DECODO: http://{host}:{port}/decodo/test (GET)")
    print("="*60)
    
    app.run(host=host, port=port, debug=debug, threaded=True)

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='IOSeiros Automation Server')
    parser.add_argument('--host', default='localhost', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8001, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    
    args = parser.parse_args()
    
    # Load environment variables from .env file if exists
    env_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'ioseiros_web_mvp', 'app', '.env')
    if os.path.exists(env_file):
        logger.info(f"Loading environment variables from {env_file}")
        with open(env_file, 'r') as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value.strip('"')
    
    start_server(args.host, args.port, args.debug)
