
# EirosAgent - Advanced Web Automation and OCR System

EirosAgent is a comprehensive automation framework that combines advanced web automation, OCR processing, computer vision, and task scheduling capabilities. Built for Stage 2 development, it provides a robust foundation for complex automation workflows.

## Features

### 🌐 Advanced Web Automation
- **Multi-browser support** (Chromium, Firefox, WebKit)
- **JavaScript injection** with stealth mode capabilities
- **Advanced form handling** with validation and auto-fill
- **Smart navigation** with condition-based waiting
- **Multi-page automation** with concurrent execution
- **Browser context management** for different scenarios

### 🔍 Enhanced OCR System
- **Multiple OCR engines**: EasyOCR, PaddleOCR, Tesseract
- **Intelligent fallback** system for maximum reliability
- **Advanced preprocessing** with noise reduction and enhancement
- **Structured data extraction** (forms, tables, receipts, documents)
- **Batch processing** capabilities
- **Engine comparison** and automatic selection

### 👁️ Computer Vision
- **Screen capture** with multi-monitor support
- **Object detection** and recognition
- **Face detection** using Haar cascades
- **UI element detection** (buttons, forms, text regions)
- **Template matching** for image-based automation
- **Image analysis** (colors, edges, similarity)

### ⏰ Task Scheduling & Macros
- **Flexible scheduling** (cron, interval, one-time, event-based)
- **YAML-based macro system** with templating
- **Conditional execution** and flow control
- **Error handling** with retry mechanisms
- **Task persistence** and recovery
- **Concurrent task execution**

### 🛠️ Utility Systems
- **Comprehensive logging** with rotation and retention
- **Configuration management** with YAML/JSON support
- **File operations** with safety checks
- **Image processing** utilities
- **Cross-platform compatibility**

## Installation

### Prerequisites
- Python 3.8+
- Node.js (for Playwright browsers)

### Install Dependencies
```bash
pip install -r requirements.txt
playwright install
```

### Optional Dependencies
For enhanced functionality:
```bash
# For advanced OCR
pip install easyocr paddleocr

# For computer vision
pip install opencv-python scikit-image

# For task scheduling
pip install croniter

# For Windows-specific features
pip install pywin32  # Windows only
```

## Quick Start

### Basic Usage
```python
import asyncio
from eiros_agent import EirosAgent

async def main():
    # Initialize agent
    agent = EirosAgent("config/default_config.yaml")
    
    try:
        # Initialize all subsystems
        await agent.initialize()
        
        # Capture and analyze screen
        result = await agent.capture_and_analyze_screen()
        print(f"Extracted {len(result['ocr_result']['text'])} characters")
        
        # Execute web automation
        task_config = {
            "name": "google_search",
            "steps": [
                {
                    "name": "navigate",
                    "action": "navigate",
                    "params": {"url": "https://www.google.com"}
                },
                {
                    "name": "search",
                    "action": "fill",
                    "params": {
                        "selector": "input[name='q']",
                        "value": "EirosAgent"
                    }
                }
            ]
        }
        
        result = await agent.automate_web_task(task_config)
        print(f"Web automation: {result['status']}")
        
    finally:
        await agent.shutdown()

if __name__ == "__main__":
    asyncio.run(main())
```

### Macro Execution
```python
# Execute a macro file
result = await agent.execute_macro(
    "config/macros/example_macro.yaml",
    variables={"target_url": "https://example.com"}
)
```

### Advanced OCR
```python
# Compare OCR engines
screenshot = await agent.vision_manager.capture_screen()
comparison = await agent.ocr_manager.compare_engines(screenshot)
print(f"Best engine: {comparison['recommendation']}")

# Extract structured data
structured_result = await agent.ocr_manager.extract_structured_data(
    screenshot,
    structure_config={"type": "form", "fields": {"name": {"pattern": "Name:"}}}
)
```

## Configuration

### Main Configuration (`config/default_config.yaml`)
```yaml
app:
  name: "EirosAgent"
  version: "2.0.0"
  debug: false

web_automation:
  browser:
    type: "chromium"
    headless: true
    timeout: 30000
  javascript:
    enable_stealth: true
    injection_timeout: 5000
  forms:
    auto_fill: true
    validation: true

ocr:
  engines:
    primary: "easyocr"
    fallback: "paddleocr"
  easyocr:
    languages: ["en", "ru"]
    gpu: true
  preprocessing:
    enhance_contrast: true
    denoise: true

scheduler:
  max_concurrent_tasks: 10
  task_timeout: 300
  retry_attempts: 3

vision:
  screen_capture:
    format: "png"
    quality: 90
  analysis:
    object_detection: true
    text_detection: true
```

### Macro Configuration (`config/macros/example_macro.yaml`)
```yaml
name: "web_scraping_example"
description: "Example web scraping automation macro"

triggers:
  - type: "time"
    schedule: "0 9 * * *"  # Daily at 9 AM

variables:
  target_url: "https://example.com"
  output_file: "./data/scraped_data.json"

steps:
  - name: "open_browser"
    action: "web.open_browser"
    params:
      headless: true
      
  - name: "navigate_to_site"
    action: "web.navigate"
    params:
      url: "{{ variables.target_url }}"
      
  - name: "extract_data"
    action: "web.inject_js"
    params:
      script: |
        return Array.from(document.querySelectorAll('.item')).map(item => ({
          title: item.querySelector('.title')?.textContent,
          description: item.querySelector('.description')?.textContent
        }));
        
  - name: "save_data"
    action: "data.save_json"
    params:
      data: "{{ steps.extract_data.result }}"
      file: "{{ variables.output_file }}"

error_handling:
  on_error: "continue"
  max_retries: 3
```

## Architecture

### Core Components
- **EirosAgent**: Main orchestrator class
- **Config**: Configuration management system
- **Exceptions**: Custom exception hierarchy

### Web Automation
- **WebAutomationManager**: Orchestrates browser automation
- **JSInjector**: Advanced JavaScript injection system
- **FormHandler**: Intelligent form processing
- **BrowserController**: Browser instance management
- **NavigationManager**: Smart page navigation

### OCR System
- **AdvancedOCRManager**: Multi-engine OCR orchestrator
- **OCR Engines**: EasyOCR, PaddleOCR, Tesseract implementations
- **ImagePreprocessor**: Advanced image enhancement
- **TextPostprocessor**: Text cleanup and validation

### Computer Vision
- **VisionManager**: Vision system orchestrator
- **ScreenCaptureManager**: Multi-platform screen capture
- **ImageAnalyzer**: Advanced image analysis
- **ObjectDetector**: Object and face detection

### Task Scheduling
- **TaskScheduler**: Advanced task scheduling system
- **MacroEngine**: YAML-based macro execution
- **TaskManager**: Individual task lifecycle management
- **Triggers**: Time, event, and condition-based triggers

## Examples

See the `examples/` directory for comprehensive usage examples:
- `basic_usage.py`: Basic EirosAgent functionality
- `advanced_web_automation.py`: Complex web automation scenarios

## Testing

Run the test suite:
```bash
pytest tests/
```

Run specific test modules:
```bash
pytest tests/test_core.py
pytest tests/test_web_automation.py
```

## Development

### Project Structure
```
eiros_agent/
├── core/                 # Core system components
├── web_automation/       # Web automation modules
├── ocr/                 # OCR processing system
├── vision/              # Computer vision components
├── scheduler/           # Task scheduling system
└── utils/               # Utility functions

config/                  # Configuration files
├── default_config.yaml
└── macros/             # Macro definitions

examples/               # Usage examples
tests/                  # Test suite
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue on GitHub
- Check the examples directory for usage patterns
- Review the configuration documentation

## Roadmap

### Stage 2 Completed Features ✅
- Advanced web automation with JavaScript injection
- Multi-engine OCR system with preprocessing
- Computer vision and screen capture
- Task scheduling with macro support
- Comprehensive configuration system

### Future Enhancements
- Machine learning model integration
- Advanced AI-powered decision making
- Cloud deployment capabilities
- REST API interface
- Plugin system for extensibility
- Enhanced security features

---

**EirosAgent** - Empowering automation through intelligent systems.
