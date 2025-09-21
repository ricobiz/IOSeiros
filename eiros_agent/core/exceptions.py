
"""
Custom exceptions for EirosAgent
"""


class EirosAgentError(Exception):
    """Base exception for EirosAgent"""
    pass


class WebAutomationError(EirosAgentError):
    """Web automation related errors"""
    pass


class OCRError(EirosAgentError):
    """OCR processing errors"""
    pass


class VisionError(EirosAgentError):
    """Vision system errors"""
    pass


class SchedulerError(EirosAgentError):
    """Task scheduler errors"""
    pass


class ConfigurationError(EirosAgentError):
    """Configuration related errors"""
    pass


class BrowserError(WebAutomationError):
    """Browser control errors"""
    pass


class JSInjectionError(WebAutomationError):
    """JavaScript injection errors"""
    pass


class FormHandlingError(WebAutomationError):
    """Form handling errors"""
    pass


class NavigationError(WebAutomationError):
    """Navigation errors"""
    pass


class OCREngineError(OCRError):
    """OCR engine specific errors"""
    pass


class ImageProcessingError(OCRError):
    """Image preprocessing errors"""
    pass


class TaskExecutionError(SchedulerError):
    """Task execution errors"""
    pass


class MacroError(SchedulerError):
    """Macro processing errors"""
    pass


class ScreenCaptureError(VisionError):
    """Screen capture errors"""
    pass


class ImageAnalysisError(VisionError):
    """Image analysis errors"""
    pass
