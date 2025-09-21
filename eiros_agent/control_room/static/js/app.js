
/**
 * Eiros Agent Control Room - Main Application
 */

class ControlRoomApp {
    constructor() {
        this.currentView = 'dashboard';
        this.settings = {
            theme: 'dark',
            refreshInterval: 5,
            autoRefresh: true,
            notificationsEnabled: true,
            soundAlerts: false,
            cpuAlertThreshold: 80,
            memoryAlertThreshold: 85,
            diskAlertThreshold: 90
        };
        
        this.data = {
            systemMetrics: {},
            tasks: [],
            notifications: [],
            logs: [],
            websocketClients: []
        };
        
        this.refreshIntervals = {};
        this.charts = {};
        
        this.init();
    }
    
    init() {
        this.loadSettings();
        this.setupEventListeners();
        this.initializeWebSocket();
        this.showView('dashboard');
        this.startAutoRefresh();
        
        console.log('Control Room App initialized');
    }
    
    loadSettings() {
        const savedSettings = localStorage.getItem('controlRoomSettings');
        if (savedSettings) {
            this.settings = { ...this.settings, ...JSON.parse(savedSettings) };
        }
        this.applySettings();
    }
    
    saveSettings() {
        localStorage.setItem('controlRoomSettings', JSON.stringify(this.settings));
        this.applySettings();
        this.showToast('Settings saved successfully', 'success');
    }
    
    applySettings() {
        // Apply theme
        document.documentElement.setAttribute('data-theme', this.settings.theme);
        
        // Update form values
        const themeSelect = document.getElementById('themeSelect');
        if (themeSelect) themeSelect.value = this.settings.theme;
        
        const refreshInterval = document.getElementById('refreshInterval');
        if (refreshInterval) refreshInterval.value = this.settings.refreshInterval;
        
        const autoRefresh = document.getElementById('autoRefresh');
        if (autoRefresh) autoRefresh.checked = this.settings.autoRefresh;
        
        const notificationsEnabled = document.getElementById('notificationsEnabled');
        if (notificationsEnabled) notificationsEnabled.checked = this.settings.notificationsEnabled;
        
        const soundAlerts = document.getElementById('soundAlerts');
        if (soundAlerts) soundAlerts.checked = this.settings.soundAlerts;
        
        const cpuAlertThreshold = document.getElementById('cpuAlertThreshold');
        if (cpuAlertThreshold) cpuAlertThreshold.value = this.settings.cpuAlertThreshold;
        
        const memoryAlertThreshold = document.getElementById('memoryAlertThreshold');
        if (memoryAlertThreshold) memoryAlertThreshold.value = this.settings.memoryAlertThreshold;
        
        const diskAlertThreshold = document.getElementById('diskAlertThreshold');
        if (diskAlertThreshold) diskAlertThreshold.value = this.settings.diskAlertThreshold;
    }
    
    setupEventListeners() {
        // User menu toggle
        const userButton = document.getElementById('userButton');
        const userDropdown = document.getElementById('userDropdown');
        
        if (userButton && userDropdown) {
            userButton.addEventListener('click', (e) => {
                e.stopPropagation();
                userDropdown.classList.toggle('show');
            });
            
            document.addEventListener('click', () => {
                userDropdown.classList.remove('show');
            });
        }
        
        // Settings form listeners
        const settingsInputs = [
            'themeSelect', 'refreshInterval', 'autoRefresh', 'notificationsEnabled',
            'soundAlerts', 'cpuAlertThreshold', 'memoryAlertThreshold', 'diskAlertThreshold'
        ];
        
        settingsInputs.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                element.addEventListener('change', () => {
                    this.updateSettingFromForm(id);
                });
            }
        });
        
        // Modal close listeners
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal(e.target.id);
            }
        });
        
        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey || e.metaKey) {
                switch (e.key) {
                    case '1':
                        e.preventDefault();
                        this.showView('dashboard');
                        break;
                    case '2':
                        e.preventDefault();
                        this.showView('systemMonitor');
                        break;
                    case '3':
                        e.preventDefault();
                        this.showView('tasks');
                        break;
                    case '4':
                        e.preventDefault();
                        this.showView('notifications');
                        break;
                    case 'r':
                        e.preventDefault();
                        this.refreshCurrentView();
                        break;
                }
            }
        });
    }
    
    updateSettingFromForm(settingId) {
        const element = document.getElementById(settingId);
        if (!element) return;
        
        let value;
        if (element.type === 'checkbox') {
            value = element.checked;
        } else if (element.type === 'number') {
            value = parseInt(element.value);
        } else {
            value = element.value;
        }
        
        // Map form IDs to setting keys
        const settingMap = {
            'themeSelect': 'theme',
            'refreshInterval': 'refreshInterval',
            'autoRefresh': 'autoRefresh',
            'notificationsEnabled': 'notificationsEnabled',
            'soundAlerts': 'soundAlerts',
            'cpuAlertThreshold': 'cpuAlertThreshold',
            'memoryAlertThreshold': 'memoryAlertThreshold',
            'diskAlertThreshold': 'diskAlertThreshold'
        };
        
        const settingKey = settingMap[settingId];
        if (settingKey) {
            this.settings[settingKey] = value;
            
            // Apply immediate changes
            if (settingKey === 'theme') {
                document.documentElement.setAttribute('data-theme', value);
            } else if (settingKey === 'refreshInterval' || settingKey === 'autoRefresh') {
                this.updateAutoRefresh();
            }
        }
    }
    
    initializeWebSocket() {
        if (window.websocketManager) {
            window.websocketManager.connect();
        }
    }
    
    showView(viewName) {
        // Hide all views
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });
        
        // Remove active class from nav items
        document.querySelectorAll('.nav-item').forEach(item => {
            item.classList.remove('active');
        });
        
        // Show selected view
        const view = document.getElementById(viewName + 'View');
        if (view) {
            view.classList.add('active');
        }
        
        // Add active class to corresponding nav item
        const navLink = document.querySelector(`[onclick="show${viewName.charAt(0).toUpperCase() + viewName.slice(1)}()"]`);
        if (navLink) {
            navLink.closest('.nav-item').classList.add('active');
        }
        
        this.currentView = viewName;
        
        // Load view-specific data
        this.loadViewData(viewName);
    }
    
    loadViewData(viewName) {
        switch (viewName) {
            case 'dashboard':
                this.loadDashboardData();
                break;
            case 'systemMonitor':
                this.loadSystemMonitorData();
                break;
            case 'tasks':
                this.loadTasksData();
                break;
            case 'notifications':
                this.loadNotificationsData();
                break;
            case 'logs':
                this.loadLogsData();
                break;
        }
    }
    
    async loadDashboardData() {
        try {
            // Load system metrics
            const systemResponse = await fetch('/api/v1/system/metrics');
            if (systemResponse.ok) {
                const systemData = await systemResponse.json();
                this.updateDashboardMetrics(systemData);
            }
            
            // Load tasks summary
            const tasksResponse = await fetch('/api/v1/tasks');
            if (tasksResponse.ok) {
                const tasksData = await tasksResponse.json();
                this.updateTasksSummary(tasksData.tasks || []);
            }
            
            // Load notifications summary
            const notificationsResponse = await fetch('/api/v1/notifications');
            if (notificationsResponse.ok) {
                const notificationsData = await notificationsResponse.json();
                this.updateNotificationsSummary(notificationsData.notifications || []);
            }
            
            // Initialize charts
            if (window.chartsManager) {
                window.chartsManager.initializeDashboardCharts();
            }
            
        } catch (error) {
            console.error('Error loading dashboard data:', error);
            this.showToast('Failed to load dashboard data', 'error');
        }
    }
    
    updateDashboardMetrics(systemData) {
        // Update CPU usage
        const cpuUsage = document.getElementById('cpuUsage');
        if (cpuUsage && systemData.cpu) {
            cpuUsage.textContent = `${systemData.cpu.percent?.toFixed(1) || 0}%`;
        }
        
        // Update memory usage
        const memoryUsage = document.getElementById('memoryUsage');
        if (memoryUsage && systemData.memory?.virtual) {
            memoryUsage.textContent = `${systemData.memory.virtual.percent?.toFixed(1) || 0}%`;
        }
        
        // Update disk usage
        const diskUsage = document.getElementById('diskUsage');
        if (diskUsage && systemData.disk?.usage) {
            const diskData = Object.values(systemData.disk.usage);
            const maxDiskUsage = Math.max(...diskData.map(d => d.percent || 0));
            diskUsage.textContent = `${maxDiskUsage.toFixed(1)}%`;
        }
        
        // Update uptime
        const systemUptime = document.getElementById('systemUptime');
        if (systemUptime && systemData.system) {
            const uptimeSeconds = systemData.system.uptime_seconds || 0;
            systemUptime.textContent = this.formatUptime(uptimeSeconds);
        }
        
        this.data.systemMetrics = systemData;
    }
    
    updateTasksSummary(tasks) {
        const runningTasks = tasks.filter(t => t.status === 'running').length;
        const queuedTasks = tasks.filter(t => t.status === 'pending').length;
        const completedTasks = tasks.filter(t => t.status === 'completed').length;
        
        const runningElement = document.getElementById('runningTasks');
        if (runningElement) runningElement.textContent = runningTasks;
        
        const queuedElement = document.getElementById('queuedTasks');
        if (queuedElement) queuedElement.textContent = queuedTasks;
        
        const completedElement = document.getElementById('completedTasks');
        if (completedElement) completedElement.textContent = completedTasks;
        
        this.data.tasks = tasks;
    }
    
    updateNotificationsSummary(notifications) {
        const unreadNotifications = notifications.filter(n => !n.read).length;
        const activeAlerts = notifications.filter(n => n.type === 'alert' && !n.read).length;
        
        const unreadElement = document.getElementById('unreadNotifications');
        if (unreadElement) unreadElement.textContent = unreadNotifications;
        
        const alertsElement = document.getElementById('activeAlerts');
        if (alertsElement) alertsElement.textContent = activeAlerts;
        
        // Update notification badge
        const notificationBadge = document.getElementById('notificationBadge');
        if (notificationBadge) {
            notificationBadge.textContent = unreadNotifications;
            notificationBadge.style.display = unreadNotifications > 0 ? 'inline' : 'none';
        }
        
        this.data.notifications = notifications;
    }
    
    async loadSystemMonitorData() {
        try {
            const timeRange = document.getElementById('timeRangeSelect')?.value || '1h';
            const response = await fetch(`/api/v1/system/metrics/history?time_range=${timeRange}`);
            
            if (response.ok) {
                const data = await response.json();
                this.updateSystemMonitorCharts(data.metrics || []);
                this.updateProcessList(data.metrics?.[0]?.processes || {});
            }
            
        } catch (error) {
            console.error('Error loading system monitor data:', error);
            this.showToast('Failed to load system monitor data', 'error');
        }
    }
    
    updateSystemMonitorCharts(metricsHistory) {
        if (window.chartsManager) {
            window.chartsManager.updateSystemMonitorCharts(metricsHistory);
        }
    }
    
    updateProcessList(processesData) {
        const processList = document.getElementById('processList');
        if (!processList || !processesData.top_cpu) return;
        
        processList.innerHTML = '';
        
        processesData.top_cpu.slice(0, 10).forEach(process => {
            const processItem = document.createElement('div');
            processItem.className = 'process-item';
            processItem.innerHTML = `
                <div class="process-name">${process.name || 'Unknown'}</div>
                <div class="process-stats">
                    <span>CPU: ${(process.cpu_percent || 0).toFixed(1)}%</span>
                    <span>Memory: ${(process.memory_percent || 0).toFixed(1)}%</span>
                    <span>PID: ${process.pid || 'N/A'}</span>
                </div>
            `;
            processList.appendChild(processItem);
        });
    }
    
    async loadTasksData() {
        try {
            const response = await fetch('/api/v1/tasks');
            if (response.ok) {
                const data = await response.json();
                this.updateTasksList(data.tasks || []);
            }
        } catch (error) {
            console.error('Error loading tasks data:', error);
            this.showToast('Failed to load tasks data', 'error');
        }
    }
    
    updateTasksList(tasks) {
        const tasksList = document.getElementById('tasksList');
        if (!tasksList) return;
        
        tasksList.innerHTML = '';
        
        if (tasks.length === 0) {
            tasksList.innerHTML = '<div class="text-center p-4">No tasks found</div>';
            return;
        }
        
        tasks.forEach(task => {
            const taskItem = document.createElement('div');
            taskItem.className = 'task-item';
            taskItem.innerHTML = `
                <div class="task-status ${task.status}"></div>
                <div class="task-info">
                    <div class="task-name">${task.name || 'Unnamed Task'}</div>
                    <div class="task-description">${task.description || 'No description'}</div>
                    <div class="task-meta">
                        <span>Type: ${task.type || 'Unknown'}</span>
                        <span>Priority: ${task.priority || 'Medium'}</span>
                        <span>Progress: ${task.progress || 0}%</span>
                        <span>Created: ${this.formatDate(task.created_at)}</span>
                    </div>
                </div>
                <div class="task-actions">
                    ${task.status === 'pending' ? '<button class="btn btn-sm btn-primary" onclick="app.executeTask(\'' + task.id + '\')">Execute</button>' : ''}
                    ${task.status === 'running' ? '<button class="btn btn-sm btn-warning" onclick="app.pauseTask(\'' + task.id + '\')">Pause</button>' : ''}
                    ${task.status === 'failed' && task.can_retry ? '<button class="btn btn-sm btn-secondary" onclick="app.retryTask(\'' + task.id + '\')">Retry</button>' : ''}
                    <button class="btn btn-sm btn-secondary" onclick="app.viewTask(\'' + task.id + '\')">View</button>
                </div>
            `;
            tasksList.appendChild(taskItem);
        });
        
        this.data.tasks = tasks;
    }
    
    async loadNotificationsData() {
        try {
            const response = await fetch('/api/v1/notifications');
            if (response.ok) {
                const data = await response.json();
                this.updateNotificationsList(data.notifications || []);
            }
        } catch (error) {
            console.error('Error loading notifications data:', error);
            this.showToast('Failed to load notifications data', 'error');
        }
    }
    
    updateNotificationsList(notifications) {
        const notificationsList = document.getElementById('notificationsList');
        if (!notificationsList) return;
        
        notificationsList.innerHTML = '';
        
        if (notifications.length === 0) {
            notificationsList.innerHTML = '<div class="text-center p-4">No notifications</div>';
            return;
        }
        
        notifications.forEach(notification => {
            const notificationItem = document.createElement('div');
            notificationItem.className = `notification-item ${notification.read ? 'read' : 'unread'}`;
            notificationItem.innerHTML = `
                <div class="notification-icon ${notification.type}">
                    <i class="fas ${this.getNotificationIcon(notification.type)}"></i>
                </div>
                <div class="notification-content">
                    <div class="notification-title">${notification.title || 'Notification'}</div>
                    <div class="notification-message">${notification.message || ''}</div>
                    <div class="notification-time">${this.formatDate(notification.timestamp)}</div>
                </div>
                <div class="notification-actions">
                    ${!notification.read ? '<button class="btn btn-sm btn-secondary" onclick="app.markNotificationAsRead(\'' + notification.id + '\')">Mark Read</button>' : ''}
                </div>
            `;
            notificationsList.appendChild(notificationItem);
        });
        
        this.data.notifications = notifications;
    }
    
    async loadLogsData() {
        try {
            // This would typically fetch from a logs endpoint
            // For now, we'll show some sample logs
            this.updateLogsList([
                {
                    timestamp: new Date().toISOString(),
                    level: 'INFO',
                    message: 'Control Room initialized successfully'
                },
                {
                    timestamp: new Date(Date.now() - 60000).toISOString(),
                    level: 'INFO',
                    message: 'WebSocket connection established'
                },
                {
                    timestamp: new Date(Date.now() - 120000).toISOString(),
                    level: 'WARNING',
                    message: 'High CPU usage detected: 85%'
                }
            ]);
        } catch (error) {
            console.error('Error loading logs data:', error);
            this.showToast('Failed to load logs data', 'error');
        }
    }
    
    updateLogsList(logs) {
        const logsList = document.getElementById('logsList');
        if (!logsList) return;
        
        logsList.innerHTML = '';
        
        logs.forEach(log => {
            const logEntry = document.createElement('div');
            logEntry.className = 'log-entry';
            logEntry.innerHTML = `
                <div class="log-time">${this.formatTime(log.timestamp)}</div>
                <div class="log-level ${log.level}">${log.level}</div>
                <div class="log-message">${log.message}</div>
            `;
            logsList.appendChild(logEntry);
        });
        
        this.data.logs = logs;
    }
    
    startAutoRefresh() {
        this.updateAutoRefresh();
    }
    
    updateAutoRefresh() {
        // Clear existing intervals
        Object.values(this.refreshIntervals).forEach(interval => {
            clearInterval(interval);
        });
        this.refreshIntervals = {};
        
        if (!this.settings.autoRefresh) return;
        
        const interval = this.settings.refreshInterval * 1000;
        
        // Set up refresh intervals for different views
        this.refreshIntervals.dashboard = setInterval(() => {
            if (this.currentView === 'dashboard') {
                this.loadDashboardData();
            }
        }, interval);
        
        this.refreshIntervals.systemMonitor = setInterval(() => {
            if (this.currentView === 'systemMonitor') {
                this.loadSystemMonitorData();
            }
        }, interval);
        
        this.refreshIntervals.tasks = setInterval(() => {
            if (this.currentView === 'tasks') {
                this.loadTasksData();
            }
        }, interval * 2); // Tasks refresh less frequently
        
        this.refreshIntervals.notifications = setInterval(() => {
            if (this.currentView === 'notifications') {
                this.loadNotificationsData();
            }
        }, interval * 3); // Notifications refresh even less frequently
    }
    
    refreshCurrentView() {
        this.loadViewData(this.currentView);
        this.showToast('Data refreshed', 'info');
    }
    
    // Modal management
    showModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('show');
        }
    }
    
    closeModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.remove('show');
        }
    }
    
    // Task management
    async executeTask(taskId) {
        try {
            const response = await fetch(`/api/v1/tasks/${taskId}/execute`, {
                method: 'POST'
            });
            
            if (response.ok) {
                this.showToast('Task execution started', 'success');
                this.loadTasksData();
            } else {
                this.showToast('Failed to execute task', 'error');
            }
        } catch (error) {
            console.error('Error executing task:', error);
            this.showToast('Failed to execute task', 'error');
        }
    }
    
    async createTask() {
        const form = document.getElementById('createTaskForm');
        if (!form) return;
        
        const formData = new FormData(form);
        const taskData = {
            name: document.getElementById('taskName').value,
            type: document.getElementById('taskType').value,
            description: document.getElementById('taskDescription').value,
            priority: document.getElementById('taskPriority').value,
            config: {}
        };
        
        // Parse config JSON
        const configText = document.getElementById('taskConfig').value;
        if (configText) {
            try {
                taskData.config = JSON.parse(configText);
            } catch (error) {
                this.showToast('Invalid JSON in configuration', 'error');
                return;
            }
        }
        
        try {
            const response = await fetch('/api/v1/tasks', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(taskData)
            });
            
            if (response.ok) {
                this.showToast('Task created successfully', 'success');
                this.closeModal('createTaskModal');
                form.reset();
                this.loadTasksData();
            } else {
                this.showToast('Failed to create task', 'error');
            }
        } catch (error) {
            console.error('Error creating task:', error);
            this.showToast('Failed to create task', 'error');
        }
    }
    
    // Notification management
    async markNotificationAsRead(notificationId) {
        try {
            const response = await fetch(`/api/v1/notifications/${notificationId}/read`, {
                method: 'PUT'
            });
            
            if (response.ok) {
                this.loadNotificationsData();
                this.loadDashboardData(); // Update notification counts
            }
        } catch (error) {
            console.error('Error marking notification as read:', error);
        }
    }
    
    async markAllAsRead() {
        // This would typically be a batch operation
        const unreadNotifications = this.data.notifications.filter(n => !n.read);
        
        for (const notification of unreadNotifications) {
            await this.markNotificationAsRead(notification.id);
        }
        
        this.showToast('All notifications marked as read', 'success');
    }
    
    // Toast notifications
    showToast(message, type = 'info', duration = 5000) {
        const toastContainer = document.getElementById('toastContainer');
        if (!toastContainer) return;
        
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
            <div class="toast-header">
                <div class="toast-title">${this.getToastTitle(type)}</div>
                <button class="toast-close" onclick="this.parentElement.parentElement.remove()">&times;</button>
            </div>
            <div class="toast-message">${message}</div>
        `;
        
        toastContainer.appendChild(toast);
        
        // Auto remove after duration
        setTimeout(() => {
            if (toast.parentElement) {
                toast.remove();
            }
        }, duration);
        
        // Play sound if enabled
        if (this.settings.soundAlerts && type === 'error') {
            this.playAlertSound();
        }
    }
    
    getToastTitle(type) {
        const titles = {
            info: 'Information',
            success: 'Success',
            warning: 'Warning',
            error: 'Error'
        };
        return titles[type] || 'Notification';
    }
    
    getNotificationIcon(type) {
        const icons = {
            info: 'fa-info-circle',
            success: 'fa-check-circle',
            warning: 'fa-exclamation-triangle',
            error: 'fa-times-circle',
            alert: 'fa-bell'
        };
        return icons[type] || 'fa-bell';
    }
    
    playAlertSound() {
        // Create a simple beep sound
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioContext.createOscillator();
        const gainNode = audioContext.createGain();
        
        oscillator.connect(gainNode);
        gainNode.connect(audioContext.destination);
        
        oscillator.frequency.value = 800;
        oscillator.type = 'sine';
        
        gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.5);
        
        oscillator.start(audioContext.currentTime);
        oscillator.stop(audioContext.currentTime + 0.5);
    }
    
    // Utility functions
    formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        
        if (days > 0) {
            return `${days}d ${hours}h ${minutes}m`;
        } else if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else {
            return `${minutes}m`;
        }
    }
    
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        
        const date = new Date(dateString);
        const now = new Date();
        const diff = now - date;
        
        if (diff < 60000) { // Less than 1 minute
            return 'Just now';
        } else if (diff < 3600000) { // Less than 1 hour
            const minutes = Math.floor(diff / 60000);
            return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
        } else if (diff < 86400000) { // Less than 1 day
            const hours = Math.floor(diff / 3600000);
            return `${hours} hour${hours > 1 ? 's' : ''} ago`;
        } else {
            return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
        }
    }
    
    formatTime(dateString) {
        if (!dateString) return 'N/A';
        return new Date(dateString).toLocaleTimeString();
    }
}

// Global functions for HTML onclick handlers
function showDashboard() {
    app.showView('dashboard');
}

function showSystemMonitor() {
    app.showView('systemMonitor');
}

function showTasks() {
    app.showView('tasks');
}

function showNotifications() {
    app.showView('notifications');
}

function showLogs() {
    app.showView('logs');
}

function showSettings() {
    app.showView('settings');
}

function showProfile() {
    app.showToast('Profile management coming soon', 'info');
}

function logout() {
    app.showToast('Logout functionality coming soon', 'info');
}

function refreshDashboard() {
    app.loadDashboardData();
}

function refreshSystemMonitor() {
    app.loadSystemMonitorData();
}

function refreshTasks() {
    app.loadTasksData();
}

function refreshLogs() {
    app.loadLogsData();
}

function updateTimeRange() {
    app.loadSystemMonitorData();
}

function filterTasks() {
    // Implement task filtering
    app.showToast('Task filtering coming soon', 'info');
}

function filterNotifications() {
    // Implement notification filtering
    app.showToast('Notification filtering coming soon', 'info');
}

function filterLogs() {
    // Implement log filtering
    app.showToast('Log filtering coming soon', 'info');
}

function showCreateTaskModal() {
    app.showModal('createTaskModal');
}

function closeModal(modalId) {
    app.closeModal(modalId);
}

function createTask() {
    app.createTask();
}

function markAllAsRead() {
    app.markAllAsRead();
}

function clearNotifications() {
    app.showToast('Clear notifications functionality coming soon', 'info');
}

function clearLogs() {
    app.showToast('Clear logs functionality coming soon', 'info');
}

function changeTheme() {
    // Theme change is handled by the settings update
}

function saveSettings() {
    app.saveSettings();
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.app = new ControlRoomApp();
});
