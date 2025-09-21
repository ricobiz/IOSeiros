
"""
Screen Capture Manager - handles screen and window capture
"""
import asyncio
from typing import Dict, Any, Optional, List, Tuple
import platform
from pathlib import Path
import numpy as np
from PIL import Image, ImageGrab
from loguru import logger

from ..core.exceptions import ScreenCaptureError


class ScreenCaptureManager:
    """
    Advanced screen capture system with multi-platform support
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize screen capture manager"""
        self.config = config
        self.format = config.get("format", "png")
        self.quality = config.get("quality", 90)
        self.region_detection = config.get("region_detection", True)
        
        self.platform = platform.system().lower()
        self.is_initialized = False
        
        logger.info(f"ScreenCaptureManager initialized for {self.platform}")
    
    async def initialize(self) -> None:
        """Initialize screen capture system"""
        try:
            logger.info("Initializing screen capture system...")
            
            # Platform-specific initialization
            if self.platform == "windows":
                await self._initialize_windows()
            elif self.platform == "darwin":  # macOS
                await self._initialize_macos()
            elif self.platform == "linux":
                await self._initialize_linux()
            else:
                logger.warning(f"Unsupported platform: {self.platform}")
            
            self.is_initialized = True
            logger.info("Screen capture system initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize screen capture: {e}")
            raise ScreenCaptureError(f"Screen capture initialization failed: {e}")
    
    async def shutdown(self) -> None:
        """Shutdown screen capture system"""
        logger.info("Shutting down screen capture system...")
        self.is_initialized = False
        logger.info("Screen capture system shutdown complete")
    
    async def capture_screen(self, region: Optional[Dict[str, int]] = None) -> Image.Image:
        """Capture full screen or region"""
        if not self.is_initialized:
            raise ScreenCaptureError("Screen capture not initialized")
        
        try:
            logger.debug("Capturing screen")
            
            if region:
                # Capture specific region
                bbox = (
                    region.get("x", 0),
                    region.get("y", 0),
                    region.get("x", 0) + region.get("width", 100),
                    region.get("y", 0) + region.get("height", 100)
                )
                screenshot = ImageGrab.grab(bbox=bbox)
            else:
                # Capture full screen
                screenshot = ImageGrab.grab()
            
            logger.debug(f"Screenshot captured: {screenshot.size}")
            return screenshot
            
        except Exception as e:
            logger.error(f"Screen capture failed: {e}")
            raise ScreenCaptureError(f"Screen capture failed: {e}")
    
    async def capture_window(self, window_title: str) -> Optional[Image.Image]:
        """Capture specific window by title"""
        if not self.is_initialized:
            raise ScreenCaptureError("Screen capture not initialized")
        
        try:
            logger.debug(f"Capturing window: {window_title}")
            
            if self.platform == "windows":
                return await self._capture_window_windows(window_title)
            elif self.platform == "darwin":
                return await self._capture_window_macos(window_title)
            elif self.platform == "linux":
                return await self._capture_window_linux(window_title)
            else:
                logger.warning("Window capture not supported on this platform")
                return None
                
        except Exception as e:
            logger.error(f"Window capture failed: {e}")
            raise ScreenCaptureError(f"Window capture failed: {e}")
    
    async def capture_multiple_screens(self) -> List[Image.Image]:
        """Capture all available screens"""
        if not self.is_initialized:
            raise ScreenCaptureError("Screen capture not initialized")
        
        try:
            logger.debug("Capturing multiple screens")
            
            screenshots = []
            
            # Get screen info
            screen_info = await self.get_screen_info()
            monitors = screen_info.get("monitors", [])
            
            for i, monitor in enumerate(monitors):
                try:
                    region = {
                        "x": monitor.get("x", 0),
                        "y": monitor.get("y", 0),
                        "width": monitor.get("width", 1920),
                        "height": monitor.get("height", 1080)
                    }
                    
                    screenshot = await self.capture_screen(region)
                    screenshots.append(screenshot)
                    
                    logger.debug(f"Captured screen {i+1}: {screenshot.size}")
                    
                except Exception as e:
                    logger.error(f"Failed to capture screen {i+1}: {e}")
            
            return screenshots
            
        except Exception as e:
            logger.error(f"Multiple screen capture failed: {e}")
            raise ScreenCaptureError(f"Multiple screen capture failed: {e}")
    
    async def get_screen_info(self) -> Dict[str, Any]:
        """Get screen information"""
        try:
            if self.platform == "windows":
                return await self._get_screen_info_windows()
            elif self.platform == "darwin":
                return await self._get_screen_info_macos()
            elif self.platform == "linux":
                return await self._get_screen_info_linux()
            else:
                # Fallback using PIL
                screenshot = ImageGrab.grab()
                return {
                    "primary_screen": {
                        "width": screenshot.width,
                        "height": screenshot.height,
                        "x": 0,
                        "y": 0
                    },
                    "monitors": [{
                        "width": screenshot.width,
                        "height": screenshot.height,
                        "x": 0,
                        "y": 0,
                        "primary": True
                    }],
                    "total_width": screenshot.width,
                    "total_height": screenshot.height
                }
                
        except Exception as e:
            logger.error(f"Failed to get screen info: {e}")
            return {}
    
    async def list_windows(self) -> List[Dict[str, Any]]:
        """List all available windows"""
        try:
            if self.platform == "windows":
                return await self._list_windows_windows()
            elif self.platform == "darwin":
                return await self._list_windows_macos()
            elif self.platform == "linux":
                return await self._list_windows_linux()
            else:
                logger.warning("Window listing not supported on this platform")
                return []
                
        except Exception as e:
            logger.error(f"Failed to list windows: {e}")
            return []
    
    async def save_screenshot(self, image: Image.Image, path: str) -> str:
        """Save screenshot to file"""
        try:
            # Ensure directory exists
            Path(path).parent.mkdir(parents=True, exist_ok=True)
            
            # Save with specified format and quality
            if self.format.lower() == "jpeg":
                image.save(path, format="JPEG", quality=self.quality)
            else:
                image.save(path, format="PNG")
            
            logger.debug(f"Screenshot saved to: {path}")
            return path
            
        except Exception as e:
            logger.error(f"Failed to save screenshot: {e}")
            raise ScreenCaptureError(f"Failed to save screenshot: {e}")
    
    # Platform-specific implementations
    async def _initialize_windows(self) -> None:
        """Initialize Windows-specific screen capture"""
        try:
            import win32gui
            import win32con
            import win32api
            self._win32_available = True
        except ImportError:
            logger.warning("pywin32 not available, using fallback methods")
            self._win32_available = False
    
    async def _initialize_macos(self) -> None:
        """Initialize macOS-specific screen capture"""
        try:
            import Quartz
            self._quartz_available = True
        except ImportError:
            logger.warning("Quartz not available, using fallback methods")
            self._quartz_available = False
    
    async def _initialize_linux(self) -> None:
        """Initialize Linux-specific screen capture"""
        try:
            import Xlib.display
            self._xlib_available = True
        except ImportError:
            logger.warning("Xlib not available, using fallback methods")
            self._xlib_available = False
    
    async def _capture_window_windows(self, window_title: str) -> Optional[Image.Image]:
        """Capture window on Windows"""
        if not hasattr(self, '_win32_available') or not self._win32_available:
            return None
        
        try:
            import win32gui
            import win32ui
            import win32con
            from ctypes import windll
            
            # Find window
            hwnd = win32gui.FindWindow(None, window_title)
            if not hwnd:
                logger.warning(f"Window not found: {window_title}")
                return None
            
            # Get window rect
            left, top, right, bottom = win32gui.GetWindowRect(hwnd)
            width = right - left
            height = bottom - top
            
            # Capture window
            hwndDC = win32gui.GetWindowDC(hwnd)
            mfcDC = win32ui.CreateDCFromHandle(hwndDC)
            saveDC = mfcDC.CreateCompatibleDC()
            
            saveBitMap = win32ui.CreateBitmap()
            saveBitMap.CreateCompatibleBitmap(mfcDC, width, height)
            saveDC.SelectObject(saveBitMap)
            
            result = windll.user32.PrintWindow(hwnd, saveDC.GetSafeHdc(), 3)
            
            if result:
                bmpinfo = saveBitMap.GetInfo()
                bmpstr = saveBitMap.GetBitmapBits(True)
                
                img = Image.frombuffer(
                    'RGB',
                    (bmpinfo['bmWidth'], bmpinfo['bmHeight']),
                    bmpstr, 'raw', 'BGRX', 0, 1
                )
                
                # Cleanup
                win32gui.DeleteObject(saveBitMap.GetHandle())
                saveDC.DeleteDC()
                mfcDC.DeleteDC()
                win32gui.ReleaseDC(hwnd, hwndDC)
                
                return img
            
            return None
            
        except Exception as e:
            logger.error(f"Windows window capture failed: {e}")
            return None
    
    async def _capture_window_macos(self, window_title: str) -> Optional[Image.Image]:
        """Capture window on macOS"""
        # Placeholder for macOS implementation
        logger.warning("macOS window capture not implemented")
        return None
    
    async def _capture_window_linux(self, window_title: str) -> Optional[Image.Image]:
        """Capture window on Linux"""
        # Placeholder for Linux implementation
        logger.warning("Linux window capture not implemented")
        return None
    
    async def _get_screen_info_windows(self) -> Dict[str, Any]:
        """Get screen info on Windows"""
        if not hasattr(self, '_win32_available') or not self._win32_available:
            return {}
        
        try:
            import win32api
            import win32con
            
            monitors = []
            
            def monitor_enum_proc(hMonitor, hdcMonitor, lprcMonitor, dwData):
                monitors.append({
                    "x": lprcMonitor[0],
                    "y": lprcMonitor[1],
                    "width": lprcMonitor[2] - lprcMonitor[0],
                    "height": lprcMonitor[3] - lprcMonitor[1],
                    "primary": hMonitor == win32api.MonitorFromPoint((0, 0))
                })
                return True
            
            win32api.EnumDisplayMonitors(None, None, monitor_enum_proc, 0)
            
            # Get primary screen
            primary = next((m for m in monitors if m["primary"]), monitors[0] if monitors else None)
            
            return {
                "primary_screen": primary,
                "monitors": monitors,
                "total_width": max(m["x"] + m["width"] for m in monitors) if monitors else 0,
                "total_height": max(m["y"] + m["height"] for m in monitors) if monitors else 0
            }
            
        except Exception as e:
            logger.error(f"Failed to get Windows screen info: {e}")
            return {}
    
    async def _get_screen_info_macos(self) -> Dict[str, Any]:
        """Get screen info on macOS"""
        # Placeholder for macOS implementation
        return {}
    
    async def _get_screen_info_linux(self) -> Dict[str, Any]:
        """Get screen info on Linux"""
        # Placeholder for Linux implementation
        return {}
    
    async def _list_windows_windows(self) -> List[Dict[str, Any]]:
        """List windows on Windows"""
        if not hasattr(self, '_win32_available') or not self._win32_available:
            return []
        
        try:
            import win32gui
            
            windows = []
            
            def enum_windows_proc(hwnd, lParam):
                if win32gui.IsWindowVisible(hwnd):
                    title = win32gui.GetWindowText(hwnd)
                    if title:
                        left, top, right, bottom = win32gui.GetWindowRect(hwnd)
                        windows.append({
                            "title": title,
                            "hwnd": hwnd,
                            "x": left,
                            "y": top,
                            "width": right - left,
                            "height": bottom - top
                        })
                return True
            
            win32gui.EnumWindows(enum_windows_proc, 0)
            return windows
            
        except Exception as e:
            logger.error(f"Failed to list Windows windows: {e}")
            return []
    
    async def _list_windows_macos(self) -> List[Dict[str, Any]]:
        """List windows on macOS"""
        # Placeholder for macOS implementation
        return []
    
    async def _list_windows_linux(self) -> List[Dict[str, Any]]:
        """List windows on Linux"""
        # Placeholder for Linux implementation
        return []
    
    def get_status(self) -> Dict[str, Any]:
        """Get screen capture status"""
        return {
            "initialized": self.is_initialized,
            "platform": self.platform,
            "format": self.format,
            "quality": self.quality,
            "region_detection": self.region_detection
        }
