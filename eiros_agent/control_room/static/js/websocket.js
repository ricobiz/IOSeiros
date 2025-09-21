
/**
 * WebSocket Manager for Real-time Communication
 */

class WebSocketManager {
    constructor() {
        this.socket = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 1000;
        this.isConnecting = false;
        this.messageHandlers = {};
        this.connectionStatus = 'disconnected';
        
        this.setupEventHandlers();
    }
    
    setupEventHandlers() {
        // Register default message handlers
        this.on('connection_established', this.handleConnectionEstablished.bind(this));
        this.on('system_metrics', this.handleSystemMetrics.bind(this));
        this.on('application_metrics', this.handleApplicationMetrics.bind(this));
        this.on('alert', this.handleAlert.bind(this));
        this.on('notification', this.handleNotification.bind(this));
        this.on('task_response', this.handleTaskResponse.bind(this));
        this.on('error', this.handleError.bind(this));
    }
    
    connect() {
        if (this.isConnecting || (this.socket && this.socket.readyState === WebSocket.OPEN)) {
            return;
        }
        
        this.isConnecting = true;
        this.updateConnectionStatus('connecting');
        
        try {
            // Determine WebSocket URL
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const host = window.location.hostname;
            const port = 8765; // WebSocket server port
            const wsUrl = `${protocol}//${host}:${port}`;
            
            console.log('Connecting to WebSocket:', wsUrl);
            
            this.socket = new WebSocket(wsUrl);
            
            this.socket.onopen = this.onOpen.bind(this);
            this.socket.onmessage = this.onMessage.bind(this);
            this.socket.onclose = this.onClose.bind(this);
            this.socket.onerror = this.onError.bind(this);
            
        } catch (error) {
            console.error('WebSocket connection error:', error);
            this.isConnecting = false;
            this.updateConnectionStatus('disconnected');
            this.scheduleReconnect();
        }
    }
    
    onOpen(event) {
        console.log('WebSocket connected');
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.updateConnectionStatus('connected');
        
        // Send initial ping
        this.send({
            type: 'ping',
            timestamp: new Date().toISOString()
        });
        
        // Subscribe to system metrics
        this.send({
            type: 'subscribe',
            subscription_type: 'system_metrics'
        });
        
        // Subscribe to notifications
        this.send({
            type: 'subscribe',
            subscription_type: 'notifications'
        });
    }
    
    onMessage(event) {
        try {
            const message = JSON.parse(event.data);
            console.log('WebSocket message received:', message.type);
            
            // Trigger appropriate handler
            this.trigger(message.type, message);
            
        } catch (error) {
            console.error('Error parsing WebSocket message:', error);
        }
    }
    
    onClose(event) {
        console.log('WebSocket disconnected:', event.code, event.reason);
        this.isConnecting = false;
        this.updateConnectionStatus('disconnected');
        
        // Attempt to reconnect if not a clean close
        if (event.code !== 1000) {
            this.scheduleReconnect();
        }
    }
    
    onError(event) {
        console.error('WebSocket error:', event);
        this.isConnecting = false;
        this.updateConnectionStatus('disconnected');
    }
    
    send(message) {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
            this.socket.send(JSON.stringify(message));
            return true;
        } else {
            console.warn('WebSocket not connected, message not sent:', message);
            return false;
        }
    }
    
    scheduleReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.error('Max reconnection attempts reached');
            return;
        }
        
        this.reconnectAttempts++;
        const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
        
        console.log(`Scheduling reconnection attempt ${this.reconnectAttempts} in ${delay}ms`);
        
        setTimeout(() => {
            this.connect();
        }, delay);
    }
    
    updateConnectionStatus(status) {
        this.connectionStatus = status;
        
        const statusElement = document.getElementById('connectionStatus');
        if (statusElement) {
            statusElement.className = `connection-status ${status}`;
            
            const statusText = statusElement.querySelector('span');
            if (statusText) {
                switch (status) {
                    case 'connected':
                        statusText.textContent = 'Connected';
                        break;
                    case 'connecting':
                        statusText.textContent = 'Connecting...';
                        break;
                    case 'disconnected':
                        statusText.textContent = 'Disconnected';
                        break;
                }
            }
        }
    }
    
    // Event system
    on(eventType, handler) {
        if (!this.messageHandlers[eventType]) {
            this.messageHandlers[eventType] = [];
        }
        this.messageHandlers[eventType].push(handler);
    }
    
    off(eventType, handler) {
        if (this.messageHandlers[eventType]) {
            const index = this.messageHandlers[eventType].indexOf(handler);
            if (index > -1) {
                this.messageHandlers[eventType].splice(index, 1);
            }
        }
    }
    
    trigger(eventType, data) {
        if (this.messageHandlers[eventType]) {
            this.messageHandlers[eventType].forEach(handler => {
                try {
                    handler(data);
                } catch (error) {
                    console.error(`Error in ${eventType} handler:`, error);
                }
            });
        }
    }
    
    // Message handlers
    handleConnectionEstablished(message) {
        console.log('Connection established:', message);
        
        if (window.app) {
            window.app.showToast('Connected to Control Room', 'success');
        }
    }
    
    handleSystemMetrics(message) {
        console.log('System metrics received');
        
        // Update dashboard if visible
        if (window.app && window.app.currentView === 'dashboard') {
            window.app.updateDashboardMetrics(message.data);
        }
        
        // Update charts
        if (window.chartsManager) {
            window.chartsManager.updateRealTimeCharts(message.data);
        }
    }
    
    handleApplicationMetrics(message) {
        console.log('Application metrics received');
        
        // Update performance metrics
        if (window.app && message.data.performance) {
            const responseTime = document.getElementById('responseTime');
            if (responseTime && message.data.performance.api_response) {
                const avgTime = message.data.performance.api_response.avg_time;
                responseTime.textContent = `${avgTime.toFixed(0)}ms`;
            }
        }
    }
    
    handleAlert(message) {
        console.log('Alert received:', message.data);
        
        if (window.app) {
            const alert = message.data;
            const title = `System Alert: ${alert.type}`;
            window.app.showToast(alert.message, 'error', 10000);
            
            // Add to recent activity
            this.addToRecentActivity({
                type: 'error',
                title: title,
                description: alert.message,
                timestamp: message.timestamp
            });
        }
    }
    
    handleNotification(message) {
        console.log('Notification received:', message.data);
        
        if (window.app) {
            const notification = message.data;
            
            // Show toast if notifications are enabled
            if (window.app.settings.notificationsEnabled) {
                window.app.showToast(notification.message, notification.type);
            }
            
            // Update notification badge
            const badge = document.getElementById('notificationBadge');
            if (badge) {
                const currentCount = parseInt(badge.textContent) || 0;
                badge.textContent = currentCount + 1;
                badge.style.display = 'inline';
            }
            
            // Add to recent activity
            this.addToRecentActivity({
                type: notification.type,
                title: notification.title,
                description: notification.message,
                timestamp: message.timestamp
            });
        }
    }
    
    handleTaskResponse(message) {
        console.log('Task response received:', message.data);
        
        if (window.app) {
            const response = message.data;
            window.app.showToast(response.message, response.status === 'success' ? 'success' : 'info');
            
            // Refresh tasks if on tasks view
            if (window.app.currentView === 'tasks') {
                setTimeout(() => {
                    window.app.loadTasksData();
                }, 1000);
            }
        }
    }
    
    handleError(message) {
        console.error('WebSocket error message:', message);
        
        if (window.app) {
            window.app.showToast(message.message || 'An error occurred', 'error');
        }
    }
    
    addToRecentActivity(activity) {
        const recentActivity = document.getElementById('recentActivity');
        if (!recentActivity) return;
        
        const activityItem = document.createElement('div');
        activityItem.className = 'activity-item';
        activityItem.innerHTML = `
            <div class="activity-icon ${activity.type}">
                <i class="fas ${this.getActivityIcon(activity.type)}"></i>
            </div>
            <div class="activity-content">
                <div class="activity-title">${activity.title}</div>
                <div class="activity-description">${activity.description}</div>
            </div>
            <div class="activity-time">${this.formatTime(activity.timestamp)}</div>
        `;
        
        // Add to top of list
        recentActivity.insertBefore(activityItem, recentActivity.firstChild);
        
        // Keep only last 10 items
        while (recentActivity.children.length > 10) {
            recentActivity.removeChild(recentActivity.lastChild);
        }
    }
    
    getActivityIcon(type) {
        const icons = {
            info: 'fa-info-circle',
            success: 'fa-check-circle',
            warning: 'fa-exclamation-triangle',
            error: 'fa-times-circle',
            alert: 'fa-bell'
        };
        return icons[type] || 'fa-circle';
    }
    
    formatTime(timestamp) {
        return new Date(timestamp).toLocaleTimeString();
    }
    
    // Public methods for sending messages
    requestMetrics(metricsType = 'system', timeRange = '1h') {
        return this.send({
            type: 'get_metrics',
            metrics_type: metricsType,
            time_range: timeRange,
            request_id: this.generateRequestId()
        });
    }
    
    executeTask(taskConfig) {
        return this.send({
            type: 'execute_task',
            task_config: taskConfig,
            request_id: this.generateRequestId()
        });
    }
    
    updateSettings(settings) {
        return this.send({
            type: 'update_settings',
            settings: settings,
            request_id: this.generateRequestId()
        });
    }
    
    joinRoom(roomName) {
        return this.send({
            type: 'join_room',
            room: roomName
        });
    }
    
    leaveRoom(roomName) {
        return this.send({
            type: 'leave_room',
            room: roomName
        });
    }
    
    subscribe(subscriptionType) {
        return this.send({
            type: 'subscribe',
            subscription_type: subscriptionType
        });
    }
    
    unsubscribe(subscriptionType) {
        return this.send({
            type: 'unsubscribe',
            subscription_type: subscriptionType
        });
    }
    
    ping() {
        return this.send({
            type: 'ping',
            timestamp: new Date().toISOString()
        });
    }
    
    generateRequestId() {
        return 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    // Connection management
    disconnect() {
        if (this.socket) {
            this.socket.close(1000, 'Client disconnect');
        }
    }
    
    reconnect() {
        this.disconnect();
        setTimeout(() => {
            this.connect();
        }, 1000);
    }
    
    getConnectionStatus() {
        return {
            status: this.connectionStatus,
            readyState: this.socket ? this.socket.readyState : WebSocket.CLOSED,
            reconnectAttempts: this.reconnectAttempts
        };
    }
}

// Initialize WebSocket manager
document.addEventListener('DOMContentLoaded', () => {
    window.websocketManager = new WebSocketManager();
});
