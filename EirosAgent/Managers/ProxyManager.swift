
//
//  ProxyManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//

import Foundation
import Network
import Combine

@MainActor
class ProxyManager: ObservableObject {
    static let shared = ProxyManager()
    
    // MARK: - Published Properties
    @Published var isProxyEnabled = false
    @Published var proxyStatus: ProxyStatus = .disconnected
    @Published var currentProxyConfig: ProxyConfiguration?
    @Published var connectionLatency: TimeInterval = 0
    @Published var dataTransferred: Int64 = 0
    @Published var lastError: String?
    @Published var availableProxies: [ProxyConfiguration] = []
    
    // MARK: - DECODO Configuration
    private let decodoPrimaryEndpoint = "proxy.decodo.io"
    private let decodoPrimaryPort = 8080
    private let decodoSecondaryEndpoint = "backup.decodo.io"
    private let decodoSecondaryPort = 8080
    
    // MARK: - Network Monitoring
    private var networkMonitor: NWPathMonitor?
    private var monitorQueue = DispatchQueue(label: "ProxyNetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Proxy Session
    private var proxySession: URLSession?
    private var defaultSession: URLSession = .shared
    
    private init() {
        setupNetworkMonitoring()
        loadProxyConfigurations()
        
        // Auto-enable proxy if configurations are available
        if !availableProxies.isEmpty {
            Task {
                await enableProxy(with: availableProxies.first!)
            }
        }
    }
    
    // MARK: - Proxy Configuration
    
    private func loadProxyConfigurations() {
        // DECODO Unblocker configurations
        let decodoPrimary = ProxyConfiguration(
            id: "decodo-primary",
            name: "DECODO Unblocker (Primary)",
            type: .http,
            host: decodoPrimaryEndpoint,
            port: decodoPrimaryPort,
            username: nil, // DECODO typically doesn't require auth
            password: nil,
            isDefault: true,
            capabilities: [.webUnblocking, .geoBypass, .antiDetection]
        )
        
        let decodoSecondary = ProxyConfiguration(
            id: "decodo-secondary",
            name: "DECODO Unblocker (Backup)",
            type: .http,
            host: decodoSecondaryEndpoint,
            port: decodoSecondaryPort,
            username: nil,
            password: nil,
            isDefault: false,
            capabilities: [.webUnblocking, .geoBypass, .antiDetection]
        )
        
        // Add SOCKS5 configuration for advanced use cases
        let decodoSOCKS = ProxyConfiguration(
            id: "decodo-socks",
            name: "DECODO SOCKS5",
            type: .socks5,
            host: decodoPrimaryEndpoint,
            port: 1080,
            username: nil,
            password: nil,
            isDefault: false,
            capabilities: [.webUnblocking, .geoBypass, .antiDetection, .fullTunneling]
        )
        
        availableProxies = [decodoPrimary, decodoSecondary, decodoSOCKS]
        
        // Load custom configurations from UserDefaults if any
        loadCustomProxyConfigurations()
    }
    
    private func loadCustomProxyConfigurations() {
        if let data = UserDefaults.standard.data(forKey: "CustomProxyConfigurations"),
           let customConfigs = try? JSONDecoder().decode([ProxyConfiguration].self, from: data) {
            availableProxies.append(contentsOf: customConfigs)
        }
    }
    
    func saveCustomProxyConfiguration(_ config: ProxyConfiguration) {
        // Add to available proxies
        if let index = availableProxies.firstIndex(where: { $0.id == config.id }) {
            availableProxies[index] = config
        } else {
            availableProxies.append(config)
        }
        
        // Save to UserDefaults
        let customConfigs = availableProxies.filter { !$0.id.hasPrefix("decodo-") }
        if let data = try? JSONEncoder().encode(customConfigs) {
            UserDefaults.standard.set(data, forKey: "CustomProxyConfigurations")
        }
    }
    
    // MARK: - Proxy Control
    
    func enableProxy(with configuration: ProxyConfiguration) async {
        proxyStatus = .connecting
        currentProxyConfig = configuration
        lastError = nil
        
        do {
            // Create proxy session configuration
            let sessionConfig = createProxySessionConfiguration(for: configuration)
            proxySession = URLSession(configuration: sessionConfig)
            
            // Test proxy connection
            let isConnected = await testProxyConnection(configuration)
            
            if isConnected {
                proxyStatus = .connected
                isProxyEnabled = true
                
                // Start latency monitoring
                startLatencyMonitoring()
                
                print("✅ DECODO Proxy enabled: \(configuration.name)")
            } else {
                throw ProxyError.connectionFailed("Failed to connect to \(configuration.name)")
            }
            
        } catch {
            proxyStatus = .error
            lastError = error.localizedDescription
            isProxyEnabled = false
            print("❌ Proxy connection failed: \(error.localizedDescription)")
            
            // Try fallback proxy if available
            await tryFallbackProxy()
        }
    }
    
    func disableProxy() {
        proxyStatus = .disconnected
        isProxyEnabled = false
        currentProxyConfig = nil
        proxySession = nil
        connectionLatency = 0
        
        print("🔌 Proxy disabled")
    }
    
    private func tryFallbackProxy() async {
        guard let currentConfig = currentProxyConfig,
              let fallbackConfig = availableProxies.first(where: { 
                  $0.id != currentConfig.id && $0.capabilities.contains(.webUnblocking) 
              }) else {
            return
        }
        
        print("🔄 Trying fallback proxy: \(fallbackConfig.name)")
        await enableProxy(with: fallbackConfig)
    }
    
    // MARK: - Session Configuration
    
    private func createProxySessionConfiguration(for config: ProxyConfiguration) -> URLSessionConfiguration {
        let sessionConfig = URLSessionConfiguration.default
        
        // Configure proxy settings
        var proxyDict: [String: Any] = [:]
        
        switch config.type {
        case .http:
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = true
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = config.host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = config.port
            
            // HTTPS proxy (same as HTTP for DECODO)
            proxyDict[kCFNetworkProxiesHTTPSEnable as String] = true
            proxyDict[kCFNetworkProxiesHTTPSProxy as String] = config.host
            proxyDict[kCFNetworkProxiesHTTPSPort as String] = config.port
            
        case .socks5:
            proxyDict[kCFNetworkProxiesSOCKSEnable as String] = true
            proxyDict[kCFNetworkProxiesSOCKSProxy as String] = config.host
            proxyDict[kCFNetworkProxiesSOCKSPort as String] = config.port
        }
        
        // Add authentication if provided
        if let username = config.username, let password = config.password {
            // For HTTP proxies, authentication is handled via headers
            // For SOCKS5, it's handled by the proxy protocol
            sessionConfig.httpAdditionalHeaders = [
                "Proxy-Authorization": "Basic \(Data("\(username):\(password)".utf8).base64EncodedString())"
            ]
        }
        
        sessionConfig.connectionProxyDictionary = proxyDict
        
        // DECODO-specific optimizations
        sessionConfig.timeoutIntervalForRequest = 30.0
        sessionConfig.timeoutIntervalForResource = 60.0
        sessionConfig.httpMaximumConnectionsPerHost = 6
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Anti-detection headers
        sessionConfig.httpAdditionalHeaders = (sessionConfig.httpAdditionalHeaders ?? [:]).merging([
            "User-Agent": generateRandomUserAgent(),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
            "Accept-Encoding": "gzip, deflate, br",
            "DNT": "1",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1"
        ]) { _, new in new }
        
        return sessionConfig
    }
    
    private func generateRandomUserAgent() -> String {
        let userAgents = [
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ]
        return userAgents.randomElement() ?? userAgents[0]
    }
    
    // MARK: - Connection Testing
    
    private func testProxyConnection(_ config: ProxyConfiguration) async -> Bool {
        guard let session = proxySession else { return false }
        
        // Test with a simple HTTP request
        let testURLs = [
            "http://httpbin.org/ip",
            "https://api.ipify.org?format=json",
            "http://icanhazip.com"
        ]
        
        for testURL in testURLs {
            guard let url = URL(string: testURL) else { continue }
            
            do {
                let startTime = Date()
                let (data, response) = try await session.data(from: url)
                let latency = Date().timeIntervalSince(startTime)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   data.count > 0 {
                    
                    connectionLatency = latency
                    dataTransferred += Int64(data.count)
                    
                    // Verify we're going through proxy by checking IP
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("✅ Proxy test successful. Response: \(responseString.prefix(100))")
                    }
                    
                    return true
                }
            } catch {
                print("❌ Proxy test failed for \(testURL): \(error.localizedDescription)")
                continue
            }
        }
        
        return false
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status == .satisfied {
                    // Network is available, check proxy status
                    if self?.isProxyEnabled == true && self?.proxyStatus == .error {
                        // Try to reconnect proxy
                        if let config = self?.currentProxyConfig {
                            await self?.enableProxy(with: config)
                        }
                    }
                } else {
                    // Network is unavailable
                    self?.proxyStatus = .disconnected
                }
            }
        }
        
        networkMonitor?.start(queue: monitorQueue)
    }
    
    private func startLatencyMonitoring() {
        // Monitor latency every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updateLatency()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateLatency() async {
        guard isProxyEnabled,
              let config = currentProxyConfig,
              let session = proxySession else { return }
        
        let testURL = URL(string: "http://httpbin.org/get")!
        
        do {
            let startTime = Date()
            let (_, response) = try await session.data(from: testURL)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                connectionLatency = Date().timeIntervalSince(startTime)
            }
        } catch {
            // If latency test fails, proxy might be down
            if connectionLatency > 10.0 { // If latency is too high, try fallback
                await tryFallbackProxy()
            }
        }
    }
    
    // MARK: - Public Interface
    
    func getProxySession() -> URLSession {
        return proxySession ?? defaultSession
    }
    
    func isUsingProxy() -> Bool {
        return isProxyEnabled && proxyStatus == .connected
    }
    
    func getCurrentProxyInfo() -> String {
        guard let config = currentProxyConfig else {
            return "No proxy configured"
        }
        
        return "\(config.name) (\(config.host):\(config.port)) - Latency: \(Int(connectionLatency * 1000))ms"
    }
    
    func getProxyStatistics() -> ProxyStatistics {
        return ProxyStatistics(
            isEnabled: isProxyEnabled,
            status: proxyStatus,
            currentProxy: currentProxyConfig?.name ?? "None",
            latency: connectionLatency,
            dataTransferred: dataTransferred,
            uptime: proxyStatus == .connected ? Date().timeIntervalSince(Date()) : 0
        )
    }
    
    // MARK: - WebView Integration
    
    func getWebViewProxyConfiguration() -> [String: Any]? {
        guard isProxyEnabled,
              let config = currentProxyConfig else {
            return nil
        }
        
        var proxyDict: [String: Any] = [:]
        
        switch config.type {
        case .http:
            proxyDict["HTTPEnable"] = true
            proxyDict["HTTPProxy"] = config.host
            proxyDict["HTTPPort"] = config.port
            proxyDict["HTTPSEnable"] = true
            proxyDict["HTTPSProxy"] = config.host
            proxyDict["HTTPSPort"] = config.port
            
        case .socks5:
            proxyDict["SOCKSEnable"] = true
            proxyDict["SOCKSProxy"] = config.host
            proxyDict["SOCKSPort"] = config.port
        }
        
        return proxyDict
    }
}

// MARK: - Data Models

struct ProxyConfiguration: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: ProxyType
    let host: String
    let port: Int
    let username: String?
    let password: String?
    let isDefault: Bool
    let capabilities: [ProxyCapability]
    
    static func == (lhs: ProxyConfiguration, rhs: ProxyConfiguration) -> Bool {
        return lhs.id == rhs.id
    }
}

enum ProxyType: String, Codable, CaseIterable {
    case http = "http"
    case socks5 = "socks5"
    
    var displayName: String {
        switch self {
        case .http: return "HTTP/HTTPS"
        case .socks5: return "SOCKS5"
        }
    }
}

enum ProxyCapability: String, Codable, CaseIterable {
    case webUnblocking = "web_unblocking"
    case geoBypass = "geo_bypass"
    case antiDetection = "anti_detection"
    case fullTunneling = "full_tunneling"
    
    var displayName: String {
        switch self {
        case .webUnblocking: return "Web Unblocking"
        case .geoBypass: return "Geo Bypass"
        case .antiDetection: return "Anti-Detection"
        case .fullTunneling: return "Full Tunneling"
        }
    }
}

enum ProxyStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }
    
    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "orange"
        case .connected: return "green"
        case .error: return "red"
        }
    }
}

struct ProxyStatistics {
    let isEnabled: Bool
    let status: ProxyStatus
    let currentProxy: String
    let latency: TimeInterval
    let dataTransferred: Int64
    let uptime: TimeInterval
    
    var formattedLatency: String {
        return "\(Int(latency * 1000))ms"
    }
    
    var formattedDataTransferred: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: dataTransferred)
    }
    
    var formattedUptime: String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

enum ProxyError: Error, LocalizedError {
    case configurationInvalid(String)
    case connectionFailed(String)
    case authenticationFailed
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .configurationInvalid(let message):
            return "Invalid proxy configuration: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationFailed:
            return "Proxy authentication failed"
        case .networkUnavailable:
            return "Network is unavailable"
        }
    }
}
