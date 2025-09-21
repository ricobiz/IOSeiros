
"""
Control Room Integration - Integrates Control Room with main EirosAgent
"""
import asyncio
from typing import Dict, Any, Optional
from pathlib import Path
from loguru import logger

from .agent import EirosAgent
from ..control_room import ControlRoomManager


class EirosAgentWithControlRoom(EirosAgent):
    """
    Extended EirosAgent with Control Room integration
    """
    
    def __init__(self, config_path: Optional[str] = None, control_room_config: Optional[Dict[str, Any]] = None):
        """Initialize EirosAgent with Control Room"""
        super().__init__(config_path)
        
        # Control Room configuration
        self.control_room_config = control_room_config or self._load_control_room_config()
        self.control_room: Optional[ControlRoomManager] = None
        
        logger.info("EirosAgent with Control Room initialized")
    
    def _load_control_room_config(self) -> Dict[str, Any]:
        """Load Control Room configuration"""
        try:
            config_path = Path("config/control_room_config.yaml")
            if config_path.exists():
                import yaml
                with open(config_path, 'r') as f:
                    config = yaml.safe_load(f)
                return config.get('control_room', {})
            else:
                return self._get_default_control_room_config()
        except Exception as e:
            logger.error(f"Failed to load Control Room config: {e}")
            return self._get_default_control_room_config()
    
    def _get_default_control_room_config(self) -> Dict[str, Any]:
        """Get default Control Room configuration"""
        return {
            'api': {
                'host': 'localhost',
                'port': 8080
            },
            'websocket': {
                'host': 'localhost',
                'port': 8765
            },
            'monitoring': {
                'interval': 5,
                'history_size': 1000
            },
            'metrics': {
                'interval': 10,
                'max_metrics_per_type': 1000
            }
        }
    
    async def initialize(self) -> None:
        """Initialize EirosAgent and Control Room"""
        try:
            # Initialize base agent
            await super().initialize()
            
            # Initialize Control Room
            self.control_room = ControlRoomManager(self.control_room_config)
            await self.control_room.initialize()
            
            # Set up integrations
            await self._setup_control_room_integrations()
            
            # Start Control Room monitoring
            await self.control_room.start_monitoring()
            
            logger.info("EirosAgent with Control Room initialization complete")
            
        except Exception as e:
            logger.error(f"Failed to initialize EirosAgent with Control Room: {e}")
            raise
    
    async def shutdown(self) -> None:
        """Shutdown EirosAgent and Control Room"""
        logger.info("Shutting down EirosAgent with Control Room...")
        
        # Shutdown Control Room first
        if self.control_room:
            await self.control_room.shutdown()
        
        # Shutdown base agent
        await super().shutdown()
        
        logger.info("EirosAgent with Control Room shutdown complete")
    
    async def _setup_control_room_integrations(self) -> None:
        """Setup integrations between Control Room and EirosAgent components"""
        if not self.control_room:
            return
        
        # Set reference to main agent in Control Room
        self.control_room.rest_api.set_control_room_manager(self.control_room)
        
        # Register custom metrics
        await self._register_custom_metrics()
        
        # Setup task integration
        await self._setup_task_integration()
        
        # Setup notification integration
        await self._setup_notification_integration()
        
        logger.info("Control Room integrations setup complete")
    
    async def _register_custom_metrics(self) -> None:
        """Register custom metrics for Control Room"""
        if not self.control_room or not self.control_room.metrics_collector:
            return
        
        metrics_collector = self.control_room.metrics_collector
        
        # Register agent status metric
        metrics_collector.register_custom_metric(
            'agent_status',
            lambda: 'running' if self.is_initialized else 'stopped'
        )
        
        # Register component status metrics
        metrics_collector.register_custom_metric(
            'web_automation_status',
            lambda: self.web_automation.get_status() if self.web_automation else None
        )
        
        metrics_collector.register_custom_metric(
            'ocr_manager_status',
            lambda: self.ocr_manager.get_status() if self.ocr_manager else None
        )
        
        metrics_collector.register_custom_metric(
            'scheduler_status',
            lambda: self.scheduler.get_status() if self.scheduler else None
        )
        
        metrics_collector.register_custom_metric(
            'vision_manager_status',
            lambda: self.vision_manager.get_status() if self.vision_manager else None
        )
        
        logger.info("Custom metrics registered")
    
    async def _setup_task_integration(self) -> None:
        """Setup task integration between Control Room and Scheduler"""
        if not self.control_room or not self.scheduler:
            return
        
        # Override Control Room's get_active_tasks method
        async def get_active_tasks():
            try:
                # Get tasks from scheduler
                scheduler_status = self.scheduler.get_status()
                
                # Convert to Control Room format
                tasks = []
                if 'active_tasks' in scheduler_status:
                    for task_info in scheduler_status['active_tasks']:
                        tasks.append({
                            'id': task_info.get('id', 'unknown'),
                            'name': task_info.get('name', 'Unknown Task'),
                            'type': task_info.get('type', 'general'),
                            'status': task_info.get('status', 'unknown'),
                            'progress': task_info.get('progress', 0),
                            'created_at': task_info.get('created_at'),
                            'description': task_info.get('description', '')
                        })
                
                return tasks
                
            except Exception as e:
                logger.error(f"Error getting active tasks: {e}")
                return []
        
        # Replace the method
        self.control_room.get_active_tasks = get_active_tasks
        
        logger.info("Task integration setup complete")
    
    async def _setup_notification_integration(self) -> None:
        """Setup notification integration"""
        if not self.control_room:
            return
        
        # Create notification for agent initialization
        from ..control_room.models.notification import Notification
        
        init_notification = Notification.create_success(
            title="EirosAgent Initialized",
            message="EirosAgent with Control Room has been successfully initialized",
            source="eiros_agent",
            category="system"
        )
        
        self.control_room.notifications.append(init_notification)
        
        logger.info("Notification integration setup complete")
    
    async def execute_macro(self, macro_path: str, variables: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute macro with Control Room integration"""
        try:
            # Record task execution start
            if self.control_room and self.control_room.metrics_collector:
                import time
                start_time = time.time()
            
            # Execute macro using base implementation
            result = await super().execute_macro(macro_path, variables)
            
            # Record task execution time
            if self.control_room and self.control_room.metrics_collector:
                execution_time = time.time() - start_time
                self.control_room.metrics_collector.record_task_execution_time(execution_time)
                
                if result.get('status') == 'success':
                    self.control_room.metrics_collector.record_success('macro_execution')
                else:
                    self.control_room.metrics_collector.record_error('macro_execution_failed')
            
            # Create notification
            if self.control_room:
                from ..control_room.models.notification import Notification
                
                if result.get('status') == 'success':
                    notification = Notification.create_success(
                        title="Macro Executed",
                        message=f"Macro {macro_path} executed successfully",
                        source="eiros_agent",
                        category="task"
                    )
                else:
                    notification = Notification.create_error(
                        title="Macro Execution Failed",
                        message=f"Macro {macro_path} execution failed: {result.get('error', 'Unknown error')}",
                        source="eiros_agent",
                        category="task"
                    )
                
                self.control_room.notifications.append(notification)
            
            return result
            
        except Exception as e:
            # Record error
            if self.control_room and self.control_room.metrics_collector:
                self.control_room.metrics_collector.record_error('macro_execution_error')
            
            # Create error notification
            if self.control_room:
                from ..control_room.models.notification import Notification
                
                notification = Notification.create_error(
                    title="Macro Execution Error",
                    message=f"Error executing macro {macro_path}: {str(e)}",
                    source="eiros_agent",
                    category="error"
                )
                
                self.control_room.notifications.append(notification)
            
            raise
    
    async def automate_web_task(self, task_config: Dict[str, Any]) -> Dict[str, Any]:
        """Execute web automation task with Control Room integration"""
        try:
            # Record API response time start
            if self.control_room and self.control_room.metrics_collector:
                import time
                start_time = time.time()
            
            # Execute task using base implementation
            result = await super().automate_web_task(task_config)
            
            # Record API response time
            if self.control_room and self.control_room.metrics_collector:
                response_time = time.time() - start_time
                self.control_room.metrics_collector.record_api_response_time(response_time)
                
                if result.get('status') == 'success':
                    self.control_room.metrics_collector.record_success('web_automation')
                else:
                    self.control_room.metrics_collector.record_error('web_automation_failed')
            
            return result
            
        except Exception as e:
            # Record error
            if self.control_room and self.control_room.metrics_collector:
                self.control_room.metrics_collector.record_error('web_automation_error')
            
            raise
    
    def get_status(self) -> Dict[str, Any]:
        """Get comprehensive status including Control Room"""
        base_status = super().get_status()
        
        if self.control_room:
            base_status['control_room'] = self.control_room.get_status()
        
        return base_status
    
    def get_control_room_url(self) -> str:
        """Get Control Room web interface URL"""
        if self.control_room and self.control_room.rest_api:
            host = self.control_room.rest_api.host
            port = self.control_room.rest_api.port
            return f"http://{host}:{port}"
        return "http://localhost:8080"
    
    async def send_control_room_notification(self, title: str, message: str, notification_type: str = 'info') -> None:
        """Send notification to Control Room"""
        if not self.control_room:
            return
        
        from ..control_room.models.notification import Notification
        
        if notification_type == 'success':
            notification = Notification.create_success(title, message, source="eiros_agent")
        elif notification_type == 'warning':
            notification = Notification.create_warning(title, message, source="eiros_agent")
        elif notification_type == 'error':
            notification = Notification.create_error(title, message, source="eiros_agent")
        else:
            notification = Notification.create_info(title, message, source="eiros_agent")
        
        self.control_room.notifications.append(notification)
        
        # Broadcast via WebSocket if available
        if self.control_room.websocket_server:
            await self.control_room.websocket_server.broadcast({
                'type': 'notification',
                'data': notification.to_dict()
            })
