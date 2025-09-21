
/**
 * Charts Manager for Control Room Visualizations
 */

class ChartsManager {
    constructor() {
        this.charts = {};
        this.chartColors = {
            primary: '#2563eb',
            success: '#10b981',
            warning: '#f59e0b',
            error: '#ef4444',
            info: '#06b6d4',
            secondary: '#64748b'
        };
        
        this.defaultOptions = {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    labels: {
                        color: this.getTextColor()
                    }
                }
            },
            scales: {
                x: {
                    ticks: {
                        color: this.getTextColor()
                    },
                    grid: {
                        color: this.getBorderColor()
                    }
                },
                y: {
                    ticks: {
                        color: this.getTextColor()
                    },
                    grid: {
                        color: this.getBorderColor()
                    }
                }
            }
        };
    }
    
    getTextColor() {
        return getComputedStyle(document.documentElement)
            .getPropertyValue('--text-secondary').trim();
    }
    
    getBorderColor() {
        return getComputedStyle(document.documentElement)
            .getPropertyValue('--border-color').trim();
    }
    
    initializeDashboardCharts() {
        this.createSystemMetricsChart();
        this.createTaskPerformanceChart();
    }
    
    createSystemMetricsChart() {
        const canvas = document.getElementById('systemMetricsChart');
        if (!canvas) return;
        
        const ctx = canvas.getContext('2d');
        
        this.charts.systemMetrics = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [
                    {
                        label: 'CPU Usage (%)',
                        data: [],
                        borderColor: this.chartColors.primary,
                        backgroundColor: this.chartColors.primary + '20',
                        tension: 0.4,
                        fill: false
                    },
                    {
                        label: 'Memory Usage (%)',
                        data: [],
                        borderColor: this.chartColors.success,
                        backgroundColor: this.chartColors.success + '20',
                        tension: 0.4,
                        fill: false
                    },
                    {
                        label: 'Disk Usage (%)',
                        data: [],
                        borderColor: this.chartColors.warning,
                        backgroundColor: this.chartColors.warning + '20',
                        tension: 0.4,
                        fill: false
                    }
                ]
            },
            options: {
                ...this.defaultOptions,
                scales: {
                    ...this.defaultOptions.scales,
                    y: {
                        ...this.defaultOptions.scales.y,
                        min: 0,
                        max: 100
                    }
                },
                plugins: {
                    ...this.defaultOptions.plugins,
                    title: {
                        display: true,
                        text: 'System Resource Usage',
                        color: this.getTextColor()
                    }
                }
            }
        });
    }
    
    createTaskPerformanceChart() {
        const canvas = document.getElementById('taskPerformanceChart');
        if (!canvas) return;
        
        const ctx = canvas.getContext('2d');
        
        this.charts.taskPerformance = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Completed', 'Running', 'Failed', 'Pending'],
                datasets: [{
                    data: [0, 0, 0, 0],
                    backgroundColor: [
                        this.chartColors.success,
                        this.chartColors.info,
                        this.chartColors.error,
                        this.chartColors.warning
                    ],
                    borderWidth: 2,
                    borderColor: this.getBorderColor()
                }]
            },
            options: {
                ...this.defaultOptions,
                plugins: {
                    ...this.defaultOptions.plugins,
                    title: {
                        display: true,
                        text: 'Task Status Distribution',
                        color: this.getTextColor()
                    }
                }
            }
        });
    }
    
    updateSystemMonitorCharts(metricsHistory) {
        this.createCPUMemoryChart(metricsHistory);
        this.createDiskIOChart(metricsHistory);
        this.createNetworkChart(metricsHistory);
    }
    
    createCPUMemoryChart(metricsHistory) {
        const canvas = document.getElementById('cpuMemoryChart');
        if (!canvas) return;
        
        // Destroy existing chart
        if (this.charts.cpuMemory) {
            this.charts.cpuMemory.destroy();
        }
        
        const ctx = canvas.getContext('2d');
        
        const labels = metricsHistory.map(m => 
            new Date(m.timestamp).toLocaleTimeString()
        ).slice(-20); // Last 20 data points
        
        const cpuData = metricsHistory.map(m => 
            m.cpu?.percent || 0
        ).slice(-20);
        
        const memoryData = metricsHistory.map(m => 
            m.memory?.virtual?.percent || 0
        ).slice(-20);
        
        this.charts.cpuMemory = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'CPU Usage (%)',
                        data: cpuData,
                        borderColor: this.chartColors.primary,
                        backgroundColor: this.chartColors.primary + '20',
                        tension: 0.4,
                        fill: false
                    },
                    {
                        label: 'Memory Usage (%)',
                        data: memoryData,
                        borderColor: this.chartColors.success,
                        backgroundColor: this.chartColors.success + '20',
                        tension: 0.4,
                        fill: false
                    }
                ]
            },
            options: {
                ...this.defaultOptions,
                scales: {
                    ...this.defaultOptions.scales,
                    y: {
                        ...this.defaultOptions.scales.y,
                        min: 0,
                        max: 100
                    }
                }
            }
        });
    }
    
    createDiskIOChart(metricsHistory) {
        const canvas = document.getElementById('diskIOChart');
        if (!canvas) return;
        
        // Destroy existing chart
        if (this.charts.diskIO) {
            this.charts.diskIO.destroy();
        }
        
        const ctx = canvas.getContext('2d');
        
        const labels = metricsHistory.map(m => 
            new Date(m.timestamp).toLocaleTimeString()
        ).slice(-20);
        
        const readData = metricsHistory.map(m => {
            const diskIO = m.disk?.io?.total;
            return diskIO ? (diskIO.read_bytes / 1024 / 1024) : 0; // Convert to MB
        }).slice(-20);
        
        const writeData = metricsHistory.map(m => {
            const diskIO = m.disk?.io?.total;
            return diskIO ? (diskIO.write_bytes / 1024 / 1024) : 0; // Convert to MB
        }).slice(-20);
        
        this.charts.diskIO = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Read (MB)',
                        data: readData,
                        borderColor: this.chartColors.info,
                        backgroundColor: this.chartColors.info + '20',
                        tension: 0.4,
                        fill: false
                    },
                    {
                        label: 'Write (MB)',
                        data: writeData,
                        borderColor: this.chartColors.warning,
                        backgroundColor: this.chartColors.warning + '20',
                        tension: 0.4,
                        fill: false
                    }
                ]
            },
            options: {
                ...this.defaultOptions,
                scales: {
                    ...this.defaultOptions.scales,
                    y: {
                        ...this.defaultOptions.scales.y,
                        min: 0
                    }
                }
            }
        });
    }
    
    createNetworkChart(metricsHistory) {
        const canvas = document.getElementById('networkChart');
        if (!canvas) return;
        
        // Destroy existing chart
        if (this.charts.network) {
            this.charts.network.destroy();
        }
        
        const ctx = canvas.getContext('2d');
        
        const labels = metricsHistory.map(m => 
            new Date(m.timestamp).toLocaleTimeString()
        ).slice(-20);
        
        const sentData = metricsHistory.map(m => {
            const networkIO = m.network?.io?.total;
            return networkIO ? (networkIO.bytes_sent / 1024 / 1024) : 0; // Convert to MB
        }).slice(-20);
        
        const recvData = metricsHistory.map(m => {
            const networkIO = m.network?.io?.total;
            return networkIO ? (networkIO.bytes_recv / 1024 / 1024) : 0; // Convert to MB
        }).slice(-20);
        
        this.charts.network = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Sent (MB)',
                        data: sentData,
                        borderColor: this.chartColors.error,
                        backgroundColor: this.chartColors.error + '20',
                        tension: 0.4,
                        fill: false
                    },
                    {
                        label: 'Received (MB)',
                        data: recvData,
                        borderColor: this.chartColors.secondary,
                        backgroundColor: this.chartColors.secondary + '20',
                        tension: 0.4,
                        fill: false
                    }
                ]
            },
            options: {
                ...this.defaultOptions,
                scales: {
                    ...this.defaultOptions.scales,
                    y: {
                        ...this.defaultOptions.scales.y,
                        min: 0
                    }
                }
            }
        });
    }
    
    updateRealTimeCharts(systemData) {
        // Update system metrics chart
        if (this.charts.systemMetrics) {
            const chart = this.charts.systemMetrics;
            const now = new Date().toLocaleTimeString();
            
            // Add new data point
            chart.data.labels.push(now);
            chart.data.datasets[0].data.push(systemData.cpu?.percent || 0);
            chart.data.datasets[1].data.push(systemData.memory?.virtual?.percent || 0);
            
            // Calculate max disk usage
            let maxDiskUsage = 0;
            if (systemData.disk?.usage) {
                maxDiskUsage = Math.max(...Object.values(systemData.disk.usage).map(d => d.percent || 0));
            }
            chart.data.datasets[2].data.push(maxDiskUsage);
            
            // Keep only last 20 data points
            if (chart.data.labels.length > 20) {
                chart.data.labels.shift();
                chart.data.datasets.forEach(dataset => {
                    dataset.data.shift();
                });
            }
            
            chart.update('none'); // Update without animation for real-time feel
        }
    }
    
    updateTaskPerformanceChart(tasks) {
        if (!this.charts.taskPerformance || !tasks) return;
        
        const statusCounts = {
            completed: 0,
            running: 0,
            failed: 0,
            pending: 0
        };
        
        tasks.forEach(task => {
            if (statusCounts.hasOwnProperty(task.status)) {
                statusCounts[task.status]++;
            }
        });
        
        this.charts.taskPerformance.data.datasets[0].data = [
            statusCounts.completed,
            statusCounts.running,
            statusCounts.failed,
            statusCounts.pending
        ];
        
        this.charts.taskPerformance.update();
    }
    
    createCustomChart(canvasId, type, data, options = {}) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return null;
        
        // Destroy existing chart if it exists
        if (this.charts[canvasId]) {
            this.charts[canvasId].destroy();
        }
        
        const ctx = canvas.getContext('2d');
        
        const mergedOptions = {
            ...this.defaultOptions,
            ...options
        };
        
        this.charts[canvasId] = new Chart(ctx, {
            type: type,
            data: data,
            options: mergedOptions
        });
        
        return this.charts[canvasId];
    }
    
    destroyChart(chartId) {
        if (this.charts[chartId]) {
            this.charts[chartId].destroy();
            delete this.charts[chartId];
        }
    }
    
    destroyAllCharts() {
        Object.keys(this.charts).forEach(chartId => {
            this.destroyChart(chartId);
        });
    }
    
    updateChartTheme() {
        // Update chart colors when theme changes
        Object.values(this.charts).forEach(chart => {
            if (chart.options.plugins?.legend?.labels) {
                chart.options.plugins.legend.labels.color = this.getTextColor();
            }
            
            if (chart.options.scales?.x?.ticks) {
                chart.options.scales.x.ticks.color = this.getTextColor();
                chart.options.scales.x.grid.color = this.getBorderColor();
            }
            
            if (chart.options.scales?.y?.ticks) {
                chart.options.scales.y.ticks.color = this.getTextColor();
                chart.options.scales.y.grid.color = this.getBorderColor();
            }
            
            chart.update();
        });
    }
    
    exportChart(chartId, format = 'png') {
        const chart = this.charts[chartId];
        if (!chart) return null;
        
        return chart.toBase64Image(format);
    }
    
    resizeCharts() {
        Object.values(this.charts).forEach(chart => {
            chart.resize();
        });
    }
}

// Initialize charts manager
document.addEventListener('DOMContentLoaded', () => {
    window.chartsManager = new ChartsManager();
    
    // Update chart theme when theme changes
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            if (mutation.type === 'attributes' && mutation.attributeName === 'data-theme') {
                if (window.chartsManager) {
                    setTimeout(() => {
                        window.chartsManager.updateChartTheme();
                    }, 100);
                }
            }
        });
    });
    
    observer.observe(document.documentElement, {
        attributes: true,
        attributeFilter: ['data-theme']
    });
    
    // Resize charts on window resize
    window.addEventListener('resize', () => {
        if (window.chartsManager) {
            window.chartsManager.resizeCharts();
        }
    });
});
