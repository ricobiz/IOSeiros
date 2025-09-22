# DECODO Site Unblocker - Hybrid Authentication Usage Examples

## Overview

This document provides practical examples of using the DECODO Site Unblocker with **hybrid authentication** support:
- **Username:Password** for proxy authentication (unblock.decodo.com:60000)
- **API Key** for enhanced features and statistics

## Prerequisites

1. **DECODO Account**: Sign up at [decodo.com](https://decodo.com)
2. **Proxy Credentials**: Get username/password from your DECODO dashboard
3. **API Key**: Generate API key for enhanced features (optional)
4. **App Configuration**: Enter all credentials in the DECODO Settings view

## Basic Setup

### 1. Configure Hybrid Credentials

```swift
// Set your DECODO credentials with API key (recommended)
DECODOConfiguration.shared.setCredentials(
    username: "your_username",
    password: "your_password",
    apiKey: "your_api_key_here"
)

// Verify configuration
if DECODOConfiguration.shared.hasValidCredentials() {
    print("✅ DECODO credentials configured")
    print("✅ API key available: \(DECODOConfiguration.shared.credentials?.apiKey != nil)")
} else {
    print("❌ DECODO credentials missing")
}
```

### 2. Basic Proxy Setup

```swift
// Load DECODO configurations
ProxyManager.shared.loadDECODOConfigurations()

// Enable DECODO proxy with hybrid authentication
await ProxyManager.shared.enableDECODOSiteUnblocker()

// Check status
if ProxyManager.shared.isProxyEnabled {
    print("✅ DECODO proxy active with hybrid auth")
}
```

## Site Unblocker Examples

### 1. Basic Screenshot Capture

```swift
// Test proxy connection first
if let config = DECODOConfiguration.shared.getSiteUnblockerConfiguration() {
    let result = await DECODOConfiguration.shared.testSiteUnblockerConnection()
    
    if result.success {
        print("✅ Site Unblocker connected")
        print("📊 Latency: \(result.formattedLatency)")
    }
}
```

### 2. Screenshot with Enhanced Headers

```swift
// Create headers with API key for enhanced features
let headers = DECODOConfiguration.createSiteUnblockerHeaders(
    headlessMode: .png,
    geoLocation: "US",
    sessionId: "screenshot_session_001",
    customHeaders: [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
    ]
)

// Headers will include:
// X-SU-API-Key: your_api_key_here (if configured)
// X-SU-Headless: png
// X-SU-Geo: US
// X-SU-Session-Id: screenshot_session_001
// X-SU-Custom-User-Agent: Mozilla/5.0...
```

### 3. JavaScript Rendering with Session Management

```swift
// Create session-based headers for consistent rendering
let sessionHeaders = DECODOConfiguration.createSiteUnblockerHeaders(
    headlessMode: .html,
    geoLocation: "UK",
    sessionId: "js_render_session_002"
)

// The API key enables:
// - Session persistence across requests
// - Enhanced JavaScript execution
// - Priority processing
// - Detailed usage statistics
```

### 4. Advanced Geo-Targeting

```swift
// Use API key for premium geo-targeting options
let jsHeaders = DECODOConfiguration.createSiteUnblockerHeaders(
    headlessMode: .html,
    geoLocation: "DE-Berlin", // City-level targeting (API key required)
    sessionId: "geo_session_003"
)

// Without API key: Basic country-level geo-targeting
// With API key: City-level and ISP-level targeting
```

## Complete Integration Example

```swift
// 1. Configure hybrid authentication
DECODOConfiguration.shared.setCredentials(username: "your_username", password: "your_password", apiKey: "your_api_key")

// 2. Create enhanced headers
let headers = DECODOConfiguration.createSiteUnblockerHeaders(
    headlessMode: .png,
    geoLocation: "US-California",
    sessionId: "integration_session"
)

// 3. Enable proxy with hybrid auth
await ProxyManager.shared.enableDECODOSiteUnblocker()

// Now your web requests will go through DECODO with:
// - Proxy authentication via username:password
// - Enhanced features via API key
// - Session management and statistics
// - Priority routing and support
```

## Web Scraping API Examples

### 1. Basic Web Scraping

```swift
// Create payload with API key for enhanced parsing
let headers = DECODOConfiguration.createWebScrapingAPIPayload(
    url: "https://example.com",
    target: "universal",
    headlessMode: .html,
    enableParsing: true
)

// Payload includes:
// api_key: your_api_key_here (enables advanced parsing)
// url: https://example.com
// target: universal
// headless: html
// parse: true
```

### 2. Advanced Automation Integration

```swift
// Enable DECODO for automation with hybrid auth
await AutomationController.shared.enableDECODOForAutomation()

// Enhanced automation capabilities with API key:
// - Advanced captcha solving
// - Intelligent retry logic
// - Session-based automation
// - Priority processing
```

## Error Handling and Validation

### 1. Comprehensive Validation

```swift
func validateAndSetupDECODO(username: String, password: String, apiKey: String?) async -> Bool {
    // Set hybrid credentials
    DECODOConfiguration.shared.setCredentials(username: username, password: password, apiKey: apiKey)
    
    // Test proxy connection
    guard let config = DECODOConfiguration.shared.getSiteUnblockerConfiguration() else {
        print("❌ Failed to create proxy configuration")
        return false
    }
    
    let result = await DECODOConfiguration.shared.testSiteUnblockerConnection()
    
    if result.success {
        print("✅ DECODO setup successful")
        print("📊 Proxy latency: \(result.formattedLatency)")
        print("🔑 API key configured: \(apiKey != nil)")
        return true
    } else {
        print("❌ DECODO setup failed: \(result.error ?? "Unknown error")")
        DECODOConfiguration.shared.clearCredentials()
        return false
    }
}
```

### 2. Graceful Fallback

```swift
func setupProxyWithFallback() async {
    // Try to enable DECODO proxy with hybrid auth
    if DECODOConfiguration.shared.hasValidCredentials() {
        await ProxyManager.shared.enableDECODOSiteUnblocker()
        
        if ProxyManager.shared.isProxyEnabled {
            print("✅ DECODO proxy enabled with hybrid authentication")
            return
        }
    }
    
    print("⚠️ Using direct connection - DECODO not available")
    // Continue with direct connection
}
```

## Testing Examples

### 1. Unit Testing

```swift
func testDECODOHybridIntegration() {
    // Test hybrid credential storage
    DECODOConfiguration.shared.setCredentials(username: "test_user", password: "test_pass", apiKey: "test_key")
    
    // Verify configuration
    let config = DECODOConfiguration.shared.getSiteUnblockerConfiguration()
    
    XCTAssertEqual(config?.host, "unblock.decodo.com")
    XCTAssertEqual(config?.port, 60000)
    XCTAssertEqual(config?.username, "test_user")
    XCTAssertEqual(config?.password, "test_pass")
    
    // Test header generation with API key
    let headers = DECODOConfiguration.createSiteUnblockerHeaders()
    XCTAssertEqual(headers["X-SU-API-Key"], "test_key")
}
```

### 2. Integration Testing

```swift
func testRealDECODOConnection() async {
    // Load credentials from environment
    guard let username = ProcessInfo.processEnvironment["DECODO_USERNAME"],
          let password = ProcessInfo.processEnvironment["DECODO_PASSWORD"] else {
        XCTSkip("Real DECODO credentials not available")
        return
    }
    
    let apiKey = ProcessInfo.processEnvironment["DECODO_API_KEY"]
    
    DECODOConfiguration.shared.setCredentials(username: username, password: password, apiKey: apiKey)
    
    guard let config = DECODOConfiguration.shared.getSiteUnblockerConfiguration() else {
        XCTFail("Failed to create configuration")
        return
    }
    
    let result = await DECODOConfiguration.shared.testSiteUnblockerConnection()
    XCTAssertTrue(result.success, "Connection failed: \(result.error ?? "Unknown")")
}
```

## Environment Configuration

### 1. Development Setup

```bash
# Required proxy credentials
export DECODO_USERNAME="your_username"
export DECODO_PASSWORD="your_password"

# Optional API key for enhanced features
export DECODO_API_KEY="your_api_key"
```

### 2. Production Configuration

```swift
// Load from secure storage in production
func setupDECODO(username: String, password: String, apiKey: String?) async -> Bool {
    DECODOConfiguration.shared.setCredentials(username: username, password: password, apiKey: apiKey)
    
    guard let config = DECODOConfiguration.shared.getSiteUnblockerConfiguration() else {
        return false
    }
    
    let result = await DECODOConfiguration.shared.testSiteUnblockerConnection()
    return result.success
}
```

## Security Best Practices

### 1. Credential Management

```swift
// ✅ Good: Use secure credential storage
func setupDECODOSafely() async {
    guard DECODOConfiguration.shared.hasValidCredentials() else {
        print("❌ No DECODO credentials configured")
        return
    }
    
    await ProxyManager.shared.enableDECODOSiteUnblocker()
    
    if !ProxyManager.shared.isProxyEnabled {
        print("❌ Failed to enable DECODO proxy")
    }
}

// ❌ Bad: Never hardcode credentials
// DECODOConfiguration.setCredentials(username: "hardcoded", password: "secret", apiKey: "key")
```

### 2. Cleanup

```swift
func cleanupDECODO() {
    // Clear credentials when no longer needed
    DECODOConfiguration.shared.clearCredentials()
    
    // Disable proxy
    ProxyManager.shared.disableProxy()
}
```

## Troubleshooting

### Common Issues

1. **"No DECODO proxy available"**
   - Check if credentials are set: `DECODOConfiguration.shared.hasValidCredentials()`
   - Verify credentials in DECODO dashboard
   - Test connection: `await DECODOConfiguration.shared.testSiteUnblockerConnection()`

2. **"Proxy authentication failed"**
   - Verify username/password are correct
   - Check proxy endpoint accessibility
   - Verify DECODO service status

3. **"API key invalid"**
   - Check API key format and permissions
   - Regenerate API key in DECODO dashboard
   - Verify API key is properly configured

4. **"Connection timeout"**
   - Check network connectivity
   - Try different geo-location
   - Check DECODO service status

### Debug Status

```swift
func debugDECODOStatus() {
    print("DECODO Status:")
    print("- Credentials configured: \(DECODOConfiguration.shared.hasValidCredentials())")
    print("- API key available: \(DECODOConfiguration.shared.credentials?.apiKey != nil)")
    print("- Connection status: \(DECODOConfiguration.shared.connectionStatus)")
    print("- Proxy enabled: \(ProxyManager.shared.isProxyEnabled)")
    
    if let config = DECODOConfiguration.shared.getSiteUnblockerConfiguration() {
        print("- Proxy endpoint: \(config.endpoint):\(config.port)")
        print("- Capabilities: \(config.capabilities)")
    }
}
```

## Support and Resources

For issues with the DECODO integration:

1. **Configuration Issues**: Check credentials and API key in settings
2. **Connection Problems**: Test connection and check service status
3. **API Issues**: Contact DECODO support at support@decodo.com
4. **Account Issues**: Check your DECODO dashboard

### Resources
- [DECODO Website](https://decodo.com)
- [DECODO Dashboard](https://dashboard.decodo.com)
- [DECODO Documentation](https://help.decodo.com)
- [Site Unblocker Quick Start](https://help.decodo.com/docs/site-unblocker-quick-start)

---

**The hybrid authentication system provides enhanced functionality while maintaining full backward compatibility with existing username:password configurations.**
