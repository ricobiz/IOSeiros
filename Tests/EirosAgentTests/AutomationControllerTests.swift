
//
//  AutomationControllerTests.swift
//  EirosAgentTests
//
//  Created by DeepAgent on 2025-09-21.
//

import XCTest
import UIKit
@testable import EirosAgent

@MainActor
final class AutomationControllerTests: XCTestCase {
    
    var automationController: AutomationController!
    var mockWebViewManager: MockWebViewManager!
    
    override func setUp() async throws {
        try await super.setUp()
        automationController = AutomationController.shared
        mockWebViewManager = MockWebViewManager()
        automationController.setWebViewManager(mockWebViewManager)
    }
    
    override func tearDown() async throws {
        automationController.stopAutomation()
        automationController.clearLog()
        try await super.tearDown()
    }
    
    func testAutomationControllerInitialization() {
        XCTAssertNotNil(automationController)
        XCTAssertFalse(automationController.isAutomationActive)
        XCTAssertEqual(automationController.tasksCompleted, 0)
        XCTAssertEqual(automationController.tasksSuccessful, 0)
    }
    
    func testSetAutomationMode() {
        automationController.setAutomationMode(.qwen2vl)
        XCTAssertEqual(automationController.automationMode, .qwen2vl)
        
        automationController.setAutomationMode(.openRouter)
        XCTAssertEqual(automationController.automationMode, .openRouter)
        
        automationController.setAutomationMode(.hybrid)
        XCTAssertEqual(automationController.automationMode, .hybrid)
    }
    
    func testSimpleTaskExecution() async {
        let task = AutomationTask(
            name: "Test Task",
            description: "Simple test task",
            steps: [
                AutomationStep(
                    description: "Take screenshot",
                    action: .screenshot
                )
            ],
            priority: .low,
            estimatedDuration: 1.0
        )
        
        await automationController.executeTask(task)
        
        XCTAssertEqual(automationController.tasksCompleted, 1)
        XCTAssertFalse(automationController.isAutomationActive)
    }
    
    func testTaskWithMultipleSteps() async {
        let task = AutomationTask(
            name: "Multi-step Task",
            description: "Task with multiple steps",
            steps: [
                AutomationStep(
                    description: "Take screenshot",
                    action: .screenshot,
                    delayAfter: 0.1
                ),
                AutomationStep(
                    description: "Wait",
                    action: .wait(duration: 0.1),
                    delayAfter: 0.1
                ),
                AutomationStep(
                    description: "Tap element",
                    action: .tap(selector: "button"),
                    delayAfter: 0.1
                )
            ],
            priority: .medium,
            estimatedDuration: 2.0
        )
        
        await automationController.executeTask(task)
        
        XCTAssertEqual(automationController.tasksCompleted, 1)
        XCTAssertGreaterThan(automationController.executionLog.count, 0)
    }
    
    func testStopAutomation() async {
        let longTask = AutomationTask(
            name: "Long Task",
            description: "Task that should be stopped",
            steps: [
                AutomationStep(
                    description: "Long wait",
                    action: .wait(duration: 5.0)
                )
            ],
            priority: .low,
            estimatedDuration: 5.0
        )
        
        // Start task asynchronously
        Task {
            await automationController.executeTask(longTask)
        }
        
        // Wait a bit for task to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Stop automation
        automationController.stopAutomation()
        
        XCTAssertFalse(automationController.isAutomationActive)
        XCTAssertNil(automationController.currentTask)
    }
    
    func testAutomationStatus() {
        let status = automationController.getAutomationStatus()
        
        XCTAssertFalse(status.isActive)
        XCTAssertNil(status.currentTask)
        XCTAssertEqual(status.mode, automationController.automationMode)
        XCTAssertEqual(status.tasksCompleted, automationController.tasksCompleted)
        XCTAssertNotNil(status.componentsReady)
    }
    
    func testLogEntryCreation() {
        let initialLogCount = automationController.executionLog.count
        
        // Execute a simple task to generate log entries
        let task = AutomationTask(
            name: "Log Test",
            description: "Test log generation",
            steps: [
                AutomationStep(
                    description: "Screenshot for log test",
                    action: .screenshot
                )
            ],
            priority: .low,
            estimatedDuration: 1.0
        )
        
        Task {
            await automationController.executeTask(task)
        }
        
        // Wait for task completion
        let expectation = XCTestExpectation(description: "Task completion")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertGreaterThan(automationController.executionLog.count, initialLogCount)
    }
}

// MARK: - Mock Classes

class MockWebViewManager: WebViewManager {
    var mockScreenshot: UIImage?
    var mockPageContent: String = "Mock page content"
    
    override func captureScreenshot() async throws -> UIImage {
        if let screenshot = mockScreenshot {
            return screenshot
        }
        
        // Create a simple test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
    
    override func getPageContent() async -> String? {
        return mockPageContent
    }
    
    override func clickElement(selector: String) async {
        // Mock implementation - just log the action
        print("Mock: Clicked element with selector: \(selector)")
    }
    
    override func typeText(_ text: String, selector: String) async {
        // Mock implementation - just log the action
        print("Mock: Typed '\(text)' in element with selector: \(selector)")
    }
}
