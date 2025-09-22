
# Eiros Agent iOS - Enhanced DECODO Integration

## 🚀 Overview

Eiros Agent iOS is an advanced automation platform with comprehensive DECODO integration, featuring screenshot capture, JavaScript rendering, vision analysis, and intelligent automation workflows.

## ✨ Key Features

### 🖼️ Screenshot Automation
- **DECODO Site Unblocker**: PNG screenshots via proxy
- **Web Scraping API**: Advanced screenshot capture
- **Geo-Targeting**: Location-based screenshots
- **Device Emulation**: Desktop, mobile Android, mobile iOS
- **Vision Analysis**: AI-powered screenshot analysis

### 🤖 Intelligent Automation
- **Multi-Step Workflows**: Complex automation tasks
- **JavaScript Rendering**: Dynamic content support
- **Element Interaction**: Click, type, scroll, extract
- **Error Handling**: Robust error recovery
- **Progress Tracking**: Real-time execution monitoring

### 👁️ Vision Analysis
- **Qwen2VL Integration**: Advanced AI image analysis
- **Text Extraction**: OCR from screenshots
- **Object Detection**: UI element identification
- **Automation Guidance**: AI-powered automation recommendations
- **Batch Processing**: Multiple image analysis

### 🌍 DECODO Integration
- **Site Unblocker**: Proxy-based web unblocking
- **Web Scraping API**: Structured data extraction
- **Geo-Targeting**: Global IP routing
- **Session Management**: Persistent connections
- **Real-Time Monitoring**: Connection health and statistics

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Eiros Agent iOS                          │
├─────────────────────────────────────────────────────────────┤
│  UI Components                                              │
│  ├── DECODOSettingsView      (Configuration)               │
│  ├── AutomationPanelView     (Task Management)             │
│  └── VisionAnalysisView      (Image Analysis)              │
├─────────────────────────────────────────────────────────────┤
│  Core Managers                                              │
│  ├── DECODOConfiguration     (API Integration)             │
│  ├── ProxyManager            (Proxy & Screenshots)         │
│  ├── AutomationController    (Task Execution)              │
│  ├── VisionManager           (AI Analysis)                 │
│  └── iOSAutomationBridge     (WebView Integration)         │
├─────────────────────────────────────────────────────────────┤
│  External Services                                          │
│  ├── DECODO Site Unblocker   (Proxy Service)               │
│  ├── DECODO Web Scraping API (Data Extraction)             │
│  └── Qwen2VL Server          (Vision Analysis)             │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Prerequisites
- iOS 15.0+
- Xcode 14.0+
- DECODO account ([decodo.com](https://decodo.com))
- Python 3.8+ (for Qwen2VL server)

### 2. DECODO Setup
1. Sign up at [decodo.com](https://decodo.com)
2. Get credentials from dashboard
3. Configure in app settings

### 3. Qwen2VL Server
```bash
cd Python
pip install -r requirements.txt
python qwen2vl_enhanced_server.py --host 0.0.0.0 --port 8000
```

### 4. iOS App Configuration
1. Open DECODOSettingsView
2. Enter DECODO credentials
3. Test connections
4. Enable automation

## 📱 Usage Examples

### Screenshot Capture
```swift
// Configure DECODO
DECODOConfiguration.shared.setCredentials(username: "user", password: "pass")

// Enable proxy
await ProxyManager.shared.enableDECODOSiteUnblocker()

// Capture screenshot with geo-targeting
let result = await ProxyManager.shared.captureScreenshotThroughProxy(
    url: "https://example.com",
    options: ScreenshotOptions(
        geoLocation: "United States",
        deviceType: .desktop
    )
)

if result.success, let imageData = result.imageData {
    let screenshot = UIImage(data: imageData)
    // Process screenshot
}
```

### Vision Analysis
```swift
// Analyze screenshot from URL
let analysis = await VisionManager.shared.analyzeScreenshot(
    from: "https://example.com",
    using: ProxyManager.shared,
    options: VisionAnalysisOptions(
        analysisPrompt: "Identify all interactive elements for automation",
        geoLocation: "Germany"
    )
)

if analysis.success {
    print("Detected elements: \(analysis.detectedObjects)")
    print("Extracted text: \(analysis.text)")
    print("AI analysis: \(analysis.metadata["qwen2vlDescription"] ?? "")")
}
```

### Automation Workflow
```swift
// Create automation task
let task = AutomationController.shared.createWebScrapingTask(
    url: "https://example.com",
    selectors: [".title", ".price", ".description"],
    options: WebScrapingTaskOptions(
        geoLocation: "United Kingdom",
        deviceType: .desktop,
        extractAttribute: "text"
    )
)

// Execute task
let result = await AutomationController.shared.executeTask(task)

if result.success {
    print("Screenshots: \(result.screenshots.count)")
    if let data = result.data {
        let extractedData = try JSONSerialization.jsonObject(with: data)
        print("Extracted data: \(extractedData)")
    }
}
```

### iOS WebView Automation
```swift
// Create WebView with proxy
let webView = iOSAutomationBridge.shared.createWebView(with: proxyConfig)

// Navigate and interact
await iOSAutomationBridge.shared.navigateToURL("https://example.com", in: webView)
await iOSAutomationBridge.shared.clickElement(selector: "#submit-button", in: webView)
await iOSAutomationBridge.shared.typeText("Hello World", in: "#input-field", webView: webView)

// Extract data
let extraction = await iOSAutomationBridge.shared.extractText(from: ".results", webView: webView)
print("Extracted elements: \(extraction.elements)")
```

## 🎯 Key Capabilities

### DECODO Integration
- **Real API Endpoints**: `unblock.decodo.com:60000` and `scraper-api.decodo.com`
- **Authentication**: Secure credential management
- **Proxy Support**: HTTP/HTTPS proxy with authentication
- **Health Monitoring**: Real-time connection monitoring

### Screenshot Features
- **PNG Capture**: High-quality screenshot capture
- **Geo-Targeting**: Location-based screenshots
- **Device Emulation**: Multiple device types
- **Session Management**: Consistent IP addresses
- **Batch Processing**: Multiple URL screenshots

### Vision Analysis
- **AI-Powered**: Advanced Qwen2VL integration
- **Text Extraction**: OCR from images
- **Object Detection**: UI element identification
- **Automation Guidance**: AI automation recommendations
- **Custom Prompts**: Flexible analysis prompts

### Automation Engine
- **Multi-Step Tasks**: Complex workflow execution
- **Action Types**: Navigate, screenshot, click, type, extract, wait, scroll
- **Error Handling**: Robust error recovery
- **Progress Tracking**: Real-time execution monitoring
- **Vision Integration**: Automatic screenshot analysis

## 🧪 Testing

### Unit Tests
```bash
xcodebuild test -scheme EirosAgent -destination 'platform=iOS Simulator,name=iPhone 14'
```

### Integration Tests
```bash
# Set real DECODO credentials for integration testing
export DECODO_TEST_USERNAME="your_username"
export DECODO_TEST_PASSWORD="your_password"

# Run tests
xcodebuild test -scheme EirosAgent -destination 'platform=iOS Simulator,name=iPhone 14'
```

### Python Server Tests
```bash
cd Python
python -m pytest test_qwen2vl_server.py -v
```

## 📊 Performance

### Benchmarks
- **Screenshot Capture**: < 5 seconds average
- **Vision Analysis**: < 3 seconds per image
- **Automation Tasks**: Variable based on complexity
- **Memory Usage**: < 200MB during normal operation

### Optimization Features
- **Connection Pooling**: Efficient proxy connections
- **Session Reuse**: Consistent IP addresses
- **Batch Processing**: Multiple operations
- **Background Processing**: Non-blocking operations

## 🔧 Configuration

### DECODO Settings
```swift
// Basic configuration
DECODOConfiguration.shared.setCredentials(username: "user", password: "pass")

// Advanced configuration
let headers = DECODOConfiguration.createSiteUnblockerHeaders(
    headlessMode: .png,
    geoLocation: "United States",
    sessionId: "session123",
    customHeaders: ["User-Agent": "Custom Agent"]
)
```

### Automation Options
```swift
let options = AutomationTaskOptions(
    useProxy: true,
    enableJavaScript: true,
    timeout: 120.0,
    stopOnError: false
)
```

### Vision Analysis Options
```swift
let visionOptions = VisionAnalysisOptions(
    analysisPrompt: "Analyze this webpage for automation opportunities",
    geoLocation: "Germany",
    deviceType: .desktop
)
```

## 📚 Documentation

### Complete Guides
- **[DECODO_AUTOMATION_GUIDE.md](Documentation/DECODO_AUTOMATION_GUIDE.md)**: Comprehensive usage guide
- **[INTEGRATION_COMPLETE_ENHANCED.md](Documentation/INTEGRATION_COMPLETE_ENHANCED.md)**: Integration overview
- **API Reference**: Complete API documentation
- **Troubleshooting**: Common issues and solutions

### Key Topics
1. **Screenshot Capture**: PNG screenshots with geo-targeting
2. **JavaScript Rendering**: Dynamic content rendering
3. **Vision Analysis**: AI-powered image analysis
4. **Automation Workflows**: Multi-step task execution
5. **iOS Integration**: Native WebView automation
6. **Error Handling**: Comprehensive error management

## 🛠️ Development

### Project Structure
```
EirosAgent/
├── Sources/
│   ├── Core/
│   │   ├── DECODO/           # DECODO integration
│   │   ├── Managers/         # Core managers
│   │   ├── Vision/           # Vision analysis
│   │   └── iOS/              # iOS automation
│   └── UI/
│       └── Views/            # SwiftUI views
├── Tests/                    # Test suites
├── Python/                   # Qwen2VL server
└── Documentation/            # Complete documentation
```

### Build Requirements
- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Python 3.8+ (for server)

### Dependencies
- SwiftUI
- Combine
- WebKit
- Vision
- Network

## 🔐 Security

### Data Protection
- **Keychain Storage**: Secure credential storage
- **HTTPS/TLS**: Encrypted connections
- **No Data Logging**: Privacy-focused design
- **Local Processing**: On-device analysis

### Best Practices
- Credentials never logged or exposed
- Automatic credential cleanup
- Secure proxy authentication
- Privacy-compliant data handling

## 🚀 Deployment

### Production Checklist
- [ ] DECODO credentials configured
- [ ] Qwen2VL server running
- [ ] Connection tests passing
- [ ] Automation workflows tested
- [ ] Error handling verified
- [ ] Performance benchmarks met

### Monitoring
- Connection health monitoring
- Usage statistics tracking
- Error rate monitoring
- Performance metrics

## 🤝 Contributing

### Development Setup
1. Clone repository
2. Install dependencies
3. Configure DECODO credentials
4. Start Qwen2VL server
5. Run tests

### Code Style
- Swift style guide compliance
- Comprehensive documentation
- Unit test coverage
- Error handling

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

### Getting Help
1. Check documentation
2. Review troubleshooting guide
3. Run connection tests
4. Check server logs

### Common Issues
- **"DECODO not configured"**: Set credentials in settings
- **"No proxy enabled"**: Enable proxy in automation panel
- **"Connection failed"**: Check internet and DECODO service status
- **"Vision analysis failed"**: Ensure Qwen2VL server is running

### Contact
- GitHub Issues: Report bugs and feature requests
- Documentation: Complete guides and API reference
- DECODO Support: For service-specific issues

---

**Eiros Agent iOS with Enhanced DECODO Integration - Production Ready** 🚀

*Powerful automation, intelligent analysis, seamless integration.*
