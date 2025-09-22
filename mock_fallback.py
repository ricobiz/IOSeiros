
#!/usr/bin/env python3
"""
Mock Fallback Implementation for Qwen2-VL
Provides mock responses when MLX is not available (non-Apple Silicon systems)
"""

import time
import random
import logging
from typing import Dict, Any, Optional
from PIL import Image
import json

logger = logging.getLogger(__name__)

class MockQwen2VLProcessor:
    """Mock processor that simulates Qwen2-VL responses"""
    
    def __init__(self):
        self.model_name = "Mock Qwen2-VL (Fallback)"
        self.loaded = True
        self.response_templates = self._load_response_templates()
        
    def _load_response_templates(self) -> Dict[str, list]:
        """Load response templates for different task types"""
        return {
            "general": [
                "This appears to be a mobile application interface with various UI elements.",
                "I can see a screen with buttons, text fields, and navigation elements.",
                "The image shows a user interface with interactive components.",
                "This looks like a mobile app screen with standard UI controls."
            ],
            "findElement": [
                "I can identify several UI elements in this interface:\n- Button in the center area\n- Text field near the top\n- Navigation bar at the bottom\n- Menu icon in the top-left corner",
                "The screen contains multiple interactive elements:\n- Primary action button\n- Input fields for user data\n- Navigation controls\n- Status indicators",
                "UI elements detected:\n- Clickable buttons (2-3 visible)\n- Text input areas\n- Menu/navigation components\n- Icon elements"
            ],
            "clickElement": [
                "Clickable elements found:\n- Main action button (center-right)\n- Menu button (top-left)\n- Tab bar items (bottom)\n- Secondary buttons (various locations)",
                "Interactive elements available for tapping:\n- Primary button for main action\n- Navigation tabs\n- Menu options\n- Icon buttons",
                "Tappable UI components:\n- Action buttons\n- Menu items\n- Navigation controls\n- Interactive icons"
            ],
            "extractText": [
                "Text content extracted:\n- App Title\n- Button Labels: 'Continue', 'Cancel', 'Settings'\n- Menu Items: 'Home', 'Profile', 'Help'\n- Status Text: 'Ready'",
                "Visible text elements:\n- Header: 'Application Name'\n- Buttons: 'Submit', 'Back'\n- Labels: 'Username', 'Password'\n- Footer: 'Version 1.0'",
                "Text found in interface:\n- Title bar text\n- Button captions\n- Field labels\n- Navigation text\n- Status messages"
            ],
            "describeScreen": [
                "This is a mobile application screen with a clean, modern interface. The layout includes a header with navigation, main content area with form elements, and a bottom navigation bar. The design follows standard mobile UI patterns with appropriate spacing and visual hierarchy.",
                "The screen displays a typical mobile app interface featuring a top navigation bar, central content area with interactive elements, and bottom tab navigation. The layout is user-friendly with clear visual separation between different sections.",
                "This appears to be a main application screen with standard mobile UI components. The interface includes header navigation, content sections with buttons and text fields, and footer navigation elements arranged in a logical hierarchy."
            ],
            "findButton": [
                "Buttons identified:\n- Primary action button (blue, center)\n- Secondary button (gray, right)\n- Menu button (hamburger icon, top-left)\n- Tab buttons (bottom navigation)",
                "Button elements found:\n- Main CTA button\n- Cancel/Back button\n- Settings button (gear icon)\n- Navigation tab buttons",
                "Clickable buttons detected:\n- Action buttons (2-3 visible)\n- Icon buttons in header\n- Tab bar buttons\n- Menu toggle button"
            ],
            "findTextField": [
                "Text input fields located:\n- Username/Email field (top)\n- Password field (below username)\n- Search field (header area)\n- Optional comment field (bottom)",
                "Input elements found:\n- Primary text field for user input\n- Secondary field for additional data\n- Search/filter input\n- Text area for longer content",
                "Text fields identified:\n- Login credentials fields\n- Search input box\n- Form input fields\n- Text area components"
            ]
        }
    
    def analyze_image(self, image: Image.Image, prompt: str, task_type: str = "general") -> Dict[str, Any]:
        """Mock image analysis with realistic response times"""
        # Simulate processing time
        processing_time = random.uniform(0.5, 2.0)
        time.sleep(processing_time)
        
        # Get appropriate response template
        templates = self.response_templates.get(task_type, self.response_templates["general"])
        response = random.choice(templates)
        
        # Add some variation based on image properties
        if image:
            width, height = image.size
            if width > height:
                response += f"\n\nNote: Landscape orientation detected ({width}x{height})"
            else:
                response += f"\n\nNote: Portrait orientation detected ({width}x{height})"
        
        # Generate mock parsed response
        parsed_response = self._generate_parsed_response(task_type, response)
        
        # Calculate mock confidence
        confidence = random.uniform(0.7, 0.9)
        
        logger.info(f"Mock analysis completed in {processing_time:.2f}s (task: {task_type})")
        
        return {
            "success": True,
            "error": None,
            "response": response,
            "parsed_response": parsed_response,
            "confidence": confidence,
            "processing_time": processing_time,
            "task_type": task_type,
            "mock_mode": True,
            "model_info": {
                "name": self.model_name,
                "type": "mock_fallback",
                "platform": "cross-platform"
            }
        }
    
    def _generate_parsed_response(self, task_type: str, response: str) -> Dict[str, Any]:
        """Generate mock parsed response based on task type"""
        parsed = {
            "elements": [],
            "text_content": "",
            "description": response,
            "coordinates": [],
            "suggestions": []
        }
        
        if task_type == "extractText":
            # Mock text extraction
            text_lines = [
                "App Title",
                "Continue",
                "Cancel", 
                "Settings",
                "Home",
                "Profile",
                "Version 1.0"
            ]
            parsed["text_content"] = "\n".join(random.sample(text_lines, k=random.randint(3, 6)))
        
        elif task_type in ["findElement", "clickElement", "findButton"]:
            # Mock UI elements
            mock_elements = [
                {
                    "type": "button",
                    "description": "Primary action button",
                    "confidence": 0.85,
                    "position": "center",
                    "properties": {"text": "Continue", "enabled": True}
                },
                {
                    "type": "button", 
                    "description": "Menu button",
                    "confidence": 0.80,
                    "position": "top-left",
                    "properties": {"icon": "hamburger", "enabled": True}
                }
            ]
            parsed["elements"] = random.sample(mock_elements, k=random.randint(1, 2))
        
        elif task_type == "findTextField":
            # Mock text fields
            mock_fields = [
                {
                    "type": "textField",
                    "description": "Username input field",
                    "confidence": 0.88,
                    "position": "top",
                    "properties": {"placeholder": "Enter username", "required": True}
                },
                {
                    "type": "textField",
                    "description": "Search field",
                    "confidence": 0.82,
                    "position": "header",
                    "properties": {"placeholder": "Search...", "required": False}
                }
            ]
            parsed["elements"] = random.sample(mock_fields, k=random.randint(1, 2))
        
        # Add mock suggestions
        suggestions = [
            "Consider using accessibility labels for better UI automation",
            "Verify element positions with actual device testing",
            "Test with different screen sizes and orientations"
        ]
        parsed["suggestions"] = random.sample(suggestions, k=random.randint(1, 2))
        
        return parsed
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get mock model information"""
        return {
            "name": self.model_name,
            "type": "mock_fallback",
            "platform": "cross-platform",
            "loaded": True,
            "capabilities": [
                "UI element detection (simulated)",
                "Text extraction (simulated)", 
                "Screen description (simulated)",
                "Basic image analysis (simulated)"
            ],
            "limitations": [
                "Responses are template-based",
                "No actual computer vision processing",
                "Limited accuracy compared to real models",
                "Primarily for testing and development"
            ]
        }
    
    def test_connection(self) -> Dict[str, Any]:
        """Test mock processor functionality"""
        # Create a simple test image
        test_image = Image.new('RGB', (100, 100), color='white')
        
        # Run a test analysis
        result = self.analyze_image(test_image, "Test prompt", "general")
        
        return {
            "status": "success",
            "message": "Mock processor is working correctly",
            "test_result": result,
            "processor_info": self.get_model_info()
        }

class MockMLXLoader:
    """Mock MLX loader that provides fallback functionality"""
    
    def __init__(self):
        self.processor = MockQwen2VLProcessor()
        self.loaded = True
        
    async def load_model(self, model_name: str = "mock") -> bool:
        """Mock model loading (always succeeds)"""
        logger.info(f"Loading mock model: {model_name}")
        time.sleep(1.0)  # Simulate loading time
        logger.info("✅ Mock model loaded successfully")
        return True
    
    def generate_response(self, image, prompt: str, **kwargs) -> str:
        """Generate mock response"""
        task_type = kwargs.get('task_type', 'general')
        result = self.processor.analyze_image(image, prompt, task_type)
        return result['response']
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get mock model information"""
        return self.processor.get_model_info()
    
    def check_mlx_availability(self) -> bool:
        """Always returns False for mock loader"""
        return False

# Global mock loader instance
mock_loader = MockMLXLoader()

def create_mock_response(prompt: str, task_type: str = "general", processing_time: float = 1.0) -> Dict[str, Any]:
    """Create a mock response for testing purposes"""
    mock_processor = MockQwen2VLProcessor()
    
    # Create a dummy image for testing
    test_image = Image.new('RGB', (375, 812), color='lightgray')  # iPhone-like dimensions
    
    return mock_processor.analyze_image(test_image, prompt, task_type)

if __name__ == "__main__":
    # Test mock functionality
    print("🧪 Testing Mock Qwen2-VL Processor")
    print("=" * 50)
    
    processor = MockQwen2VLProcessor()
    
    # Test different task types
    test_cases = [
        ("Describe this screen", "general"),
        ("Find all buttons", "findButton"),
        ("Extract text from image", "extractText"),
        ("Identify UI elements", "findElement"),
        ("Find clickable elements", "clickElement")
    ]
    
    for prompt, task_type in test_cases:
        print(f"\n🔍 Testing: {task_type}")
        print(f"Prompt: {prompt}")
        
        # Create test image
        test_image = Image.new('RGB', (375, 812), color='white')
        
        # Analyze
        result = processor.analyze_image(test_image, prompt, task_type)
        
        print(f"✅ Success: {result['success']}")
        print(f"⏱️  Time: {result['processing_time']:.2f}s")
        print(f"🎯 Confidence: {result['confidence']:.2f}")
        print(f"📝 Response: {result['response'][:100]}...")
        
        if result['parsed_response']['elements']:
            print(f"🔧 Elements found: {len(result['parsed_response']['elements'])}")
    
    print(f"\n📊 Model Info:")
    info = processor.get_model_info()
    for key, value in info.items():
        print(f"  {key}: {value}")
