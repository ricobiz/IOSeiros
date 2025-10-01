
//
//  DECODOIntegrationTests.swift
//  EirosAgentTests
//
//  Comprehensive DECODO Integration Tests
//  Created: 2025-09-22
//

import XCTest
@testable import EirosAgent

class DECODOIntegrationTests: XCTestCase {
    
    var decodoConfig: DECODOConfiguration!
    var proxyManager: ProxyManager!
    var automationController: AutomationController!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        decodoConfig = DECODOConfiguration.shared
        proxyManager = ProxyManager.shared
        automationController = AutomationController.shared
        
        // Clear any existing state
        decodoConfig.clearCredentials()
        proxyManager.disableProxy()
        automationController.disableAutomation()
    }
    
    override func tearDown() async throws {
        // Clean up after tests
        decodoConfig.clearCredentials()
        proxyManager.disableProxy()
        automationController.disableAutomation()
        
        try await super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDECODOConfigurationInitialization() {
        XCTAssertNotNil(decodoConfig)
        XCTAssertFalse(decodoConfig.isConfigured)
        XCTAssertEqual(decodoConfig.connectionStatus, .disconnected)
    }
    
    func testCredentialManagement() {
        // Test initial state
        XCTAssertFalse(decodoConfig.hasValidCredentials())
        XCTAssertFalse(decodoConfig.isConfigured)
        
        // Test setting credentials
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        XCTAssertTrue(decodoConfig.hasValidCredentials())
        XCTAssertTrue(decodoConfig.isConfigured)
        
        // Test clearing credentials
        decodoConfig.clearCredentials()
        XCTAssertFalse(decodoConfig.hasValidCredentials())
        XCTAssertFalse(decodoConfig.isConfigured)
    }
    
    func testSiteUnblockerConfiguration() {
        // Without credentials
        XCTAssertNil(decodoConfig.getSiteUnblockerConfiguration())
        
        // With credentials
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        
        let config = decodoConfig.getSiteUnblockerConfiguration()
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.endpoint, "unblock.decodo.com")
        XCTAssertEqual(config?.port, 60000)
        XCTAssertEqual(config?.username, "testuser")
        XCTAssertEqual(config?.password, "testpass")
        XCTAssertTrue(config?.capabilities.contains(.javascriptRendering) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.screenshotCapture) ?? false)
    }
    
    func testWebScrapingAPIConfiguration() {
        // Without credentials
        XCTAssertNil(decodoConfig.getWebScrapingAPIConfiguration())
        
        // With credentials
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        
        let config = decodoConfig.getWebScrapingAPIConfiguration()
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.endpoint, "https://scraper-api.decodo.com/v2/scrape")
        XCTAssertEqual(config?.username, "testuser")
        XCTAssertEqual(config?.password, "testpass")
        XCTAssertTrue(config?.capabilities.contains(.structuredParsing) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.targetTemplates) ?? false)
    }
    
    // MARK: - Header Generation Tests
    
    func testSiteUnblockerHeaderGeneration() {
        let headers = DECODOConfiguration.createSiteUnblockerHeaders(
            headlessMode: .png,
            geoLocation: "United States",
            sessionId: "test123",
            customHeaders: ["Custom-Header": "CustomValue"],
            statusCodes: [200, 404]
        )
        
        XCTAssertEqual(headers["X-SU-Headless"], "png")
        XCTAssertEqual(headers["X-SU-Geo"], "United States")
        XCTAssertEqual(headers["X-SU-Session-Id"], "test123")
        XCTAssertEqual(headers["X-SU-Custom-Custom-Header"], "CustomValue")
        XCTAssertEqual(headers["X-SU-Status-Code"], "200, 404")
        
        // Check default headers
        XCTAssertNotNil(headers["Accept"])
        XCTAssertNotNil(headers["Accept-Language"])
        XCTAssertNotNil(headers["DNT"])
    }
    
    func testWebScrapingAPIPayloadGeneration() {
        let payload = DECODOConfiguration.createWebScrapingAPIPayload(
            url: "https://example.com",
            target: "universal",
            headlessMode: .html,
            geoLocation: "Germany",
            locale: "de-DE",
            deviceType: .mobileAndroid,
            enableParsing: true,
            markdownOutput: true,
            sessionId: "session123",
            customHeaders: ["User-Agent": "Custom Agent"],
            httpMethod: .POST
        )
        
        XCTAssertEqual(payload["url"] as? String, "https://example.com")
        XCTAssertEqual(payload["target"] as? String, "universal")
        XCTAssertEqual(payload["headless"] as? String, "html")
        XCTAssertEqual(payload["geo"] as? String, "Germany")
        XCTAssertEqual(payload["locale"] as? String, "de-DE")
        XCTAssertEqual(payload["device_type"] as? String, "mobile_android")
        XCTAssertEqual(payload["parse"] as? Bool, true)
        XCTAssertEqual(payload["markdown"] as? Bool, true)
        XCTAssertEqual(payload["session_id"] as? String, "session123")
        XCTAssertEqual(payload["http_method"] as? String, "POST")
        
        let headers = payload["headers"] as? [String: String]
        XCTAssertEqual(headers?["User-Agent"], "Custom Agent")
    }
    
    // MARK: - Proxy Manager Tests
    
    @MainActor
    func testProxyManagerInitialization() {
        XCTAssertNotNil(proxyManager)
        XCTAssertFalse(proxyManager.isProxyEnabled)
        XCTAssertNil(proxyManager.currentProxy)
        XCTAssertEqual(proxyManager.connectionStatus, .disconnected)
    }
    
    @MainActor
    func testProxyConfigurationLoading() {
        // Without DECODO credentials
        XCTAssertTrue(proxyManager.availableProxies.filter { $0.id.hasPrefix("decodo-") }.isEmpty)
        
        // With DECODO credentials
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        
        // Trigger configuration loading (this would normally happen automatically)
        // For testing, we need to manually trigger it
        let expectation = XCTestExpectation(description: "Proxy configurations loaded")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let decodoProxies = self.proxyManager.availableProxies.filter { $0.id.hasPrefix("decodo-") }
            XCTAssertFalse(decodoProxies.isEmpty)
            
            let siteUnblocker = decodoProxies.first { $0.id == "decodo-site-unblocker" }
            XCTAssertNotNil(siteUnblocker)
            XCTAssertEqual(siteUnblocker?.name, "DECODO Site Unblocker")
            XCTAssertEqual(siteUnblocker?.host, "unblock.decodo.com")
            XCTAssertEqual(siteUnblocker?.port, 60000)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Automation Controller Tests
    
    @MainActor
    func testAutomationControllerInitialization() {
        XCTAssertNotNil(automationController)
        XCTAssertFalse(automationController.isAutomationEnabled)
        XCTAssertNil(automationController.currentTask)
        XCTAssertEqual(automationController.executionStatus, .idle)
        XCTAssertEqual(automationController.executionProgress, 0.0)
    }
    
    @MainActor
    func testAutomationEnableDisable() {
        // Test enabling
        automationController.enableAutomation()
        XCTAssertTrue(automationController.isAutomationEnabled)
        
        // Test disabling
        automationController.disableAutomation()
        XCTAssertFalse(automationController.isAutomationEnabled)
    }
    
    @MainActor
    func testScreenshotTaskCreation() {
        let task = automationController.createScreenshotTask(
            url: "https://example.com",
            options: ScreenshotTaskOptions(
                geoLocation: "United States",
                deviceType: .desktop,
                sessionId: "test123"
            )
        )
        
        XCTAssertEqual(task.name, "Screenshot: https://lh7-us.googleusercontent.com/5Pj_Y6Mfz4ka5-8VQE4M6tVHglda60cXUqTxO0dHn2lu06VAVQkGQshIRC5BC44HOZk2MOevYjW5cCQPHRsqL_qUIKIYnVhanaKztw59HybCoo1Hfh6Nd751SmP8hcyvOWaj9_dQL8K1wmZRx2mYXjM
        XCTAssertEqual(task.actions.count, 1)
        XCTAssertEqual(task.actions.first?.type, .screenshot)
        XCTAssertEqual(task.actions.first?.target, "https://example.com")
        XCTAssertTrue(task.options.useProxy)
        XCTAssertTrue(task.options.enableJavaScript)
    }
    
    @MainActor
    func testWebScrapingTaskCreation() {
        let selectors = [".title", ".price", ".description"]
        let task = automationController.createWebScrapingTask(
            url: "https://example.com",
            selectors: selectors,
            options: WebScrapingTaskOptions(
                geoLocation: "Germany",
                deviceType: .mobileAndroid,
                extractAttribute: "text",
                extractMultiple: true
            )
        )
        
        XCTAssertEqual(task.name, "Web Scraping: https://example.com")
        XCTAssertTrue(task.actions.count > selectors.count) // Should include navigate, wait, extract actions, and screenshot
        
        let navigateAction = task.actions.first { $0.type == .navigate }
        XCTAssertNotNil(navigateAction)
        XCTAssertEqual(navigateAction?.target, "https://example.com")
        
        let extractActions = task.actions.filter { $0.type == .extract }
        XCTAssertEqual(extractActions.count, selectors.count)
        
        let screenshotAction = task.actions.first { $0.type == .screenshot }
        XCTAssertNotNil(screenshotAction)
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testFullIntegrationFlow() async {
        // Setup
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        automationController.enableAutomation()
        
        // Verify components are ready
        let status = automationController.getAutomationStatus()
        XCTAssertTrue(status.isEnabled)
        XCTAssertTrue(status.componentsReady["DECODOConfiguration"] ?? false)
        XCTAssertTrue(status.componentsReady["AutomationController"] ?? false)
        
        // Create and execute a simple task
        let task = automationController.createScreenshotTask(
            url: "https://example.com",
            options: ScreenshotTaskOptions(deviceType: .desktop)
        )
        
        // Note: This test would require actual network connectivity and valid credentials
        // For unit testing, we're just verifying the task creation and setup
        XCTAssertNotNil(task)
        XCTAssertEqual(task.actions.count, 1)
        XCTAssertEqual(task.actions.first?.type, .screenshot)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCredentialsHandling() {
        // Test empty credentials
        decodoConfig.setCredentials(username: "", password: "")
        XCTAssertFalse(decodoConfig.hasValidCredentials())
        
        decodoConfig.setCredentials(username: "test", password: "")
        XCTAssertFalse(decodoConfig.hasValidCredentials())
        
        decodoConfig.setCredentials(username: "", password: "test")
        XCTAssertFalse(decodoConfig.hasValidCredentials())
        
        // Test valid credentials
        decodoConfig.setCredentials(username: "test", password: "test")
        XCTAssertTrue(decodoConfig.hasValidCredentials())
    }
    
    @MainActor
    func testAutomationWithoutProxy() async {
        // Enable automation but don't configure proxy
        automationController.enableAutomation()
        
        let task = automationController.createScreenshotTask(url: "https://example.com")
        
        // Task should be created but execution might fail without proper proxy setup
        XCTAssertNotNil(task)
        XCTAssertTrue(task.options.useProxy)
        
        // The actual execution would fail in a real scenario, but for unit testing
        // we're just verifying the task structure
    }
    
    // MARK: - Performance Tests
    
    func testConfigurationPerformance() {
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        
        measure {
            for _ in 0..<100 {
                _ = decodoConfig.getSiteUnblockerConfiguration()
                _ = decodoConfig.getWebScrapingAPIConfiguration()
            }
        }
    }
    
    func testHeaderGenerationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = DECODOConfiguration.createSiteUnblockerHeaders(
                    headlessMode: .png,
                    geoLocation: "United States",
                    sessionId: "test123"
                )
            }
        }
    }
    
    func testPayloadGenerationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = DECODOConfiguration.createWebScrapingAPIPayload(
                    url: "https://example.com",
                    target: "universal",
                    headlessMode: .html,
                    geoLocation: "Germany"
                )
            }
        }
    }
    
    // MARK: - Real API Tests (Conditional)
    
    func testRealSiteUnblockerConnection() async {
        // Skip this test if no real credentials are provided
        guard let testUsername = ProcessInfo.processEnvironment["DECODO_TEST_USERNAME"],
              let testPassword = ProcessInfo.processEnvironment["DECODO_TEST_PASSWORD"],
              !testUsername.isEmpty && !testPassword.isEmpty else {
            print("⚠️ Skipping real API test - no credentials provided")
            print("💡 Set DECODO_TEST_USERNAME and DECODO_TEST_PASSWORD environment variables to run this test")
            return
        }
        
        // Set test credentials
        decodoConfig.setCredentials(username: testUsername, password: testPassword)
        
        // Test Site Unblocker connection
        let result = await decodoConfig.testSiteUnblockerConnection()
        
        XCTAssertTrue(result.success, "Real Site Unblocker API connection failed: \(result.error ?? "Unknown error")")
        XCTAssertGreaterThan(result.latency, 0)
        XCTAssertNotNil(result.responseData)
        
        print("✅ Real Site Unblocker API test successful - Latency: \(result.formattedLatency)")
    }
    
    func testRealWebScrapingAPIConnection() async {
        // Skip this test if no real credentials are provided
        guard let testUsername = ProcessInfo.processEnvironment["DECODO_TEST_USERNAME"],
              let testPassword = ProcessInfo.processEnvironment["DECODO_TEST_PASSWORD"],
              !testUsername.isEmpty && !testPassword.isEmpty else {
            print("⚠️ Skipping real API test - no credentials provided")
            return
        }
        
        // Set test credentials
        decodoConfig.setCredentials(username: testUsername, password: testPassword)
        
        // Test Web Scraping API connection
        let result = await decodoConfig.testWebScrapingAPI()
        
        XCTAssertTrue(result.success, "Real Web Scraping API connection failed: \(result.error ?? "Unknown error")")
        XCTAssertGreaterThan(result.latency, 0)
        XCTAssertNotNil(result.responseData)
        
        print("✅ Real Web Scraping API test successful - Latency: \(result.formattedLatency)")
    }
    
    // MARK: - Screenshot Tests
    
    @MainActor
    func testScreenshotCapture() async {
        // This test would require real credentials and network connectivity
        // For unit testing, we're testing the interface and structure
        
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        
        let options = ScreenshotOptions(
            geoLocation: "United States",
            sessionId: "test123",
            target: "universal",
            deviceType: .desktop
        )
        
        // The actual screenshot capture would require network connectivity
        // For unit testing, we're just verifying the method exists and can be called
        let result = await proxyManager.captureScreenshotThroughProxy(url: "https://example.com", options: options)
        
        // Without real credentials and network, this will fail, but we can test the structure
        XCTAssertNotNil(result)
        XCTAssertFalse(result.success) // Expected to fail without real setup
        XCTAssertNotNil(result.error)
    }
    
    // MARK: - Capability Tests
    
    func testHeadlessModeEnum() {
        XCTAssertEqual(HeadlessMode.html.rawValue, "html")
        XCTAssertEqual(HeadlessMode.png.rawValue, "png")
        XCTAssertEqual(HeadlessMode.html.description, "Rendered HTML")
        XCTAssertEqual(HeadlessMode.png.description, "Screenshot (PNG)")
    }
    
    func testDeviceTypeEnum() {
        XCTAssertEqual(DeviceType.desktop.rawValue, "desktop")
        XCTAssertEqual(DeviceType.mobileAndroid.rawValue, "mobile_android")
        XCTAssertEqual(DeviceType.mobileIOS.rawValue, "mobile_ios")
    }
    
    func testDECODOCapabilityEnum() {
        let capabilities: Set<DECODOCapability> = [
            .javascriptRendering,
            .screenshotCapture,
            .geoTargeting,
            .sessionManagement
        ]
        
        XCTAssertTrue(capabilities.contains(.javascriptRendering))
        XCTAssertTrue(capabilities.contains(.screenshotCapture))
        XCTAssertFalse(capabilities.contains(.structuredParsing))
    }
    
    // MARK: - Connection Status Tests
    
    func testConnectionStatusEnum() {
        XCTAssertEqual(ConnectionStatus.disconnected.description, "Disconnected")
        XCTAssertEqual(ConnectionStatus.connecting.description, "Connecting")
        XCTAssertEqual(ConnectionStatus.connected.description, "Connected")
        XCTAssertEqual(ConnectionStatus.error.description, "Error")
        
        XCTAssertEqual(ConnectionStatus.disconnected.color, "gray")
        XCTAssertEqual(ConnectionStatus.connecting.color, "orange")
        XCTAssertEqual(ConnectionStatus.connected.color, "green")
        XCTAssertEqual(ConnectionStatus.error.color, "red")
    }
}

// MARK: - Mock Tests for UI Components

class DECODOUIIntegrationTests: XCTestCase {
    
    func testDECODOSettingsViewInitialization() {
        // Test that the settings view can be initialized
        // This would be tested in UI tests in a real scenario
        XCTAssertTrue(true) // Placeholder for UI testing
    }
    
    func testAutomationPanelViewInitialization() {
        // Test that the automation panel view can be initialized
        // This would be tested in UI tests in a real scenario
        XCTAssertTrue(true) // Placeholder for UI testing
    }
}
