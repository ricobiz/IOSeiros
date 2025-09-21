
"""
Task Model
"""
from typing import Dict, Any, List, Optional
from datetime import datetime
from dataclasses import dataclass, asdict
from enum import Enum
import json
import uuid


class TaskStatus(Enum):
    """Task status enumeration"""
    PENDING = 'pending'
    RUNNING = 'running'
    COMPLETED = 'completed'
    FAILED = 'failed'
    CANCELLED = 'cancelled'
    PAUSED = 'paused'


class TaskPriority(Enum):
    """Task priority enumeration"""
    LOW = 'low'
    MEDIUM = 'medium'
    HIGH = 'high'
    CRITICAL = 'critical'


@dataclass
class Task:
    """
    Task data model
    """
    id: str
    name: str
    description: str = ''
    type: str = 'general'
    status: str = TaskStatus.PENDING.value
    priority: str = TaskPriority.MEDIUM.value
    config: Dict[str, Any] = None
    parameters: Dict[str, Any] = None
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    created_at: datetime = None
    updated_at: datetime = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    scheduled_at: Optional[datetime] = None
    timeout: Optional[int] = None
    retry_count: int = 0
    max_retries: int = 3
    user_id: Optional[str] = None
    tags: List[str] = None
    dependencies: List[str] = None
    progress: float = 0.0
    logs: List[Dict[str, Any]] = None
    
    def __post_init__(self):
        """Initialize default values"""
        if not self.id:
            self.id = str(uuid.uuid4())
        
        if self.config is None:
            self.config = {}
        
        if self.parameters is None:
            self.parameters = {}
        
        if self.tags is None:
            self.tags = []
        
        if self.dependencies is None:
            self.dependencies = []
        
        if self.logs is None:
            self.logs = []
        
        if self.created_at is None:
            self.created_at = datetime.utcnow()
        
        if self.updated_at is None:
            self.updated_at = datetime.utcnow()
    
    def start(self) -> None:
        """Mark task as started"""
        self.status = TaskStatus.RUNNING.value
        self.started_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
        self.add_log('info', 'Task started')
    
    def complete(self, result: Optional[Dict[str, Any]] = None) -> None:
        """Mark task as completed"""
        self.status = TaskStatus.COMPLETED.value
        self.completed_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
        self.progress = 100.0
        
        if result:
            self.result = result
        
        self.add_log('info', 'Task completed successfully')
    
    def fail(self, error: str) -> None:
        """Mark task as failed"""
        self.status = TaskStatus.FAILED.value
        self.completed_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
        self.error = error
        self.add_log('error', f'Task failed: {error}')
    
    def cancel(self) -> None:
        """Cancel task"""
        self.status = TaskStatus.CANCELLED.value
        self.completed_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
        self.add_log('warning', 'Task cancelled')
    
    def pause(self) -> None:
        """Pause task"""
        self.status = TaskStatus.PAUSED.value
        self.updated_at = datetime.utcnow()
        self.add_log('info', 'Task paused')
    
    def resume(self) -> None:
        """Resume task"""
        self.status = TaskStatus.RUNNING.value
        self.updated_at = datetime.utcnow()
        self.add_log('info', 'Task resumed')
    
    def retry(self) -> bool:
        """Attempt to retry task"""
        if self.retry_count >= self.max_retries:
            return False
        
        self.retry_count += 1
        self.status = TaskStatus.PENDING.value
        self.error = None
        self.updated_at = datetime.utcnow()
        self.add_log('info', f'Task retry attempt {self.retry_count}/{self.max_retries}')
        
        return True
    
    def update_progress(self, progress: float) -> None:
        """Update task progress"""
        self.progress = max(0.0, min(100.0, progress))
        self.updated_at = datetime.utcnow()
    
    def add_log(self, level: str, message: str, data: Optional[Dict[str, Any]] = None) -> None:
        """Add log entry"""
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': level,
            'message': message,
            'data': data or {}
        }
        self.logs.append(log_entry)
        self.updated_at = datetime.utcnow()
    
    def add_tag(self, tag: str) -> None:
        """Add tag to task"""
        if tag not in self.tags:
            self.tags.append(tag)
            self.updated_at = datetime.utcnow()
    
    def remove_tag(self, tag: str) -> None:
        """Remove tag from task"""
        if tag in self.tags:
            self.tags.remove(tag)
            self.updated_at = datetime.utcnow()
    
    def add_dependency(self, task_id: str) -> None:
        """Add task dependency"""
        if task_id not in self.dependencies:
            self.dependencies.append(task_id)
            self.updated_at = datetime.utcnow()
    
    def remove_dependency(self, task_id: str) -> None:
        """Remove task dependency"""
        if task_id in self.dependencies:
            self.dependencies.remove(task_id)
            self.updated_at = datetime.utcnow()
    
    def is_finished(self) -> bool:
        """Check if task is finished"""
        return self.status in [
            TaskStatus.COMPLETED.value,
            TaskStatus.FAILED.value,
            TaskStatus.CANCELLED.value
        ]
    
    def is_running(self) -> bool:
        """Check if task is running"""
        return self.status == TaskStatus.RUNNING.value
    
    def can_retry(self) -> bool:
        """Check if task can be retried"""
        return (self.status == TaskStatus.FAILED.value and 
                self.retry_count < self.max_retries)
    
    def get_duration(self) -> Optional[float]:
        """Get task duration in seconds"""
        if not self.started_at:
            return None
        
        end_time = self.completed_at or datetime.utcnow()
        return (end_time - self.started_at).total_seconds()
    
    def get_priority_score(self) -> int:
        """Get priority score for sorting"""
        priority_scores = {
            TaskPriority.LOW.value: 1,
            TaskPriority.MEDIUM.value: 2,
            TaskPriority.HIGH.value: 3,
            TaskPriority.CRITICAL.value: 4
        }
        return priority_scores.get(self.priority, 2)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        data = asdict(self)
        
        # Convert datetime objects to ISO strings
        if self.created_at:
            data['created_at'] = self.created_at.isoformat()
        if self.updated_at:
            data['updated_at'] = self.updated_at.isoformat()
        if self.started_at:
            data['started_at'] = self.started_at.isoformat()
        if self.completed_at:
            data['completed_at'] = self.completed_at.isoformat()
        if self.scheduled_at:
            data['scheduled_at'] = self.scheduled_at.isoformat()
        
        # Add computed fields
        data['is_finished'] = self.is_finished()
        data['is_running'] = self.is_running()
        data['can_retry'] = self.can_retry()
        data['duration'] = self.get_duration()
        data['priority_score'] = self.get_priority_score()
        
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Task':
        """Create from dictionary"""
        # Convert ISO strings back to datetime objects
        datetime_fields = ['created_at', 'updated_at', 'started_at', 'completed_at', 'scheduled_at']
        for field in datetime_fields:
            if field in data and isinstance(data[field], str):
                data[field] = datetime.fromisoformat(data[field].replace('Z', '+00:00'))
        
        # Remove computed fields
        computed_fields = ['is_finished', 'is_running', 'can_retry', 'duration', 'priority_score']
        for field in computed_fields:
            data.pop(field, None)
        
        return cls(**data)
    
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict(), indent=2)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'Task':
        """Create from JSON string"""
        data = json.loads(json_str)
        return cls.from_dict(data)
    
    def get_summary(self) -> Dict[str, Any]:
        """Get task summary"""
        return {
            'id': self.id,
            'name': self.name,
            'type': self.type,
            'status': self.status,
            'priority': self.priority,
            'progress': self.progress,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'duration': self.get_duration(),
            'retry_count': self.retry_count,
            'tags': self.tags
        }
    
    def __str__(self) -> str:
        return f"Task(id={self.id}, name={self.name}, status={self.status}, progress={self.progress}%)"
    
    def __repr__(self) -> str:
        return self.__str__()
