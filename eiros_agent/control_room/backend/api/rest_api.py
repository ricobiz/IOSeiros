
"""
REST API Server - HTTP endpoints for Control Room
"""
import asyncio
import json
from typing import Dict, Any, Optional, List
from datetime import datetime
from pathlib import Path
import aiohttp
from aiohttp import web, web_request, web_response
from aiohttp.web_middlewares import middleware
from loguru import logger
import traceback


class ControlRoomAPI:
    """
    REST API server for Control Room management
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize REST API server"""
        self.config = config
        self.host = config.get('host', 'localhost')
        self.port = config.get('port', 8080)
        self.is_running = False
        
        # Web application
        self.app = None
        self.runner = None
        self.site = None
        
        # Reference to control room manager (will be set externally)
        self.control_room_manager = None
        
        logger.info(f"Control Room API initialized on {self.host}:{self.port}")
    
    async def initialize(self) -> None:
        """Initialize REST API server"""
        try:
            # Create web application
            self.app = web.Application(middlewares=[
                self._cors_middleware,
                self._error_middleware,
                self._logging_middleware
            ])
            
            # Setup routes
            self._setup_routes()
            
            # Start server
            self.runner = web.AppRunner(self.app)
            await self.runner.setup()
            
            self.site = web.TCPSite(
                self.runner,
                self.host,
                self.port,
                reuse_address=True,
                reuse_port=True
            )
            
            await self.site.start()
            
            self.is_running = True
            logger.info(f"Control Room API started on http://{self.host}:{self.port}")
            
        except Exception as e:
            logger.error(f"Failed to initialize Control Room API: {e}")
            raise
    
    async def shutdown(self) -> None:
        """Shutdown REST API server"""
        logger.info("Shutting down Control Room API...")
        
        self.is_running = False
        
        if self.site:
            await self.site.stop()
        
        if self.runner:
            await self.runner.cleanup()
        
        logger.info("Control Room API shutdown complete")
    
    def set_control_room_manager(self, manager) -> None:
        """Set reference to control room manager"""
        self.control_room_manager = manager
    
    def _setup_routes(self) -> None:
        """Setup API routes"""
        # Health check
        self.app.router.add_get('/health', self._health_check)
        self.app.router.add_get('/status', self._get_status)
        
        # System monitoring
        self.app.router.add_get('/api/v1/system/metrics', self._get_system_metrics)
        self.app.router.add_get('/api/v1/system/metrics/history', self._get_system_metrics_history)
        self.app.router.add_get('/api/v1/system/status', self._get_system_status)
        
        # Application metrics
        self.app.router.add_get('/api/v1/metrics', self._get_application_metrics)
        self.app.router.add_get('/api/v1/metrics/history', self._get_application_metrics_history)
        self.app.router.add_post('/api/v1/metrics/custom', self._add_custom_metric)
        
        # Task management
        self.app.router.add_get('/api/v1/tasks', self._get_tasks)
        self.app.router.add_post('/api/v1/tasks', self._create_task)
        self.app.router.add_get('/api/v1/tasks/{task_id}', self._get_task)
        self.app.router.add_put('/api/v1/tasks/{task_id}', self._update_task)
        self.app.router.add_delete('/api/v1/tasks/{task_id}', self._delete_task)
        self.app.router.add_post('/api/v1/tasks/{task_id}/execute', self._execute_task)
        
        # Notifications
        self.app.router.add_get('/api/v1/notifications', self._get_notifications)
        self.app.router.add_post('/api/v1/notifications', self._create_notification)
        self.app.router.add_put('/api/v1/notifications/{notification_id}/read', self._mark_notification_read)
        
        # User profiles
        self.app.router.add_get('/api/v1/users/profile', self._get_user_profile)
        self.app.router.add_put('/api/v1/users/profile', self._update_user_profile)
        self.app.router.add_get('/api/v1/users/settings', self._get_user_settings)
        self.app.router.add_put('/api/v1/users/settings', self._update_user_settings)
        
        # WebSocket clients
        self.app.router.add_get('/api/v1/websocket/clients', self._get_websocket_clients)
        self.app.router.add_post('/api/v1/websocket/broadcast', self._websocket_broadcast)
        
        # Configuration
        self.app.router.add_get('/api/v1/config', self._get_config)
        self.app.router.add_put('/api/v1/config', self._update_config)
        
        # Static files (for frontend)
        static_path = Path(__file__).parent.parent.parent / 'static'
        if static_path.exists():
            self.app.router.add_static('/', static_path, name='static')
        
        # Frontend routes (SPA support)
        self.app.router.add_get('/', self._serve_frontend)
        self.app.router.add_get('/dashboard', self._serve_frontend)
        self.app.router.add_get('/tasks', self._serve_frontend)
        self.app.router.add_get('/settings', self._serve_frontend)
    
    @middleware
    async def _cors_middleware(self, request: web_request.Request, handler) -> web_response.Response:
        """CORS middleware"""
        try:
            response = await handler(request)
        except Exception as e:
            response = web.json_response(
                {'error': str(e)},
                status=500
            )
        
        # Add CORS headers
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        
        return response
    
    @middleware
    async def _error_middleware(self, request: web_request.Request, handler) -> web_response.Response:
        """Error handling middleware"""
        try:
            return await handler(request)
        except web.HTTPException:
            raise
        except Exception as e:
            logger.error(f"API error: {e}\n{traceback.format_exc()}")
            return web.json_response(
                {
                    'error': 'Internal server error',
                    'message': str(e),
                    'timestamp': datetime.utcnow().isoformat()
                },
                status=500
            )
    
    @middleware
    async def _logging_middleware(self, request: web_request.Request, handler) -> web_response.Response:
        """Request logging middleware"""
        start_time = datetime.utcnow()
        
        try:
            response = await handler(request)
            
            # Log request
            duration = (datetime.utcnow() - start_time).total_seconds()
            logger.info(f"{request.method} {request.path} - {response.status} - {duration:.3f}s")
            
            return response
        except Exception as e:
            duration = (datetime.utcnow() - start_time).total_seconds()
            logger.error(f"{request.method} {request.path} - ERROR - {duration:.3f}s - {e}")
            raise
    
    # Health and status endpoints
    async def _health_check(self, request: web_request.Request) -> web_response.Response:
        """Health check endpoint"""
        return web.json_response({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0'
        })
    
    async def _get_status(self, request: web_request.Request) -> web_response.Response:
        """Get overall system status"""
        try:
            status = {
                'api': {
                    'running': self.is_running,
                    'host': self.host,
                    'port': self.port
                },
                'timestamp': datetime.utcnow().isoformat()
            }
            
            if self.control_room_manager:
                status['control_room'] = self.control_room_manager.get_status()
            
            return web.json_response(status)
            
        except Exception as e:
            logger.error(f"Error getting status: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # System monitoring endpoints
    async def _get_system_metrics(self, request: web_request.Request) -> web_response.Response:
        """Get current system metrics"""
        try:
            if not self.control_room_manager or not self.control_room_manager.system_monitor:
                return web.json_response({'error': 'System monitor not available'}, status=503)
            
            metrics = await self.control_room_manager.system_monitor.collect_metrics()
            return web.json_response(metrics)
            
        except Exception as e:
            logger.error(f"Error getting system metrics: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _get_system_metrics_history(self, request: web_request.Request) -> web_response.Response:
        """Get system metrics history"""
        try:
            if not self.control_room_manager or not self.control_room_manager.system_monitor:
                return web.json_response({'error': 'System monitor not available'}, status=503)
            
            time_range = request.query.get('time_range', '1h')
            metrics = await self.control_room_manager.system_monitor.get_historical_metrics(time_range)
            
            return web.json_response({
                'time_range': time_range,
                'metrics': metrics,
                'count': len(metrics)
            })
            
        except Exception as e:
            logger.error(f"Error getting system metrics history: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _get_system_status(self, request: web_request.Request) -> web_response.Response:
        """Get system status"""
        try:
            if not self.control_room_manager or not self.control_room_manager.system_monitor:
                return web.json_response({'error': 'System monitor not available'}, status=503)
            
            status = await self.control_room_manager.system_monitor.get_current_status()
            return web.json_response(status)
            
        except Exception as e:
            logger.error(f"Error getting system status: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # Application metrics endpoints
    async def _get_application_metrics(self, request: web_request.Request) -> web_response.Response:
        """Get current application metrics"""
        try:
            if not self.control_room_manager or not self.control_room_manager.metrics_collector:
                return web.json_response({'error': 'Metrics collector not available'}, status=503)
            
            metrics = await self.control_room_manager.metrics_collector.collect_application_metrics()
            return web.json_response(metrics)
            
        except Exception as e:
            logger.error(f"Error getting application metrics: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _get_application_metrics_history(self, request: web_request.Request) -> web_response.Response:
        """Get application metrics history"""
        try:
            if not self.control_room_manager or not self.control_room_manager.metrics_collector:
                return web.json_response({'error': 'Metrics collector not available'}, status=503)
            
            metric_type = request.query.get('type', 'application')
            time_range = request.query.get('time_range', '1h')
            
            metrics = await self.control_room_manager.metrics_collector.get_historical_metrics(
                metric_type, time_range
            )
            
            return web.json_response({
                'metric_type': metric_type,
                'time_range': time_range,
                'metrics': metrics,
                'count': len(metrics)
            })
            
        except Exception as e:
            logger.error(f"Error getting application metrics history: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _add_custom_metric(self, request: web_request.Request) -> web_response.Response:
        """Add custom metric"""
        try:
            if not self.control_room_manager or not self.control_room_manager.metrics_collector:
                return web.json_response({'error': 'Metrics collector not available'}, status=503)
            
            data = await request.json()
            metric_name = data.get('name')
            metric_value = data.get('value')
            
            if not metric_name:
                return web.json_response({'error': 'Metric name required'}, status=400)
            
            # Register custom metric
            self.control_room_manager.metrics_collector.register_custom_metric(
                metric_name, lambda: metric_value
            )
            
            return web.json_response({
                'message': f'Custom metric {metric_name} added',
                'name': metric_name,
                'value': metric_value
            })
            
        except Exception as e:
            logger.error(f"Error adding custom metric: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # Task management endpoints
    async def _get_tasks(self, request: web_request.Request) -> web_response.Response:
        """Get all tasks"""
        try:
            if not self.control_room_manager:
                return web.json_response({'error': 'Control room manager not available'}, status=503)
            
            tasks = await self.control_room_manager.get_active_tasks()
            return web.json_response({'tasks': tasks})
            
        except Exception as e:
            logger.error(f"Error getting tasks: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _create_task(self, request: web_request.Request) -> web_response.Response:
        """Create new task"""
        try:
            data = await request.json()
            
            # Validate task data
            if not data.get('name'):
                return web.json_response({'error': 'Task name required'}, status=400)
            
            # Create task (this would integrate with the scheduler)
            task_id = f"task_{datetime.utcnow().timestamp()}"
            
            return web.json_response({
                'message': 'Task created',
                'task_id': task_id,
                'task': data
            }, status=201)
            
        except Exception as e:
            logger.error(f"Error creating task: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _get_task(self, request: web_request.Request) -> web_response.Response:
        """Get specific task"""
        try:
            task_id = request.match_info['task_id']
            
            # Get task details (placeholder)
            task = {
                'id': task_id,
                'name': f'Task {task_id}',
                'status': 'active',
                'created_at': datetime.utcnow().isoformat()
            }
            
            return web.json_response({'task': task})
            
        except Exception as e:
            logger.error(f"Error getting task: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _update_task(self, request: web_request.Request) -> web_response.Response:
        """Update task"""
        try:
            task_id = request.match_info['task_id']
            data = await request.json()
            
            return web.json_response({
                'message': f'Task {task_id} updated',
                'task_id': task_id,
                'updates': data
            })
            
        except Exception as e:
            logger.error(f"Error updating task: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _delete_task(self, request: web_request.Request) -> web_response.Response:
        """Delete task"""
        try:
            task_id = request.match_info['task_id']
            
            return web.json_response({
                'message': f'Task {task_id} deleted',
                'task_id': task_id
            })
            
        except Exception as e:
            logger.error(f"Error deleting task: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _execute_task(self, request: web_request.Request) -> web_response.Response:
        """Execute task"""
        try:
            task_id = request.match_info['task_id']
            
            return web.json_response({
                'message': f'Task {task_id} execution started',
                'task_id': task_id,
                'status': 'executing'
            })
            
        except Exception as e:
            logger.error(f"Error executing task: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # Notification endpoints
    async def _get_notifications(self, request: web_request.Request) -> web_response.Response:
        """Get notifications"""
        try:
            if not self.control_room_manager:
                return web.json_response({'error': 'Control room manager not available'}, status=503)
            
            notifications = [n.to_dict() for n in self.control_room_manager.notifications]
            
            return web.json_response({
                'notifications': notifications,
                'count': len(notifications)
            })
            
        except Exception as e:
            logger.error(f"Error getting notifications: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _create_notification(self, request: web_request.Request) -> web_response.Response:
        """Create notification"""
        try:
            data = await request.json()
            
            # Validate notification data
            if not data.get('message'):
                return web.json_response({'error': 'Notification message required'}, status=400)
            
            notification_id = f"notification_{datetime.utcnow().timestamp()}"
            
            return web.json_response({
                'message': 'Notification created',
                'notification_id': notification_id,
                'notification': data
            }, status=201)
            
        except Exception as e:
            logger.error(f"Error creating notification: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _mark_notification_read(self, request: web_request.Request) -> web_response.Response:
        """Mark notification as read"""
        try:
            notification_id = request.match_info['notification_id']
            
            return web.json_response({
                'message': f'Notification {notification_id} marked as read',
                'notification_id': notification_id
            })
            
        except Exception as e:
            logger.error(f"Error marking notification as read: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # User profile endpoints
    async def _get_user_profile(self, request: web_request.Request) -> web_response.Response:
        """Get user profile"""
        try:
            # Placeholder user profile
            profile = {
                'id': 'user_1',
                'name': 'Control Room User',
                'email': 'user@example.com',
                'role': 'admin',
                'created_at': datetime.utcnow().isoformat()
            }
            
            return web.json_response({'profile': profile})
            
        except Exception as e:
            logger.error(f"Error getting user profile: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _update_user_profile(self, request: web_request.Request) -> web_response.Response:
        """Update user profile"""
        try:
            data = await request.json()
            
            return web.json_response({
                'message': 'User profile updated',
                'updates': data
            })
            
        except Exception as e:
            logger.error(f"Error updating user profile: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _get_user_settings(self, request: web_request.Request) -> web_response.Response:
        """Get user settings"""
        try:
            # Placeholder settings
            settings = {
                'theme': 'dark',
                'notifications_enabled': True,
                'refresh_interval': 5,
                'dashboard_layout': 'default'
            }
            
            return web.json_response({'settings': settings})
            
        except Exception as e:
            logger.error(f"Error getting user settings: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _update_user_settings(self, request: web_request.Request) -> web_response.Response:
        """Update user settings"""
        try:
            data = await request.json()
            
            return web.json_response({
                'message': 'User settings updated',
                'settings': data
            })
            
        except Exception as e:
            logger.error(f"Error updating user settings: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # WebSocket endpoints
    async def _get_websocket_clients(self, request: web_request.Request) -> web_response.Response:
        """Get WebSocket clients"""
        try:
            if not self.control_room_manager or not self.control_room_manager.websocket_server:
                return web.json_response({'error': 'WebSocket server not available'}, status=503)
            
            clients = self.control_room_manager.websocket_server.get_connected_clients()
            rooms = self.control_room_manager.websocket_server.get_rooms()
            
            return web.json_response({
                'clients': clients,
                'rooms': rooms,
                'total_clients': len(clients)
            })
            
        except Exception as e:
            logger.error(f"Error getting WebSocket clients: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _websocket_broadcast(self, request: web_request.Request) -> web_response.Response:
        """Broadcast message via WebSocket"""
        try:
            if not self.control_room_manager or not self.control_room_manager.websocket_server:
                return web.json_response({'error': 'WebSocket server not available'}, status=503)
            
            data = await request.json()
            message = data.get('message')
            
            if not message:
                return web.json_response({'error': 'Message required'}, status=400)
            
            sent_count = await self.control_room_manager.websocket_server.broadcast(message)
            
            return web.json_response({
                'message': 'Broadcast sent',
                'sent_to_clients': sent_count
            })
            
        except Exception as e:
            logger.error(f"Error broadcasting WebSocket message: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # Configuration endpoints
    async def _get_config(self, request: web_request.Request) -> web_response.Response:
        """Get configuration"""
        try:
            # Return safe configuration (no sensitive data)
            safe_config = {
                'api': {
                    'host': self.host,
                    'port': self.port
                },
                'monitoring': {
                    'interval': self.config.get('monitoring_interval', 5),
                    'history_size': self.config.get('history_size', 1000)
                }
            }
            
            return web.json_response({'config': safe_config})
            
        except Exception as e:
            logger.error(f"Error getting config: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def _update_config(self, request: web_request.Request) -> web_response.Response:
        """Update configuration"""
        try:
            data = await request.json()
            
            # Update configuration (implement proper validation)
            return web.json_response({
                'message': 'Configuration updated',
                'updates': data
            })
            
        except Exception as e:
            logger.error(f"Error updating config: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    # Frontend serving
    async def _serve_frontend(self, request: web_request.Request) -> web_response.Response:
        """Serve frontend application"""
        try:
            static_path = Path(__file__).parent.parent.parent / 'static'
            index_path = static_path / 'index.html'
            
            if index_path.exists():
                return web.FileResponse(index_path)
            else:
                # Return basic HTML if no frontend is built
                html_content = """
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Eiros Agent Control Room</title>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                </head>
                <body>
                    <h1>Eiros Agent Control Room</h1>
                    <p>Control Room interface is starting up...</p>
                    <p>API is available at <a href="/api/v1/status">/api/v1/status</a></p>
                </body>
                </html>
                """
                return web.Response(text=html_content, content_type='text/html')
                
        except Exception as e:
            logger.error(f"Error serving frontend: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    def get_status(self) -> Dict[str, Any]:
        """Get API server status"""
        return {
            'running': self.is_running,
            'host': self.host,
            'port': self.port,
            'routes_count': len(self.app.router.routes()) if self.app else 0
        }
