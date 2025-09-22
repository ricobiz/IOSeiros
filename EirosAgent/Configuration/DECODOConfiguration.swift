
//
//  DECODOConfiguration.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//

import Foundation

struct DECODOConfiguration {
    // MARK: - DECODO Unblocker Endpoints
    static let primaryEndpoint = "proxy.decodo.io"
    static let primaryPort = 8080
    static let secondaryEndpoint = "backup.decodo.io"
    static let secondaryPort = 8080
    static let socksPort = 1080
    
    // MARK: - Connection Settings
    static let connectionTimeout: TimeInterval = 30.0
    static let maxRetries = 3
    static let healthCheckInterval: TimeInterval = 60.0
    static let latencyCheckInterval: TimeInterval = 30.0
    
    // MARK: - Anti-Detection Features
    static let userAgentRotation = true
    static let headerRandomization = true
    static let connectionPooling = true
    static let requestThrottling = true
    
    // MARK: - Supported Capabilities
    static let supportedCapabilities: [ProxyCapability] = [
        .webUnblocking,
        .geoBypass,
        .antiDetection
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
    
    static func getDefaultProxyConfiguration() -> ProxyConfiguration {
        return ProxyConfiguration(
            id: "decodo-default",
            name: "DECODO Unblocker",
            type: .http,
            host: primaryEndpoint,
            port: primaryPort,
            username: nil,
            password: nil,
            isDefault: true,
            capabilities: supportedCapabilities
        )
    }
    
    static func getAllProxyConfigurations() -> [ProxyConfiguration] {
        return [
            ProxyConfiguration(
                id: "decodo-primary",
                name: "DECODO Unblocker (Primary)",
                type: .http,
                host: primaryEndpoint,
                port: primaryPort,
                username: nil,
                password: nil,
                isDefault: true,
                capabilities: supportedCapabilities
            ),
            ProxyConfiguration(
                id: "decodo-secondary",
                name: "DECODO Unblocker (Backup)",
                type: .http,
                host: secondaryEndpoint,
                port: secondaryPort,
                username: nil,
                password: nil,
                isDefault: false,
                capabilities: supportedCapabilities
            ),
            ProxyConfiguration(
                id: "decodo-socks",
                name: "DECODO SOCKS5",
                type: .socks5,
                host: primaryEndpoint,
                port: socksPort,
                username: nil,
                password: nil,
                isDefault: false,
                capabilities: supportedCapabilities + [.fullTunneling]
            )
        ]
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

// MARK: - DECODO Integration Extensions

extension ProxyManager {
    func loadDECODOConfigurations() {
        let decodoConfigs = DECODOConfiguration.getAllProxyConfigurations()
        
        // Replace existing DECODO configurations
        availableProxies.removeAll { $0.id.hasPrefix("decodo-") }
        availableProxies.append(contentsOf: decodoConfigs)
        
        print("✅ Loaded \(decodoConfigs.count) DECODO proxy configurations")
    }
    
    func enableDECODOPrimary() async {
        if let primaryConfig = availableProxies.first(where: { $0.id == "decodo-primary" }) {
            await enableProxy(with: primaryConfig)
        }
    }
    
    func enableDECODOSecondary() async {
        if let secondaryConfig = availableProxies.first(where: { $0.id == "decodo-secondary" }) {
            await enableProxy(with: secondaryConfig)
        }
    }
    
    func enableDECODOSOCKS() async {
        if let socksConfig = availableProxies.first(where: { $0.id == "decodo-socks" }) {
            await enableProxy(with: socksConfig)
        }
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
            return "DECODO Unblocker: Active"
        } else {
            return "DECODO Unblocker: Inactive"
        }
    }
}

extension AutomationController {
    func enableDECODOForAutomation() async {
        await enableProxyForAutomation()
        addLogEntry("DECODO Unblocker enabled for automation", type: .info)
    }
    
    func disableDECODOForAutomation() {
        disableProxyForAutomation()
        addLogEntry("DECODO Unblocker disabled for automation", type: .info)
    }
    
    func getDECODOAutomationStatus() -> String {
        return getProxyStatusForAutomation()
    }
}
