
//
//  TouchGridSystemTests.swift
//  EirosAgentTests
//
//  Created by DeepAgent on 2025-09-21.
//

import XCTest
import UIKit
@testable import EirosAgent

@MainActor
final class TouchGridSystemTests: XCTestCase {
    
    var touchGridSystem: TouchGridSystem!
    
    override func setUp() async throws {
        try await super.setUp()
        touchGridSystem = TouchGridSystem.shared
        touchGridSystem.reset()
    }
    
    override func tearDown() async throws {
        touchGridSystem.reset()
        try await super.tearDown()
    }
    
    func testTouchGridSystemInitialization() {
        XCTAssertNotNil(touchGridSystem)
        XCTAssertEqual(touchGridSystem.gridSize.width, 20)
        XCTAssertEqual(touchGridSystem.gridSize.height, 20)
        XCTAssertTrue(touchGridSystem.touchHistory.isEmpty)
    }
    
    func testCoordinateConversion() {
        let webViewFrame = CGRect(x: 0, y: 100, width: 400, height: 600)
        touchGridSystem.updateWebViewFrame(webViewFrame)
        
        let screenPoint = CGPoint(x: 200, y: 400)
        let webViewPoint = touchGridSystem.convertScreenToWebView(screenPoint)
        
        XCTAssertEqual(webViewPoint.x, 200.0, accuracy: 1.0)
        XCTAssertEqual(webViewPoint.y, 300.0, accuracy: 1.0)
    }
    
    func testVisionCoordinateConversion() {
        let webViewFrame = CGRect(x: 0, y: 0, width: 400, height: 600)
        touchGridSystem.updateWebViewFrame(webViewFrame)
        
        let visionRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5) // Normalized coordinates
        let imageSize = CGSize(width: 400, height: 600)
        
        let screenRect = touchGridSystem.convertVisionToScreen(visionRect, imageSize: imageSize)
        
        XCTAssertEqual(screenRect.origin.x, 100.0, accuracy: 1.0)
        XCTAssertEqual(screenRect.origin.y, 150.0, accuracy: 1.0)
        XCTAssertEqual(screenRect.width, 200.0, accuracy: 1.0)
        XCTAssertEqual(screenRect.height, 300.0, accuracy: 1.0)
    }
    
    func testOptimalTouchPoint() {
        let element = UIElement(
            type: .button,
            text: "Test Button",
            boundingBox: CGRect(x: 100, y: 100, width: 200, height: 50),
            confidence: 0.9,
            isInteractable: true
        )
        
        let touchPoint = touchGridSystem.getOptimalTouchPoint(for: element)
        
        // Should be center of the element
        XCTAssertEqual(touchPoint.x, 200.0, accuracy: 1.0)
        XCTAssertEqual(touchPoint.y, 125.0, accuracy: 1.0)
    }
    
    func testGridPointGeneration() {
        let webViewFrame = CGRect(x: 0, y: 0, width: 400, height: 600)
        touchGridSystem.updateWebViewFrame(webViewFrame)
        touchGridSystem.gridSize = CGSize(width: 4, height: 6) // 4x6 grid
        
        let gridPoints = touchGridSystem.getGridPoints()
        
        XCTAssertEqual(gridPoints.count, 24) // 4 * 6 = 24 points
        
        // Check first point (should be at center of first grid cell)
        let firstPoint = gridPoints.first!
        XCTAssertEqual(firstPoint.x, 50.0, accuracy: 1.0) // 400/4/2 = 50
        XCTAssertEqual(firstPoint.y, 50.0, accuracy: 1.0) // 600/6/2 = 50
    }
    
    func testNearestGridPoint() {
        let webViewFrame = CGRect(x: 0, y: 0, width: 400, height: 400)
        touchGridSystem.updateWebViewFrame(webViewFrame)
        touchGridSystem.gridSize = CGSize(width: 4, height: 4) // 4x4 grid
        
        let testPoint = CGPoint(x: 120, y: 180) // Should be closest to grid point at (100, 200)
        let nearestPoint = touchGridSystem.getNearestGridPoint(to: testPoint)
        
        XCTAssertEqual(nearestPoint.x, 50.0, accuracy: 10.0) // Allow some tolerance
        XCTAssertEqual(nearestPoint.y, 50.0, accuracy: 10.0)
    }
    
    func testTouchValidation() {
        let webViewFrame = CGRect(x: 0, y: 100, width: 400, height: 600)
        touchGridSystem.updateWebViewFrame(webViewFrame)
        
        // Valid point within webview
        let validPoint = CGPoint(x: 200, y: 400)
        let validResult = touchGridSystem.validateTouchPoint(validPoint)
        XCTAssertTrue(validResult.isValid)
        XCTAssertNotNil(validResult.adjustedPoint)
        
        // Invalid point outside webview
        let invalidPoint = CGPoint(x: 500, y: 50)
        let invalidResult = touchGridSystem.validateTouchPoint(invalidPoint)
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertNil(invalidResult.adjustedPoint)
    }
    
    func testTouchEventGeneration() {
        let testPoint = CGPoint(x: 100, y: 200)
        let touchEvent = touchGridSystem.generateTouchEvent(at: testPoint, type: .tap)
        
        XCTAssertEqual(touchEvent.point, testPoint)
        XCTAssertEqual(touchEvent.type, .tap)
        XCTAssertEqual(touchGridSystem.touchHistory.count, 1)
        XCTAssertEqual(touchGridSystem.lastTouchPoint, testPoint)
    }
    
    func testTouchExecution() async {
        let webViewFrame = CGRect(x: 0, y: 0, width: 400, height: 600)
        touchGridSystem.updateWebViewFrame(webViewFrame)
        
        let testPoint = CGPoint(x: 200, y: 300)
        let success = await touchGridSystem.executeTouchAt(testPoint, type: .tap)
        
        XCTAssertTrue(success)
        XCTAssertEqual(touchGridSystem.touchHistory.count, 1)
        XCTAssertEqual(touchGridSystem.touchHistory.first?.type, .tap)
    }
    
    func testTouchAnalytics() {
        // Generate some test touches
        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 300, y: 300)
        ]
        
        for point in points {
            _ = touchGridSystem.generateTouchEvent(at: point, type: .tap)
        }
        
        let analytics = touchGridSystem.getTouchAnalytics()
        
        XCTAssertEqual(analytics.totalTouches, 3)
        XCTAssertEqual(analytics.touchTypeDistribution[.tap], 3)
        XCTAssertGreaterThan(analytics.averageAccuracy, 0.0)
        XCTAssertNotNil(analytics.lastTouchTime)
    }
    
    func testCalibrationWithScreenshot() async {
        let testImage = createTestImage(size: CGSize(width: 400, height: 600))
        
        await touchGridSystem.calibrateWithScreenshot(testImage)
        
        XCTAssertTrue(touchGridSystem.isCalibrated)
    }
    
    func testHistoryLimit() {
        // Generate more than 100 touches to test history limit
        for i in 0..<150 {
            let point = CGPoint(x: Double(i % 100), y: Double(i % 100))
            _ = touchGridSystem.generateTouchEvent(at: point, type: .tap)
        }
        
        XCTAssertEqual(touchGridSystem.touchHistory.count, 100)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}
