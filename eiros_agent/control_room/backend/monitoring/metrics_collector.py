
"""
Metrics Collector - Application and custom metrics collection
"""
import asyncio
import time
from typing import Dict, Any, List, Optional, Callable
from datetime import datetime, timedelta
from collections import defaultdict, deque
import json
from pathlib import Path
from loguru import logger


class MetricsCollector:
    """
    Application metrics collector for Control Room
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize Metrics Collector"""
        self.config = config
        self.is_running = False
        
        # Metrics storage
        self.metrics_storage = defaultdict(lambda: deque(maxlen=config.get('max_metrics_per_type', 1000)))
        self.custom_metrics = {}
        self.metric_handlers = {}
        
        # Performance tracking
        self.performance_metrics = {
            'task_execution_times': deque(maxlen=100),
            'api_response_times': deque(maxlen=100),
            'error_counts': defaultdict(int),
            'success_counts': defaultdict(int)
        }
        
        logger.info("Metrics Collector initialized")
    
    async def initialize(self) -> None:
        """Initialize metrics collector"""
        try:
            # Load historical metrics if configured
            if self.config.get('load_history', False):
                await self._load_historical_metrics()
            
            # Register default metric handlers
            self._register_default_handlers()
            
            self.is_running = True
            logger.info("Metrics Collector initialization complete")
            
        except Exception as e:
            logger.error(f"Failed to initialize Metrics Collector: {e}")
            raise
    
    async def shutdown(self) -> None:
        """Shutdown metrics collector"""
        logger.info("Shutting down Metrics Collector...")
        
        self.is_running = False
        
        # Save metrics if configured
        if self.config.get('save_on_shutdown', True):
            await self._save_metrics()
        
        logger.info("Metrics Collector shutdown complete")
    
    async def collect_application_metrics(self) -> Dict[str, Any]:
        """Collect application-specific metrics"""
        try:
            metrics = {
                'timestamp': datetime.utcnow().isoformat(),
                'performance': await self._collect_performance_metrics(),
                'tasks': await self._collect_task_metrics(),
                'errors': await self._collect_error_metrics(),
                'custom': await self._collect_custom_metrics()
            }
            
            # Store metrics
            await self.store_metrics(metrics)
            
            return metrics
            
        except Exception as e:
            logger.error(f"Error collecting application metrics: {e}")
            return {}
    
    async def _collect_performance_metrics(self) -> Dict[str, Any]:
        """Collect performance metrics"""
        try:
            task_times = list(self.performance_metrics['task_execution_times'])
            api_times = list(self.performance_metrics['api_response_times'])
            
            return {
                'task_execution': {
                    'count': len(task_times),
                    'avg_time': sum(task_times) / len(task_times) if task_times else 0,
                    'min_time': min(task_times) if task_times else 0,
                    'max_time': max(task_times) if task_times else 0,
                    'recent_times': task_times[-10:]  # Last 10 execution times
                },
                'api_response': {
                    'count': len(api_times),
                    'avg_time': sum(api_times) / len(api_times) if api_times else 0,
                    'min_time': min(api_times) if api_times else 0,
                    'max_time': max(api_times) if api_times else 0,
                    'recent_times': api_times[-10:]  # Last 10 response times
                },
                'throughput': {
                    'tasks_per_minute': len([t for t in task_times if t > time.time() - 60]),
                    'api_calls_per_minute': len([t for t in api_times if t > time.time() - 60])
                }
            }
            
        except Exception as e:
            logger.error(f"Error collecting performance metrics: {e}")
            return {}
    
    async def _collect_task_metrics(self) -> Dict[str, Any]:
        """Collect task-related metrics"""
        try:
            # This would integrate with the existing scheduler
            # For now, return placeholder data
            return {
                'active_tasks': 0,
                'completed_tasks': sum(self.performance_metrics['success_counts'].values()),
                'failed_tasks': sum(self.performance_metrics['error_counts'].values()),
                'queued_tasks': 0,
                'task_types': dict(self.performance_metrics['success_counts'])
            }
            
        except Exception as e:
            logger.error(f"Error collecting task metrics: {e}")
            return {}
    
    async def _collect_error_metrics(self) -> Dict[str, Any]:
        """Collect error metrics"""
        try:
            total_errors = sum(self.performance_metrics['error_counts'].values())
            total_successes = sum(self.performance_metrics['success_counts'].values())
            total_operations = total_errors + total_successes
            
            return {
                'total_errors': total_errors,
                'total_successes': total_successes,
                'error_rate': (total_errors / total_operations) if total_operations > 0 else 0,
                'errors_by_type': dict(self.performance_metrics['error_counts']),
                'recent_errors': self._get_recent_errors()
            }
            
        except Exception as e:
            logger.error(f"Error collecting error metrics: {e}")
            return {}
    
    async def _collect_custom_metrics(self) -> Dict[str, Any]:
        """Collect custom metrics"""
        try:
            custom_data = {}
            
            for metric_name, metric_data in self.custom_metrics.items():
                if callable(metric_data):
                    # If it's a function, call it to get current value
                    try:
                        custom_data[metric_name] = await metric_data() if asyncio.iscoroutinefunction(metric_data) else metric_data()
                    except Exception as e:
                        logger.error(f"Error collecting custom metric {metric_name}: {e}")
                        custom_data[metric_name] = None
                else:
                    # If it's a static value
                    custom_data[metric_name] = metric_data
            
            return custom_data
            
        except Exception as e:
            logger.error(f"Error collecting custom metrics: {e}")
            return {}
    
    async def process_metrics(self, raw_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Process and enhance raw metrics"""
        try:
            processed_metrics = raw_metrics.copy()
            
            # Add calculated fields
            if 'cpu' in raw_metrics:
                processed_metrics['cpu']['status'] = self._get_cpu_status(raw_metrics['cpu'].get('percent', 0))
            
            if 'memory' in raw_metrics:
                memory_percent = raw_metrics['memory'].get('virtual', {}).get('percent', 0)
                processed_metrics['memory']['status'] = self._get_memory_status(memory_percent)
            
            if 'disk' in raw_metrics:
                disk_usage = raw_metrics['disk'].get('usage', {})
                max_disk_percent = max([disk.get('percent', 0) for disk in disk_usage.values()]) if disk_usage else 0
                processed_metrics['disk']['max_usage_percent'] = max_disk_percent
                processed_metrics['disk']['status'] = self._get_disk_status(max_disk_percent)
            
            # Add trend analysis
            processed_metrics['trends'] = await self._calculate_trends(raw_metrics)
            
            # Add alerts
            processed_metrics['alerts'] = await self._generate_metric_alerts(processed_metrics)
            
            return processed_metrics
            
        except Exception as e:
            logger.error(f"Error processing metrics: {e}")
            return raw_metrics
    
    def _get_cpu_status(self, cpu_percent: float) -> str:
        """Get CPU status based on usage percentage"""
        if cpu_percent < 50:
            return 'normal'
        elif cpu_percent < 80:
            return 'warning'
        else:
            return 'critical'
    
    def _get_memory_status(self, memory_percent: float) -> str:
        """Get memory status based on usage percentage"""
        if memory_percent < 70:
            return 'normal'
        elif memory_percent < 85:
            return 'warning'
        else:
            return 'critical'
    
    def _get_disk_status(self, disk_percent: float) -> str:
        """Get disk status based on usage percentage"""
        if disk_percent < 80:
            return 'normal'
        elif disk_percent < 90:
            return 'warning'
        else:
            return 'critical'
    
    async def _calculate_trends(self, current_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate trends for key metrics"""
        try:
            trends = {}
            
            # Get recent metrics for trend calculation
            recent_metrics = list(self.metrics_storage['system'])[-10:]  # Last 10 metrics
            
            if len(recent_metrics) >= 2:
                # CPU trend
                cpu_values = [m.get('cpu', {}).get('percent', 0) for m in recent_metrics]
                trends['cpu'] = self._calculate_trend(cpu_values)
                
                # Memory trend
                memory_values = [m.get('memory', {}).get('virtual', {}).get('percent', 0) for m in recent_metrics]
                trends['memory'] = self._calculate_trend(memory_values)
                
                # Disk trend (max usage)
                disk_values = []
                for m in recent_metrics:
                    disk_usage = m.get('disk', {}).get('usage', {})
                    max_disk = max([disk.get('percent', 0) for disk in disk_usage.values()]) if disk_usage else 0
                    disk_values.append(max_disk)
                trends['disk'] = self._calculate_trend(disk_values)
            
            return trends
            
        except Exception as e:
            logger.error(f"Error calculating trends: {e}")
            return {}
    
    def _calculate_trend(self, values: List[float]) -> Dict[str, Any]:
        """Calculate trend for a series of values"""
        if len(values) < 2:
            return {'direction': 'stable', 'change': 0}
        
        # Simple linear trend calculation
        recent_avg = sum(values[-3:]) / len(values[-3:]) if len(values) >= 3 else values[-1]
        older_avg = sum(values[:3]) / len(values[:3]) if len(values) >= 3 else values[0]
        
        change = recent_avg - older_avg
        
        if abs(change) < 1:  # Less than 1% change
            direction = 'stable'
        elif change > 0:
            direction = 'increasing'
        else:
            direction = 'decreasing'
        
        return {
            'direction': direction,
            'change': change,
            'recent_avg': recent_avg,
            'older_avg': older_avg
        }
    
    async def _generate_metric_alerts(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate alerts based on metrics"""
        alerts = []
        
        try:
            # CPU alerts
            cpu_percent = metrics.get('cpu', {}).get('percent', 0)
            if cpu_percent > 90:
                alerts.append({
                    'type': 'cpu_critical',
                    'severity': 'critical',
                    'message': f'Critical CPU usage: {cpu_percent:.1f}%',
                    'value': cpu_percent
                })
            elif cpu_percent > 80:
                alerts.append({
                    'type': 'cpu_warning',
                    'severity': 'warning',
                    'message': f'High CPU usage: {cpu_percent:.1f}%',
                    'value': cpu_percent
                })
            
            # Memory alerts
            memory_percent = metrics.get('memory', {}).get('virtual', {}).get('percent', 0)
            if memory_percent > 90:
                alerts.append({
                    'type': 'memory_critical',
                    'severity': 'critical',
                    'message': f'Critical memory usage: {memory_percent:.1f}%',
                    'value': memory_percent
                })
            elif memory_percent > 85:
                alerts.append({
                    'type': 'memory_warning',
                    'severity': 'warning',
                    'message': f'High memory usage: {memory_percent:.1f}%',
                    'value': memory_percent
                })
            
            # Disk alerts
            disk_percent = metrics.get('disk', {}).get('max_usage_percent', 0)
            if disk_percent > 95:
                alerts.append({
                    'type': 'disk_critical',
                    'severity': 'critical',
                    'message': f'Critical disk usage: {disk_percent:.1f}%',
                    'value': disk_percent
                })
            elif disk_percent > 90:
                alerts.append({
                    'type': 'disk_warning',
                    'severity': 'warning',
                    'message': f'High disk usage: {disk_percent:.1f}%',
                    'value': disk_percent
                })
            
        except Exception as e:
            logger.error(f"Error generating metric alerts: {e}")
        
        return alerts
    
    async def store_metrics(self, metrics: Dict[str, Any]) -> None:
        """Store metrics in memory"""
        try:
            metric_type = metrics.get('type', 'application')
            self.metrics_storage[metric_type].append(metrics)
            
        except Exception as e:
            logger.error(f"Error storing metrics: {e}")
    
    async def get_historical_metrics(self, metric_type: str, time_range: str = '1h') -> List[Dict[str, Any]]:
        """Get historical metrics for specified type and time range"""
        try:
            # Parse time range
            if time_range == '1h':
                cutoff_time = datetime.utcnow() - timedelta(hours=1)
            elif time_range == '6h':
                cutoff_time = datetime.utcnow() - timedelta(hours=6)
            elif time_range == '24h':
                cutoff_time = datetime.utcnow() - timedelta(hours=24)
            else:
                cutoff_time = datetime.utcnow() - timedelta(hours=1)
            
            # Get metrics for the specified type
            metrics = list(self.metrics_storage.get(metric_type, []))
            
            # Filter by time range
            filtered_metrics = []
            for metric in metrics:
                try:
                    metric_time = datetime.fromisoformat(metric['timestamp'].replace('Z', '+00:00'))
                    if metric_time >= cutoff_time:
                        filtered_metrics.append(metric)
                except (KeyError, ValueError):
                    continue
            
            return filtered_metrics
            
        except Exception as e:
            logger.error(f"Error getting historical metrics: {e}")
            return []
    
    def register_custom_metric(self, name: str, metric_func: Callable) -> None:
        """Register a custom metric function"""
        self.custom_metrics[name] = metric_func
        logger.info(f"Registered custom metric: {name}")
    
    def record_task_execution_time(self, execution_time: float) -> None:
        """Record task execution time"""
        self.performance_metrics['task_execution_times'].append(execution_time)
    
    def record_api_response_time(self, response_time: float) -> None:
        """Record API response time"""
        self.performance_metrics['api_response_times'].append(response_time)
    
    def record_error(self, error_type: str) -> None:
        """Record an error occurrence"""
        self.performance_metrics['error_counts'][error_type] += 1
    
    def record_success(self, operation_type: str) -> None:
        """Record a successful operation"""
        self.performance_metrics['success_counts'][operation_type] += 1
    
    def _get_recent_errors(self) -> List[Dict[str, Any]]:
        """Get recent error information"""
        # This would typically come from a more sophisticated logging system
        # For now, return basic error count information
        return [
            {
                'type': error_type,
                'count': count,
                'timestamp': datetime.utcnow().isoformat()
            }
            for error_type, count in self.performance_metrics['error_counts'].items()
            if count > 0
        ]
    
    def _register_default_handlers(self) -> None:
        """Register default metric handlers"""
        # Register handlers for different metric types
        self.metric_handlers['system'] = self._handle_system_metrics
        self.metric_handlers['application'] = self._handle_application_metrics
        self.metric_handlers['custom'] = self._handle_custom_metrics
    
    async def _handle_system_metrics(self, metrics: Dict[str, Any]) -> None:
        """Handle system metrics"""
        # Process system metrics if needed
        pass
    
    async def _handle_application_metrics(self, metrics: Dict[str, Any]) -> None:
        """Handle application metrics"""
        # Process application metrics if needed
        pass
    
    async def _handle_custom_metrics(self, metrics: Dict[str, Any]) -> None:
        """Handle custom metrics"""
        # Process custom metrics if needed
        pass
    
    async def _load_historical_metrics(self) -> None:
        """Load historical metrics from storage"""
        try:
            metrics_path = Path(self.config.get('metrics_path', './data/metrics_history.json'))
            if metrics_path.exists():
                with open(metrics_path, 'r') as f:
                    historical_data = json.load(f)
                
                for metric_type, metrics_list in historical_data.items():
                    for metric in metrics_list:
                        self.metrics_storage[metric_type].append(metric)
                
                logger.info(f"Loaded historical metrics from {metrics_path}")
                
        except Exception as e:
            logger.error(f"Error loading historical metrics: {e}")
    
    async def _save_metrics(self) -> None:
        """Save current metrics to storage"""
        try:
            metrics_path = Path(self.config.get('metrics_path', './data/metrics_history.json'))
            metrics_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Convert deques to lists for JSON serialization
            metrics_data = {}
            for metric_type, metrics_deque in self.metrics_storage.items():
                metrics_data[metric_type] = list(metrics_deque)
            
            with open(metrics_path, 'w') as f:
                json.dump(metrics_data, f, indent=2)
            
            logger.info(f"Saved metrics to {metrics_path}")
            
        except Exception as e:
            logger.error(f"Error saving metrics: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get collector status"""
        return {
            'running': self.is_running,
            'metrics_types': list(self.metrics_storage.keys()),
            'total_metrics': sum(len(metrics) for metrics in self.metrics_storage.values()),
            'custom_metrics': list(self.custom_metrics.keys()),
            'performance_metrics': {
                'task_executions': len(self.performance_metrics['task_execution_times']),
                'api_responses': len(self.performance_metrics['api_response_times']),
                'total_errors': sum(self.performance_metrics['error_counts'].values()),
                'total_successes': sum(self.performance_metrics['success_counts'].values())
            }
        }
