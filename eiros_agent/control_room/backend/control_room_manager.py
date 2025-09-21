
"""
Control Room Manager - Main orchestrator for the control room interface
"""
import asyncio
from typing import Dict, Any, Optional, List
from pathlib import Path
import json
from datetime import datetime
from loguru import logger

from .monitoring.system_monitor import SystemMonitor
from .monitoring.metrics_collector import MetricsCollector
from .websocket.websocket_server import WebSocketServer
from .api.rest_api import ControlRoomAPI
from ..models.user_profile import UserProfile
from ..models.notification import Notification


class ControlRoomManager:
    """
    Main Control Room Manager that coordinates all control room components
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize Control Room Manager"""
        self.config = config
        self.is_running = False
        
        # Initialize components
        self.system_monitor = SystemMonitor(config.get('monitoring', {}))
        self.metrics_collector = MetricsCollector(config.get('metrics', {}))
        self.websocket_server = WebSocketServer(config.get('websocket', {}))
        self.rest_api = ControlRoomAPI(config.get('api', {}))
        
        # User management
        self.user_profiles: Dict[str, UserProfile] = {}
        self.active_sessions: Dict[str, Dict[str, Any]] = {}
        
        # Notifications
        self.notifications: List[Notification] = []
        self.notification_handlers = {}
        
        logger.info("Control Room Manager initialized")
    
    async def initialize(self) -> None:
        """Initialize all control room components"""
        try:
            logger.info("Initializing Control Room components...")
            
            # Initialize monitoring
            await self.system_monitor.initialize()
            await self.metrics_collector.initialize()
            
            # Initialize communication
            await self.websocket_server.initialize()
            await self.rest_api.initialize()
            
            # Load user profiles
            await self._load_user_profiles()
            
            # Setup event handlers
            self._setup_event_handlers()
            
            self.is_running = True
            logger.info("Control Room initialization complete")
            
        except Exception as e:
            logger.error(f"Failed to initialize Control Room: {e}")
            raise
    
    async def shutdown(self) -> None:
        """Shutdown all control room components"""
        logger.info("Shutting down Control Room...")
        
        self.is_running = False
        
        # Shutdown components
        if self.websocket_server:
            await self.websocket_server.shutdown()
        if self.rest_api:
            await self.rest_api.shutdown()
        if self.system_monitor:
            await self.system_monitor.shutdown()
        if self.metrics_collector:
            await self.metrics_collector.shutdown()
        
        # Save user profiles
        await self._save_user_profiles()
        
        logger.info("Control Room shutdown complete")
    
    async def start_monitoring(self) -> None:
        """Start real-time monitoring"""
        if not self.is_running:
            raise RuntimeError("Control Room not initialized")
        
        logger.info("Starting real-time monitoring...")
        
        # Start monitoring tasks
        asyncio.create_task(self._monitoring_loop())
        asyncio.create_task(self._metrics_collection_loop())
        asyncio.create_task(self._notification_processing_loop())
        
        logger.info("Real-time monitoring started")
    
    async def _monitoring_loop(self) -> None:
        """Main monitoring loop"""
        while self.is_running:
            try:
                # Collect system metrics
                metrics = await self.system_monitor.collect_metrics()
                
                # Process metrics
                processed_metrics = await self.metrics_collector.process_metrics(metrics)
                
                # Broadcast to connected clients
                await self.websocket_server.broadcast({
                    'type': 'system_metrics',
                    'data': processed_metrics,
                    'timestamp': datetime.utcnow().isoformat()
                })
                
                # Check for alerts
                alerts = await self._check_alerts(processed_metrics)
                if alerts:
                    await self._handle_alerts(alerts)
                
                await asyncio.sleep(self.config.get('monitoring_interval', 5))
                
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                await asyncio.sleep(1)
    
    async def _metrics_collection_loop(self) -> None:
        """Metrics collection and aggregation loop"""
        while self.is_running:
            try:
                # Collect application metrics
                app_metrics = await self.metrics_collector.collect_application_metrics()
                
                # Store metrics
                await self.metrics_collector.store_metrics(app_metrics)
                
                # Broadcast to clients
                await self.websocket_server.broadcast({
                    'type': 'application_metrics',
                    'data': app_metrics,
                    'timestamp': datetime.utcnow().isoformat()
                })
                
                await asyncio.sleep(self.config.get('metrics_interval', 10))
                
            except Exception as e:
                logger.error(f"Error in metrics collection loop: {e}")
                await asyncio.sleep(1)
    
    async def _notification_processing_loop(self) -> None:
        """Process and send notifications"""
        while self.is_running:
            try:
                # Process pending notifications
                pending_notifications = [n for n in self.notifications if not n.sent]
                
                for notification in pending_notifications:
                    await self._send_notification(notification)
                
                await asyncio.sleep(self.config.get('notification_interval', 2))
                
            except Exception as e:
                logger.error(f"Error in notification processing loop: {e}")
                await asyncio.sleep(1)
    
    async def _check_alerts(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Check metrics for alert conditions"""
        alerts = []
        
        # CPU usage alert
        if metrics.get('cpu_percent', 0) > self.config.get('cpu_alert_threshold', 80):
            alerts.append({
                'type': 'cpu_high',
                'severity': 'warning',
                'message': f"High CPU usage: {metrics['cpu_percent']:.1f}%",
                'value': metrics['cpu_percent']
            })
        
        # Memory usage alert
        if metrics.get('memory_percent', 0) > self.config.get('memory_alert_threshold', 85):
            alerts.append({
                'type': 'memory_high',
                'severity': 'warning',
                'message': f"High memory usage: {metrics['memory_percent']:.1f}%",
                'value': metrics['memory_percent']
            })
        
        # Disk usage alert
        if metrics.get('disk_percent', 0) > self.config.get('disk_alert_threshold', 90):
            alerts.append({
                'type': 'disk_high',
                'severity': 'critical',
                'message': f"High disk usage: {metrics['disk_percent']:.1f}%",
                'value': metrics['disk_percent']
            })
        
        return alerts
    
    async def _handle_alerts(self, alerts: List[Dict[str, Any]]) -> None:
        """Handle system alerts"""
        for alert in alerts:
            notification = Notification(
                id=f"alert_{datetime.utcnow().timestamp()}",
                type='alert',
                severity=alert['severity'],
                title=f"System Alert: {alert['type']}",
                message=alert['message'],
                data=alert,
                timestamp=datetime.utcnow()
            )
            
            self.notifications.append(notification)
            
            # Broadcast alert immediately
            await self.websocket_server.broadcast({
                'type': 'alert',
                'data': alert,
                'timestamp': datetime.utcnow().isoformat()
            })
    
    async def _send_notification(self, notification: Notification) -> None:
        """Send notification to appropriate channels"""
        try:
            # Send via WebSocket
            await self.websocket_server.broadcast({
                'type': 'notification',
                'data': notification.to_dict(),
                'timestamp': datetime.utcnow().isoformat()
            })
            
            notification.sent = True
            notification.sent_at = datetime.utcnow()
            
        except Exception as e:
            logger.error(f"Failed to send notification {notification.id}: {e}")
    
    def _setup_event_handlers(self) -> None:
        """Setup event handlers for various components"""
        # WebSocket event handlers
        self.websocket_server.on('client_connected', self._on_client_connected)
        self.websocket_server.on('client_disconnected', self._on_client_disconnected)
        self.websocket_server.on('client_message', self._on_client_message)
    
    async def _on_client_connected(self, client_id: str, client_info: Dict[str, Any]) -> None:
        """Handle client connection"""
        logger.info(f"Client connected: {client_id}")
        
        # Send initial data to client
        initial_data = {
            'type': 'initial_data',
            'data': {
                'system_status': await self.system_monitor.get_current_status(),
                'active_tasks': await self.get_active_tasks(),
                'recent_notifications': [n.to_dict() for n in self.notifications[-10:]]
            },
            'timestamp': datetime.utcnow().isoformat()
        }
        
        await self.websocket_server.send_to_client(client_id, initial_data)
    
    async def _on_client_disconnected(self, client_id: str) -> None:
        """Handle client disconnection"""
        logger.info(f"Client disconnected: {client_id}")
        
        # Clean up session data
        if client_id in self.active_sessions:
            del self.active_sessions[client_id]
    
    async def _on_client_message(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle client messages"""
        try:
            message_type = message.get('type')
            
            if message_type == 'get_metrics':
                await self._handle_get_metrics_request(client_id, message)
            elif message_type == 'execute_task':
                await self._handle_execute_task_request(client_id, message)
            elif message_type == 'update_settings':
                await self._handle_update_settings_request(client_id, message)
            else:
                logger.warning(f"Unknown message type from {client_id}: {message_type}")
                
        except Exception as e:
            logger.error(f"Error handling client message from {client_id}: {e}")
    
    async def _handle_get_metrics_request(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle metrics request from client"""
        metrics_type = message.get('metrics_type', 'system')
        time_range = message.get('time_range', '1h')
        
        if metrics_type == 'system':
            metrics = await self.system_monitor.get_historical_metrics(time_range)
        else:
            metrics = await self.metrics_collector.get_historical_metrics(metrics_type, time_range)
        
        response = {
            'type': 'metrics_response',
            'request_id': message.get('request_id'),
            'data': metrics,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        await self.websocket_server.send_to_client(client_id, response)
    
    async def _handle_execute_task_request(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle task execution request from client"""
        task_config = message.get('task_config')
        
        if not task_config:
            await self.websocket_server.send_to_client(client_id, {
                'type': 'error',
                'message': 'Task configuration required',
                'request_id': message.get('request_id')
            })
            return
        
        # Execute task (this would integrate with the existing scheduler)
        # For now, just acknowledge the request
        response = {
            'type': 'task_response',
            'request_id': message.get('request_id'),
            'status': 'accepted',
            'message': 'Task execution started',
            'timestamp': datetime.utcnow().isoformat()
        }
        
        await self.websocket_server.send_to_client(client_id, response)
    
    async def _handle_update_settings_request(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle settings update request from client"""
        settings = message.get('settings')
        
        if settings:
            # Update configuration (implement proper validation)
            self.config.update(settings)
            
            response = {
                'type': 'settings_response',
                'request_id': message.get('request_id'),
                'status': 'success',
                'message': 'Settings updated',
                'timestamp': datetime.utcnow().isoformat()
            }
        else:
            response = {
                'type': 'error',
                'request_id': message.get('request_id'),
                'message': 'Settings data required'
            }
        
        await self.websocket_server.send_to_client(client_id, response)
    
    async def get_active_tasks(self) -> List[Dict[str, Any]]:
        """Get list of active tasks"""
        # This would integrate with the existing scheduler
        return []
    
    async def _load_user_profiles(self) -> None:
        """Load user profiles from storage"""
        try:
            profiles_path = Path(self.config.get('profiles_path', './data/user_profiles.json'))
            if profiles_path.exists():
                with open(profiles_path, 'r') as f:
                    profiles_data = json.load(f)
                    
                for profile_data in profiles_data:
                    profile = UserProfile.from_dict(profile_data)
                    self.user_profiles[profile.id] = profile
                    
                logger.info(f"Loaded {len(self.user_profiles)} user profiles")
        except Exception as e:
            logger.error(f"Failed to load user profiles: {e}")
    
    async def _save_user_profiles(self) -> None:
        """Save user profiles to storage"""
        try:
            profiles_path = Path(self.config.get('profiles_path', './data/user_profiles.json'))
            profiles_path.parent.mkdir(parents=True, exist_ok=True)
            
            profiles_data = [profile.to_dict() for profile in self.user_profiles.values()]
            
            with open(profiles_path, 'w') as f:
                json.dump(profiles_data, f, indent=2)
                
            logger.info(f"Saved {len(self.user_profiles)} user profiles")
        except Exception as e:
            logger.error(f"Failed to save user profiles: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get current control room status"""
        return {
            'running': self.is_running,
            'active_sessions': len(self.active_sessions),
            'total_notifications': len(self.notifications),
            'user_profiles': len(self.user_profiles),
            'components': {
                'system_monitor': self.system_monitor.get_status() if self.system_monitor else None,
                'metrics_collector': self.metrics_collector.get_status() if self.metrics_collector else None,
                'websocket_server': self.websocket_server.get_status() if self.websocket_server else None,
                'rest_api': self.rest_api.get_status() if self.rest_api else None
            }
        }
