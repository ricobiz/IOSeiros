
"""Web Automation Module"""

from .manager import WebAutomationManager
from .js_injector import JSInjector
from .browser_controller import BrowserController
from .form_handler import FormHandler
from .navigation import NavigationManager

__all__ = [
    "WebAutomationManager",
    "JSInjector", 
    "BrowserController",
    "FormHandler",
    "NavigationManager"
]
