//
//  DECODOHybridAuthTests.swift
//  EirosAgentTests
//
//  DECODO Hybrid Authentication Tests (Username:Password + API Key)
//  Created: 2025-09-22
//

import XCTest
@testable import EirosAgent

class DECODOHybridAuthTests: XCTestCase {
    
    private var decodoConfig: DECODOConfiguration!
    
    override func setUp() {
        super.setUp()
        decodoConfig = DECODOConfiguration.shared
        decodoConfig.clearCredentials()
    }
    
    override func tearDown() {
        decodoConfig.clearCredentials()
        super.tearDown()
    }
    
    // MARK: - Hybrid Credentials Tests
    
    func testHybridCredentialsStorage() {
        // Test setting credentials with API key
        decodoConfig.setCredentials(
            username: "test_user",
            password: "test_pass",
            apiKey: "test_api_key_123"
        )
        
        XCTAssertTrue(decodoConfig.hasValidCredentials())
        
        // Verify credentials are stored
        let credentials = decodoConfig.credentials
        XCTAssertNotNil(credentials)
        XCTAssertEqual(credentials?.username, "test_user")
        XCTAssertEqual(credentials?.password, "test_pass")
        XCTAssertEqual(credentials?.apiKey, "test_api_key_123")
    }
    
    func testCredentialsWithoutAPIKey() {
        // Test setting credentials without API key
        decodoConfig.setCredentials(
            username: "test_user",
            password: "test_pass"
        )
        
        XCTAssertTrue(decodoConfig.hasValidCredentials())
        
        let credentials = decodoConfig.credentials
        XCTAssertNotNil(credentials)
        XCTAssertEqual(credentials?.username, "test_user")
        XCTAssertEqual(credentials?.password, "test_pass")
        XCTAssertNil(credentials?.apiKey)
    }
    
    func testCredentialsWithEmptyAPIKey() {
        // Test setting credentials with empty API key
        decodoConfig.setCredentials(
            username: "test_user",
            password: "test_pass",
            apiKey: ""
        )
        
        let credentials = decodoConfig.credentials
        XCTAssertNotNil(credentials)
        XCTAssertNil(credentials?.apiKey) // Empty string should be stored as nil
    }
    
    // MARK: - Site Unblocker Headers Tests
    
    func testSiteUnblockerHeadersWithAPIKey() {
        // Set credentials with API key
        decodoConfig.setCredentials(
            username: "test_user",
            password: "test_pass",
            apiKey: "test_api_key_123"
        )
        
        let headers = DECODOConfiguration.createSiteUnblockerHeaders(
            headlessMode: .png,
            geoLocation: "US",
            sessionId: "session_123"
        )
        
        // Verify API key is included
        XCTAssertEqual(headers["X-SU-API-Key"], "test_api_key_123")
        XCTAssertEqual(headers["X-SU-Headless"], "png")
        XCTAssertEqual(headers["X-SU-Geo"], "US")
        XCTAssertEqual(headers["X-SU-Session-Id"], "session_123")
    }
    
    func testSiteUnblockerHeadersWithoutAPIKey() {
        // Set credentials without API key
        decodoConfig.setCredentials(
            username: "test_user",
            password: "test_pass"
        )
        
        let headers = DECODOConfiguration.createSiteUnblockerHeaders(
            headlessMode: .html
        )
        
        // Verify API key is not included
        XCTAssertNil(headers["X-SU-API-Key"])
        XCTAssertEqual(headers["X-SU-Headless"], "html")
    }
    
    func testSiteUnblockerHeadersWithExplicitAPIKey() {
        // Test with explicit API key parameter
        let headers = DECODOConfiguration.createSiteUnblockerHeaders(
            headlessMode: .png,
            apiKey: "explicit_api_key"
        )
        
        // Explicit API key should take precedence
        XCTAssertEqual(headers["X-SU-API-Key"], "explicit_api_key")
        XCTAssertEqual(headers["X-SU-Headless"], "png")
    }
    
    // MARK: - Web Scraping API Payload Tests
    
    func testWebScrapingAPIPayloadWithAPIKey() {
        // Set credentials with API key
        decodoConfig.setCredentials(
            username: "test_user",
            password: "test_pass",
            apiKey: "test_api_key_123"
        )
        
        let payload = DECODOConfiguration.createWebScrapingAPIPayload(
            url: "https://example.com",
            target: "universal",
            headlessMode: .html
        )
        
        // Verify API key is included in payload
        XCTAssertEqual(payload["api_key"] as? String, "test_api_key_123")
        XCTAssertEqual(payload["url"] as? String, "https://example.com")
        XCTAssertEqual(payload["target"] as? String, "universal")
        XCTAssertEqual(payload["headless"] as? String, "html")
    }
    
    func testWebScrapingAPIPayloadWithoutAPIKey() {
        // Set credentials without API key
        decodoConfig.setCredentials(
            username: "test_user",
            password: "test_pass"
        )
        
        let payload = DECODOConfiguration.createWebScrapingAPIPayload(
            url: "https://example.com"
        )
        
        // Verify API key is not included
        XCTAssertNil(payload["api_key"])
        XCTAssertEqual(payload["url"] as? String, "https://example.com")
    }
    
    func testWebScrapingAPIPayloadWithExplicitAPIKey() {
        // Test with explicit API key parameter
        let payload = DECODOConfiguration.createWebScrapingAPIPayload(
            url: "https://example.com",
            apiKey: "explicit_api_key"
        )
        
        // Explicit API key should take precedence
        XCTAssertEqual(payload["api_key"] as? String, "explicit_api_key")
    }
    
    // MARK: - Proxy Configuration Tests
    
    func testSiteUnblockerProxyConfiguration() {
        decodoConfig.setCredentials(
            username: "proxy_user",
            password: "proxy_pass",
            apiKey: "api_key_123"
        )
        
        let config = decodoConfig.getSiteUnblockerConfiguration()
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.endpoint, "unblock.decodo.com")
        XCTAssertEqual(config?.port, 60000)
        XCTAssertEqual(config?.username, "proxy_user")
        XCTAssertEqual(config?.password, "proxy_pass")
        
        // Verify capabilities
        XCTAssertTrue(config?.capabilities.contains(.javascriptRendering) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.screenshotCapture) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.geoTargeting) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.sessionManagement) ?? false)
    }
    
    func testWebScrapingAPIConfiguration() {
        decodoConfig.setCredentials(
            username: "api_user",
            password: "api_pass",
            apiKey: "api_key_456"
        )
        
        let config = decodoConfig.getWebScrapingAPIConfiguration()
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.endpoint, "https://scraper-api.decodo.com/v2/scrape")
        XCTAssertEqual(config?.username, "api_user")
        XCTAssertEqual(config?.password, "api_pass")
        
        // Verify capabilities
        XCTAssertTrue(config?.capabilities.contains(.javascriptRendering) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.screenshotCapture) ?? false)
        XCTAssertTrue(config?.capabilities.contains(.structuredParsing) ?? false)
    }
    
    // MARK: - Keychain Persistence Tests
    
    func testKeychainPersistenceWithAPIKey() {
        // Set credentials with API key
        decodoConfig.setCredentials(
            username: "persistent_user",
            password: "persistent_pass",
            apiKey: "persistent_api_key"
        )
        
        // Create new instance to test persistence
        let newConfig = DECODOConfiguration()
        newConfig.loadCredentials()
        
        let credentials = newConfig.credentials
        XCTAssertNotNil(credentials)
        XCTAssertEqual(credentials?.username, "persistent_user")
        XCTAssertEqual(credentials?.password, "persistent_pass")
        XCTAssertEqual(credentials?.apiKey, "persistent_api_key")
    }
    
    func testKeychainClearance() {
        // Set credentials with API key
        decodoConfig.setCredentials(
            username: "temp_user",
            password: "temp_pass",
            apiKey: "temp_api_key"
        )
        
        // Clear credentials
        decodoConfig.clearCredentials()
        
        // Create new instance to verify clearance
        let newConfig = DECODOConfiguration()
        newConfig.loadCredentials()
        
        XCTAssertFalse(newConfig.hasValidCredentials())
        XCTAssertNil(newConfig.credentials)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteHybridAuthFlow() {
        // 1. Set hybrid credentials
        decodoConfig.setCredentials(
            username: "integration_user",
            password: "integration_pass",
            apiKey: "integration_api_key"
        )
        
        // 2. Verify configuration is valid
        XCTAssertTrue(decodoConfig.hasValidCredentials())
        XCTAssertTrue(decodoConfig.isConfigured)
        
        // 3. Test Site Unblocker headers
        let suHeaders = DECODOConfiguration.createSiteUnblockerHeaders(
            headlessMode: .png,
            geoLocation: "US"
        )
        XCTAssertEqual(suHeaders["X-SU-API-Key"], "integration_api_key")
        XCTAssertEqual(suHeaders["X-SU-Headless"], "png")
        XCTAssertEqual(suHeaders["X-SU-Geo"], "US")
        
        // 4. Test Web Scraping API payload
        let wsPayload = DECODOConfiguration.createWebScrapingAPIPayload(
            url: "https://example.com",
            headlessMode: .html
        )
        XCTAssertEqual(wsPayload["api_key"] as? String, "integration_api_key")
        XCTAssertEqual(wsPayload["url"] as? String, "https://example.com")
        XCTAssertEqual(wsPayload["headless"] as? String, "html")
        
        // 5. Test proxy configurations
        let suConfig = decodoConfig.getSiteUnblockerConfiguration()
        XCTAssertNotNil(suConfig)
        XCTAssertEqual(suConfig?.username, "integration_user")
        XCTAssertEqual(suConfig?.password, "integration_pass")
        
        let wsConfig = decodoConfig.getWebScrapingAPIConfiguration()
        XCTAssertNotNil(wsConfig)
        XCTAssertEqual(wsConfig?.username, "integration_user")
        XCTAssertEqual(wsConfig?.password, "integration_pass")
    }
    
    // MARK: - Real API Tests (Conditional)
    
    func testRealSiteUnblockerConnection() async {
        // Skip if no real credentials available
        guard let username = ProcessInfo.processEnvironment["DECODO_TEST_USERNAME"],
              let password = ProcessInfo.processEnvironment["DECODO_TEST_PASSWORD"] else {
            throw XCTSkip("Real DECODO credentials not available")
        }
        
        let apiKey = ProcessInfo.processEnvironment["DECODO_TEST_API_KEY"]
        
        decodoConfig.setCredentials(
            username: username,
            password: password,
            apiKey: apiKey
        )
        
        let result = await decodoConfig.testSiteUnblockerConnection()
        
        XCTAssertTrue(result.success, "Site Unblocker connection failed: \(result.error ?? "Unknown error")")
        XCTAssertGreaterThan(result.latency, 0)
        XCTAssertNotNil(result.responseData)
    }
    
    func testRealWebScrapingAPI() async {
        // Skip if no real credentials available
        guard let username = ProcessInfo.processEnvironment["DECODO_TEST_USERNAME"],
              let password = ProcessInfo.processEnvironment["DECODO_TEST_PASSWORD"] else {
            throw XCTSkip("Real DECODO credentials not available")
        }
        
        let apiKey = ProcessInfo.processEnvironment["DECODO_TEST_API_KEY"]
        
        decodoConfig.setCredentials(
            username: username,
            password: password,
            apiKey: apiKey
        )
        
        let result = await decodoConfig.testWebScrapingAPI()
        
        XCTAssertTrue(result.success, "Web Scraping API connection failed: \(result.error ?? "Unknown error")")
        XCTAssertGreaterThan(result.latency, 0)
        XCTAssertNotNil(result.responseData)
    }
}
