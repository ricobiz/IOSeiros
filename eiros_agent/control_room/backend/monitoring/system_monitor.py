
"""
System Monitor - Real-time system metrics collection
"""
import asyncio
import psutil
import platform
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from collections import deque
import json
from pathlib import Path
from loguru import logger


class SystemMonitor:
    """
    Real-time system monitoring component
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize System Monitor"""
        self.config = config
        self.is_running = False
        
        # Historical data storage
        self.history_size = config.get('history_size', 1000)
        self.metrics_history = deque(maxlen=self.history_size)
        
        # System info cache
        self._system_info = None
        self._last_system_info_update = None
        
        logger.info("System Monitor initialized")
    
    async def initialize(self) -> None:
        """Initialize system monitor"""
        try:
            # Get initial system information
            await self._update_system_info()
            
            self.is_running = True
            logger.info("System Monitor initialization complete")
            
        except Exception as e:
            logger.error(f"Failed to initialize System Monitor: {e}")
            raise
    
    async def shutdown(self) -> None:
        """Shutdown system monitor"""
        logger.info("Shutting down System Monitor...")
        
        self.is_running = False
        
        # Save historical data if configured
        if self.config.get('save_history', False):
            await self._save_history()
        
        logger.info("System Monitor shutdown complete")
    
    async def collect_metrics(self) -> Dict[str, Any]:
        """Collect current system metrics"""
        try:
            metrics = {
                'timestamp': datetime.utcnow().isoformat(),
                'cpu': await self._get_cpu_metrics(),
                'memory': await self._get_memory_metrics(),
                'disk': await self._get_disk_metrics(),
                'network': await self._get_network_metrics(),
                'processes': await self._get_process_metrics(),
                'system': await self._get_system_metrics()
            }
            
            # Add to history
            self.metrics_history.append(metrics)
            
            return metrics
            
        except Exception as e:
            logger.error(f"Error collecting system metrics: {e}")
            return {}
    
    async def _get_cpu_metrics(self) -> Dict[str, Any]:
        """Get CPU metrics"""
        try:
            # Get CPU percentages
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_per_core = psutil.cpu_percent(interval=1, percpu=True)
            
            # Get CPU frequencies
            cpu_freq = psutil.cpu_freq()
            
            # Get CPU stats
            cpu_stats = psutil.cpu_stats()
            
            # Get load average (Unix only)
            load_avg = None
            try:
                load_avg = psutil.getloadavg()
            except AttributeError:
                pass  # Windows doesn't have load average
            
            return {
                'percent': cpu_percent,
                'per_core': cpu_per_core,
                'count': psutil.cpu_count(),
                'count_logical': psutil.cpu_count(logical=True),
                'frequency': {
                    'current': cpu_freq.current if cpu_freq else None,
                    'min': cpu_freq.min if cpu_freq else None,
                    'max': cpu_freq.max if cpu_freq else None
                },
                'stats': {
                    'ctx_switches': cpu_stats.ctx_switches,
                    'interrupts': cpu_stats.interrupts,
                    'soft_interrupts': cpu_stats.soft_interrupts,
                    'syscalls': cpu_stats.syscalls
                },
                'load_average': load_avg
            }
            
        except Exception as e:
            logger.error(f"Error getting CPU metrics: {e}")
            return {}
    
    async def _get_memory_metrics(self) -> Dict[str, Any]:
        """Get memory metrics"""
        try:
            # Virtual memory
            virtual_mem = psutil.virtual_memory()
            
            # Swap memory
            swap_mem = psutil.swap_memory()
            
            return {
                'virtual': {
                    'total': virtual_mem.total,
                    'available': virtual_mem.available,
                    'used': virtual_mem.used,
                    'free': virtual_mem.free,
                    'percent': virtual_mem.percent,
                    'active': getattr(virtual_mem, 'active', None),
                    'inactive': getattr(virtual_mem, 'inactive', None),
                    'buffers': getattr(virtual_mem, 'buffers', None),
                    'cached': getattr(virtual_mem, 'cached', None)
                },
                'swap': {
                    'total': swap_mem.total,
                    'used': swap_mem.used,
                    'free': swap_mem.free,
                    'percent': swap_mem.percent,
                    'sin': swap_mem.sin,
                    'sout': swap_mem.sout
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting memory metrics: {e}")
            return {}
    
    async def _get_disk_metrics(self) -> Dict[str, Any]:
        """Get disk metrics"""
        try:
            disk_metrics = {}
            
            # Disk usage for all mounted disks
            disk_partitions = psutil.disk_partitions()
            disk_usage = {}
            
            for partition in disk_partitions:
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    disk_usage[partition.device] = {
                        'mountpoint': partition.mountpoint,
                        'fstype': partition.fstype,
                        'total': usage.total,
                        'used': usage.used,
                        'free': usage.free,
                        'percent': (usage.used / usage.total) * 100 if usage.total > 0 else 0
                    }
                except PermissionError:
                    # Skip inaccessible partitions
                    continue
            
            # Disk I/O statistics
            disk_io = psutil.disk_io_counters()
            disk_io_per_disk = psutil.disk_io_counters(perdisk=True)
            
            disk_metrics = {
                'usage': disk_usage,
                'io': {
                    'total': {
                        'read_count': disk_io.read_count if disk_io else 0,
                        'write_count': disk_io.write_count if disk_io else 0,
                        'read_bytes': disk_io.read_bytes if disk_io else 0,
                        'write_bytes': disk_io.write_bytes if disk_io else 0,
                        'read_time': disk_io.read_time if disk_io else 0,
                        'write_time': disk_io.write_time if disk_io else 0
                    },
                    'per_disk': {}
                }
            }
            
            # Per-disk I/O stats
            for disk, io_stats in disk_io_per_disk.items():
                disk_metrics['io']['per_disk'][disk] = {
                    'read_count': io_stats.read_count,
                    'write_count': io_stats.write_count,
                    'read_bytes': io_stats.read_bytes,
                    'write_bytes': io_stats.write_bytes,
                    'read_time': io_stats.read_time,
                    'write_time': io_stats.write_time
                }
            
            return disk_metrics
            
        except Exception as e:
            logger.error(f"Error getting disk metrics: {e}")
            return {}
    
    async def _get_network_metrics(self) -> Dict[str, Any]:
        """Get network metrics"""
        try:
            # Network I/O statistics
            net_io = psutil.net_io_counters()
            net_io_per_interface = psutil.net_io_counters(pernic=True)
            
            # Network connections
            connections = psutil.net_connections()
            
            # Network interface addresses
            net_if_addrs = psutil.net_if_addrs()
            net_if_stats = psutil.net_if_stats()
            
            network_metrics = {
                'io': {
                    'total': {
                        'bytes_sent': net_io.bytes_sent if net_io else 0,
                        'bytes_recv': net_io.bytes_recv if net_io else 0,
                        'packets_sent': net_io.packets_sent if net_io else 0,
                        'packets_recv': net_io.packets_recv if net_io else 0,
                        'errin': net_io.errin if net_io else 0,
                        'errout': net_io.errout if net_io else 0,
                        'dropin': net_io.dropin if net_io else 0,
                        'dropout': net_io.dropout if net_io else 0
                    },
                    'per_interface': {}
                },
                'connections': {
                    'total': len(connections),
                    'by_status': {},
                    'by_family': {}
                },
                'interfaces': {}
            }
            
            # Per-interface I/O stats
            for interface, io_stats in net_io_per_interface.items():
                network_metrics['io']['per_interface'][interface] = {
                    'bytes_sent': io_stats.bytes_sent,
                    'bytes_recv': io_stats.bytes_recv,
                    'packets_sent': io_stats.packets_sent,
                    'packets_recv': io_stats.packets_recv,
                    'errin': io_stats.errin,
                    'errout': io_stats.errout,
                    'dropin': io_stats.dropin,
                    'dropout': io_stats.dropout
                }
            
            # Connection statistics
            for conn in connections:
                status = conn.status
                family = conn.family.name if hasattr(conn.family, 'name') else str(conn.family)
                
                network_metrics['connections']['by_status'][status] = \
                    network_metrics['connections']['by_status'].get(status, 0) + 1
                network_metrics['connections']['by_family'][family] = \
                    network_metrics['connections']['by_family'].get(family, 0) + 1
            
            # Interface information
            for interface, addrs in net_if_addrs.items():
                stats = net_if_stats.get(interface)
                
                network_metrics['interfaces'][interface] = {
                    'addresses': [
                        {
                            'family': addr.family.name if hasattr(addr.family, 'name') else str(addr.family),
                            'address': addr.address,
                            'netmask': addr.netmask,
                            'broadcast': addr.broadcast
                        }
                        for addr in addrs
                    ],
                    'stats': {
                        'isup': stats.isup if stats else False,
                        'duplex': stats.duplex.name if stats and hasattr(stats.duplex, 'name') else None,
                        'speed': stats.speed if stats else None,
                        'mtu': stats.mtu if stats else None
                    }
                }
            
            return network_metrics
            
        except Exception as e:
            logger.error(f"Error getting network metrics: {e}")
            return {}
    
    async def _get_process_metrics(self) -> Dict[str, Any]:
        """Get process metrics"""
        try:
            processes = []
            
            # Get top processes by CPU and memory usage
            top_processes_cpu = sorted(
                psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']),
                key=lambda p: p.info['cpu_percent'] or 0,
                reverse=True
            )[:10]
            
            top_processes_memory = sorted(
                psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']),
                key=lambda p: p.info['memory_percent'] or 0,
                reverse=True
            )[:10]
            
            return {
                'total_count': len(psutil.pids()),
                'top_cpu': [
                    {
                        'pid': p.info['pid'],
                        'name': p.info['name'],
                        'cpu_percent': p.info['cpu_percent'],
                        'memory_percent': p.info['memory_percent']
                    }
                    for p in top_processes_cpu
                ],
                'top_memory': [
                    {
                        'pid': p.info['pid'],
                        'name': p.info['name'],
                        'cpu_percent': p.info['cpu_percent'],
                        'memory_percent': p.info['memory_percent']
                    }
                    for p in top_processes_memory
                ]
            }
            
        except Exception as e:
            logger.error(f"Error getting process metrics: {e}")
            return {}
    
    async def _get_system_metrics(self) -> Dict[str, Any]:
        """Get general system metrics"""
        try:
            # Boot time
            boot_time = datetime.fromtimestamp(psutil.boot_time())
            uptime = datetime.now() - boot_time
            
            # Users
            users = psutil.users()
            
            return {
                'boot_time': boot_time.isoformat(),
                'uptime_seconds': uptime.total_seconds(),
                'users': [
                    {
                        'name': user.name,
                        'terminal': user.terminal,
                        'host': user.host,
                        'started': datetime.fromtimestamp(user.started).isoformat()
                    }
                    for user in users
                ]
            }
            
        except Exception as e:
            logger.error(f"Error getting system metrics: {e}")
            return {}
    
    async def _update_system_info(self) -> None:
        """Update cached system information"""
        try:
            self._system_info = {
                'platform': platform.platform(),
                'system': platform.system(),
                'release': platform.release(),
                'version': platform.version(),
                'machine': platform.machine(),
                'processor': platform.processor(),
                'architecture': platform.architecture(),
                'hostname': platform.node(),
                'python_version': platform.python_version()
            }
            
            self._last_system_info_update = datetime.utcnow()
            
        except Exception as e:
            logger.error(f"Error updating system info: {e}")
    
    async def get_current_status(self) -> Dict[str, Any]:
        """Get current system status"""
        try:
            current_metrics = await self.collect_metrics()
            
            # Update system info if needed
            if (not self._last_system_info_update or 
                datetime.utcnow() - self._last_system_info_update > timedelta(hours=1)):
                await self._update_system_info()
            
            return {
                'system_info': self._system_info,
                'current_metrics': current_metrics,
                'monitoring_status': {
                    'running': self.is_running,
                    'history_size': len(self.metrics_history),
                    'last_update': current_metrics.get('timestamp')
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting current status: {e}")
            return {}
    
    async def get_historical_metrics(self, time_range: str = '1h') -> List[Dict[str, Any]]:
        """Get historical metrics for specified time range"""
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
            
            # Filter metrics by time range
            filtered_metrics = []
            for metric in self.metrics_history:
                metric_time = datetime.fromisoformat(metric['timestamp'].replace('Z', '+00:00'))
                if metric_time >= cutoff_time:
                    filtered_metrics.append(metric)
            
            return filtered_metrics
            
        except Exception as e:
            logger.error(f"Error getting historical metrics: {e}")
            return []
    
    async def _save_history(self) -> None:
        """Save metrics history to file"""
        try:
            history_path = Path(self.config.get('history_path', './data/system_metrics_history.json'))
            history_path.parent.mkdir(parents=True, exist_ok=True)
            
            history_data = list(self.metrics_history)
            
            with open(history_path, 'w') as f:
                json.dump(history_data, f, indent=2)
            
            logger.info(f"Saved {len(history_data)} metrics records to {history_path}")
            
        except Exception as e:
            logger.error(f"Error saving metrics history: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get monitor status"""
        return {
            'running': self.is_running,
            'history_size': len(self.metrics_history),
            'last_update': self.metrics_history[-1]['timestamp'] if self.metrics_history else None
        }
