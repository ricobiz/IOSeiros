
"""
Task Manager - manages individual task execution
"""
import asyncio
from typing import Dict, Any, Optional, List, Callable
import uuid
from datetime import datetime
from loguru import logger

from ..core.exceptions import TaskExecutionError


class TaskManager:
    """
    Manages individual task execution and lifecycle
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize task manager"""
        self.config = config
        self.task_handlers: Dict[str, Callable] = {}
        self.active_tasks: Dict[str, Dict[str, Any]] = {}
        self.task_history: List[Dict[str, Any]] = []
        self.is_initialized = False
        
        # Register built-in task handlers
        self._register_builtin_handlers()
        
        logger.info("TaskManager initialized")
    
    async def initialize(self) -> None:
        """Initialize task manager"""
        try:
            logger.info("Initializing task manager...")
            self.is_initialized = True
            logger.info("Task manager initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize task manager: {e}")
            raise TaskExecutionError(f"Task manager initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown task manager"""
        logger.info("Shutting down task manager...")
        
        # Cancel active tasks
        for task_id, task_info in self.active_tasks.items():
            if "task" in task_info and not task_info["task"].done():
                task_info["task"].cancel()
                logger.info(f"Cancelled active task: {task_id}")
        
        self.active_tasks.clear()
        self.is_initialized = False
        logger.info("Task manager shutdown complete")
    
    async def execute_task(self, task_config: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a task"""
        if not self.is_initialized:
            raise TaskExecutionError("Task manager not initialized")
        
        task_id = task_config.get("id", str(uuid.uuid4()))
        task_type = task_config.get("type", "generic")
        task_name = task_config.get("name", f"task_{task_id}")
        
        logger.info(f"Executing task: {task_name} ({task_type})")
        
        try:
            # Create task info
            task_info = {
                "id": task_id,
                "name": task_name,
                "type": task_type,
                "config": task_config,
                "status": "running",
                "start_time": datetime.now(),
                "end_time": None,
                "result": None,
                "error": None
            }
            
            self.active_tasks[task_id] = task_info
            
            # Find and execute task handler
            handler = self.task_handlers.get(task_type)
            if not handler:
                raise TaskExecutionError(f"Unknown task type: {task_type}")
            
            # Execute task
            result = await handler(task_config)
            
            # Update task info
            task_info.update({
                "status": "completed",
                "end_time": datetime.now(),
                "result": result
            })
            
            # Move to history
            self.task_history.append(task_info.copy())
            del self.active_tasks[task_id]
            
            logger.info(f"Task completed successfully: {task_name}")
            
            return {
                "task_id": task_id,
                "status": "success",
                "result": result,
                "execution_time": (task_info["end_time"] - task_info["start_time"]).total_seconds()
            }
            
        except Exception as e:
            logger.error(f"Task execution failed: {e}")
            
            # Update task info with error
            if task_id in self.active_tasks:
                task_info = self.active_tasks[task_id]
                task_info.update({
                    "status": "failed",
                    "end_time": datetime.now(),
                    "error": str(e)
                })
                
                self.task_history.append(task_info.copy())
                del self.active_tasks[task_id]
            
            raise TaskExecutionError(f"Task execution failed: {e}")
    
    def register_task_handler(self, task_type: str, handler: Callable) -> None:
        """Register a task handler"""
        self.task_handlers[task_type] = handler
        logger.info(f"Registered task handler: {task_type}")
    
    def _register_builtin_handlers(self) -> None:
        """Register built-in task handlers"""
        
        async def generic_task_handler(task_config: Dict[str, Any]) -> Dict[str, Any]:
            """Generic task handler"""
            logger.info("Executing generic task")
            
            # Simulate some work
            await asyncio.sleep(1)
            
            return {
                "message": "Generic task completed",
                "config": task_config
            }
        
        async def http_request_handler(task_config: Dict[str, Any]) -> Dict[str, Any]:
            """HTTP request task handler"""
            import aiohttp
            
            url = task_config.get("url")
            method = task_config.get("method", "GET").upper()
            headers = task_config.get("headers", {})
            data = task_config.get("data")
            params = task_config.get("params")
            timeout = task_config.get("timeout", 30)
            
            if not url:
                raise TaskExecutionError("URL is required for HTTP request task")
            
            logger.info(f"Making {method} request to {url}")
            
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=timeout)) as session:
                async with session.request(
                    method=method,
                    url=url,
                    headers=headers,
                    json=data if method in ["POST", "PUT", "PATCH"] else None,
                    params=params
                ) as response:
                    result = {
                        "status_code": response.status,
                        "headers": dict(response.headers),
                        "url": str(response.url)
                    }
                    
                    # Try to get response content
                    try:
                        if response.content_type == "application/json":
                            result["data"] = await response.json()
                        else:
                            result["data"] = await response.text()
                    except Exception as e:
                        logger.warning(f"Failed to parse response content: {e}")
                        result["data"] = None
                    
                    return result
        
        async def file_operation_handler(task_config: Dict[str, Any]) -> Dict[str, Any]:
            """File operation task handler"""
            from pathlib import Path
            import shutil
            
            operation = task_config.get("operation", "read")
            file_path = task_config.get("file_path")
            
            if not file_path:
                raise TaskExecutionError("file_path is required for file operation task")
            
            path = Path(file_path)
            
            if operation == "read":
                if not path.exists():
                    raise TaskExecutionError(f"File not found: {file_path}")
                
                content = path.read_text(encoding='utf-8')
                return {
                    "operation": "read",
                    "file_path": file_path,
                    "content": content,
                    "size": len(content)
                }
            
            elif operation == "write":
                content = task_config.get("content", "")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding='utf-8')
                
                return {
                    "operation": "write",
                    "file_path": file_path,
                    "size": len(content)
                }
            
            elif operation == "copy":
                destination = task_config.get("destination")
                if not destination:
                    raise TaskExecutionError("destination is required for copy operation")
                
                if not path.exists():
                    raise TaskExecutionError(f"Source file not found: {file_path}")
                
                dest_path = Path(destination)
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, dest_path)
                
                return {
                    "operation": "copy",
                    "source": file_path,
                    "destination": destination
                }
            
            elif operation == "delete":
                if path.exists():
                    if path.is_file():
                        path.unlink()
                    else:
                        shutil.rmtree(path)
                
                return {
                    "operation": "delete",
                    "file_path": file_path,
                    "existed": path.exists()
                }
            
            else:
                raise TaskExecutionError(f"Unknown file operation: {operation}")
        
        async def shell_command_handler(task_config: Dict[str, Any]) -> Dict[str, Any]:
            """Shell command task handler"""
            command = task_config.get("command")
            working_dir = task_config.get("working_dir")
            timeout = task_config.get("timeout", 60)
            
            if not command:
                raise TaskExecutionError("command is required for shell command task")
            
            logger.info(f"Executing shell command: {command}")
            
            try:
                process = await asyncio.create_subprocess_shell(
                    command,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=working_dir
                )
                
                stdout, stderr = await asyncio.wait_for(
                    process.communicate(),
                    timeout=timeout
                )
                
                return {
                    "command": command,
                    "return_code": process.returncode,
                    "stdout": stdout.decode('utf-8') if stdout else "",
                    "stderr": stderr.decode('utf-8') if stderr else "",
                    "success": process.returncode == 0
                }
                
            except asyncio.TimeoutError:
                raise TaskExecutionError(f"Command timed out after {timeout} seconds")
            except Exception as e:
                raise TaskExecutionError(f"Command execution failed: {e}")
        
        async def data_processing_handler(task_config: Dict[str, Any]) -> Dict[str, Any]:
            """Data processing task handler"""
            operation = task_config.get("operation", "transform")
            data = task_config.get("data")
            
            if data is None:
                raise TaskExecutionError("data is required for data processing task")
            
            if operation == "transform":
                # Simple data transformation example
                if isinstance(data, list):
                    result = [str(item).upper() if isinstance(item, str) else item for item in data]
                elif isinstance(data, dict):
                    result = {k: str(v).upper() if isinstance(v, str) else v for k, v in data.items()}
                else:
                    result = str(data).upper()
                
                return {
                    "operation": "transform",
                    "original_data": data,
                    "transformed_data": result
                }
            
            elif operation == "filter":
                filter_condition = task_config.get("filter_condition", "")
                
                if isinstance(data, list):
                    # Simple filtering - in real implementation, use safe evaluation
                    result = [item for item in data if eval(filter_condition.replace("item", "item"))]
                else:
                    result = data
                
                return {
                    "operation": "filter",
                    "original_data": data,
                    "filtered_data": result,
                    "filter_condition": filter_condition
                }
            
            else:
                raise TaskExecutionError(f"Unknown data processing operation: {operation}")
        
        # Register handlers
        self.task_handlers.update({
            "generic": generic_task_handler,
            "http_request": http_request_handler,
            "file_operation": file_operation_handler,
            "shell_command": shell_command_handler,
            "data_processing": data_processing_handler
        })
    
    def get_active_tasks(self) -> List[Dict[str, Any]]:
        """Get list of active tasks"""
        return list(self.active_tasks.values())
    
    def get_task_history(self, limit: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get task execution history"""
        history = self.task_history.copy()
        if limit:
            history = history[-limit:]
        return history
    
    def get_task_info(self, task_id: str) -> Optional[Dict[str, Any]]:
        """Get information about a specific task"""
        # Check active tasks
        if task_id in self.active_tasks:
            return self.active_tasks[task_id].copy()
        
        # Check history
        for task_info in self.task_history:
            if task_info["id"] == task_id:
                return task_info.copy()
        
        return None
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get task execution statistics"""
        total_tasks = len(self.task_history)
        successful_tasks = len([t for t in self.task_history if t["status"] == "completed"])
        failed_tasks = len([t for t in self.task_history if t["status"] == "failed"])
        
        # Calculate average execution time
        completed_tasks = [t for t in self.task_history if t["status"] == "completed" and t["end_time"]]
        avg_execution_time = 0
        if completed_tasks:
            total_time = sum((t["end_time"] - t["start_time"]).total_seconds() for t in completed_tasks)
            avg_execution_time = total_time / len(completed_tasks)
        
        # Task type distribution
        task_types = {}
        for task in self.task_history:
            task_type = task["type"]
            task_types[task_type] = task_types.get(task_type, 0) + 1
        
        return {
            "total_tasks": total_tasks,
            "successful_tasks": successful_tasks,
            "failed_tasks": failed_tasks,
            "success_rate": successful_tasks / total_tasks if total_tasks > 0 else 0,
            "active_tasks": len(self.active_tasks),
            "average_execution_time": avg_execution_time,
            "task_types": task_types
        }
