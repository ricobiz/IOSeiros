
//
//  DECODOConfiguration.swift
//  EirosAgent
//
//  Enhanced DECODO Integration with Full Automation Support
//  Created: 2025-09-22
//

import Foundation
import Network

// MARK: - DECODO Configuration Manager

public class DECODOConfiguration: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = DECODOConfiguration()
    
    // MARK: - Real DECODO Endpoints
    public static let siteUnblockerEndpoint = "unblock.decodo.com"
    public static let siteUnblockerPort = 60000
    public static let webScrapingAPIEndpoint = "https://scraper-api.decodo.com/v2/scrape"
    
    // MARK: - Published Properties
    @Published public var isConfigured = false
    @Published public var connectionStatus: ConnectionStatus = .disconnected
    @Published public var lastTestResult: TestResult?
    
    // MARK: - Private Properties
    private var credentials: DECODOCredentials?
    private let keychain = KeychainManager()
    private let networkMonitor = NWPathMonitor()
    
    // MARK: - Initialization
    private init() {
        loadCredentials()
        setupNetworkMonitoring()
    }
    
    // MARK: - Credential Management
    
    public func setCredentials(username: String, password: String, apiKey: String? = nil) {
        let newCredentials = DECODOCredentials(username: username, password: password, apiKey: apiKey)
        self.credentials = newCredentials
        
        // Save to keychain
        keychain.save(key: "decodo_username", value: username)
        keychain.save(key: "decodo_password", value: password)
        if let apiKey = apiKey {
            keychain.save(key: "decodo_api_key", value: apiKey)
        } else {
            keychain.delete(key: "decodo_api_key")
        }
        
        DispatchQueue.main.async {
            self.isConfigured = self.hasValidCredentials()
        }
    }
    
    public func loadCredentials() {
        guard let username = keychain.load(key: "decodo_username"),
              let password = keychain.load(key: "decodo_password") else {
            return
        }
        
        let apiKey = keychain.load(key: "decodo_api_key")
        self.credentials = DECODOCredentials(username: username, password: password, apiKey: apiKey)
        DispatchQueue.main.async {
            self.isConfigured = self.hasValidCredentials()
        }
    }
    
    public func clearCredentials() {
        credentials = nil
        keychain.delete(key: "decodo_username")
        keychain.delete(key: "decodo_password")
        keychain.delete(key: "decodo_api_key")
        
        DispatchQueue.main.async {
            self.isConfigured = false
            self.connectionStatus = .disconnected
        }
    }
    
    public func hasValidCredentials() -> Bool {
        guard let creds = credentials else { return false }
        return !creds.username.isEmpty && !creds.password.isEmpty
    }
    
    // MARK: - Site Unblocker Configuration
    
    public func getSiteUnblockerConfiguration() -> SiteUnblockerConfig? {
        guard let creds = credentials else { return nil }
        
        return SiteUnblockerConfig(
            endpoint: Self.siteUnblockerEndpoint,
            port: Self.siteUnblockerPort,
            username: creds.username,
            password: creds.password,
            capabilities: [
                .javascriptRendering,
                .screenshotCapture,
                .geoTargeting,
                .sessionManagement,
                .customHeaders,
                .postRequests,
                .captchaBypass
            ]
        )
    }
    
    // MARK: - Web Scraping API Configuration
    
    public func getWebScrapingAPIConfiguration() -> WebScrapingAPIConfig? {
        guard let creds = credentials else { return nil }
        
        return WebScrapingAPIConfig(
            endpoint: Self.webScrapingAPIEndpoint,
            username: creds.username,
            password: creds.password,
            capabilities: [
                .javascriptRendering,
                .screenshotCapture,
                .structuredParsing,
                .targetTemplates,
                .asyncRequests,
                .markdownOutput
            ]
        )
    }
    
    // MARK: - Header Generation
    
    public static func createSiteUnblockerHeaders(
        headlessMode: HeadlessMode? = nil,
        geoLocation: String? = nil,
        sessionId: String? = nil,
        customHeaders: [String: String]? = nil,
        statusCodes: [Int]? = nil,
        apiKey: String? = nil
    ) -> [String: String] {
        var headers: [String: String] = [:]
        
        // API Key for additional functions (statistics, management)
        if let key = apiKey ?? shared.credentials?.apiKey {
            headers["X-SU-API-Key"] = key
        }
        
        // JavaScript rendering / Screenshot capture
        if let mode = headlessMode {
            headers["X-SU-Headless"] = mode.rawValue
        }
        
        // Geo-targeting
        if let geo = geoLocation {
            headers["X-SU-Geo"] = geo
        }
        
        // Session management
        if let session = sessionId {
            headers["X-SU-Session-Id"] = session
        }
        
        // Custom status codes
        if let codes = statusCodes {
            headers["X-SU-Status-Code"] = codes.map(String.init).joined(separator: ", ")
        }
        
        // Custom headers with X-SU-Custom- prefix
        if let custom = customHeaders {
            for (key, value) in custom {
                headers["X-SU-Custom-\(key)"] = value
            }
        }
        
        // Default headers for anti-detection
        headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
        headers["Accept-Language"] = "en-US,en;q=0.5"
        headers["Accept-Encoding"] = "gzip, deflate, br"
        headers["DNT"] = "1"
        headers["Connection"] = "keep-alive"
        headers["Upgrade-Insecure-Requests"] = "1"
        
        return headers
    }
    
    public static func createWebScrapingAPIPayload(
        url: String,
        target: String? = nil,
        headlessMode: HeadlessMode? = nil,
        geoLocation: String? = nil,
        locale: String? = nil,
        deviceType: DeviceType = .desktop,
        enableParsing: Bool = false,
        markdownOutput: Bool = false,
        sessionId: String? = nil,
        customHeaders: [String: String]? = nil,
        httpMethod: HTTPMethod = .GET,
        payload: Data? = nil,
        apiKey: String? = nil
    ) -> [String: Any] {
        var requestPayload: [String: Any] = [
            "url": url,
            "device_type": deviceType.rawValue,
            "http_method": httpMethod.rawValue
        ]
        
        // API Key for additional functions
        if let key = apiKey ?? shared.credentials?.apiKey {
            requestPayload["api_key"] = key
        }
        
        if let target = target {
            requestPayload["target"] = target
        }
        
        if let mode = headlessMode {
            requestPayload["headless"] = mode.rawValue
        }
        
        if let geo = geoLocation {
            requestPayload["geo"] = geo
        }
        
        if let locale = locale {
            requestPayload["locale"] = locale
        }
        
        if enableParsing {
            requestPayload["parse"] = true
        }
        
        if markdownOutput {
            requestPayload["markdown"] = true
        }
        
        if let session = sessionId {
            requestPayload["session_id"] = session
        }
        
        if let headers = customHeaders {
            requestPayload["headers"] = headers
        }
        
        if let data = payload {
            requestPayload["payload"] = data.base64EncodedString()
        }
        
        return requestPayload
    }
    
    // MARK: - Connection Testing
    
    public func testSiteUnblockerConnection() async -> TestResult {
        guard let config = getSiteUnblockerConfiguration() else {
            let result = TestResult(success: false, error: "No valid credentials", latency: 0, responseData: nil)
            DispatchQueue.main.async {
                self.lastTestResult = result
                self.connectionStatus = .error
            }
            return result
        }
        
        let startTime = Date()
        
        do {
            let result = await performSiteUnblockerTest(config: config)
            let latency = Date().timeIntervalSince(startTime)
            
            let testResult = TestResult(
                success: result.success,
                error: result.error,
                latency: latency,
                responseData: result.data
            )
            
            DispatchQueue.main.async {
                self.lastTestResult = testResult
                self.connectionStatus = result.success ? .connected : .error
            }
            
            return testResult
        } catch {
            let testResult = TestResult(
                success: false,
                error: error.localizedDescription,
                latency: Date().timeIntervalSince(startTime),
                responseData: nil
            )
            
            DispatchQueue.main.async {
                self.lastTestResult = testResult
                self.connectionStatus = .error
            }
            
            return testResult
        }
    }
    
    public func testWebScrapingAPI() async -> TestResult {
        guard let config = getWebScrapingAPIConfiguration() else {
            let result = TestResult(success: false, error: "No valid credentials", latency: 0, responseData: nil)
            DispatchQueue.main.async {
                self.lastTestResult = result
            }
            return result
        }
        
        let startTime = Date()
        
        do {
            let result = await performWebScrapingAPITest(config: config)
            let latency = Date().timeIntervalSince(startTime)
            
            let testResult = TestResult(
                success: result.success,
                error: result.error,
                latency: latency,
                responseData: result.data
            )
            
            DispatchQueue.main.async {
                self.lastTestResult = testResult
            }
            
            return testResult
        } catch {
            let testResult = TestResult(
                success: false,
                error: error.localizedDescription,
                latency: Date().timeIntervalSince(startTime),
                responseData: nil
            )
            
            DispatchQueue.main.async {
                self.lastTestResult = testResult
            }
            
            return testResult
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self?.connectionStatus == .disconnected {
                        self?.connectionStatus = .connecting
                    }
                } else {
                    self?.connectionStatus = .disconnected
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func performSiteUnblockerTest(config: SiteUnblockerConfig) async -> (success: Bool, error: String?, data: Data?) {
        // Test with a simple request to ip.decodo.com
        let testURL = "https://ip.decodo.com/"
        
        var request = URLRequest(url: URL(string: testURL)!)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
        
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
        
        let session = URLSession(configuration: sessionConfig)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (success: true, error: nil, data: data)
                } else {
                    return (success: false, error: "HTTP \(httpResponse.statusCode)", data: data)
                }
            }
            
            return (success: true, error: nil, data: data)
        } catch {
            return (success: false, error: error.localizedDescription, data: nil)
        }
    }
    
    private func performWebScrapingAPITest(config: WebScrapingAPIConfig) async -> (success: Bool, error: String?, data: Data?) {
        guard let url = URL(string: config.endpoint) else {
            return (success: false, error: "Invalid endpoint URL", data: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        
        // Add authentication
        let credentials = "\(config.username):\(config.password)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Create test payload
        let payload = Self.createWebScrapingAPIPayload(
            url: "https://ip.decodo.com/",
            target: "universal",
            headlessMode: .html
        )
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return (success: false, error: "Failed to serialize payload", data: nil)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (success: true, error: nil, data: data)
                } else {
                    return (success: false, error: "HTTP \(httpResponse.statusCode)", data: data)
                }
            }
            
            return (success: true, error: nil, data: data)
        } catch {
            return (success: false, error: error.localizedDescription, data: nil)
        }
    }
}

// MARK: - Supporting Types

public struct DECODOCredentials {
    let username: String
    let password: String
    let apiKey: String?
    
    init(username: String, password: String, apiKey: String? = nil) {
        self.username = username
        self.password = password
        self.apiKey = apiKey
    }
}

public struct SiteUnblockerConfig {
    let endpoint: String
    let port: Int
    let username: String
    let password: String
    let capabilities: Set<DECODOCapability>
}

public struct WebScrapingAPIConfig {
    let endpoint: String
    let username: String
    let password: String
    let capabilities: Set<DECODOCapability>
}

public enum HeadlessMode: String, CaseIterable {
    case html = "html"
    case png = "png"
    
    var description: String {
        switch self {
        case .html:
            return "Rendered HTML"
        case .png:
            return "Screenshot (PNG)"
        }
    }
}

public enum DeviceType: String, CaseIterable {
    case desktop = "desktop"
    case mobileAndroid = "mobile_android"
    case mobileIOS = "mobile_ios"
    
    var description: String {
        switch self {
        case .desktop:
            return "Desktop"
        case .mobileAndroid:
            return "Mobile Android"
        case .mobileIOS:
            return "Mobile iOS"
        }
    }
}

public enum HTTPMethod: String, CaseIterable {
    case GET = "GET"
    case POST = "POST"
}

public enum DECODOCapability: String, CaseIterable {
    case javascriptRendering = "javascript_rendering"
    case screenshotCapture = "screenshot_capture"
    case geoTargeting = "geo_targeting"
    case sessionManagement = "session_management"
    case customHeaders = "custom_headers"
    case postRequests = "post_requests"
    case captchaBypass = "captcha_bypass"
    case structuredParsing = "structured_parsing"
    case targetTemplates = "target_templates"
    case asyncRequests = "async_requests"
    case markdownOutput = "markdown_output"
}

public enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error
    
    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .error:
            return "Error"
        }
    }
    
    var color: String {
        switch self {
        case .disconnected:
            return "gray"
        case .connecting:
            return "orange"
        case .connected:
            return "green"
        case .error:
            return "red"
        }
    }
}

public struct TestResult {
    let success: Bool
    let error: String?
    let latency: TimeInterval
    let responseData: Data?
    
    var formattedLatency: String {
        return String(format: "%.0f ms", latency * 1000)
    }
}

// MARK: - Keychain Manager

private class KeychainManager {
    func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
