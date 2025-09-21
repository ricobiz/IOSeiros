
//
//  Qwen2VLManagerTests.swift
//  EirosAgentTests
//
//  Created by DeepAgent on 2025-09-21.
//

import XCTest
import UIKit
@testable import EirosAgent

@MainActor
final class Qwen2VLManagerTests: XCTestCase {
    
    var qwen2VLManager: Qwen2VLManager!
    
    override func setUp() async throws {
        try await super.setUp()
        qwen2VLManager = Qwen2VLManager.shared
        qwen2VLManager.resetMetrics()
    }
    
    override func tearDown() async throws {
        qwen2VLManager.unloadModel()
        qwen2VLManager.resetMetrics()
        try await super.tearDown()
    }
    
    func testQwen2VLManagerInitialization() {
        XCTAssertNotNil(qwen2VLManager)
        XCTAssertFalse(qwen2VLManager.isModelLoaded)
        XCTAssertFalse(qwen2VLManager.isProcessing)
        XCTAssertNotNil(qwen2VLManager.modelInfo)
        XCTAssertEqual(qwen2VLManager.totalInferences, 0)
    }
    
    func testModelInfo() {
        let modelInfo = qwen2VLManager.modelInfo
        
        XCTAssertNotNil(modelInfo)
        XCTAssertEqual(modelInfo?.name, "Qwen2-VL-2B")
        XCTAssertEqual(modelInfo?.version, "2.0")
        XCTAssertEqual(modelInfo?.parameters, "2B")
        XCTAssertTrue(modelInfo?.supportedLanguages.contains("en") ?? false)
        XCTAssertTrue(modelInfo?.capabilities.contains(.textRecognition) ?? false)
    }
    
    func testModelLoading() async {
        XCTAssertFalse(qwen2VLManager.isModelLoaded)
        
        await qwen2VLManager.loadModel()
        
        XCTAssertTrue(qwen2VLManager.isModelLoaded)
        XCTAssertFalse(qwen2VLManager.isProcessing)
        XCTAssertEqual(qwen2VLManager.processingProgress, 1.0)
    }
    
    func testModelUnloading() async {
        await qwen2VLManager.loadModel()
        XCTAssertTrue(qwen2VLManager.isModelLoaded)
        
        qwen2VLManager.unloadModel()
        
        XCTAssertFalse(qwen2VLManager.isModelLoaded)
        XCTAssertEqual(qwen2VLManager.processingProgress, 0.0)
        XCTAssertNil(qwen2VLManager.lastAnalysisResult)
    }
    
    func testImageAnalysis() async {
        await qwen2VLManager.loadModel()
        
        let testImage = createTestImage(size: CGSize(width: 400, height: 600))
        let result = await qwen2VLManager.analyzeImage(testImage, prompt: "Analyze this test image")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.imageSize, testImage.size)
        XCTAssertEqual(result?.prompt, "Analyze this test image")
        XCTAssertGreaterThan(result?.detectedElements.count ?? 0, 0)
        XCTAssertFalse(result?.textContent.isEmpty ?? true)
        XCTAssertFalse(result?.sceneDescription.isEmpty ?? true)
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.5)
        XCTAssertEqual(qwen2VLManager.totalInferences, 1)
    }
    
    func testImageAnalysisWithoutModel() async {
        XCTAssertFalse(qwen2VLManager.isModelLoaded)
        
        let testImage = createTestImage(size: CGSize(width: 400, height: 600))
        let result = await qwen2VLManager.analyzeImage(testImage)
        
        XCTAssertNil(result)
        XCTAssertNotNil(qwen2VLManager.lastError)
        XCTAssertTrue(qwen2VLManager.lastError?.contains("not loaded") ?? false)
    }
    
    func testAutomationAnalysis() async {
        await qwen2VLManager.loadModel()
        
        let testImage = createTestImage(size: CGSize(width: 400, height: 600))
        let intent = AutomationIntent(
            type: .tap,
            description: "Tap the submit button",
            parameters: ["target": "submit"]
        )
        
        let result = await qwen2VLManager.analyzeForAutomation(testImage, intent: intent)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.intent.type, .tap)
        XCTAssertGreaterThan(result?.detectedElements.count ?? 0, 0)
        XCTAssertGreaterThan(result?.recommendedActions.count ?? 0, 0)
        XCTAssertNotNil(result?.executionPlan)
        XCTAssertGreaterThan(result?.executionPlan.steps.count ?? 0, 0)
    }
    
    func testElementDetection() async {
        await qwen2VLManager.loadModel()
        
        let testImage = createTestImage(size: CGSize(width: 400, height: 600))
        let result = await qwen2VLManager.analyzeImage(testImage)
        
        XCTAssertNotNil(result)
        
        let elements = result?.detectedElements ?? []
        XCTAssertGreaterThan(elements.count, 0)
        
        // Check that elements have valid properties
        for element in elements {
            XCTAssertNotNil(element.id)
            XCTAssertFalse(element.text.isEmpty)
            XCTAssertGreaterThan(element.confidence, 0.0)
            XCTAssertLessThanOrEqual(element.confidence, 1.0)
            XCTAssertTrue(element.boundingBox.width > 0)
            XCTAssertTrue(element.boundingBox.height > 0)
        }
    }
    
    func testPerformanceMetrics() async {
        await qwen2VLManager.loadModel()
        
        let testImage = createTestImage(size: CGSize(width: 400, height: 600))
        
        // Perform multiple analyses
        for _ in 0..<3 {
            _ = await qwen2VLManager.analyzeImage(testImage)
        }
        
        XCTAssertEqual(qwen2VLManager.totalInferences, 3)
        XCTAssertGreaterThan(qwen2VLManager.lastInferenceTime, 0)
        XCTAssertGreaterThan(qwen2VLManager.averageInferenceTime, 0)
        
        let status = qwen2VLManager.getModelStatus()
        XCTAssertTrue(status.isLoaded)
        XCTAssertEqual(status.performanceMetrics.totalInferences, 3)
    }
    
    func testModelStatus() {
        let status = qwen2VLManager.getModelStatus()
        
        XCTAssertNotNil(status)
        XCTAssertEqual(status.isLoaded, qwen2VLManager.isModelLoaded)
        XCTAssertEqual(status.isAvailable, qwen2VLManager.isAvailable)
        XCTAssertEqual(status.isProcessing, qwen2VLManager.isProcessing)
        XCTAssertNotNil(status.modelInfo)
        XCTAssertNotNil(status.performanceMetrics)
    }
    
    func testResetMetrics() async {
        await qwen2VLManager.loadModel()
        
        let testImage = createTestImage(size: CGSize(width: 400, height: 600))
        _ = await qwen2VLManager.analyzeImage(testImage)
        
        XCTAssertGreaterThan(qwen2VLManager.totalInferences, 0)
        
        qwen2VLManager.resetMetrics()
        
        XCTAssertEqual(qwen2VLManager.totalInferences, 0)
        XCTAssertEqual(qwen2VLManager.lastInferenceTime, 0)
        XCTAssertEqual(qwen2VLManager.averageInferenceTime, 0)
        XCTAssertNil(qwen2VLManager.lastError)
    }
    
    func testElementTypes() {
        let elementTypes = Qwen2VLElementType.allCases
        
        XCTAssertTrue(elementTypes.contains(.button))
        XCTAssertTrue(elementTypes.contains(.textField))
        XCTAssertTrue(elementTypes.contains(.label))
        XCTAssertTrue(elementTypes.contains(.image))
        XCTAssertTrue(elementTypes.contains(.link))
        XCTAssertTrue(elementTypes.contains(.searchField))
        XCTAssertTrue(elementTypes.contains(.scrollView))
        
        // Test display names
        XCTAssertEqual(Qwen2VLElementType.button.displayName, "Button")
        XCTAssertEqual(Qwen2VLElementType.textField.displayName, "Text Field")
    }
    
    func testCapabilities() {
        let capabilities = Qwen2VLCapability.allCases
        
        XCTAssertTrue(capabilities.contains(.textRecognition))
        XCTAssertTrue(capabilities.contains(.objectDetection))
        XCTAssertTrue(capabilities.contains(.sceneUnderstanding))
        XCTAssertTrue(capabilities.contains(.uiElementDetection))
        
        // Test display names
        XCTAssertEqual(Qwen2VLCapability.textRecognition.displayName, "Text Recognition")
        XCTAssertEqual(Qwen2VLCapability.objectDetection.displayName, "Object Detection")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        // Create a simple test image with some colored rectangles
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        UIColor.blue.setFill()
        UIRectFill(CGRect(x: 50, y: 50, width: 100, height: 50))
        
        UIColor.red.setFill()
        UIRectFill(CGRect(x: 200, y: 100, width: 150, height: 30))
        
        UIColor.green.setFill()
        UIRectFill(CGRect(x: 100, y: 200, width: 200, height: 40))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
}
