
"""
Metric Model
"""
from typing import Dict, Any, List, Optional, Union
from datetime import datetime
from dataclasses import dataclass, asdict
from enum import Enum
import json
import uuid


class MetricType(Enum):
    """Metric types"""
    COUNTER = 'counter'
    GAUGE = 'gauge'
    HISTOGRAM = 'histogram'
    SUMMARY = 'summary'


class MetricUnit(Enum):
    """Metric units"""
    NONE = 'none'
    BYTES = 'bytes'
    SECONDS = 'seconds'
    PERCENT = 'percent'
    COUNT = 'count'
    RATE = 'rate'


@dataclass
class Metric:
    """
    Metric data model
    """
    id: str
    name: str
    value: Union[float, int]
    type: str = MetricType.GAUGE.value
    unit: str = MetricUnit.NONE.value
    description: str = ''
    labels: Dict[str, str] = None
    timestamp: datetime = None
    source: str = 'system'
    category: str = 'general'
    tags: List[str] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        """Initialize default values"""
        if not self.id:
            self.id = str(uuid.uuid4())
        
        if self.labels is None:
            self.labels = {}
        
        if self.tags is None:
            self.tags = []
        
        if self.metadata is None:
            self.metadata = {}
        
        if self.timestamp is None:
            self.timestamp = datetime.utcnow()
    
    def add_label(self, key: str, value: str) -> None:
        """Add label to metric"""
        self.labels[key] = value
    
    def remove_label(self, key: str) -> None:
        """Remove label from metric"""
        self.labels.pop(key, None)
    
    def add_tag(self, tag: str) -> None:
        """Add tag to metric"""
        if tag not in self.tags:
            self.tags.append(tag)
    
    def remove_tag(self, tag: str) -> None:
        """Remove tag from metric"""
        if tag in self.tags:
            self.tags.remove(tag)
    
    def set_metadata(self, key: str, value: Any) -> None:
        """Set metadata value"""
        self.metadata[key] = value
    
    def get_formatted_value(self) -> str:
        """Get formatted value with unit"""
        if self.unit == MetricUnit.BYTES.value:
            return self._format_bytes(self.value)
        elif self.unit == MetricUnit.SECONDS.value:
            return self._format_seconds(self.value)
        elif self.unit == MetricUnit.PERCENT.value:
            return f"{self.value:.1f}%"
        elif self.unit == MetricUnit.RATE.value:
            return f"{self.value:.2f}/s"
        else:
            return str(self.value)
    
    def _format_bytes(self, bytes_value: Union[float, int]) -> str:
        """Format bytes value"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_value < 1024.0:
                return f"{bytes_value:.1f} {unit}"
            bytes_value /= 1024.0
        return f"{bytes_value:.1f} PB"
    
    def _format_seconds(self, seconds_value: Union[float, int]) -> str:
        """Format seconds value"""
        if seconds_value < 60:
            return f"{seconds_value:.2f}s"
        elif seconds_value < 3600:
            minutes = seconds_value / 60
            return f"{minutes:.1f}m"
        else:
            hours = seconds_value / 3600
            return f"{hours:.1f}h"
    
    def is_numeric(self) -> bool:
        """Check if metric value is numeric"""
        return isinstance(self.value, (int, float))
    
    def get_age_seconds(self) -> float:
        """Get age of metric in seconds"""
        return (datetime.utcnow() - self.timestamp).total_seconds()
    
    def is_stale(self, max_age_seconds: int = 300) -> bool:
        """Check if metric is stale (older than max_age_seconds)"""
        return self.get_age_seconds() > max_age_seconds
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        data = asdict(self)
        
        # Convert datetime to ISO string
        if self.timestamp:
            data['timestamp'] = self.timestamp.isoformat()
        
        # Add computed fields
        data['formatted_value'] = self.get_formatted_value()
        data['age_seconds'] = self.get_age_seconds()
        data['is_stale'] = self.is_stale()
        data['is_numeric'] = self.is_numeric()
        
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Metric':
        """Create from dictionary"""
        # Convert ISO string back to datetime
        if 'timestamp' in data and isinstance(data['timestamp'], str):
            data['timestamp'] = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
        
        # Remove computed fields
        computed_fields = ['formatted_value', 'age_seconds', 'is_stale', 'is_numeric']
        for field in computed_fields:
            data.pop(field, None)
        
        return cls(**data)
    
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict(), indent=2)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'Metric':
        """Create from JSON string"""
        data = json.loads(json_str)
        return cls.from_dict(data)
    
    @classmethod
    def create_counter(cls, name: str, value: Union[float, int], **kwargs) -> 'Metric':
        """Create counter metric"""
        return cls(
            id=str(uuid.uuid4()),
            name=name,
            value=value,
            type=MetricType.COUNTER.value,
            unit=MetricUnit.COUNT.value,
            **kwargs
        )
    
    @classmethod
    def create_gauge(cls, name: str, value: Union[float, int], **kwargs) -> 'Metric':
        """Create gauge metric"""
        return cls(
            id=str(uuid.uuid4()),
            name=name,
            value=value,
            type=MetricType.GAUGE.value,
            **kwargs
        )
    
    @classmethod
    def create_percentage(cls, name: str, value: Union[float, int], **kwargs) -> 'Metric':
        """Create percentage metric"""
        return cls(
            id=str(uuid.uuid4()),
            name=name,
            value=value,
            type=MetricType.GAUGE.value,
            unit=MetricUnit.PERCENT.value,
            **kwargs
        )
    
    @classmethod
    def create_bytes(cls, name: str, value: Union[float, int], **kwargs) -> 'Metric':
        """Create bytes metric"""
        return cls(
            id=str(uuid.uuid4()),
            name=name,
            value=value,
            type=MetricType.GAUGE.value,
            unit=MetricUnit.BYTES.value,
            **kwargs
        )
    
    @classmethod
    def create_duration(cls, name: str, value: Union[float, int], **kwargs) -> 'Metric':
        """Create duration metric"""
        return cls(
            id=str(uuid.uuid4()),
            name=name,
            value=value,
            type=MetricType.GAUGE.value,
            unit=MetricUnit.SECONDS.value,
            **kwargs
        )
    
    def get_prometheus_format(self) -> str:
        """Get metric in Prometheus format"""
        labels_str = ''
        if self.labels:
            label_pairs = [f'{k}="{v}"' for k, v in self.labels.items()]
            labels_str = '{' + ','.join(label_pairs) + '}'
        
        return f"{self.name}{labels_str} {self.value}"
    
    def __str__(self) -> str:
        return f"Metric(name={self.name}, value={self.get_formatted_value()}, type={self.type})"
    
    def __repr__(self) -> str:
        return self.__str__()


@dataclass
class MetricSeries:
    """
    Time series of metrics
    """
    name: str
    metrics: List[Metric]
    labels: Dict[str, str] = None
    
    def __post_init__(self):
        """Initialize default values"""
        if self.labels is None:
            self.labels = {}
    
    def add_metric(self, metric: Metric) -> None:
        """Add metric to series"""
        self.metrics.append(metric)
        # Sort by timestamp
        self.metrics.sort(key=lambda m: m.timestamp)
    
    def get_latest(self) -> Optional[Metric]:
        """Get latest metric"""
        return self.metrics[-1] if self.metrics else None
    
    def get_oldest(self) -> Optional[Metric]:
        """Get oldest metric"""
        return self.metrics[0] if self.metrics else None
    
    def get_range(self, start_time: datetime, end_time: datetime) -> List[Metric]:
        """Get metrics in time range"""
        return [
            m for m in self.metrics
            if start_time <= m.timestamp <= end_time
        ]
    
    def get_average(self) -> Optional[float]:
        """Get average value"""
        if not self.metrics:
            return None
        
        numeric_metrics = [m for m in self.metrics if m.is_numeric()]
        if not numeric_metrics:
            return None
        
        return sum(m.value for m in numeric_metrics) / len(numeric_metrics)
    
    def get_min(self) -> Optional[float]:
        """Get minimum value"""
        numeric_metrics = [m for m in self.metrics if m.is_numeric()]
        return min(m.value for m in numeric_metrics) if numeric_metrics else None
    
    def get_max(self) -> Optional[float]:
        """Get maximum value"""
        numeric_metrics = [m for m in self.metrics if m.is_numeric()]
        return max(m.value for m in numeric_metrics) if numeric_metrics else None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            'name': self.name,
            'labels': self.labels,
            'metrics': [m.to_dict() for m in self.metrics],
            'count': len(self.metrics),
            'latest': self.get_latest().to_dict() if self.get_latest() else None,
            'statistics': {
                'average': self.get_average(),
                'min': self.get_min(),
                'max': self.get_max()
            }
        }
    
    def __str__(self) -> str:
        return f"MetricSeries(name={self.name}, count={len(self.metrics)})"
    
    def __repr__(self) -> str:
        return self.__str__()
