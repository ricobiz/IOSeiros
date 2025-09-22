# DECODO Site Unblocker - Hybrid Authentication Guide

## Overview

This guide describes the updated DECODO Site Unblocker integration with **hybrid authentication** support:
- **Username:Password** for proxy authentication (unblock.decodo.com:60000)
- **API Key** for additional functions (statistics, management, enhanced features)

## Authentication Architecture

### 1. Proxy Authentication
- **Endpoint**: `unblock.decodo.com:60000`
- **Method**: HTTP Basic Authentication via `Proxy-Authorization` header
- **Format**: `Basic base64(username:password)`
- **Usage**: Required for all proxy requests

### 2. API Key Authentication
- **Header**: `X-SU-API-Key: your_api_key`
- **Usage**: Optional, enables additional features:
  - Usage statistics
  - Session management
  - Advanced geo-targeting
  - Priority routing
  - Enhanced support

## Configuration

### 1. Setting Hybrid Credentials

```swift
// With API Key (recommended)
DECODOConfiguration.shared.setCredentials(
    username: "your_username",
    password: "your_password", 
    apiKey: "your_api_key"
)

// Without API Key (basic functionality)
DECODOConfiguration.shared.setCredentials(
    username: "your_username",
    password: "your_password"
)
```

### 2. Environment Variables

```bash
# Required for proxy authentication
export DECODO_USERNAME="your_username"
export DECODO_PASSWORD="your_password"

# Optional for enhanced features
export DECODO_API_KEY="your_api_key"
```

## Site Unblocker Headers

### Basic Headers (Username:Password only)
```swift
let headers = DECODOConfiguration.createSiteUnblockerHeaders(
    headlessMode: .png,
    geoLocation: "US",
    sessionId: "session_123"
)

// Generated headers:
// X-SU-Headless: png
// X-SU-Geo: US
// X-SU-Session-Id: session_123
// Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
// ... (standard browser headers)
```

### Enhanced Headers (With API Key)
```swift
let headers = DECODOConfiguration.createSiteUnblockerHeaders(
    headlessMode: .png,
    geoLocation: "US", 
    sessionId: "session_123"
)

// Generated headers include:
// X-SU-API-Key: your_api_key  ← Additional API key header
// X-SU-Headless: png
// X-SU-Geo: US
// X-SU-Session-Id: session_123
// ... (all standard headers)
```

## Web Scraping API Payload

### Basic Payload (Username:Password only)
```swift
let payload = DECODOConfiguration.createWebScrapingAPIPayload(
    url: "https://example.com",
    target: "universal",
    headlessMode: .html
)

// Generated payload:
// {
//   "url": "https://example.com",
//   "target": "universal", 
//   "headless": "html",
//   "device_type": "desktop",
//   "http_method": "GET"
// }
```

### Enhanced Payload (With API Key)
```swift
let payload = DECODOConfiguration.createWebScrapingAPIPayload(
    url: "https://example.com",
    target: "universal",
    headlessMode: .html
)

// Generated payload includes:
// {
//   "api_key": "your_api_key",  ← Additional API key field
//   "url": "https://example.com",
//   "target": "universal",
//   "headless": "html",
//   "device_type": "desktop", 
//   "http_method": "GET"
// }
```

## Proxy Configuration

### Site Unblocker Proxy Setup
```swift
// Enable Site Unblocker proxy
await ProxyManager.shared.enableDECODOSiteUnblocker()

// The proxy will be configured as:
// - Host: unblock.decodo.com
// - Port: 60000
// - Authentication: username:password via Proxy-Authorization
// - Additional headers: X-SU-API-Key (if available)
```

### Request Flow
```
1. Client Request
   ↓
2. Proxy-Authorization: Basic base64(username:password)
   ↓
3. X-SU-API-Key: your_api_key (if available)
   ↓
4. unblock.decodo.com:60000
   ↓
5. Target Website
```

## UI Integration

### Settings View Updates
The `DECODOSettingsView` now includes:

1. **Username Field**: Required for proxy authentication
2. **Password Field**: Required for proxy authentication  
3. **API Key Field**: Optional for enhanced features
4. **Save Button**: Stores all credentials securely in Keychain
5. **Test Buttons**: Validate both proxy and API functionality

### Usage Example
```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                // ... other content
                
                NavigationLink("DECODO Settings") {
                    DECODOSettingsView()
                }
            }
        }
    }
}
```

## Testing

### Unit Tests
```swift
func testHybridAuthentication() {
    // Test with API key
    DECODOConfiguration.shared.setCredentials(
        username: "test_user",
        password: "test_pass", 
        apiKey: "test_api_key"
    )
    
    let headers = DECODOConfiguration.createSiteUnblockerHeaders()
    XCTAssertEqual(headers["X-SU-API-Key"], "test_api_key")
}
```

### Integration Tests
```swift
func testRealConnection() async {
    guard let username = ProcessInfo.processEnvironment["DECODO_USERNAME"],
          let password = ProcessInfo.processEnvironment["DECODO_PASSWORD"] else {
        throw XCTSkip("Real credentials not available")
    }
    
    let apiKey = ProcessInfo.processEnvironment["DECODO_API_KEY"]
    
    DECODOConfiguration.shared.setCredentials(
        username: username,
        password: password,
        apiKey: apiKey
    )
    
    let result = await DECODOConfiguration.shared.testSiteUnblockerConnection()
    XCTAssertTrue(result.success)
}
```

## API Key Benefits

When an API key is provided, you get access to:

### 1. Enhanced Statistics
- Request/response metrics
- Bandwidth usage tracking
- Success/failure rates
- Geographic distribution

### 2. Session Management
- Persistent sessions across requests
- Session-based IP rotation
- Custom session timeouts
- Session state tracking

### 3. Priority Support
- Faster response times
- Priority routing
- Dedicated support channels
- Advanced troubleshooting

### 4. Advanced Features
- Custom geo-targeting options
- Enhanced captcha solving
- Premium proxy pools
- Advanced retry logic

## Error Handling

### Common Issues

1. **"Proxy Authentication Required"**
   - Verify username/password are correct
   - Check credentials in DECODO dashboard
   - Ensure proxy endpoint is accessible

2. **"API Key Invalid"**
   - Verify API key format
   - Check API key permissions
   - Regenerate API key if needed

3. **"Connection Timeout"**
   - Check network connectivity
   - Verify proxy endpoint availability
   - Try different geo-location

### Debug Information
```swift
func debugDECODOStatus() {
    let config = DECODOConfiguration.shared
    print("DECODO Status:")
    print("- Credentials configured: \(config.hasValidCredentials())")
    print("- Connection status: \(config.connectionStatus)")
    print("- API key available: \(config.credentials?.apiKey != nil)")
    
    if let lastTest = config.lastTestResult {
        print("- Last test: \(lastTest.success ? "Success" : "Failed")")
        print("- Latency: \(lastTest.formattedLatency)")
        if let error = lastTest.error {
            print("- Error: \(error)")
        }
    }
}
```

## Migration from Previous Version

### Before (Username:Password only)
```swift
DECODOConfiguration.setCredentials(username: "user", password: "pass")
let headers = DECODOConfiguration.createSiteUnblockerHeaders()
// No API key functionality
```

### After (Hybrid Authentication)
```swift
// Backward compatible - existing code works
DECODOConfiguration.shared.setCredentials(username: "user", password: "pass")

// Enhanced - with API key
DECODOConfiguration.shared.setCredentials(
    username: "user", 
    password: "pass",
    apiKey: "api_key"
)

let headers = DECODOConfiguration.createSiteUnblockerHeaders()
// Automatically includes X-SU-API-Key if available
```

## Best Practices

### 1. Security
- Store credentials in Keychain (automatically handled)
- Never hardcode credentials in source code
- Use environment variables for testing
- Rotate API keys regularly

### 2. Performance
- Reuse sessions when possible
- Use appropriate geo-targeting
- Monitor usage statistics
- Implement proper retry logic

### 3. Error Handling
- Always check connection test results
- Implement fallback mechanisms
- Log errors for debugging
- Provide user feedback

## Support

### Getting Credentials
1. Sign up at [decodo.com](https://decodo.com)
2. Access your dashboard
3. Generate username/password for proxy
4. Generate API key for enhanced features
5. Configure in app settings

### Troubleshooting
1. Test connection in app settings
2. Check DECODO service status
3. Verify credentials in dashboard
4. Contact DECODO support if needed

### Resources
- [DECODO Website](https://decodo.com)
- [DECODO Dashboard](https://dashboard.decodo.com)
- [Site Unblocker Documentation](https://help.decodo.com/docs/site-unblocker-quick-start)
- [API Documentation](https://help.decodo.com/docs/api)

---

**This hybrid authentication system provides full backward compatibility while enabling enhanced features through optional API key integration.**
