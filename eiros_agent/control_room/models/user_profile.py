
"""
User Profile Model
"""
from typing import Dict, Any, List, Optional
from datetime import datetime
from dataclasses import dataclass, asdict
import json


@dataclass
class UserProfile:
    """
    User profile data model
    """
    id: str
    name: str
    email: str
    role: str = 'user'
    preferences: Dict[str, Any] = None
    permissions: List[str] = None
    created_at: datetime = None
    updated_at: datetime = None
    last_login: Optional[datetime] = None
    is_active: bool = True
    
    def __post_init__(self):
        """Initialize default values"""
        if self.preferences is None:
            self.preferences = {
                'theme': 'dark',
                'language': 'en',
                'timezone': 'UTC',
                'notifications_enabled': True,
                'dashboard_layout': 'default',
                'refresh_interval': 5,
                'auto_refresh': True,
                'sound_alerts': False
            }
        
        if self.permissions is None:
            self.permissions = self._get_default_permissions()
        
        if self.created_at is None:
            self.created_at = datetime.utcnow()
        
        if self.updated_at is None:
            self.updated_at = datetime.utcnow()
    
    def _get_default_permissions(self) -> List[str]:
        """Get default permissions based on role"""
        if self.role == 'admin':
            return [
                'view_dashboard',
                'view_metrics',
                'view_tasks',
                'create_tasks',
                'edit_tasks',
                'delete_tasks',
                'execute_tasks',
                'view_notifications',
                'create_notifications',
                'manage_users',
                'manage_settings',
                'view_logs',
                'system_control'
            ]
        elif self.role == 'operator':
            return [
                'view_dashboard',
                'view_metrics',
                'view_tasks',
                'create_tasks',
                'edit_tasks',
                'execute_tasks',
                'view_notifications',
                'create_notifications'
            ]
        else:  # user
            return [
                'view_dashboard',
                'view_metrics',
                'view_tasks',
                'view_notifications'
            ]
    
    def has_permission(self, permission: str) -> bool:
        """Check if user has specific permission"""
        return permission in self.permissions
    
    def update_preference(self, key: str, value: Any) -> None:
        """Update user preference"""
        self.preferences[key] = value
        self.updated_at = datetime.utcnow()
    
    def update_preferences(self, preferences: Dict[str, Any]) -> None:
        """Update multiple preferences"""
        self.preferences.update(preferences)
        self.updated_at = datetime.utcnow()
    
    def add_permission(self, permission: str) -> None:
        """Add permission to user"""
        if permission not in self.permissions:
            self.permissions.append(permission)
            self.updated_at = datetime.utcnow()
    
    def remove_permission(self, permission: str) -> None:
        """Remove permission from user"""
        if permission in self.permissions:
            self.permissions.remove(permission)
            self.updated_at = datetime.utcnow()
    
    def set_last_login(self) -> None:
        """Set last login timestamp"""
        self.last_login = datetime.utcnow()
        self.updated_at = datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        data = asdict(self)
        
        # Convert datetime objects to ISO strings
        if self.created_at:
            data['created_at'] = self.created_at.isoformat()
        if self.updated_at:
            data['updated_at'] = self.updated_at.isoformat()
        if self.last_login:
            data['last_login'] = self.last_login.isoformat()
        
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'UserProfile':
        """Create from dictionary"""
        # Convert ISO strings back to datetime objects
        if 'created_at' in data and isinstance(data['created_at'], str):
            data['created_at'] = datetime.fromisoformat(data['created_at'].replace('Z', '+00:00'))
        if 'updated_at' in data and isinstance(data['updated_at'], str):
            data['updated_at'] = datetime.fromisoformat(data['updated_at'].replace('Z', '+00:00'))
        if 'last_login' in data and isinstance(data['last_login'], str):
            data['last_login'] = datetime.fromisoformat(data['last_login'].replace('Z', '+00:00'))
        
        return cls(**data)
    
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict(), indent=2)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'UserProfile':
        """Create from JSON string"""
        data = json.loads(json_str)
        return cls.from_dict(data)
    
    def get_safe_dict(self) -> Dict[str, Any]:
        """Get dictionary without sensitive information"""
        data = self.to_dict()
        
        # Remove sensitive fields if needed
        # (currently no sensitive fields, but this method is for future use)
        
        return data
    
    def __str__(self) -> str:
        return f"UserProfile(id={self.id}, name={self.name}, role={self.role})"
    
    def __repr__(self) -> str:
        return self.__str__()
