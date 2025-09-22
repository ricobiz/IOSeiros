# 🚀 Eiros Agent - Complete AI-Powered Automation System

**Eiros Agent** is a comprehensive, multi-platform automation framework that combines advanced AI capabilities, web automation, computer vision, OCR processing, and real-time monitoring. This complete system represents the culmination of a 3-stage development process, delivering enterprise-grade automation with intelligent decision-making capabilities.

## 🎯 Project Overview

Eiros Agent is built as both an **iOS application** and a **Python automation framework**, providing seamless integration between mobile and desktop automation workflows. The system features local LLM integration, advanced web automation, computer vision capabilities, and a comprehensive Control Room interface for real-time monitoring and management.

## ✨ Complete Feature Set

### 🧠 **Stage 1: LLM Integration & Visual Recognition**
- **Local LLM Integration**: On-device AI processing with llama.cpp
- **Multimodal AI**: Support for text + vision processing
- **Multiple Model Support**: Llama 2 7B/13B, Code Llama 7B, Mistral 7B
- **iOS Vision Framework**: OCR text recognition and object detection
- **Screen Analysis**: Comprehensive UI element detection and analysis
- **SwiftUI Interface**: Modern iOS app with intuitive controls

### 🔍 **NEW: Qwen2VL Multimodal Integration**
- **Advanced Vision-Language Analysis**: State-of-the-art multimodal understanding
- **Scene Description**: Generate detailed natural language descriptions of images
- **Visual Reasoning**: Answer complex questions about image content
- **UI Element Analysis**: Intelligent analysis of user interface components
- **Text Extraction**: Advanced OCR with contextual understanding
- **Batch Processing**: Efficient analysis of multiple images
- **Flexible Deployment**: Support for both API-based and local inference

### 🌐 **Stage 2: Advanced Web Automation & OCR**
- **Multi-browser Support**: Chromium, Firefox, WebKit with Playwright
- **JavaScript Injection**: Stealth mode capabilities and pre-built templates
- **Advanced Form Handling**: Validation, auto-fill, and smart navigation
- **Enhanced OCR System**: EasyOCR, PaddleOCR, Tesseract with intelligent fallback
- **Computer Vision**: Object detection, face recognition, template matching
- **Task Scheduling**: Flexible cron, interval, and event-based automation
- **YAML Macro System**: Templated automation workflows with Jinja2

### 🖥️ **Stage 3: Control Room Interface & Monitoring**
- **Real-time Dashboard**: Live system monitoring with interactive charts
- **WebSocket Communication**: Real-time data streaming and notifications
- **System Monitoring**: CPU, memory, disk, network, and process tracking
- **Task Management**: CRUD operations with execution monitoring
- **Analytics & Metrics**: Performance analysis and trend monitoring
- **Web Interface**: Modern responsive design with dark/light themes
- **RESTful API**: Comprehensive endpoints for all system operations

### 🔧 **Core Infrastructure**
- **Cross-platform Compatibility**: Windows, macOS, Linux support
- **Modular Architecture**: Extensible plugin system
- **Configuration Management**: YAML/JSON with environment variables
- **Advanced Logging**: Rotation, retention, and level filtering
- **Error Handling**: Comprehensive retry mechanisms and notifications
- **Security**: Local processing, secure storage, permission management

## 📦 Installation & Setup

### Prerequisites

#### For Python Framework:
- **Python 3.8+** (3.11+ recommended)
- **Node.js 16+** (for web interface)
- **Git** for version control

#### For iOS Application:
- **Xcode 15+**
- **iOS 16+** target device or simulator
- **macOS 13+** development environment

### Quick Start

#### 1. Clone the Repository
```bash
git clone https://github.com/ricobiz/IOSeiros.git
cd IOSeiros
```

#### 2. Python Framework Setup
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install Playwright browsers
playwright install

# Run basic example
python examples/basic_usage.py
```

#### 3. iOS Application Setup
```bash
# Open Xcode project
open EirosAgent.xcodeproj

# Build and run in Xcode
# Select target device/simulator and press Cmd+R
```

#### 4. Control Room Interface
```bash
# Start with Control Room
python examples/control_room_example.py

# Access web interface at:
# http://localhost:8080
```

### Advanced Installation

#### Optional Dependencies
```bash
# For advanced OCR capabilities
pip install easyocr paddleocr

# For computer vision features
pip install opencv-python face-recognition mediapipe

# For machine learning features
pip install torch transformers scikit-learn

# For distributed task processing
pip install redis celery
```

#### Platform-Specific Setup

**Windows:**
```bash
# Install Windows-specific dependencies
pip install pywin32 wmi
```

**macOS:**
```bash
# Install macOS-specific dependencies
pip install pyobjc-framework-Quartz pyobjc-framework-ApplicationServices
```

**Linux:**
```bash
# Install Linux-specific dependencies
sudo apt-get install python3-xlib libcairo2-dev
pip install python3-xlib pycairo
```

## 🚀 Usage Examples

### Python Framework

#### Basic Automation
```python
import asyncio
from eiros_agent import EirosAgent

async def main():
    # Initialize agent with configuration
    agent = EirosAgent("config/default_config.yaml")
    await agent.initialize()
    
    # Screen capture and OCR
    result = await agent.capture_and_analyze_screen()
    print(f"Extracted text: {result['ocr_result']['text']}")
    
    # Web automation
    await agent.web_automation.navigate("https://example.com")
    await agent.web_automation.fill_form({
        "input[name='search']": "automation"
    })
    
    await agent.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
```

#### Control Room Integration
```python
from eiros_agent.core.control_room_integration import EirosAgentWithControlRoom

async def main():
    # Initialize with Control Room
    agent = EirosAgentWithControlRoom("config/control_room_config.yaml")
    await agent.initialize()
    
    # Access Control Room at http://localhost:8080
    print(f"Control Room: {agent.get_control_room_url()}")
    
    # Keep running for monitoring
    await agent.run_forever()

if __name__ == "__main__":
    asyncio.run(main())
```

#### Advanced OCR Processing
```python
from eiros_agent.ocr import OCRManager

async def main():
    ocr = OCRManager()
    
    # Process image with multiple engines
    result = await ocr.process_image(
        "screenshot.png",
        engines=["easyocr", "paddleocr", "tesseract"],
        preprocessing=True
    )
    
    # Extract structured data
    structured = await ocr.extract_structured_data(
        result, 
        data_type="form"
    )
    
    print(f"Extracted fields: {structured}")

if __name__ == "__main__":
    asyncio.run(main())
```

### iOS Application

#### Basic Usage
```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var llmManager = EnhancedLLMManager.shared
    @StateObject private var visionManager = VisionManager.shared
    
    var body: some View {
        TabView {
            // Enhanced Control Room with AI chat
            EnhancedControlRoomView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Chat")
                }
            
            // Vision analysis and OCR
            VisionAnalysisView()
                .tabItem {
                    Image(systemName: "eye")
                    Text("Vision")
                }
            
            // Web automation browser
            BrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Browser")
                }
        }
    }
}
```

#### Screen Analysis
```swift
// Capture and analyze screen
let screenshot = await ScreenCaptureManager.shared.captureScreen()
let analysis = await VisionManager.shared.analyzeScreen(screenshot)

print("Detected UI elements: \(analysis.uiElements.count)")
print("Extracted text: \(analysis.ocrResult.text)")
```
## 🔧 Configuration

### Control Room Configuration (`config/control_room_config.yaml`)
```yaml
control_room:
  web_server:
    host: "localhost"
    port: 8080
    debug: false
  
  websocket_server:
    host: "localhost"
    port: 8765
  
  monitoring:
    system_metrics_interval: 5  # seconds
    process_monitoring: true
    network_monitoring: true
  
  notifications:
    max_notifications: 1000
    retention_days: 30

agent:
  name: "EirosAgent"
  version: "1.0.0"
  
  web_automation:
    browser: "chromium"
    headless: true
    timeout: 30000
  
  ocr:
    primary_engine: "easyocr"
    languages: ["en", "ru", "es"]
    preprocessing: true
  
  vision:
    screen_capture_format: "png"
    object_detection: true
```

## 🌐 API Reference

### Control Room REST API

#### System Monitoring
- `GET /api/v1/system/metrics` - Get current system metrics
- `GET /api/v1/system/processes` - List running processes
- `GET /api/v1/system/health` - System health check

#### Task Management
- `GET /api/v1/tasks` - List all tasks
- `POST /api/v1/tasks` - Create new task
- `GET /api/v1/tasks/{id}` - Get task details
- `PUT /api/v1/tasks/{id}` - Update task
- `DELETE /api/v1/tasks/{id}` - Delete task

#### Notifications
- `GET /api/v1/notifications` - List notifications
- `POST /api/v1/notifications` - Create notification
- `PUT /api/v1/notifications/{id}/read` - Mark as read

#### WebSocket Events
- `system_metrics` - Real-time system metrics
- `task_update` - Task status changes
- `notification` - New notifications
- `log_entry` - System log entries

## 📁 Project Structure

```
IOSeiros/
├── EirosAgent.xcodeproj/          # iOS Xcode project
├── EirosAgent/                    # iOS application source
│   ├── Managers/                  # Core managers (LLM, Vision, WebView)
│   ├── Views/                     # SwiftUI views
│   ├── Models/                    # Data models
│   └── Resources/                 # JavaScript and assets
├── eiros_agent/                   # Python framework
│   ├── core/                      # Core agent and configuration
│   ├── web_automation/            # Web automation modules
│   ├── ocr/                       # OCR processing system
│   ├── vision/                    # Computer vision capabilities
│   ├── scheduler/                 # Task scheduling system
│   ├── control_room/              # Control Room interface
│   └── utils/                     # Utility functions
├── config/                        # Configuration files
├── examples/                      # Usage examples
├── tests/                         # Test suites
└── requirements.txt               # Python dependencies
```

## 🧪 Testing

```bash
# Run all tests
pytest tests/

# Run specific test modules
pytest tests/test_core.py
pytest tests/test_web_automation.py

# Run with coverage
pytest --cov=eiros_agent tests/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **llama.cpp** for local LLM integration
- **Playwright** for web automation capabilities
- **EasyOCR, PaddleOCR, Tesseract** for OCR processing
- **OpenCV** for computer vision features
- **Chart.js** for real-time data visualization
- **SwiftUI** for modern iOS interface design

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Check the [documentation](docs/)
- Review the [examples](examples/) directory

---

**🚨 Important**: For private repository access, ensure GitHub App permissions are granted at: [GitHub App Configuration](https://github.com/apps/abacusai/installations/select_target)
