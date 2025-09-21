
"""
Notification Model
"""
from typing import Dict, Any, Optional
from datetime import datetime
from dataclasses import dataclass, asdict
from enum import Enum
import json
import uuid


class NotificationType(Enum):
    """Notification types"""
    INFO = 'info'
    WARNING = 'warning'
    ERROR = 'error'
    SUCCESS = 'success'
    ALERT = 'alert'


class NotificationSeverity(Enum):
    """Notification severity levels"""
    LOW = 'low'
    MEDIUM = 'medium'
    HIGH = 'high'
    CRITICAL = 'critical'


@dataclass
class Notification:
    """
    Notification data model
    """
    id: str
    type: str  # NotificationType
    title: str
    message: str
    severity: str = NotificationSeverity.MEDIUM.value
    data: Optional[Dict[str, Any]] = None
    timestamp: datetime = None
    read: bool = False
    read_at: Optional[datetime] = None
    sent: bool = False
    sent_at: Optional[datetime] = None
    user_id: Optional[str] = None
    source: str = 'system'
    category: str = 'general'
    expires_at: Optional[datetime] = None
    actions: Optional[Dict[str, Any]] = None
    
    def __post_init__(self):
        """Initialize default values"""
        if not self.id:
            self.id = str(uuid.uuid4())
        
        if self.timestamp is None:
            self.timestamp = datetime.utcnow()
        
        if self.data is None:
            self.data = {}
        
        if self.actions is None:
            self.actions = {}
    
    def mark_as_read(self) -> None:
        """Mark notification as read"""
        self.read = True
        self.read_at = datetime.utcnow()
    
    def mark_as_sent(self) -> None:
        """Mark notification as sent"""
        self.sent = True
        self.sent_at = datetime.utcnow()
    
    def is_expired(self) -> bool:
        """Check if notification is expired"""
        if self.expires_at is None:
            return False
        return datetime.utcnow() > self.expires_at
    
    def set_expiry(self, hours: int) -> None:
        """Set expiry time in hours from now"""
        from datetime import timedelta
        self.expires_at = datetime.utcnow() + timedelta(hours=hours)
    
    def add_action(self, action_id: str, action_data: Dict[str, Any]) -> None:
        """Add action to notification"""
        self.actions[action_id] = action_data
    
    def remove_action(self, action_id: str) -> None:
        """Remove action from notification"""
        self.actions.pop(action_id, None)
    
    def get_priority_score(self) -> int:
        """Get priority score for sorting"""
        severity_scores = {
            NotificationSeverity.LOW.value: 1,
            NotificationSeverity.MEDIUM.value: 2,
            NotificationSeverity.HIGH.value: 3,
            NotificationSeverity.CRITICAL.value: 4
        }
        
        type_scores = {
            NotificationType.INFO.value: 1,
            NotificationType.SUCCESS.value: 2,
            NotificationType.WARNING.value: 3,
            NotificationType.ERROR.value: 4,
            NotificationType.ALERT.value: 5
        }
        
        severity_score = severity_scores.get(self.severity, 2)
        type_score = type_scores.get(self.type, 1)
        
        # Higher score = higher priority
        return severity_score * 10 + type_score
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        data = asdict(self)
        
        # Convert datetime objects to ISO strings
        if self.timestamp:
            data['timestamp'] = self.timestamp.isoformat()
        if self.read_at:
            data['read_at'] = self.read_at.isoformat()
        if self.sent_at:
            data['sent_at'] = self.sent_at.isoformat()
        if self.expires_at:
            data['expires_at'] = self.expires_at.isoformat()
        
        # Add computed fields
        data['is_expired'] = self.is_expired()
        data['priority_score'] = self.get_priority_score()
        
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Notification':
        """Create from dictionary"""
        # Convert ISO strings back to datetime objects
        if 'timestamp' in data and isinstance(data['timestamp'], str):
            data['timestamp'] = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
        if 'read_at' in data and isinstance(data['read_at'], str):
            data['read_at'] = datetime.fromisoformat(data['read_at'].replace('Z', '+00:00'))
        if 'sent_at' in data and isinstance(data['sent_at'], str):
            data['sent_at'] = datetime.fromisoformat(data['sent_at'].replace('Z', '+00:00'))
        if 'expires_at' in data and isinstance(data['expires_at'], str):
            data['expires_at'] = datetime.fromisoformat(data['expires_at'].replace('Z', '+00:00'))
        
        # Remove computed fields
        data.pop('is_expired', None)
        data.pop('priority_score', None)
        
        return cls(**data)
    
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict(), indent=2)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'Notification':
        """Create from JSON string"""
        data = json.loads(json_str)
        return cls.from_dict(data)
    
    @classmethod
    def create_info(cls, title: str, message: str, **kwargs) -> 'Notification':
        """Create info notification"""
        return cls(
            id=str(uuid.uuid4()),
            type=NotificationType.INFO.value,
            title=title,
            message=message,
            severity=NotificationSeverity.LOW.value,
            **kwargs
        )
    
    @classmethod
    def create_warning(cls, title: str, message: str, **kwargs) -> 'Notification':
        """Create warning notification"""
        return cls(
            id=str(uuid.uuid4()),
            type=NotificationType.WARNING.value,
            title=title,
            message=message,
            severity=NotificationSeverity.MEDIUM.value,
            **kwargs
        )
    
    @classmethod
    def create_error(cls, title: str, message: str, **kwargs) -> 'Notification':
        """Create error notification"""
        return cls(
            id=str(uuid.uuid4()),
            type=NotificationType.ERROR.value,
            title=title,
            message=message,
            severity=NotificationSeverity.HIGH.value,
            **kwargs
        )
    
    @classmethod
    def create_alert(cls, title: str, message: str, **kwargs) -> 'Notification':
        """Create alert notification"""
        return cls(
            id=str(uuid.uuid4()),
            type=NotificationType.ALERT.value,
            title=title,
            message=message,
            severity=NotificationSeverity.CRITICAL.value,
            **kwargs
        )
    
    @classmethod
    def create_success(cls, title: str, message: str, **kwargs) -> 'Notification':
        """Create success notification"""
        return cls(
            id=str(uuid.uuid4()),
            type=NotificationType.SUCCESS.value,
            title=title,
            message=message,
            severity=NotificationSeverity.LOW.value,
            **kwargs
        )
    
    def __str__(self) -> str:
        return f"Notification(id={self.id}, type={self.type}, severity={self.severity}, title={self.title})"
    
    def __repr__(self) -> str:
        return self.__str__()
