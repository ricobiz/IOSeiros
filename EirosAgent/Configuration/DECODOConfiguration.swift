
//
//  DECODOConfiguration.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//

import Foundation

struct DECODOConfiguration {
    // MARK: - DECODO Site Unblocker Real API Endpoints
    // Real decodo.com Site Unblocker endpoint (formerly Smartproxy)
    static let realEndpoint = "unblock.decodo.com"
    static let realPort = 60000
    
    // MARK: - Authentication (Required for real API)
    // These should be configured by user in app settings
    static var username: String? = nil
    static var password: String? = nil
    
    // MARK: - Connection Settings
    static let connectionTimeout: TimeInterval = 30.0
    static let maxRetries = 3
    static let healthCheckInterval: TimeInterval = 60.0
    static let latencyCheckInterval: TimeInterval = 30.0
    
    // MARK: - Real API Features (Built into decodo.com service)
    static let automaticUnblocking = true
    static let javascriptRendering = true
    static let captchaBypass = true
    static let geoTargeting = true
    static let sessionManagement = true
    
    // MARK: - Supported Capabilities (Real decodo.com features)
    static let supportedCapabilities: [ProxyCapability] = [
        .webUnblocking,
        .geoBypass,
        .antiDetection,
        .javascriptRendering,
        .captchaBypass
    ]
    
    // MARK: - API Parameters
    static let supportedGeoLocations = [
        "US", "UK", "DE", "FR", "CA", "AU", "JP", "BR", "IN", "SG"
    ]
    
    static let supportedLocales = [
        "en-US", "en-GB", "de-DE", "fr-FR", "es-ES", "pt-BR", "ja-JP"
    ]
    
    // MARK: - Default Headers for Anti-Detection
    static let defaultHeaders: [String: String] = [
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate, br",
        "DNT": "1",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Cache-Control": "max-age=0"
    ]
    
    // MARK: - User Agent Pool
    static let userAgentPool = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPad; CPU OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36"
    ]
    
    // MARK: - Configuration Methods
    
    static func getRandomUserAgent() -> String {
        return userAgentPool.randomElement() ?? userAgentPool[0]
    }
    
    // MARK: - Authentication Management
    static func setCredentials(username: String, password: String) {
        self.username = username
        self.password = password
        UserDefaults.standard.set(username, forKey: "decodo_username")
        UserDefaults.standard.set(password, forKey: "decodo_password")
    }
    
    static func loadCredentials() {
        username = UserDefaults.standard.string(forKey: "decodo_username")
        password = UserDefaults.standard.string(forKey: "decodo_password")
    }
    
    static func clearCredentials() {
        username = nil
        password = nil
        UserDefaults.standard.removeObject(forKey: "decodo_username")
        UserDefaults.standard.removeObject(forKey: "decodo_password")
    }
    
    static func hasValidCredentials() -> Bool {
        return username != nil && password != nil && !username!.isEmpty && !password!.isEmpty
    }
    
    static func getDefaultProxyConfiguration() -> ProxyConfiguration? {
        guard hasValidCredentials() else {
            print("❌ DECODO credentials not configured")
            return nil
        }
        
        return ProxyConfiguration(
            id: "decodo-real",
            name: "DECODO Site Unblocker (Real API)",
            type: .http,
            host: realEndpoint,
            port: realPort,
            username: username,
            password: password,
            isDefault: true,
            capabilities: supportedCapabilities
        )
    }
    
    static func getAllProxyConfigurations() -> [ProxyConfiguration] {
        guard hasValidCredentials() else {
            print("❌ DECODO credentials not configured - returning empty configuration list")
            return []
        }
        
        return [
            ProxyConfiguration(
                id: "decodo-real",
                name: "DECODO Site Unblocker (Real API)",
                type: .http,
                host: realEndpoint,
                port: realPort,
                username: username,
                password: password,
                isDefault: true,
                capabilities: supportedCapabilities
            )
        ]
    }
    
    // MARK: - API Request Headers Factory
    static func createAPIHeaders(geoLocation: String? = nil, locale: String? = nil, sessionId: String? = nil, enableJS: Bool = false) -> [String: String] {
        var headers = defaultHeaders
        
        // Geo-location targeting
        if let geo = geoLocation {
            headers["X-SU-Geo"] = geo
        }
        
        // Locale setting
        if let loc = locale {
            headers["X-SU-Locale"] = loc
        }
        
        // Session management
        if let session = sessionId {
            headers["X-SU-Session-Id"] = session
        }
        
        // JavaScript rendering
        if enableJS {
            headers["X-SU-Headless"] = "html"
        }
        
        return headers
    }
    
    static func getOptimizedSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        
        // Timeouts
        config.timeoutIntervalForRequest = connectionTimeout
        config.timeoutIntervalForResource = connectionTimeout * 2
        
        // Connection settings
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil // Disable caching for privacy
        
        // Headers
        config.httpAdditionalHeaders = defaultHeaders.merging([
            "User-Agent": getRandomUserAgent()
        ]) { _, new in new }
        
        return config
    }
    
    // MARK: - Validation Methods
    
    static func validateEndpoint(_ endpoint: String, port: Int) async -> Bool {
        guard let url = URL(string: "http://\(endpoint):\(port)") else {
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.httpMethod = "HEAD"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 400
            }
            
            return false
        } catch {
            return false
        }
    }
    
    static func testProxyConnection(_ config: ProxyConfiguration) async -> ProxyTestResult {
        let startTime = Date()
        
        // Create session with proxy configuration
        let sessionConfig = URLSessionConfiguration.default
        
        var proxyDict: [String: Any] = [:]
        switch config.type {
        case .http:
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = true
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = config.host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = config.port
            proxyDict[kCFNetworkProxiesHTTPSEnable as String] = true
            proxyDict[kCFNetworkProxiesHTTPSProxy as String] = config.host
            proxyDict[kCFNetworkProxiesHTTPSPort as String] = config.port
        case .socks5:
            proxyDict[kCFNetworkProxiesSOCKSEnable as String] = true
            proxyDict[kCFNetworkProxiesSOCKSProxy as String] = config.host
            proxyDict[kCFNetworkProxiesSOCKSPort as String] = config.port
        }
        
        sessionConfig.connectionProxyDictionary = proxyDict
        sessionConfig.timeoutIntervalForRequest = 10.0
        
        let session = URLSession(configuration: sessionConfig)
        
        // Test URLs
        let testURLs = [
            "http://httpbin.org/ip",
            "https://api.ipify.org?format=json",
            "http://icanhazip.com"
        ]
        
        for testURL in testURLs {
            guard let url = URL(string: testURL) else { continue }
            
            do {
                let (data, response) = try await session.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   data.count > 0 {
                    
                    let latency = Date().timeIntervalSince(startTime)
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    
                    return ProxyTestResult(
                        success: true,
                        latency: latency,
                        error: nil,
                        responseData: responseString,
                        testURL: testURL
                    )
                }
            } catch {
                continue
            }
        }
        
        let latency = Date().timeIntervalSince(startTime)
        return ProxyTestResult(
            success: false,
            latency: latency,
            error: "All test URLs failed",
            responseData: nil,
            testURL: testURLs.first
        )
    }
}

// MARK: - Supporting Data Models

struct ProxyTestResult {
    let success: Bool
    let latency: TimeInterval
    let error: String?
    let responseData: String?
    let testURL: String?
    
    var formattedLatency: String {
        return "\(Int(latency * 1000))ms"
    }
}

// MARK: - DECODO Real API Integration Extensions

extension ProxyManager {
    func loadDECODOConfigurations() {
        // Load credentials and configurations
        DECODOConfiguration.loadCredentials()
        let decodoConfigs = DECODOConfiguration.getAllProxyConfigurations()
        
        // Replace existing DECODO configurations
        availableProxies.removeAll { $0.id.hasPrefix("decodo-") }
        availableProxies.append(contentsOf: decodoConfigs)
        
        if decodoConfigs.isEmpty {
            print("⚠️ No DECODO configurations loaded - credentials may not be set")
        } else {
            print("✅ Loaded \(decodoConfigs.count) DECODO Real API proxy configurations")
        }
    }
    
    func enableDECODOPrimary() async {
        // For real API, we only have one configuration
        if let realConfig = availableProxies.first(where: { $0.id == "decodo-real" }) {
            await enableProxy(with: realConfig)
        } else {
            print("❌ DECODO Real API configuration not found - check credentials")
        }
    }
    
    func enableDECODOSecondary() async {
        // For real API, secondary is the same as primary (single endpoint)
        await enableDECODOPrimary()
    }
    
    func enableDECODOSOCKS() async {
        // Real DECODO API doesn't use SOCKS5, redirect to HTTP proxy
        await enableDECODOPrimary()
    }
    
    func testAllDECODOProxies() async -> [String: ProxyTestResult] {
        var results: [String: ProxyTestResult] = [:]
        
        let decodoProxies = availableProxies.filter { $0.id.hasPrefix("decodo-") }
        
        for proxy in decodoProxies {
            let result = await DECODOConfiguration.testProxyConnection(proxy)
            results[proxy.id] = result
        }
        
        return results
    }
}

extension WebViewManager {
    func enableDECODOProxy() async {
        await enableProxyForWebView()
    }
    
    func getDECODOStatus() -> String {
        if isProxyEnabled {
            return "DECODO Site Unblocker (Real API): Active"
        } else {
            return "DECODO Site Unblocker (Real API): Inactive"
        }
    }
}

extension AutomationController {
    func enableDECODOForAutomation() async {
        await enableProxyForAutomation()
        addLogEntry("DECODO Site Unblocker (Real API) enabled for automation", type: .info)
    }
    
    func disableDECODOForAutomation() {
        disableProxyForAutomation()
        addLogEntry("DECODO Site Unblocker (Real API) disabled for automation", type: .info)
    }
    
    func getDECODOAutomationStatus() -> String {
        return getProxyStatusForAutomation()
    }
}
