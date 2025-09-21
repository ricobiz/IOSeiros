
"""
WebSocket Server - Real-time communication for Control Room
"""
import asyncio
import json
import uuid
from typing import Dict, Any, List, Optional, Callable, Set
from datetime import datetime
import websockets
from websockets.server import WebSocketServerProtocol
from loguru import logger


class WebSocketServer:
    """
    WebSocket server for real-time communication with Control Room clients
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize WebSocket Server"""
        self.config = config
        self.host = config.get('host', 'localhost')
        self.port = config.get('port', 8765)
        self.is_running = False
        
        # Client management
        self.clients: Dict[str, WebSocketServerProtocol] = {}
        self.client_info: Dict[str, Dict[str, Any]] = {}
        self.rooms: Dict[str, Set[str]] = {}
        
        # Event handlers
        self.event_handlers: Dict[str, List[Callable]] = {}
        
        # Server instance
        self.server = None
        
        logger.info(f"WebSocket Server initialized on {self.host}:{self.port}")
    
    async def initialize(self) -> None:
        """Initialize WebSocket server"""
        try:
            # Start WebSocket server
            self.server = await websockets.serve(
                self._handle_client,
                self.host,
                self.port,
                ping_interval=self.config.get('ping_interval', 20),
                ping_timeout=self.config.get('ping_timeout', 10),
                max_size=self.config.get('max_message_size', 1024 * 1024),  # 1MB
                max_queue=self.config.get('max_queue_size', 32)
            )
            
            self.is_running = True
            logger.info(f"WebSocket Server started on ws://{self.host}:{self.port}")
            
        except Exception as e:
            logger.error(f"Failed to initialize WebSocket Server: {e}")
            raise
    
    async def shutdown(self) -> None:
        """Shutdown WebSocket server"""
        logger.info("Shutting down WebSocket Server...")
        
        self.is_running = False
        
        # Close all client connections
        if self.clients:
            await asyncio.gather(
                *[client.close() for client in self.clients.values()],
                return_exceptions=True
            )
        
        # Stop server
        if self.server:
            self.server.close()
            await self.server.wait_closed()
        
        logger.info("WebSocket Server shutdown complete")
    
    async def _handle_client(self, websocket: WebSocketServerProtocol, path: str) -> None:
        """Handle new client connection"""
        client_id = str(uuid.uuid4())
        
        try:
            # Register client
            self.clients[client_id] = websocket
            self.client_info[client_id] = {
                'connected_at': datetime.utcnow().isoformat(),
                'remote_address': websocket.remote_address,
                'path': path,
                'user_agent': websocket.request_headers.get('User-Agent', 'Unknown'),
                'rooms': set()
            }
            
            logger.info(f"Client {client_id} connected from {websocket.remote_address}")
            
            # Trigger connection event
            await self._trigger_event('client_connected', client_id, self.client_info[client_id])
            
            # Send welcome message
            await self.send_to_client(client_id, {
                'type': 'connection_established',
                'client_id': client_id,
                'server_time': datetime.utcnow().isoformat(),
                'message': 'Connected to Control Room WebSocket Server'
            })
            
            # Handle client messages
            async for message in websocket:
                try:
                    await self._handle_message(client_id, message)
                except Exception as e:
                    logger.error(f"Error handling message from {client_id}: {e}")
                    await self.send_to_client(client_id, {
                        'type': 'error',
                        'message': f'Error processing message: {str(e)}'
                    })
        
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"Client {client_id} disconnected")
        except Exception as e:
            logger.error(f"Error handling client {client_id}: {e}")
        finally:
            # Clean up client
            await self._cleanup_client(client_id)
    
    async def _handle_message(self, client_id: str, raw_message: str) -> None:
        """Handle message from client"""
        try:
            # Parse JSON message
            message = json.loads(raw_message)
            
            # Add metadata
            message['client_id'] = client_id
            message['received_at'] = datetime.utcnow().isoformat()
            
            # Log message (excluding sensitive data)
            log_message = {k: v for k, v in message.items() if k not in ['password', 'token', 'auth']}
            logger.debug(f"Received message from {client_id}: {log_message}")
            
            # Handle different message types
            message_type = message.get('type')
            
            if message_type == 'ping':
                await self._handle_ping(client_id, message)
            elif message_type == 'join_room':
                await self._handle_join_room(client_id, message)
            elif message_type == 'leave_room':
                await self._handle_leave_room(client_id, message)
            elif message_type == 'subscribe':
                await self._handle_subscribe(client_id, message)
            elif message_type == 'unsubscribe':
                await self._handle_unsubscribe(client_id, message)
            else:
                # Trigger generic message event
                await self._trigger_event('client_message', client_id, message)
        
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON from {client_id}: {e}")
            await self.send_to_client(client_id, {
                'type': 'error',
                'message': 'Invalid JSON format'
            })
        except Exception as e:
            logger.error(f"Error processing message from {client_id}: {e}")
            await self.send_to_client(client_id, {
                'type': 'error',
                'message': f'Error processing message: {str(e)}'
            })
    
    async def _handle_ping(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle ping message"""
        await self.send_to_client(client_id, {
            'type': 'pong',
            'timestamp': datetime.utcnow().isoformat(),
            'original_timestamp': message.get('timestamp')
        })
    
    async def _handle_join_room(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle room join request"""
        room_name = message.get('room')
        
        if not room_name:
            await self.send_to_client(client_id, {
                'type': 'error',
                'message': 'Room name required'
            })
            return
        
        # Add client to room
        if room_name not in self.rooms:
            self.rooms[room_name] = set()
        
        self.rooms[room_name].add(client_id)
        self.client_info[client_id]['rooms'].add(room_name)
        
        logger.info(f"Client {client_id} joined room {room_name}")
        
        await self.send_to_client(client_id, {
            'type': 'room_joined',
            'room': room_name,
            'message': f'Joined room {room_name}'
        })
        
        # Notify other clients in the room
        await self.broadcast_to_room(room_name, {
            'type': 'user_joined_room',
            'client_id': client_id,
            'room': room_name
        }, exclude_client=client_id)
    
    async def _handle_leave_room(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle room leave request"""
        room_name = message.get('room')
        
        if not room_name:
            await self.send_to_client(client_id, {
                'type': 'error',
                'message': 'Room name required'
            })
            return
        
        # Remove client from room
        if room_name in self.rooms:
            self.rooms[room_name].discard(client_id)
            if not self.rooms[room_name]:  # Remove empty room
                del self.rooms[room_name]
        
        self.client_info[client_id]['rooms'].discard(room_name)
        
        logger.info(f"Client {client_id} left room {room_name}")
        
        await self.send_to_client(client_id, {
            'type': 'room_left',
            'room': room_name,
            'message': f'Left room {room_name}'
        })
        
        # Notify other clients in the room
        if room_name in self.rooms:
            await self.broadcast_to_room(room_name, {
                'type': 'user_left_room',
                'client_id': client_id,
                'room': room_name
            })
    
    async def _handle_subscribe(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle subscription request"""
        subscription_type = message.get('subscription_type')
        
        if not subscription_type:
            await self.send_to_client(client_id, {
                'type': 'error',
                'message': 'Subscription type required'
            })
            return
        
        # Add subscription to client info
        if 'subscriptions' not in self.client_info[client_id]:
            self.client_info[client_id]['subscriptions'] = set()
        
        self.client_info[client_id]['subscriptions'].add(subscription_type)
        
        await self.send_to_client(client_id, {
            'type': 'subscribed',
            'subscription_type': subscription_type,
            'message': f'Subscribed to {subscription_type}'
        })
        
        logger.info(f"Client {client_id} subscribed to {subscription_type}")
    
    async def _handle_unsubscribe(self, client_id: str, message: Dict[str, Any]) -> None:
        """Handle unsubscription request"""
        subscription_type = message.get('subscription_type')
        
        if not subscription_type:
            await self.send_to_client(client_id, {
                'type': 'error',
                'message': 'Subscription type required'
            })
            return
        
        # Remove subscription from client info
        if 'subscriptions' in self.client_info[client_id]:
            self.client_info[client_id]['subscriptions'].discard(subscription_type)
        
        await self.send_to_client(client_id, {
            'type': 'unsubscribed',
            'subscription_type': subscription_type,
            'message': f'Unsubscribed from {subscription_type}'
        })
        
        logger.info(f"Client {client_id} unsubscribed from {subscription_type}")
    
    async def _cleanup_client(self, client_id: str) -> None:
        """Clean up client data"""
        try:
            # Remove from rooms
            if client_id in self.client_info:
                for room_name in self.client_info[client_id].get('rooms', set()):
                    if room_name in self.rooms:
                        self.rooms[room_name].discard(client_id)
                        if not self.rooms[room_name]:  # Remove empty room
                            del self.rooms[room_name]
            
            # Remove client data
            self.clients.pop(client_id, None)
            client_info = self.client_info.pop(client_id, None)
            
            # Trigger disconnection event
            if client_info:
                await self._trigger_event('client_disconnected', client_id)
            
            logger.info(f"Cleaned up client {client_id}")
            
        except Exception as e:
            logger.error(f"Error cleaning up client {client_id}: {e}")
    
    async def send_to_client(self, client_id: str, message: Dict[str, Any]) -> bool:
        """Send message to specific client"""
        try:
            if client_id not in self.clients:
                logger.warning(f"Client {client_id} not found")
                return False
            
            websocket = self.clients[client_id]
            
            # Add server timestamp
            message['server_timestamp'] = datetime.utcnow().isoformat()
            
            # Send message
            await websocket.send(json.dumps(message))
            return True
            
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"Client {client_id} connection closed")
            await self._cleanup_client(client_id)
            return False
        except Exception as e:
            logger.error(f"Error sending message to {client_id}: {e}")
            return False
    
    async def broadcast(self, message: Dict[str, Any], exclude_client: Optional[str] = None) -> int:
        """Broadcast message to all connected clients"""
        sent_count = 0
        
        # Add server timestamp
        message['server_timestamp'] = datetime.utcnow().isoformat()
        
        # Send to all clients
        for client_id in list(self.clients.keys()):
            if exclude_client and client_id == exclude_client:
                continue
            
            if await self.send_to_client(client_id, message):
                sent_count += 1
        
        return sent_count
    
    async def broadcast_to_room(self, room_name: str, message: Dict[str, Any], exclude_client: Optional[str] = None) -> int:
        """Broadcast message to all clients in a room"""
        sent_count = 0
        
        if room_name not in self.rooms:
            return 0
        
        # Add server timestamp
        message['server_timestamp'] = datetime.utcnow().isoformat()
        
        # Send to all clients in room
        for client_id in list(self.rooms[room_name]):
            if exclude_client and client_id == exclude_client:
                continue
            
            if await self.send_to_client(client_id, message):
                sent_count += 1
        
        return sent_count
    
    async def broadcast_to_subscribers(self, subscription_type: str, message: Dict[str, Any]) -> int:
        """Broadcast message to clients subscribed to a specific type"""
        sent_count = 0
        
        # Add server timestamp
        message['server_timestamp'] = datetime.utcnow().isoformat()
        
        # Send to subscribed clients
        for client_id, client_info in self.client_info.items():
            subscriptions = client_info.get('subscriptions', set())
            if subscription_type in subscriptions:
                if await self.send_to_client(client_id, message):
                    sent_count += 1
        
        return sent_count
    
    def on(self, event: str, handler: Callable) -> None:
        """Register event handler"""
        if event not in self.event_handlers:
            self.event_handlers[event] = []
        
        self.event_handlers[event].append(handler)
        logger.info(f"Registered handler for event: {event}")
    
    def off(self, event: str, handler: Callable) -> None:
        """Unregister event handler"""
        if event in self.event_handlers:
            try:
                self.event_handlers[event].remove(handler)
                logger.info(f"Unregistered handler for event: {event}")
            except ValueError:
                pass
    
    async def _trigger_event(self, event: str, *args, **kwargs) -> None:
        """Trigger event handlers"""
        if event in self.event_handlers:
            for handler in self.event_handlers[event]:
                try:
                    if asyncio.iscoroutinefunction(handler):
                        await handler(*args, **kwargs)
                    else:
                        handler(*args, **kwargs)
                except Exception as e:
                    logger.error(f"Error in event handler for {event}: {e}")
    
    def get_connected_clients(self) -> List[Dict[str, Any]]:
        """Get list of connected clients"""
        return [
            {
                'client_id': client_id,
                'connected_at': info['connected_at'],
                'remote_address': info['remote_address'],
                'rooms': list(info['rooms']),
                'subscriptions': list(info.get('subscriptions', set()))
            }
            for client_id, info in self.client_info.items()
        ]
    
    def get_rooms(self) -> Dict[str, List[str]]:
        """Get list of rooms and their clients"""
        return {
            room_name: list(client_ids)
            for room_name, client_ids in self.rooms.items()
        }
    
    def get_status(self) -> Dict[str, Any]:
        """Get server status"""
        return {
            'running': self.is_running,
            'host': self.host,
            'port': self.port,
            'connected_clients': len(self.clients),
            'active_rooms': len(self.rooms),
            'total_connections': len(self.client_info),
            'event_handlers': {event: len(handlers) for event, handlers in self.event_handlers.items()}
        }
