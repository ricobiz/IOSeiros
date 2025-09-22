
# DECODO Site Unblocker Real API Integration Guide

## Overview

This guide describes the integration of the **real DECODO Site Unblocker API** (decodo.com, formerly Smartproxy) with the Eiros Agent iOS application for enhanced web automation and browsing capabilities.

## ⚠️ IMPORTANT: Real API Integration

**This integration now uses the actual DECODO Site Unblocker service:**
- **Endpoint**: `unblock.decodo.com:60000`
- **Authentication**: Username/Password required (from DECODO dashboard)
- **Service**: Real proxy service with CAPTCHA bypass, JavaScript rendering, and geo-targeting
- **Billing**: Pay-per-request or pay-per-GB pricing

**Previous Implementation Error**: The earlier version created a mock implementation with fake endpoints (`proxy.decodo.io`, `backup.decodo.io`). This has been corrected to use the real DECODO API.

## Features

### ✅ Implemented Features

1. **ProxyManager** - Central proxy management system
   - DECODO primary and backup endpoints
   - SOCKS5 support for advanced tunneling
   - Automatic failover between proxies
   - Real-time latency monitoring
   - Connection health checks

2. **WebView Integration** - Seamless browser proxy support
   - Dynamic proxy configuration
   - Real-time proxy switching
   - Anti-detection headers
   - User agent rotation

3. **Automation Integration** - Proxy support for AI automation
   - Qwen2VL model requests through proxy
   - Automated web interactions via proxy
   - Proxy status monitoring in automation panel

4. **User Interface** - Complete proxy control interface
   - Proxy status indicators
   - Quick proxy toggle buttons
   - Detailed proxy configuration
   - Statistics and monitoring

## Architecture

### Core Components

```
ProxyManager (Singleton)
├── DECODO Configuration Management
├── Connection Health Monitoring  
├── Automatic Failover Logic
└── Session Management

WebViewManager
├── Dynamic Proxy Configuration
├── WKWebView Proxy Integration
└── Real-time Proxy Switching

AutomationController
├── Proxy-enabled Automation
├── Qwen2VL Proxy Integration
└── Status Monitoring

UI Components
├── ProxyControlView (Full Control Panel)
├── BrowserView (Proxy Status Indicator)
└── AutomationPanelView (Quick Controls)
```

### DECODO Real API Configuration

- **Endpoint**: `unblock.decodo.com:60000`
- **Protocol**: HTTP/HTTPS Proxy
- **Authentication**: Username/Password (required)
- **Features**: JavaScript rendering, CAPTCHA bypass, geo-targeting, session management

### Getting Started

1. **Sign up at DECODO**: Visit [decodo.com](https://decodo.com) and create an account
2. **Get credentials**: Access your dashboard and generate API credentials
3. **Configure in app**: Use the DECODO Settings view to enter your credentials
4. **Test connection**: Use the built-in connection test to verify setup

## Usage

### 1. Basic Proxy Control

```swift
// Enable DECODO primary proxy
await ProxyManager.shared.enableDECODOPrimary()

// Check proxy status
let isActive = ProxyManager.shared.isUsingProxy()

// Get proxy information
let info = ProxyManager.shared.getCurrentProxyInfo()
```

### 2. WebView with Proxy

```swift
// WebView automatically uses proxy when enabled
let webViewManager = WebViewManager()

// Check proxy status in WebView
let status = webViewManager.getDECODOStatus()

// Enable proxy for WebView
await webViewManager.enableDECODOProxy()
```

### 3. Automation with Proxy

```swift
// Enable proxy for automation
await AutomationController.shared.enableDECODOForAutomation()

// Run automation task with proxy
let task = AutomationTask(...)
await AutomationController.shared.executeTask(task)
```

### 4. UI Integration

The app includes several UI components for proxy control:

- **Browser View**: Proxy status indicator with quick access
- **Automation Panel**: Proxy toggle and status display
- **Proxy Control View**: Full configuration and monitoring

## Configuration

### Default Settings

```swift
// Connection settings
static let connectionTimeout: TimeInterval = 30.0
static let maxRetries = 3
static let healthCheckInterval: TimeInterval = 60.0

// Anti-detection features
static let userAgentRotation = true
static let headerRandomization = true
static let connectionPooling = true
```

### Custom Configuration

You can add custom proxy configurations through the UI or programmatically:

```swift
let customProxy = ProxyConfiguration(
    id: "custom-proxy",
    name: "Custom Proxy",
    type: .http,
    host: "your-proxy.com",
    port: 8080,
    username: "user",
    password: "pass",
    isDefault: false,
    capabilities: [.webUnblocking]
)

ProxyManager.shared.saveCustomProxyConfiguration(customProxy)
```

## Anti-Detection Features

### 1. User Agent Rotation
- Pool of realistic mobile and desktop user agents
- Automatic rotation on each request
- iOS Safari, Chrome, and Firefox variants

### 2. Header Randomization
- Realistic browser headers
- DNT (Do Not Track) support
- Proper Accept headers for different content types

### 3. Connection Management
- Connection pooling for efficiency
- Request throttling to avoid detection
- Proper SSL/TLS handling

## Monitoring and Diagnostics

### 1. Real-time Monitoring
- Connection latency tracking
- Data transfer statistics
- Proxy health status
- Automatic failover events

### 2. Logging
- Detailed proxy connection logs
- Error tracking and reporting
- Performance metrics
- Debug information

### 3. Testing
- Built-in proxy connection testing
- Multiple test endpoints
- Latency measurement
- Success rate tracking

## Troubleshooting

### Common Issues

1. **Proxy Connection Failed**
   - Check internet connectivity
   - Verify DECODO service status
   - Try backup proxy endpoint

2. **High Latency**
   - Switch to backup proxy
   - Check network conditions
   - Verify proxy server load

3. **WebView Not Using Proxy**
   - Ensure proxy is enabled in ProxyManager
   - Check WebView configuration
   - Verify proxy settings are applied

### Debug Commands

```swift
// Test all DECODO proxies
let results = await ProxyManager.shared.testAllDECODOProxies()

// Get detailed status
let status = AutomationController.shared.getAutomationStatus()

// Check component readiness
let components = status.componentsReady
```

## Security Considerations

1. **No Authentication Required**: DECODO typically doesn't require username/password
2. **HTTPS Support**: All HTTPS traffic is properly tunneled
3. **DNS Resolution**: DNS queries go through proxy for privacy
4. **No Logging**: Local app doesn't log sensitive proxy traffic

## Performance Optimization

1. **Connection Pooling**: Reuse connections for efficiency
2. **Automatic Failover**: Switch to backup proxy on failure
3. **Health Monitoring**: Proactive connection health checks
4. **Latency Optimization**: Choose fastest available proxy

## Integration Testing

### Test Scenarios

1. **Basic Connectivity**
   - Enable proxy and browse websites
   - Verify IP address changes
   - Test HTTPS sites

2. **Automation Testing**
   - Run automation tasks with proxy enabled
   - Verify Qwen2VL model requests work
   - Test web scraping scenarios

3. **Failover Testing**
   - Disable primary proxy
   - Verify automatic failover to backup
   - Test recovery when primary returns

4. **Performance Testing**
   - Measure latency with/without proxy
   - Test concurrent connections
   - Monitor memory usage

## Future Enhancements

### Planned Features

1. **Geographic Proxy Selection**
   - Choose proxy by country/region
   - Automatic geo-optimization

2. **Load Balancing**
   - Distribute requests across multiple proxies
   - Smart routing based on performance

3. **Advanced Analytics**
   - Detailed usage statistics
   - Performance trending
   - Cost optimization insights

4. **Custom Proxy Protocols**
   - Support for additional proxy types
   - Custom authentication methods
   - Protocol-specific optimizations

## Support

For issues related to DECODO integration:

1. Check proxy service status at DECODO dashboard
2. Review application logs for error details
3. Test with backup proxy endpoints
4. Contact DECODO support for service issues

## Changelog

### Version 1.0.0 (2025-09-22)
- Initial DECODO Unblocker integration
- ProxyManager implementation
- WebView proxy support
- Automation proxy integration
- Complete UI for proxy control
- Anti-detection features
- Health monitoring and failover
- Documentation and testing guides
