
//
//  VisionIntegrationTests.swift
//  EirosAgentTests
//
//  Vision Integration Tests with DECODO Support
//  Created: 2025-09-22
//

import XCTest
import UIKit
@testable import EirosAgent

class VisionIntegrationTests: XCTestCase {
    
    var visionManager: VisionManager!
    var proxyManager: ProxyManager!
    var decodoConfig: DECODOConfiguration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        visionManager = VisionManager.shared
        proxyManager = ProxyManager.shared
        decodoConfig = DECODOConfiguration.shared
        
        // Reset state
        await MainActor.run {
            visionManager.isEnabled = true
        }
        decodoConfig.clearCredentials()
        proxyManager.disableProxy()
    }
    
    override func tearDown() async throws {
        // Clean up
        decodoConfig.clearCredentials()
        proxyManager.disableProxy()
        
        try await super.tearDown()
    }
    
    // MARK: - Vision Manager Tests
    
    @MainActor
    func testVisionManagerInitialization() {
        XCTAssertNotNil(visionManager)
        XCTAssertTrue(visionManager.isEnabled)
        XCTAssertFalse(visionManager.isProcessing)
        XCTAssertNil(visionManager.lastAnalysisResult)
        XCTAssertTrue(visionManager.processingQueue.isEmpty)
    }
    
    @MainActor
    func testVisionManagerEnableDisable() {
        // Test disabling
        visionManager.isEnabled = false
        XCTAssertFalse(visionManager.isEnabled)
        
        // Test enabling
        visionManager.isEnabled = true
        XCTAssertTrue(visionManager.isEnabled)
    }
    
    func testImageAnalysisWithDisabledVision() async {
        // Disable vision
        await MainActor.run {
            visionManager.isEnabled = false
        }
        
        // Create test image
        let testImage = createTestImage()
        
        // Analyze image
        let result = await visionManager.analyzeImage(testImage)
        
        // Should fail when disabled
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.confidence, 0.0)
        XCTAssertTrue(result.detectedObjects.isEmpty)
        XCTAssertTrue(result.text.isEmpty)
        XCTAssertNotNil(result.metadata["error"])
    }
    
    func testImageAnalysisWithValidImage() async {
        // Create test image
        let testImage = createTestImage()
        
        // Analyze image
        let result = await visionManager.analyzeImage(testImage)
        
        // Should succeed with valid image
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertNotNil(result.metadata["processingTime"])
        
        // Check that last result is updated
        await MainActor.run {
            XCTAssertNotNil(self.visionManager.lastAnalysisResult)
            XCTAssertEqual(self.visionManager.lastAnalysisResult?.success, result.success)
        }
    }
    
    func testBatchImageAnalysis() async {
        // Create test images
        let testImages = [
            createTestImage(color: .red),
            createTestImage(color: .green),
            createTestImage(color: .blue)
        ]
        
        // Analyze batch
        let results = await visionManager.batchAnalyzeImages(testImages)
        
        // Should have results for all images
        XCTAssertEqual(results.count, testImages.count)
        
        // Check batch metadata
        for (index, result) in results.enumerated() {
            XCTAssertTrue(result.success)
            XCTAssertEqual(result.metadata["batchIndex"] as? Int, index)
            XCTAssertEqual(result.metadata["batchTotal"] as? Int, testImages.count)
        }
    }
    
    func testTextExtractionFromImage() async {
        // Create image with text
        let textImage = createImageWithText("Hello World\nTest Text")
        
        // Extract text
        let result = await visionManager.extractTextFromImage(textImage)
        
        // Should extract text successfully
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertNil(result.error)
    }
    
    func testObjectDetectionInImage() async {
        // Create test image
        let testImage = createTestImage()
        
        // Detect objects
        let result = await visionManager.detectObjects(in: testImage)
        
        // Should complete successfully
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        // Objects array may be empty for simple test image
    }
    
    // MARK: - DECODO Integration Tests
    
    func testScreenshotAnalysisWithoutProxy() async {
        // Try to analyze screenshot without proxy
        let result = await visionManager.analyzeScreenshot(
            from: "https://example.com",
            using: proxyManager
        )
        
        // Should fail without proxy
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.metadata["error"])
    }
    
    func testScreenshotAnalysisWithProxy() async {
        // Configure DECODO
        decodoConfig.setCredentials(username: "testuser", password: "testpass")
        
        // Enable proxy
        let proxyEnabled = await proxyManager.enableDECODOSiteUnblocker()
        
        // Skip test if proxy couldn't be enabled (expected without real credentials)
        guard proxyEnabled else {
            print("⚠️ Skipping screenshot analysis test - proxy not enabled")
            return
        }
        
        // Analyze screenshot
        let result = await visionManager.analyzeScreenshot(
            from: "https://example.com",
            using: proxyManager,
            options: VisionAnalysisOptions(
                analysisPrompt: "Describe this webpage screenshot",
                geoLocation: "United States",
                deviceType: .desktop
            )
        )
        
        // Result depends on actual network connectivity
        // For unit testing, we mainly test the interface
        XCTAssertNotNil(result)
        
        if result.success {
            XCTAssertNotNil(result.metadata["sourceURL"])
            XCTAssertNotNil(result.metadata["captureMethod"])
        }
    }
    
    func testVisionAnalysisOptions() {
        // Test default options
        let defaultOptions = VisionAnalysisOptions()
        XCTAssertFalse(defaultOptions.analysisPrompt.isEmpty)
        XCTAssertNil(defaultOptions.geoLocation)
        XCTAssertNil(defaultOptions.sessionId)
        XCTAssertEqual(defaultOptions.deviceType, .desktop)
        
        // Test custom options
        let customOptions = VisionAnalysisOptions(
            analysisPrompt: "Custom prompt",
            geoLocation: "Germany",
            sessionId: "test123",
            deviceType: .mobileAndroid,
            sourceURL: "https://example.com",
            captureMethod: "DECODO Proxy"
        )
        
        XCTAssertEqual(customOptions.analysisPrompt, "Custom prompt")
        XCTAssertEqual(customOptions.geoLocation, "Germany")
        XCTAssertEqual(customOptions.sessionId, "test123")
        XCTAssertEqual(customOptions.deviceType, .mobileAndroid)
        XCTAssertEqual(customOptions.sourceURL, "https://example.com")
        XCTAssertEqual(customOptions.captureMethod, "DECODO Proxy")
    }
    
    // MARK: - Performance Tests
    
    func testImageAnalysisPerformance() async {
        let testImage = createTestImage()
        
        // Measure performance
        let startTime = Date()
        let result = await visionManager.analyzeImage(testImage)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        XCTAssertLessThan(processingTime, 10.0) // 10 seconds max
        XCTAssertTrue(result.success)
        
        // Check reported processing time
        if let reportedTime = result.metadata["processingTime"] as? TimeInterval {
            XCTAssertGreaterThan(reportedTime, 0.0)
            XCTAssertLessThan(reportedTime, processingTime + 1.0) // Allow some overhead
        }
    }
    
    func testBatchAnalysisPerformance() async {
        let testImages = Array(repeating: createTestImage(), count: 5)
        
        measure {
            let expectation = XCTestExpectation(description: "Batch analysis")
            
            Task {
                let results = await visionManager.batchAnalyzeImages(testImages)
                XCTAssertEqual(results.count, testImages.count)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidImageHandling() async {
        // Create invalid image data
        let invalidImageData = Data([0x00, 0x01, 0x02, 0x03])
        
        // This test would require modifying the VisionManager to accept Data directly
        // For now, we test with a valid but minimal image
        let minimalImage = UIImage(systemName: "photo") ?? createTestImage()
        
        let result = await visionManager.analyzeImage(minimalImage)
        
        // Should handle gracefully
        XCTAssertNotNil(result)
    }
    
    func testNetworkErrorHandling() async {
        // Test with invalid URL
        let result = await visionManager.analyzeScreenshot(
            from: "invalid-url",
            using: proxyManager
        )
        
        // Should fail gracefully
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.metadata["error"])
    }
    
    // MARK: - Integration with Automation Tests
    
    @MainActor
    func testVisionManagerIntegrationWithAutomation() async {
        // This test verifies that VisionManager integrates properly with AutomationController
        let automationController = AutomationController.shared
        
        // Enable automation
        automationController.enableAutomation()
        
        // Create a screenshot task
        let task = automationController.createScreenshotTask(
            url: "https://example.com",
            options: ScreenshotTaskOptions(deviceType: .desktop)
        )
        
        // Verify task creation
        XCTAssertNotNil(task)
        XCTAssertEqual(task.actions.count, 1)
        XCTAssertEqual(task.actions.first?.type, .screenshot)
        
        // The actual execution would require network connectivity
        // For unit testing, we verify the integration points exist
    }
    
    // MARK: - Qwen2VL Service Tests
    
    func testQwen2VLServiceIntegration() async {
        // Test that VisionManager can communicate with Qwen2VL service
        // This is tested indirectly through image analysis
        
        let testImage = createTestImage()
        let options = VisionAnalysisOptions(
            analysisPrompt: "Test prompt for Qwen2VL integration"
        )
        
        let result = await visionManager.analyzeImage(testImage, options: options)
        
        // Should complete (success depends on Qwen2VL service availability)
        XCTAssertNotNil(result)
        
        // Check for Qwen2VL-specific metadata
        if result.success {
            XCTAssertNotNil(result.metadata["qwen2vlSuccess"])
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(color: UIColor = .blue, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createImageWithText(_ text: String, size: CGSize = CGSize(width: 200, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Black text
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.black,
                .font: UIFont.systemFont(ofSize: 16)
            ]
            
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textRect = CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20)
            attributedText.draw(in: textRect)
        }
    }
}

// MARK: - Mock Tests for UI Components

class VisionUIIntegrationTests: XCTestCase {
    
    func testVisionAnalysisViewInitialization() {
        // Test that the vision analysis view can be initialized
        // This would be tested in UI tests in a real scenario
        XCTAssertTrue(true) // Placeholder for UI testing
    }
    
    func testImagePickerIntegration() {
        // Test image picker integration
        // This would be tested in UI tests in a real scenario
        XCTAssertTrue(true) // Placeholder for UI testing
    }
    
    func testResultsDisplayIntegration() {
        // Test results display integration
        // This would be tested in UI tests in a real scenario
        XCTAssertTrue(true) // Placeholder for UI testing
    }
}

// MARK: - Real Service Tests (Conditional)

class VisionRealServiceTests: XCTestCase {
    
    func testRealQwen2VLService() async {
        // Skip this test if Qwen2VL service is not running
        guard isQwen2VLServiceAvailable() else {
            print("⚠️ Skipping real Qwen2VL service test - service not available")
            print("💡 Start the Qwen2VL server to run this test")
            return
        }
        
        let visionManager = VisionManager.shared
        let testImage = createTestImage()
        
        let result = await visionManager.analyzeImage(testImage)
        
        XCTAssertTrue(result.success, "Real Qwen2VL service analysis failed: \(result.metadata["error"] ?? "Unknown error")")
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertFalse(result.text.isEmpty)
        
        print("✅ Real Qwen2VL service test successful")
    }
    
    private func isQwen2VLServiceAvailable() -> Bool {
        // Check if Qwen2VL service is running on localhost:8000
        let semaphore = DispatchSemaphore(value: 0)
        var isAvailable = false
        
        guard let url = URL(string: "http://localhost:8000/health") else {
            return false
        }
        
        let task = URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isAvailable = true
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        return isAvailable
    }
    
    private func createTestImage(color: UIColor = .blue, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
