
"""
Configuration management for EirosAgent
"""
import yaml
from pathlib import Path
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field
from loguru import logger


class WebAutomationConfig(BaseModel):
    """Web automation configuration"""
    browser: Dict[str, Any] = Field(default_factory=dict)
    javascript: Dict[str, Any] = Field(default_factory=dict)
    forms: Dict[str, Any] = Field(default_factory=dict)


class OCRConfig(BaseModel):
    """OCR configuration"""
    engines: Dict[str, str] = Field(default_factory=dict)
    easyocr: Dict[str, Any] = Field(default_factory=dict)
    paddleocr: Dict[str, Any] = Field(default_factory=dict)
    tesseract: Dict[str, Any] = Field(default_factory=dict)
    preprocessing: Dict[str, Any] = Field(default_factory=dict)


class SchedulerConfig(BaseModel):
    """Scheduler configuration"""
    max_concurrent_tasks: int = 10
    task_timeout: int = 300
    retry_attempts: int = 3
    retry_delay: int = 5
    storage: Dict[str, Any] = Field(default_factory=dict)


class VisionConfig(BaseModel):
    """Vision system configuration"""
    screen_capture: Dict[str, Any] = Field(default_factory=dict)
    analysis: Dict[str, Any] = Field(default_factory=dict)


class LoggingConfig(BaseModel):
    """Logging configuration"""
    level: str = "INFO"
    format: str = "{time:YYYY-MM-DD HH:mm:ss} | {level} | {name} | {message}"
    file: str = "./logs/eiros_agent.log"
    rotation: str = "1 day"
    retention: str = "30 days"


class Config:
    """Main configuration class"""
    
    def __init__(self, config_path: Optional[str] = None):
        """Load configuration from file or use defaults"""
        self.config_path = config_path or "config/default_config.yaml"
        self._config_data = self._load_config()
        
        # Parse configuration sections
        self.app = self._config_data.get("app", {})
        self.web_automation = WebAutomationConfig(**self._config_data.get("web_automation", {}))
        self.ocr = OCRConfig(**self._config_data.get("ocr", {}))
        self.scheduler = SchedulerConfig(**self._config_data.get("scheduler", {}))
        self.vision = VisionConfig(**self._config_data.get("vision", {}))
        self.logging = LoggingConfig(**self._config_data.get("logging", {}))
        
        self._setup_logging()
        logger.info(f"Configuration loaded from {self.config_path}")
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        config_file = Path(self.config_path)
        
        if not config_file.exists():
            logger.warning(f"Config file {self.config_path} not found, using defaults")
            return {}
        
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f) or {}
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            return {}
    
    def _setup_logging(self) -> None:
        """Setup logging configuration"""
        logger.remove()  # Remove default handler
        
        # Add file handler
        log_file = Path(self.logging.file)
        log_file.parent.mkdir(parents=True, exist_ok=True)
        
        logger.add(
            log_file,
            format=self.logging.format,
            level=self.logging.level,
            rotation=self.logging.rotation,
            retention=self.logging.retention
        )
        
        # Add console handler
        logger.add(
            lambda msg: print(msg, end=""),
            format=self.logging.format,
            level=self.logging.level
        )
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value by key"""
        keys = key.split('.')
        value = self._config_data
        
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        
        return value
    
    def update(self, key: str, value: Any) -> None:
        """Update configuration value"""
        keys = key.split('.')
        config = self._config_data
        
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        
        config[keys[-1]] = value
        logger.info(f"Configuration updated: {key} = {value}")
