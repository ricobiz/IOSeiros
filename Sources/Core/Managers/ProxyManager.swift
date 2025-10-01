
//
//  ProxyManager.swift
//  EirosAgent
//
//  Enhanced Proxy Manager with Full DECODO Integration
//  Created: 2025-09-22
//

import Foundation
import Combine

// MARK: - Proxy Manager

@MainActor
public class ProxyManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = ProxyManager()
    
    // MARK: - Published Properties
    @Published public var isProxyEnabled = false
    @Published public var currentProxy: ProxyConfiguration?
    @Published public var availableProxies: [ProxyConfiguration] = []
    @Published public var connectionStatus: ProxyConnectionStatus = .disconnected
    @Published public var statistics: ProxyStatistics = ProxyStatistics()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let decodoConfig = DECODOConfiguration.shared
    private var healthCheckTimer: Timer?
    private var sessionManager: ProxySessionManager
    
    // MARK: - Initialization
    private init() {
        self.sessionManager = ProxySessionManager()
        setupBindings()
        loadProxyConfigurations()
        startHealthMonitoring()
    }
    
    // MARK: - Public Methods
    
    public func enableProxy(configuration: ProxyConfiguration) async -> Bool {
        do {
            // Test connection first
            let testResult = await testProxyConnection(configuration)
            guard testResult.success else {
                await MainActor.run {
                    self.connectionStatus = .error(testResult.error ?? "Connection failed")
                }
                return false
            }
            
            // Apply configuration
            await MainActor.run {
                self.currentProxy = configuration
                self.isProxyEnabled = true
                self.connectionStatus = .connected
                self.statistics.recordConnection()
            }
            
            // Configure session manager
            sessionManager.configure(with: configuration)
            
            return true
        } catch {
            await MainActor.run {
                self.connectionStatus = .error(error.localizedDescription)
            }
            return false
        }
    }
    
    public func disableProxy() {
        currentProxy = nil
        isProxyEnabled = false
        connectionStatus = .disconnected
        sessionManager.reset()
    }
    
    public func enableDECODOSiteUnblocker() async -> Bool {
        guard let config = createDECODOSiteUnblockerConfiguration() else {
            connectionStatus = .error("DECODO not configured")
            return false
        }
        
        return await enableProxy(configuration: config)
    }
    
    public func enableDECODOWebScrapingAPI() async -> Bool {
        guard let config = createDECODOWebScrapingAPIConfiguration() else {
            connectionStatus = .error("DECODO not configured")
            return false
        }
        
        return await enableProxy(configuration: config)
    }
    
    public func testProxyConnection(_ configuration: ProxyConfiguration) async -> ProxyTestResult {
        let startTime = Date()
        
        do {
            let result = await performConnectionTest(configuration)
            let latency = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.statistics.recordTest(success: result.success, latency: latency)
            }
            
            return ProxyTestResult(
                success: result.success,
                error: result.error,
                latency: latency,
                responseData: result.data
            )
        } catch {
            let latency = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.statistics.recordTest(success: false, latency: latency)
            }
            
            return ProxyTestResult(
                success: false,
                error: error.localizedDescription,
                latency: latency,
                responseData: nil
            )
        }
    }
    
    public func getCurrentProxyInfo() -> ProxyInfo? {
        guard let proxy = currentProxy else { return nil }
        
        return ProxyInfo(
            name: proxy.name,
            type: proxy.type,
            status: connectionStatus,
            latency: statistics.averageLatency,
            dataTransferred: statistics.totalDataTransferred,
            uptime: statistics.connectionUptime
        )
    }
    
    // MARK: - Screenshot and Automation Support
    
    public func captureScreenshotThroughProxy(url: String, options: ScreenshotOptions = ScreenshotOptions()) async -> ScreenshotResult {
        guard isProxyEnabled, let proxy = currentProxy else {
            return ScreenshotResult(success: false, error: "No proxy enabled", imageData: nil)
        }
        
        if proxy.capabilities.contains(.screenshotCapture) {
            return await captureDECODOScreenshot(url: url, options: options)
        } else {
            return ScreenshotResult(success: false, error: "Proxy doesn't support screenshots", imageData: nil)
        }
    }
    
    public func executeAutomationThroughProxy(request: AutomationRequest) async -> AutomationResult {
        guard isProxyEnabled, let proxy = currentProxy else {
            return AutomationResult(success: false, error: "No proxy enabled", data: nil)
        }
        
        if proxy.capabilities.contains(.javascriptRendering) {
            return await executeDECODOAutomation(request: request)
        } else {
            return AutomationResult(success: false, error: "Proxy doesn't support automation", data: nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        decodoConfig.$isConfigured
            .sink { [weak self] isConfigured in
                if isConfigured {
                    self?.loadDECODOConfigurations()
                } else {
                    self?.removeDECODOConfigurations()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadProxyConfigurations() {
        availableProxies = []
        loadDECODOConfigurations()
        loadCustomConfigurations()
    }
    
    private func loadDECODOConfigurations() {
        guard decodoConfig.isConfigured else { return }
        
        var configs: [ProxyConfiguration] = []
        
        // Site Unblocker configuration
        if let siteUnblockerConfig = createDECODOSiteUnblockerConfiguration() {
            configs.append(siteUnblockerConfig)
        }
        
        // Web Scraping API configuration
        if let webScrapingConfig = createDECODOWebScrapingAPIConfiguration() {
            configs.append(webScrapingConfig)
        }
        
        // Update available proxies
        availableProxies.removeAll { $0.id.hasPrefix("decodo-") }
        availableProxies.append(contentsOf: configs)
    }
    
    private func removeDECODOConfigurations() {
        availableProxies.removeAll { $0.id.hasPrefix("decodo-") }
        
        if let current = currentProxy, current.id.hasPrefix("decodo-") {
            disableProxy()
        }
    }
    
    private func loadCustomConfigurations() {
        // Load custom proxy configurations from UserDefaults or other storage
        // Implementation depends on requirements
    }
    
    private func createDECODOSiteUnblockerConfiguration() -> ProxyConfiguration? {
        guard let config = decodoConfig.getSiteUnblockerConfiguration() else { return nil }
        
        return ProxyConfiguration(
            id: "decodo-site-unblocker",
            name: "DECODO Site Unblocker",
            type: .http,
            host: config.endpoint,
            port: config.port,
            username: config.username,
            password: config.password,
            isDefault: true,
            capabilities: [
                .webUnblocking,
                .javascriptRendering,
                .screenshotCapture,
                .geoTargeting,
                .sessionManagement,
                .captchaBypass
            ]
        )
    }
    
    private func createDECODOWebScrapingAPIConfiguration() -> ProxyConfiguration? {
        guard let config = decodoConfig.getWebScrapingAPIConfiguration() else { return nil }
        
        return ProxyConfiguration(
            id: "decodo-web-scraping",
            name: "DECODO Web Scraping API",
            type: .api,
            host: config.endpoint,
            port: 443,
            username: config.username,
            password: config.password,
            isDefault: false,
            capabilities: [
                .webUnblocking,
                .javascriptRendering,
                .screenshotCapture,
                .structuredParsing,
                .targetTemplates,
                .asyncRequests
            ]
        )
    }
    
    private func performConnectionTest(_ configuration: ProxyConfiguration) async -> (success: Bool, error: String?, data: Data?) {
        switch configuration.type {
        case .http, .https:
            return await testHTTPProxy(configuration)
        case .api:
            return await testAPIEndpoint(configuration)
        case .socks5:
            return await testSOCKS5Proxy(configuration)
        }
    }
    
    private func testHTTPProxy(_ configuration: ProxyConfiguration) async -> (success: Bool, error: String?, data: Data?) {
        let testURL = "https://ip.decodo.com/"
        
        guard let url = URL(string: testURL) else {
            return (false, "Invalid test URL", nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
        
        // Configure proxy
        let proxyConfig = [
            kCFNetworkProxiesHTTPProxy: configuration.host,
            kCFNetworkProxiesHTTPPort: configuration.port,
            kCFNetworkProxiesHTTPSProxy: configuration.host,
            kCFNetworkProxiesHTTPSPort: configuration.port
        ] as CFDictionary
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.connectionProxyDictionary = proxyConfig as? [AnyHashable: Any]
        
        // Add authentication if available
        if let username = configuration.username, let password = configuration.password {
            let credentials = "\(username):\(password)"
            let credentialsData = credentials.data(using: .utf8)!
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Proxy-Authorization")
        }
        
        let session = URLSession(configuration: sessionConfig)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, nil, data)
                } else {
                    return (false, "HTTP \(httpResponse.statusCode)", data)
                }
            }
            
            return (true, nil, data)
        } catch {
            return (false, error.localizedDescription, nil)
        }
    }
    
    private func testAPIEndpoint(_ configuration: ProxyConfiguration) async -> (success: Bool, error: String?, data: Data?) {
        guard let url = URL(string: configuration.host) else {
            return (false, "Invalid endpoint URL", nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        
        // Add authentication
        if let username = configuration.username, let password = configuration.password {
            let credentials = "\(username):\(password)"
            let credentialsData = credentials.data(using: .utf8)!
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Create test payload
        let payload = DECODOConfiguration.createWebScrapingAPIPayload(
            url: "https://ip.decodo.com/",
            target: "universal"
        )
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return (false, "Failed to serialize payload", nil)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, nil, data)
                } else {
                    return (false, "HTTP \(httpResponse.statusCode)", data)
                }
            }
            
            return (true, nil, data)
        } catch {
            return (false, error.localizedDescription, nil)
        }
    }
    
    private func testSOCKS5Proxy(_ configuration: ProxyConfiguration) async -> (success: Bool, error: String?, data: Data?) {
        // SOCKS5 testing implementation
        // This would require a more complex implementation
        return (false, "SOCKS5 testing not implemented", nil)
    }
    
    private func captureDECODOScreenshot(url: String, options: ScreenshotOptions) async -> ScreenshotResult {
        guard let proxy = currentProxy else {
            return ScreenshotResult(success: false, error: "No proxy configured", imageData: nil)
        }
        
        if proxy.id == "decodo-site-unblocker" {
            return await captureSiteUnblockerScreenshot(url: url, options: options)
        } else if proxy.id == "decodo-web-scraping" {
            return await captureWebScrapingAPIScreenshot(url: url, options: options)
        }
        
        return ScreenshotResult(success: false, error: "Unsupported proxy type", imageData: nil)
    }
    
    private func captureSiteUnblockerScreenshot(url: String, options: ScreenshotOptions) async -> ScreenshotResult {
        guard let config = decodoConfig.getSiteUnblockerConfiguration() else {
            return ScreenshotResult(success: false, error: "DECODO not configured", imageData: nil)
        }
        
        guard let targetURL = URL(string: url) else {
            return ScreenshotResult(success: false, error: "Invalid URL", imageData: nil)
        }
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 60.0
        
        // Configure proxy
        let proxyConfig = [
            kCFNetworkProxiesHTTPProxy: config.endpoint,
            kCFNetworkProxiesHTTPPort: config.port,
            kCFNetworkProxiesHTTPSProxy: config.endpoint,
            kCFNetworkProxiesHTTPSPort: config.port
        ] as CFDictionary
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.connectionProxyDictionary = proxyConfig as? [AnyHashable: Any]
        
        // Add authentication
        let credentials = "\(config.username):\(config.password)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Proxy-Authorization")
        
        // Add DECODO headers for screenshot
        let headers = DECODOConfiguration.createSiteUnblockerHeaders(
            headlessMode: .png,
            geoLocation: options.geoLocation,
            sessionId: options.sessionId
        )
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let session = URLSession(configuration: sessionConfig)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    await MainActor.run {
                        self.statistics.recordDataTransfer(bytes: Int64(data.count))
                    }
                    return ScreenshotResult(success: true, error: nil, imageData: data)
                } else {
                    return ScreenshotResult(success: false, error: "HTTP \(httpResponse.statusCode)", imageData: nil)
                }
            }
            
            return ScreenshotResult(success: false, error: "Invalid response", imageData: nil)
        } catch {
            return ScreenshotResult(success: false, error: error.localizedDescription, imageData: nil)
        }
    }
    
    private func captureWebScrapingAPIScreenshot(url: String, options: ScreenshotOptions) async -> ScreenshotResult {
        guard let config = decodoConfig.getWebScrapingAPIConfiguration() else {
            return ScreenshotResult(success: false, error: "DECODO not configured", imageData: nil)
        }
        
        guard let apiURL = URL(string: config.endpoint) else {
            return ScreenshotResult(success: false, error: "Invalid API endpoint", imageData: nil)
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        
        // Add authentication
        let credentials = "\(config.username):\(config.password)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Create payload for screenshot
        let payload = DECODOConfiguration.createWebScrapingAPIPayload(
            url: url,
            target: options.target,
            headlessMode: .png,
            geoLocation: options.geoLocation,
            deviceType: options.deviceType,
            sessionId: options.sessionId
        )
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return ScreenshotResult(success: false, error: "Failed to serialize payload", imageData: nil)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Parse JSON response to extract image data
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let imageBase64 = json["screenshot"] as? String,
                       let imageData = Data(base64Encoded: imageBase64) {
                        
                        await MainActor.run {
                            self.statistics.recordDataTransfer(bytes: Int64(imageData.count))
                        }
                        
                        return ScreenshotResult(success: true, error: nil, imageData: imageData)
                    } else {
                        return ScreenshotResult(success: false, error: "Invalid response format", imageData: nil)
                    }
                } else {
                    return ScreenshotResult(success: false, error: "HTTP \(httpResponse.statusCode)", imageData: nil)
                }
            }
            
            return ScreenshotResult(success: false, error: "Invalid response", imageData: nil)
        } catch {
            return ScreenshotResult(success: false, error: error.localizedDescription, imageData: nil)
        }
    }
    
    private func executeDECODOAutomation(request: AutomationRequest) async -> AutomationResult {
        // Implementation for executing automation through DECODO
        // This would handle JavaScript rendering and automation tasks
        return AutomationResult(success: false, error: "Not implemented", data: nil)
    }
    
    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() async {
        guard isProxyEnabled, let proxy = currentProxy else { return }
        
        let result = await testProxyConnection(proxy)
        
        await MainActor.run {
            if result.success {
                if case .error = self.connectionStatus {
                    self.connectionStatus = .connected
                }
            } else {
                self.connectionStatus = .error(result.error ?? "Health check failed")
            }
        }
    }
}

// MARK: - Supporting Types

public struct ProxyConfiguration: Identifiable, Codable {
    public let id: String
    public let name: String
    public let type: ProxyType
    public let host: String
    public let port: Int
    public let username: String?
    public let password: String?
    public let isDefault: Bool
    public let capabilities: Set<ProxyCapability>
    
    public init(id: String, name: String, type: ProxyType, host: String, port: Int, username: String? = nil, password: String? = nil, isDefault: Bool = false, capabilities: Set<ProxyCapability> = []) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.isDefault = isDefault
        self.capabilities = capabilities
    }
}

public enum ProxyType: String, Codable, CaseIterable {
    case http = "http"
    case https = "https"
    case socks5 = "socks5"
    case api = "api"
    
    var description: String {
        switch self {
        case .http:
            return "HTTP"
        case .https:
            return "HTTPS"
        case .socks5:
            return "SOCKS5"
        case .api:
            return "API"
        }
    }
}

public enum ProxyCapability: String, Codable, CaseIterable {
    case webUnblocking = "web_unblocking"
    case javascriptRendering = "javascript_rendering"
    case screenshotCapture = "screenshot_capture"
    case geoTargeting = "geo_targeting"
    case sessionManagement = "session_management"
    case captchaBypass = "captcha_bypass"
    case structuredParsing = "structured_parsing"
    case targetTemplates = "target_templates"
    case asyncRequests = "async_requests"
    
    var description: String {
        switch self {
        case .webUnblocking:
            return "Web Unblocking"
        case .javascriptRendering:
            return "JavaScript Rendering"
        case .screenshotCapture:
            return "Screenshot Capture"
        case .geoTargeting:
            return "Geo Targeting"
        case .sessionManagement:
            return "Session Management"
        case .captchaBypass:
            return "CAPTCHA Bypass"
        case .structuredParsing:
            return "Structured Parsing"
        case .targetTemplates:
            return "Target Templates"
        case .asyncRequests:
            return "Async Requests"
        }
    }
}

public enum ProxyConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

public struct ProxyTestResult {
    let success: Bool
    let error: String?
    let latency: TimeInterval
    let responseData: Data?
    
    var formattedLatency: String {
        return String(format: "%.0f ms", latency * 1000)
    }
}

public struct ProxyInfo {
    let name: String
    let type: ProxyType
    let status: ProxyConnectionStatus
    let latency: TimeInterval
    let dataTransferred: Int64
    let uptime: TimeInterval
    
    var formattedLatency: String {
        return String(format: "%.0f ms", latency * 1000)
    }
    
    var formattedDataTransferred: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: dataTransferred)
    }
    
    var formattedUptime: String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

public struct ProxyStatistics {
    private(set) var totalConnections: Int = 0
    private(set) var successfulConnections: Int = 0
    private(set) var totalTests: Int = 0
    private(set) var successfulTests: Int = 0
    private(set) var totalLatency: TimeInterval = 0
    private(set) var totalDataTransferred: Int64 = 0
    private(set) var connectionStartTime: Date?
    
    var successRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(successfulTests) / Double(totalTests)
    }
    
    var averageLatency: TimeInterval {
        guard totalTests > 0 else { return 0 }
        return totalLatency / Double(totalTests)
    }
    
    var connectionUptime: TimeInterval {
        guard let startTime = connectionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    mutating func recordConnection() {
        totalConnections += 1
        successfulConnections += 1
        connectionStartTime = Date()
    }
    
    mutating func recordTest(success: Bool, latency: TimeInterval) {
        totalTests += 1
        totalLatency += latency
        if success {
            successfulTests += 1
        }
    }
    
    mutating func recordDataTransfer(bytes: Int64) {
        totalDataTransferred += bytes
    }
    
    mutating func reset() {
        totalConnections = 0
        successfulConnections = 0
        totalTests = 0
        successfulTests = 0
        totalLatency = 0
        totalDataTransferred = 0
        connectionStartTime = nil
    }
}

public struct ScreenshotOptions {
    let geoLocation: String?
    let sessionId: String?
    let target: String?
    let deviceType: DeviceType
    
    init(geoLocation: String? = nil, sessionId: String? = nil, target: String? = "universal", deviceType: DeviceType = .desktop) {
        self.geoLocation = geoLocation
        self.sessionId = sessionId
        self.target = target
        self.deviceType = deviceType
    }
}

public struct ScreenshotResult {
    let success: Bool
    let error: String?
    let imageData: Data?
}

public struct AutomationRequest {
    let url: String
    let actions: [AutomationAction]
    let options: AutomationOptions
}

public struct AutomationAction {
    let type: ActionType
    let selector: String?
    let value: String?
    let delay: TimeInterval
    
    enum ActionType {
        case click
        case type
        case scroll
        case wait
        case screenshot
    }
}

public struct AutomationOptions {
    let geoLocation: String?
    let sessionId: String?
    let deviceType: DeviceType
    let enableJavaScript: Bool
    
    init(geoLocation: String? = nil, sessionId: String? = nil, deviceType: DeviceType = .desktop, enableJavaScript: Bool = true) {
        self.geoLocation = geoLocation
        self.sessionId = sessionId
        self.deviceType = deviceType
        self.enableJavaScript = enableJavaScript
    }
}

public struct AutomationResult {
    let success: Bool
    let error: String?
    let data: Data?
}

// MARK: - Proxy Session Manager

private class ProxySessionManager {
    private var currentConfiguration: ProxyConfiguration?
    private var activeSessions: [String: Date] = [:]
    
    func configure(with configuration: ProxyConfiguration) {
        self.currentConfiguration = configuration
    }
    
    func reset() {
        currentConfiguration = nil
        activeSessions.removeAll()
    }
    
    func createSession() -> String {
        let sessionId = UUID().uuidString
        activeSessions[sessionId] = Date()
        return sessionId
    }
    
    func isSessionValid(_ sessionId: String) -> Bool {
        guard let creationDate = activeSessions[sessionId] else { return false }
        
        // Sessions are valid for 10 minutes
        let expirationDate = creationDate.addingTimeInterval(600)
        return Date() < expirationDate
    }
    
    func cleanupExpiredSessions() {
        let now = Date()
        activeSessions = activeSessions.filter { _, creationDate in
            let expirationDate = creationDate.addingTimeInterval(600)
            return now < expirationDate
        }
    }
}
