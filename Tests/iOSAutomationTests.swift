
//
//  iOSAutomationTests.swift
//  EirosAgentTests
//
//  iOS Automation Bridge Tests
//  Created: 2025-09-22
//

import XCTest
import WebKit
@testable import EirosAgent

class iOSAutomationTests: XCTestCase {
    
    var automationBridge: iOSAutomationBridge!
    var proxyManager: ProxyManager!
    var decodoConfig: DECODOConfiguration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        automationBridge = iOSAutomationBridge.shared
        proxyManager = ProxyManager.shared
        decodoConfig = DECODOConfiguration.shared
        
        // Reset state
        await MainActor.run {
            automationBridge.disableAutomation()
        }
        decodoConfig.clearCredentials()
        proxyManager.disableProxy()
    }
    
    override func tearDown() async throws {
        // Clean up
        await MainActor.run {
            automationBridge.disableAutomation()
        }
        decodoConfig.clearCredentials()
        proxyManager.disableProxy()
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor
    func testAutomationBridgeInitialization() {
        XCTAssertNotNil(automationBridge)
        XCTAssertFalse(automationBridge.isEnabled)
        XCTAssertNil(automationBridge.currentWebView)
        XCTAssertEqual(automationBridge.automationStatus, .idle)
        XCTAssertNil(automationBridge.lastScreenshot)
    }
    
    @MainActor
    func testEnableDisableAutomation() {
        // Test enabling
        automationBridge.enableAutomation()
        XCTAssertTrue(automationBridge.isEnabled)
        XCTAssertEqual(automationBridge.automationStatus, .ready)
        
        // Test disabling
        automationBridge.disableAutomation()
        XCTAssertFalse(automationBridge.isEnabled)
        XCTAssertEqual(automationBridge.automationStatus, .idle)
        XCTAssertNil(automationBridge.currentWebView)
    }
    
    // MARK: - WebView Creation Tests
    
    @MainActor
    func testWebViewCreation() {
        automationBridge.enableAutomation()
        
        let webView = automationBridge.createWebView()
        
        XCTAssertNotNil(webView)
        XCTAssertEqual(automationBridge.currentWebView, webView)
        XCTAssertNotNil(webView.navigationDelegate)
        XCTAssertNotNil(webView.uiDelegate)
    }
    
    @MainActor
    func testWebViewCreationWithProxy() {
        automationBridge.enableAutomation()
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        
        // Create proxy configuration
        let proxyConfig = ProxyConfiguration(
            id: "test-proxy",
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            username: "user",
            password: "pass"
        )
        
        let webView = automationBridge.createWebView(with: proxyConfig)
        
        XCTAssertNotNil(webView)
        XCTAssertEqual(automationBridge.currentWebView, webView)
    }
    
    // MARK: - Navigation Tests
    
    @MainActor
    func testNavigationWithInvalidURL() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        let result = await automationBridge.navigateToURL("invalid-url", in: webView)
        
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }
    
    @MainActor
    func testNavigationWithoutWebView() async {
        automationBridge.enableAutomation()
        
        let result = await automationBridge.navigateToURL("https://example.com")
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "No WebView available")
    }
    
    // MARK: - Screenshot Tests
    
    @MainActor
    func testScreenshotWithoutWebView() async {
        automationBridge.enableAutomation()
        
        let result = await automationBridge.captureScreenshot()
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "No WebView available")
        XCTAssertNil(result.imageData)
    }
    
    @MainActor
    func testScreenshotWithWebView() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load a simple HTML page
        let html = "<html><body><h1>Test Page</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait a moment for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.captureScreenshot(of: webView)
        
        // Should succeed with a WebView
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.imageData)
        
        // Check that last screenshot is updated
        XCTAssertNotNil(automationBridge.lastScreenshot)
    }
    
    // MARK: - JavaScript Execution Tests
    
    @MainActor
    func testJavaScriptExecutionWithoutWebView() async {
        automationBridge.enableAutomation()
        
        let result = await automationBridge.executeJavaScript("document.title")
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "No WebView available")
        XCTAssertNil(result.result)
    }
    
    @MainActor
    func testJavaScriptExecutionWithWebView() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load a simple HTML page
        let html = "<html><head><title>Test Title</title></head><body><h1>Test Page</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.executeJavaScript("document.title", in: webView)
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.result as? String, "Test Title")
    }
    
    @MainActor
    func testJavaScriptExecutionWithError() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load a simple HTML page
        let html = "<html><body><h1>Test Page</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Execute invalid JavaScript
        let result = await automationBridge.executeJavaScript("invalid.javascript.code", in: webView)
        
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
        XCTAssertNil(result.result)
    }
    
    // MARK: - Element Interaction Tests
    
    @MainActor
    func testClickElementWithoutWebView() async {
        automationBridge.enableAutomation()
        
        let result = await automationBridge.clickElement(selector: "#test-button")
        
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }
    
    @MainActor
    func testClickElementWithWebView() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load HTML with a button
        let html = """
        <html>
        <body>
            <button id="test-button" onclick="this.textContent='Clicked'">Click Me</button>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.clickElement(selector: "#test-button", in: webView)
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.metadata["selector"] as? String, "#test-button")
        XCTAssertEqual(result.metadata["action"] as? String, "click")
    }
    
    @MainActor
    func testClickNonExistentElement() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load simple HTML
        let html = "<html><body><h1>Test Page</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.clickElement(selector: "#non-existent", in: webView)
        
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }
    
    @MainActor
    func testTypeTextInElement() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load HTML with an input field
        let html = """
        <html>
        <body>
            <input id="test-input" type="text" placeholder="Enter text">
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.typeText("Hello World", in: "#test-input", webView: webView)
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.metadata["selector"] as? String, "#test-input")
        XCTAssertEqual(result.metadata["text"] as? String, "Hello World")
        XCTAssertEqual(result.metadata["action"] as? String, "type")
    }
    
    // MARK: - Text Extraction Tests
    
    @MainActor
    func testExtractTextFromElements() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load HTML with text elements
        let html = """
        <html>
        <body>
            <h1 class="title">Main Title</h1>
            <p class="content">This is some content text.</p>
            <div class="content">Another content block.</div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.extractText(from: ".content", webView: webView)
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.elements.count, 2)
        XCTAssertEqual(result.elements[0].text, "This is some content text.")
        XCTAssertEqual(result.elements[1].text, "Another content block.")
    }
    
    // MARK: - Scrolling Tests
    
    @MainActor
    func testScrollPage() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load HTML with scrollable content
        let html = """
        <html>
        <body style="height: 2000px;">
            <h1>Top of page</h1>
            <div style="margin-top: 1500px;">
                <h2>Bottom of page</h2>
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.scrollPage(direction: .down, amount: 3, webView: webView)
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.metadata["direction"] as? String, "down")
        XCTAssertEqual(result.metadata["amount"] as? Int, 3)
        XCTAssertEqual(result.metadata["action"] as? String, "scroll")
    }
    
    // MARK: - Wait for Element Tests
    
    @MainActor
    func testWaitForExistingElement() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load HTML with an element
        let html = """
        <html>
        <body>
            <div id="existing-element">I exist!</div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.waitForElement(selector: "#existing-element", timeout: 5.0, webView: webView)
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.metadata["selector"] as? String, "#existing-element")
        XCTAssertEqual(result.metadata["action"] as? String, "wait")
    }
    
    @MainActor
    func testWaitForNonExistentElement() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load simple HTML
        let html = "<html><body><h1>Test Page</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let result = await automationBridge.waitForElement(selector: "#non-existent", timeout: 2.0, webView: webView)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "Element not found within timeout")
        XCTAssertEqual(result.metadata["timeout"] as? TimeInterval, 2.0)
    }
    
    // MARK: - DECODO Integration Tests
    
    @MainActor
    func testAutomationWithDECODOWithoutProxy() async {
        automationBridge.enableAutomation()
        
        let task = iOSAutomationTask(
            id: "test-task",
            name: "Test Task",
            actions: [
                iOSAutomationAction(
                    id: "action-1",
                    type: .screenshot,
                    target: "https://example.com"
                )
            ],
            useProxy: true
        )
        
        let result = await automationBridge.executeAutomationWithDECODO(task: task)
        
        // Should fail without proxy
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }
    
    @MainActor
    func testAutomationTaskCreation() {
        let actions = [
            iOSAutomationAction(
                id: "action-1",
                type: .navigate,
                target: "https://example.com"
            ),
            iOSAutomationAction(
                id: "action-2",
                type: .screenshot,
                target: "https://example.com"
            ),
            iOSAutomationAction(
                id: "action-3",
                type: .click,
                target: "#submit-button"
            )
        ]
        
        let task = iOSAutomationTask(
            id: "test-task",
            name: "Test Automation Task",
            actions: actions,
            useProxy: true,
            stopOnError: false
        )
        
        XCTAssertEqual(task.id, "test-task")
        XCTAssertEqual(task.name, "Test Automation Task")
        XCTAssertEqual(task.actions.count, 3)
        XCTAssertTrue(task.useProxy)
        XCTAssertFalse(task.stopOnError)
    }
    
    // MARK: - Status Tests
    
    @MainActor
    func testAutomationStatusTransitions() {
        automationBridge.enableAutomation()
        
        // Should start as ready
        XCTAssertEqual(automationBridge.automationStatus, .ready)
        
        // Status descriptions
        XCTAssertEqual(iOSAutomationStatus.idle.description, "Idle")
        XCTAssertEqual(iOSAutomationStatus.ready.description, "Ready")
        XCTAssertEqual(iOSAutomationStatus.navigating.description, "Navigating")
        XCTAssertEqual(iOSAutomationStatus.capturingScreenshot.description, "Capturing Screenshot")
        XCTAssertEqual(iOSAutomationStatus.executingScript.description, "Executing Script")
        XCTAssertEqual(iOSAutomationStatus.executing.description, "Executing")
        XCTAssertEqual(iOSAutomationStatus.completed.description, "Completed")
        XCTAssertEqual(iOSAutomationStatus.error("Test error").description, "Error: Test error")
    }
    
    // MARK: - Supporting Types Tests
    
    func testScrollDirectionEnum() {
        XCTAssertEqual(ScrollDirection.up.rawValue, "up")
        XCTAssertEqual(ScrollDirection.down.rawValue, "down")
        XCTAssertEqual(ScrollDirection.left.rawValue, "left")
        XCTAssertEqual(ScrollDirection.right.rawValue, "right")
        XCTAssertEqual(ScrollDirection.top.rawValue, "top")
        XCTAssertEqual(ScrollDirection.bottom.rawValue, "bottom")
        
        // Test all cases are covered
        XCTAssertEqual(ScrollDirection.allCases.count, 6)
    }
    
    func testNavigationResult() {
        let successResult = NavigationResult(success: true, error: nil)
        XCTAssertTrue(successResult.success)
        XCTAssertNil(successResult.error)
        
        let failureResult = NavigationResult(success: false, error: "Navigation failed")
        XCTAssertFalse(failureResult.success)
        XCTAssertEqual(failureResult.error, "Navigation failed")
    }
    
    func testJavaScriptResult() {
        let successResult = JavaScriptResult(success: true, result: "test result", error: nil)
        XCTAssertTrue(successResult.success)
        XCTAssertEqual(successResult.result as? String, "test result")
        XCTAssertNil(successResult.error)
        
        let failureResult = JavaScriptResult(success: false, result: nil, error: "Script error")
        XCTAssertFalse(failureResult.success)
        XCTAssertNil(failureResult.result)
        XCTAssertEqual(failureResult.error, "Script error")
    }
    
    func testExtractionResult() {
        let elements = [
            ExtractedElement(text: "Text 1", html: "<p>Text 1</p>", attributes: ["class": "content"]),
            ExtractedElement(text: "Text 2", html: "<p>Text 2</p>", attributes: ["id": "text2"])
        ]
        
        let result = ExtractionResult(success: true, elements: elements, error: nil)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.elements.count, 2)
        XCTAssertEqual(result.elements[0].text, "Text 1")
        XCTAssertEqual(result.elements[1].attributes["id"], "text2")
        XCTAssertNil(result.error)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testScreenshotPerformance() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load a simple page
        let html = "<html><body><h1>Performance Test</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        measure {
            let expectation = XCTestExpectation(description: "Screenshot performance")
            
            Task {
                let result = await automationBridge.captureScreenshot(of: webView)
                XCTAssertTrue(result.success)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    @MainActor
    func testJavaScriptExecutionPerformance() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load a simple page
        let html = "<html><body><h1>Performance Test</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        measure {
            let expectation = XCTestExpectation(description: "JavaScript performance")
            
            Task {
                let result = await automationBridge.executeJavaScript("document.title", in: webView)
                XCTAssertTrue(result.success)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testAutomationWithDisabledBridge() async {
        // Don't enable automation
        XCTAssertFalse(automationBridge.isEnabled)
        
        let task = iOSAutomationTask(
            id: "test-task",
            name: "Test Task",
            actions: [],
            useProxy: false
        )
        
        let result = await automationBridge.executeAutomationWithDECODO(task: task)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "iOS automation is disabled")
    }
    
    @MainActor
    func testMultipleActionsWithStopOnError() async {
        automationBridge.enableAutomation()
        let webView = automationBridge.createWebView()
        
        // Load simple HTML
        let html = "<html><body><h1>Test Page</h1></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let actions = [
            iOSAutomationAction(id: "1", type: .click, target: "#existing-element"), // This will fail
            iOSAutomationAction(id: "2", type: .screenshot, target: "")              // This should not execute
        ]
        
        let task = iOSAutomationTask(
            id: "test-task",
            name: "Test Task",
            actions: actions,
            useProxy: false,
            stopOnError: true
        )
        
        let result = await automationBridge.executeAutomationWithDECODO(task: task)
        
        // Should fail and stop on first error
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }
}

// MARK: - Mock WebView Tests

class MockWebViewTests: XCTestCase {
    
    @MainActor
    func testWebViewDelegateSetup() {
        let automationBridge = iOSAutomationBridge.shared
        automationBridge.enableAutomation()
        
        let webView = automationBridge.createWebView()
        
        XCTAssertTrue(webView.navigationDelegate === automationBridge)
        XCTAssertTrue(webView.uiDelegate === automationBridge)
    }
    
    @MainActor
    func testWebViewConfiguration() {
        let automationBridge = iOSAutomationBridge.shared
        automationBridge.enableAutomation()
        
        let webView = automationBridge.createWebView()
        
        XCTAssertTrue(webView.configuration.preferences.javaScriptEnabled)
    }
}
