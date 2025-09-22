//
//  DECODORealAPITests.swift
//  EirosAgentTests
//
//  Created for DECODO Real API Integration Testing - 2025-09-22
//

import XCTest
@testable import EirosAgent

class DECODORealAPITests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear any existing credentials before each test
        DECODOConfiguration.clearCredentials()
    }
    
    override func tearDown() {
        // Clean up after each test
        DECODOConfiguration.clearCredentials()
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDECODOEndpointConfiguration() {
        XCTAssertEqual(DECODOConfiguration.realEndpoint, "unblock.decodo.com")
        XCTAssertEqual(DECODOConfiguration.realPort, 60000)
    }
    
    func testCredentialManagement() {
        // Test initial state
        XCTAssertFalse(DECODOConfiguration.hasValidCredentials())
        
        // Test setting credentials
        DECODOConfiguration.setCredentials(username: "testuser", password: "testpass")
        XCTAssertTrue(DECODOConfiguration.hasValidCredentials())
        XCTAssertEqual(DECODOConfiguration.username, "testuser")
        XCTAssertEqual(DECODOConfiguration.password, "testpass")
        
        // Test clearing credentials
        DECODOConfiguration.clearCredentials()
        XCTAssertFalse(DECODOConfiguration.hasValidCredentials())
        XCTAssertNil(DECODOConfiguration.username)
        XCTAssertNil(DECODOConfiguration.password)
    }
    
    func testCredentialPersistence() {
        // Set credentials
        DECODOConfiguration.setCredentials(username: "persisttest", password: "persistpass")
        
        // Simulate app restart by loading credentials
        DECODOConfiguration.loadCredentials()
        
        XCTAssertTrue(DECODOConfiguration.hasValidCredentials())
        XCTAssertEqual(DECODOConfiguration.username, "persisttest")
        XCTAssertEqual(DECODOConfiguration.password, "persistpass")
    }
    
    func testProxyConfigurationGeneration() {
        // Test without credentials
        XCTAssertNil(DECODOConfiguration.getDefaultProxyConfiguration())
        
        // Test with credentials
        DECODOConfiguration.setCredentials(username: "testuser", password: "testpass")
        
        let config = DECODOConfiguration.getDefaultProxyConfiguration()
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.host, "unblock.decodo.com")
        XCTAssertEqual(config?.port, 60000)
        XCTAssertEqual(config?.username, "testuser")
        XCTAssertEqual(config?.password, "testpass")
        XCTAssertEqual(config?.type, .http)
        XCTAssertTrue(config?.capabilities.contains(.webUnblocking) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.javascriptRendering) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.captchaBypass) ?? false)
    }
    
    func testAPIHeadersGeneration() {
        let headers = DECODOConfiguration.createAPIHeaders(
            geoLocation: "US",
            locale: "en-US",
            sessionId: "test123",
            enableJS: true
        )
        
        XCTAssertEqual(headers["X-SU-Geo"], "US")
        XCTAssertEqual(headers["X-SU-Locale"], "en-US")
        XCTAssertEqual(headers["X-SU-Session-Id"], "test123")
        XCTAssertEqual(headers["X-SU-Headless"], "html")
        
        // Test default headers are included
        XCTAssertNotNil(headers["Accept"])
        XCTAssertNotNil(headers["User-Agent"])
    }
    
    // MARK: - ProxyManager Integration Tests
    
    func testProxyManagerConfigurationLoading() {
        let proxyManager = ProxyManager.shared
        
        // Test without credentials
        proxyManager.loadDECODOConfigurations()
        XCTAssertTrue(proxyManager.availableProxies.isEmpty)
        
        // Test with credentials
        DECODOConfiguration.setCredentials(username: "testuser", password: "testpass")
        proxyManager.loadDECODOConfigurations()
        XCTAssertFalse(proxyManager.availableProxies.isEmpty)
        
        let decodoProxy = proxyManager.availableProxies.first { $0.id == "decodo-real" }
        XCTAssertNotNil(decodoProxy)
        XCTAssertEqual(decodoProxy?.name, "DECODO Site Unblocker (Real API)")
    }
    
    // MARK: - Real API Connection Tests (Requires Valid Credentials)
    
    func testRealAPIConnection() async {
        // Skip this test if no real credentials are provided
        guard let testUsername = ProcessInfo.processEnvironment["DECODO_TEST_USERNAME"],
              let testPassword = ProcessInfo.processEnvironment["DECODO_TEST_PASSWORD"],
              !testUsername.isEmpty && !testPassword.isEmpty else {
            print("⚠️ Skipping real API test - no credentials provided")
            print("💡 Set DECODO_TEST_USERNAME and DECODO_TEST_PASSWORD environment variables to run this test")
            return
        }
        
        // Set test credentials
        DECODOConfiguration.setCredentials(username: testUsername, password: testPassword)
        
        guard let config = DECODOConfiguration.getDefaultProxyConfiguration() else {
            XCTFail("Failed to create proxy configuration")
            return
        }
        
        // Test connection
        let result = await DECODOConfiguration.testProxyConnection(config)
        
        XCTAssertTrue(result.success, "Real API connection failed: \(result.error ?? "Unknown error")")
        XCTAssertGreaterThan(result.latency, 0)
        XCTAssertNotNil(result.responseData)
        
        print("✅ Real API test successful - Latency: \(result.formattedLatency)")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCredentialsHandling() {
        // Test empty credentials
        DECODOConfiguration.setCredentials(username: "", password: "")
        XCTAssertFalse(DECODOConfiguration.hasValidCredentials())
        
        DECODOConfiguration.setCredentials(username: "test", password: "")
        XCTAssertFalse(DECODOConfiguration.hasValidCredentials())
        
        DECODOConfiguration.setCredentials(username: "", password: "test")
        XCTAssertFalse(DECODOConfiguration.hasValidCredentials())
    }
    
    func testConfigurationWithoutCredentials() {
        let configs = DECODOConfiguration.getAllProxyConfigurations()
        XCTAssertTrue(configs.isEmpty, "Should return empty array when no credentials are set")
    }
    
    // MARK: - Performance Tests
    
    func testConfigurationPerformance() {
        DECODOConfiguration.setCredentials(username: "testuser", password: "testpass")
        
        measure {
            for _ in 0..<100 {
                _ = DECODOConfiguration.getAllProxyConfigurations()
            }
        }
    }
    
    func testHeaderGenerationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = DECODOConfiguration.createAPIHeaders(
                    geoLocation: "US",
                    locale: "en-US",
                    sessionId: "test123",
                    enableJS: true
                )
            }
        }
    }
}

// MARK: - Mock Tests for UI Components

class DECODOUITests: XCTestCase {
    
    func testDECODOSettingsViewInitialization() {
        // Test that the settings view can be initialized
        let settingsView = DECODOSettingsView()
        XCTAssertNotNil(settingsView)
    }
    
    func testCredentialValidationInUI() {
        // Test credential validation logic used in UI
        XCTAssertFalse(DECODOConfiguration.hasValidCredentials())
        
        DECODOConfiguration.setCredentials(username: "testuser", password: "testpass")
        XCTAssertTrue(DECODOConfiguration.hasValidCredentials())
    }
}
