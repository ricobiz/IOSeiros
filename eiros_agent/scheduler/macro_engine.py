
"""
Macro Engine - executes automation macros
"""
import asyncio
from typing import Dict, Any, Optional, List, Union
import yaml
import json
from pathlib import Path
from jinja2 import Template, Environment, DictLoader
from loguru import logger

from ..core.exceptions import MacroError, TaskExecutionError


class MacroEngine:
    """
    Advanced macro execution engine with templating and flow control
    """
    
    def __init__(self):
        """Initialize macro engine"""
        self.template_env = Environment(loader=DictLoader({}))
        self.action_handlers = {}
        self.global_variables = {}
        self.is_initialized = False
        
        # Register built-in action handlers
        self._register_builtin_handlers()
        
        logger.info("MacroEngine initialized")
    
    async def initialize(self) -> None:
        """Initialize macro engine"""
        try:
            logger.info("Initializing macro engine...")
            
            # Setup template environment
            self.template_env.globals.update({
                'now': lambda: asyncio.get_event_loop().time(),
                'len': len,
                'str': str,
                'int': int,
                'float': float,
                'bool': bool
            })
            
            self.is_initialized = True
            logger.info("Macro engine initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize macro engine: {e}")
            raise MacroError(f"Macro engine initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown macro engine"""
        logger.info("Shutting down macro engine...")
        self.is_initialized = False
        logger.info("Macro engine shutdown complete")
    
    async def execute_macro(self, macro_config: Dict[str, Any], variables: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a macro"""
        if not self.is_initialized:
            raise MacroError("Macro engine not initialized")
        
        variables = variables or {}
        macro_name = macro_config.get("name", "unnamed_macro")
        
        logger.info(f"Executing macro: {macro_name}")
        
        try:
            # Setup execution context
            context = {
                "variables": {**self.global_variables, **macro_config.get("variables", {}), **variables},
                "steps": {},
                "results": {},
                "errors": [],
                "macro": macro_config
            }
            
            # Execute steps
            steps = macro_config.get("steps", [])
            for i, step in enumerate(steps):
                try:
                    step_name = step.get("name", f"step_{i}")
                    logger.info(f"Executing step: {step_name}")
                    
                    # Process step with templating
                    processed_step = await self._process_step_template(step, context)
                    
                    # Execute step
                    result = await self._execute_step(processed_step, context)
                    
                    # Store result
                    context["steps"][step_name] = result
                    context["results"][step_name] = result
                    
                    # Check for conditional flow control
                    if not await self._check_step_conditions(step, context, result):
                        logger.info(f"Step conditions not met, skipping remaining steps")
                        break
                    
                except Exception as e:
                    logger.error(f"Step {step.get('name', i)} failed: {e}")
                    
                    # Handle error based on macro configuration
                    error_handling = macro_config.get("error_handling", {})
                    on_error = error_handling.get("on_error", "stop")
                    
                    context["errors"].append({
                        "step": step.get("name", i),
                        "error": str(e),
                        "action": on_error
                    })
                    
                    if on_error == "stop":
                        raise MacroError(f"Macro stopped due to error in step {step.get('name', i)}: {e}")
                    elif on_error == "retry":
                        max_retries = error_handling.get("max_retries", 3)
                        retry_delay = error_handling.get("retry_delay", 5)
                        
                        for retry in range(max_retries):
                            logger.info(f"Retrying step {step.get('name', i)} (attempt {retry + 1})")
                            await asyncio.sleep(retry_delay)
                            
                            try:
                                result = await self._execute_step(processed_step, context)
                                context["steps"][step_name] = result
                                context["results"][step_name] = result
                                break
                            except Exception as retry_error:
                                if retry == max_retries - 1:
                                    raise MacroError(f"Step failed after {max_retries} retries: {retry_error}")
                    # on_error == "continue" - just continue to next step
            
            # Send notifications
            await self._send_notifications(macro_config, context, success=True)
            
            logger.info(f"Macro completed successfully: {macro_name}")
            
            return {
                "macro_name": macro_name,
                "status": "success",
                "results": context["results"],
                "errors": context["errors"],
                "variables": context["variables"]
            }
            
        except Exception as e:
            logger.error(f"Macro execution failed: {e}")
            
            # Send error notifications
            await self._send_notifications(macro_config, {"error": {"message": str(e)}}, success=False)
            
            raise MacroError(f"Macro execution failed: {e}")
    
    async def _execute_step(self, step: Dict[str, Any], context: Dict[str, Any]) -> Any:
        """Execute a single macro step"""
        action = step.get("action")
        params = step.get("params", {})
        
        if not action:
            raise MacroError("Step missing action")
        
        # Find action handler
        handler = self.action_handlers.get(action)
        if not handler:
            raise MacroError(f"Unknown action: {action}")
        
        # Execute action
        try:
            result = await handler(params, context)
            return result
        except Exception as e:
            raise MacroError(f"Action {action} failed: {e}")
    
    async def _process_step_template(self, step: Dict[str, Any], context: Dict[str, Any]) -> Dict[str, Any]:
        """Process step with Jinja2 templating"""
        try:
            # Convert step to JSON string for templating
            step_json = json.dumps(step)
            
            # Create template
            template = self.template_env.from_string(step_json)
            
            # Render with context
            rendered_json = template.render(**context)
            
            # Parse back to dict
            return json.loads(rendered_json)
            
        except Exception as e:
            logger.warning(f"Template processing failed, using original step: {e}")
            return step
    
    async def _check_step_conditions(self, step: Dict[str, Any], context: Dict[str, Any], result: Any) -> bool:
        """Check if step conditions are met for flow control"""
        conditions = step.get("conditions", {})
        
        if not conditions:
            return True
        
        # Check if condition
        if_condition = conditions.get("if")
        if if_condition:
            try:
                # Simple condition evaluation
                # In a real implementation, you'd use a safe expression evaluator
                condition_result = eval(if_condition, {"result": result, "context": context})
                if not condition_result:
                    return False
            except Exception as e:
                logger.warning(f"Condition evaluation failed: {e}")
                return True
        
        # Check unless condition
        unless_condition = conditions.get("unless")
        if unless_condition:
            try:
                condition_result = eval(unless_condition, {"result": result, "context": context})
                if condition_result:
                    return False
            except Exception as e:
                logger.warning(f"Unless condition evaluation failed: {e}")
                return True
        
        return True
    
    async def _send_notifications(self, macro_config: Dict[str, Any], context: Dict[str, Any], success: bool) -> None:
        """Send macro notifications"""
        try:
            notifications = macro_config.get("notifications", {})
            
            if success:
                success_notifications = notifications.get("on_success", [])
                for notification in success_notifications:
                    await self._send_notification(notification, context)
            else:
                error_notifications = notifications.get("on_error", [])
                for notification in error_notifications:
                    await self._send_notification(notification, context)
                    
        except Exception as e:
            logger.error(f"Failed to send notifications: {e}")
    
    async def _send_notification(self, notification: Dict[str, Any], context: Dict[str, Any]) -> None:
        """Send a single notification"""
        try:
            notification_type = notification.get("type", "log")
            
            if notification_type == "log":
                level = notification.get("level", "info")
                message = notification.get("message", "Notification")
                
                # Process message template
                template = self.template_env.from_string(message)
                rendered_message = template.render(**context)
                
                if level == "error":
                    logger.error(rendered_message)
                elif level == "warning":
                    logger.warning(rendered_message)
                else:
                    logger.info(rendered_message)
            
            # Add more notification types as needed (email, webhook, etc.)
            
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
    
    def _register_builtin_handlers(self) -> None:
        """Register built-in action handlers"""
        
        async def log_action(params: Dict[str, Any], context: Dict[str, Any]) -> str:
            """Log message action"""
            message = params.get("message", "Log message")
            level = params.get("level", "info")
            
            if level == "error":
                logger.error(message)
            elif level == "warning":
                logger.warning(message)
            else:
                logger.info(message)
            
            return message
        
        async def wait_action(params: Dict[str, Any], context: Dict[str, Any]) -> float:
            """Wait/sleep action"""
            seconds = params.get("seconds", 1)
            await asyncio.sleep(seconds)
            return seconds
        
        async def set_variable_action(params: Dict[str, Any], context: Dict[str, Any]) -> Any:
            """Set variable action"""
            name = params.get("name")
            value = params.get("value")
            
            if name:
                context["variables"][name] = value
            
            return value
        
        async def data_save_json_action(params: Dict[str, Any], context: Dict[str, Any]) -> str:
            """Save data as JSON"""
            data = params.get("data")
            file_path = params.get("file")
            
            if file_path and data is not None:
                Path(file_path).parent.mkdir(parents=True, exist_ok=True)
                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2, default=str)
                
                return file_path
            
            return ""
        
        # Register handlers
        self.action_handlers.update({
            "log": log_action,
            "wait": wait_action,
            "set_variable": set_variable_action,
            "data.save_json": data_save_json_action
        })
    
    def register_action_handler(self, action_name: str, handler: callable) -> None:
        """Register custom action handler"""
        self.action_handlers[action_name] = handler
        logger.info(f"Registered action handler: {action_name}")
    
    def set_global_variable(self, name: str, value: Any) -> None:
        """Set global variable"""
        self.global_variables[name] = value
        logger.debug(f"Set global variable: {name} = {value}")
    
    def get_global_variables(self) -> Dict[str, Any]:
        """Get all global variables"""
        return self.global_variables.copy()
