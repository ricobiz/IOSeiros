
//
//  AutomationController.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit
import WebKit
import Combine

@MainActor
class AutomationController: ObservableObject {
    static let shared = AutomationController()
    
    // MARK: - Published Properties
    @Published var isAutomationActive = false
    @Published var currentTask: AutomationTask?
    @Published var executionLog: [AutomationLogEntry] = []
    @Published var lastScreenshot: UIImage?
    @Published var automationMode: AutomationMode = .manual
    
    // Status and metrics
    @Published var tasksCompleted = 0
    @Published var tasksSuccessful = 0
    @Published var averageExecutionTime: TimeInterval = 0
    @Published var isProcessing = false
    
    // MARK: - Dependencies
    private let visionManager = VisionManager.shared
    private let touchGridSystem = TouchGridSystem.shared
    private let qwen2VLManager = Qwen2VLManager.shared
    private let openRouterManager = OpenRouterManager.shared
    private let enhancedLLMManager = EnhancedLLMManager.shared
    
    // MARK: - Private Properties
    private var webViewManager: WebViewManager?
    private var cancellables = Set<AnyCancellable>()
    private var executionTimes: [TimeInterval] = []
    private let maxLogEntries = 100
    
    // Configuration
    private let config = AutomationConfig(
        screenshotInterval: 2.0,
        maxRetries: 3,
        timeoutDuration: 30.0,
        enableLogging: true
    )
    
    private init() {
        setupBindings()
        initializeComponents()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor component states
        visionManager.$isProcessing
            .combineLatest(qwen2VLManager.$isProcessing, touchGridSystem.$isEnabled)
            .sink { [weak self] visionProcessing, qwenProcessing, touchEnabled in
                self?.isProcessing = visionProcessing || qwenProcessing
            }
            .store(in: &cancellables)
    }
    
    private func initializeComponents() {
        // Initialize TouchGridSystem
        touchGridSystem.isEnabled = true
        
        // Load Qwen2VL model if available
        Task {
            if qwen2VLManager.isAvailable {
                await qwen2VLManager.loadModel()
            }
        }
        
        addLogEntry("AutomationController initialized", type: .info)
    }
    
    // MARK: - WebView Integration
    
    func setWebViewManager(_ manager: WebViewManager) {
        webViewManager = manager
        
        // Update TouchGridSystem with WebView frame
        let webViewFrame = manager.webView.frame
        touchGridSystem.updateWebViewFrame(webViewFrame)
        
        addLogEntry("WebView integrated with AutomationController", type: .info)
    }
    
    // MARK: - Task Execution
    
    func executeTask(_ task: AutomationTask) async {
        guard !isAutomationActive else {
            addLogEntry("Automation already active, cannot start new task", type: .warning)
            return
        }
        
        isAutomationActive = true
        currentTask = task
        let startTime = Date()
        
        addLogEntry("Starting task: \(task.name)", type: .info)
        
        do {
            let success = try await performTaskExecution(task)
            
            if success {
                tasksSuccessful += 1
                addLogEntry("Task completed successfully: \(task.name)", type: .success)
            } else {
                addLogEntry("Task failed: \(task.name)", type: .error)
            }
            
            tasksCompleted += 1
            updateExecutionMetrics(startTime: startTime)
            
        } catch {
            addLogEntry("Task execution error: \(error.localizedDescription)", type: .error)
        }
        
        isAutomationActive = false
        currentTask = nil
    }
    
    private func performTaskExecution(_ task: AutomationTask) async throws -> Bool {
        var success = false
        var retryCount = 0
        
        while !success && retryCount < config.maxRetries {
            if retryCount > 0 {
                addLogEntry("Retrying task (attempt \(retryCount + 1))", type: .info)
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            }
            
            success = try await executeTaskSteps(task)
            retryCount += 1
        }
        
        return success
    }
    
    private func executeTaskSteps(_ task: AutomationTask) async throws -> Bool {
        for (index, step) in task.steps.enumerated() {
            addLogEntry("Executing step \(index + 1): \(step.description)", type: .info)
            
            let stepSuccess = try await executeStep(step)
            
            if !stepSuccess {
                addLogEntry("Step \(index + 1) failed", type: .error)
                return false
            }
            
            // Wait between steps
            if index < task.steps.count - 1 {
                try await Task.sleep(nanoseconds: UInt64(step.delayAfter * 1_000_000_000))
            }
        }
        
        return true
    }
    
    private func executeStep(_ step: AutomationStep) async throws -> Bool {
        // Take screenshot for analysis
        guard let screenshot = await captureScreenshot() else {
            throw AutomationError.screenshotFailed
        }
        
        lastScreenshot = screenshot
        
        // Analyze screenshot based on automation mode
        let analysisResult = await analyzeScreenshot(screenshot, for: step)
        
        guard let result = analysisResult else {
            throw AutomationError.analysisFailed
        }
        
        // Execute the step action
        return await executeStepAction(step, with: result)
    }
    
    // MARK: - Screenshot Analysis
    
    private func captureScreenshot() async -> UIImage? {
        guard let webViewManager = webViewManager else {
            addLogEntry("WebView manager not available", type: .error)
            return nil
        }
        
        do {
            let screenshot = try await webViewManager.webView.takeSnapshot(with: nil)
            
            // Calibrate TouchGridSystem with screenshot
            await touchGridSystem.calibrateWithScreenshot(screenshot)
            
            return screenshot
        } catch {
            addLogEntry("Screenshot capture failed: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    private func analyzeScreenshot(_ screenshot: UIImage, for step: AutomationStep) async -> ScreenAnalysisResult? {
        switch automationMode {
        case .manual:
            return await analyzeWithVisionFramework(screenshot)
        case .qwen2vl:
            return await analyzeWithQwen2VL(screenshot, step: step)
        case .openRouter:
            return await analyzeWithOpenRouter(screenshot, step: step)
        case .hybrid:
            return await analyzeWithHybridApproach(screenshot, step: step)
        }
    }
    
    private func analyzeWithVisionFramework(_ screenshot: UIImage) async -> ScreenAnalysisResult? {
        let result = await visionManager.analyzeScreen(screenshot)
        
        return ScreenAnalysisResult(
            elements: result.uiElements,
            textContent: result.detectedText.map { $0.text }.joined(separator: " "),
            confidence: 0.8,
            analysisMethod: "Vision Framework"
        )
    }
    
    private func analyzeWithQwen2VL(_ screenshot: UIImage, step: AutomationStep) async -> ScreenAnalysisResult? {
        let intent = AutomationIntent(
            type: step.action.automationIntentType,
            description: step.description,
            parameters: step.parameters
        )
        
        guard let result = await qwen2VLManager.analyzeForAutomation(screenshot, intent: intent) else {
            return nil
        }
        
        let elements = result.detectedElements.map { qwenElement in
            UIElement(
                type: qwenElement.type.uiElementType,
                text: qwenElement.text,
                boundingBox: qwenElement.boundingBox,
                confidence: qwenElement.confidence,
                isInteractable: qwenElement.isInteractable
            )
        }
        
        return ScreenAnalysisResult(
            elements: elements,
            textContent: result.detectedElements.map { $0.text }.joined(separator: " "),
            confidence: result.confidence,
            analysisMethod: "Qwen2-VL"
        )
    }
    
    private func analyzeWithOpenRouter(_ screenshot: UIImage, step: AutomationStep) async -> ScreenAnalysisResult? {
        let context = "Analyze this screenshot for UI automation. I need to \(step.description). Please identify relevant UI elements and their coordinates."
        
        let analysisText = await openRouterManager.analyzeScreenWithContext(image: screenshot, context: context)
        
        // Parse OpenRouter response (simplified)
        // In a real implementation, this would parse structured data
        return ScreenAnalysisResult(
            elements: [], // Would parse from OpenRouter response
            textContent: analysisText,
            confidence: 0.7,
            analysisMethod: "OpenRouter"
        )
    }
    
    private func analyzeWithHybridApproach(_ screenshot: UIImage, step: AutomationStep) async -> ScreenAnalysisResult? {
        // Use Vision Framework for basic detection
        let visionResult = await analyzeWithVisionFramework(screenshot)
        
        // Enhance with Qwen2VL if available
        if qwen2VLManager.isModelLoaded {
            let qwenResult = await analyzeWithQwen2VL(screenshot, step: step)
            
            // Combine results
            if let vision = visionResult, let qwen = qwenResult {
                return ScreenAnalysisResult(
                    elements: vision.elements + qwen.elements,
                    textContent: "\(vision.textContent)\n\(qwen.textContent)",
                    confidence: (vision.confidence + qwen.confidence) / 2,
                    analysisMethod: "Hybrid (Vision + Qwen2VL)"
                )
            }
        }
        
        return visionResult
    }
    
    // MARK: - Action Execution
    
    private func executeStepAction(_ step: AutomationStep, with analysis: ScreenAnalysisResult) async -> Bool {
        switch step.action {
        case .tap(let selector):
            return await executeTapAction(selector: selector, analysis: analysis)
        case .typeText(let text, let selector):
            return await executeTypeAction(text: text, selector: selector, analysis: analysis)
        case .scroll(let direction):
            return await executeScrollAction(direction: direction, analysis: analysis)
        case .wait(let duration):
            return await executeWaitAction(duration: duration)
        case .screenshot:
            return await executeScreenshotAction()
        case .custom(let action):
            return await executeCustomAction(action, analysis: analysis)
        }
    }
    
    private func executeTapAction(selector: String, analysis: ScreenAnalysisResult) async -> Bool {
        // Find element to tap
        let targetElement = findElement(selector: selector, in: analysis.elements)
        
        guard let element = targetElement else {
            addLogEntry("Could not find element with selector: \(selector)", type: .error)
            return false
        }
        
        let tapPoint = touchGridSystem.getOptimalTouchPoint(for: element)
        let success = await touchGridSystem.executeTouchAt(tapPoint, type: .tap)
        
        if success {
            addLogEntry("Tapped element at \(tapPoint)", type: .success)
            
            // Also execute JavaScript tap if WebView is available
            if let webViewManager = webViewManager {
                await webViewManager.clickElement(selector: selector)
            }
        } else {
            addLogEntry("Failed to tap element at \(tapPoint)", type: .error)
        }
        
        return success
    }
    
    private func executeTypeAction(text: String, selector: String, analysis: ScreenAnalysisResult) async -> Bool {
        // Find text input element
        let targetElement = findElement(selector: selector, in: analysis.elements)
        
        guard let element = targetElement, element.type == .textField else {
            addLogEntry("Could not find text field with selector: \(selector)", type: .error)
            return false
        }
        
        // First tap to focus
        let tapPoint = touchGridSystem.getOptimalTouchPoint(for: element)
        let tapSuccess = await touchGridSystem.executeTouchAt(tapPoint, type: .tap)
        
        if !tapSuccess {
            return false
        }
        
        // Wait for focus
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Type text via JavaScript
        if let webViewManager = webViewManager {
            await webViewManager.typeText(text, selector: selector)
            addLogEntry("Typed text '\(text)' into field", type: .success)
            return true
        }
        
        return false
    }
    
    private func executeScrollAction(direction: ScrollDirection, analysis: ScreenAnalysisResult) async -> Bool {
        guard let webViewManager = webViewManager else {
            return false
        }
        
        let scrollScript = """
        window.scrollBy({
            left: \(direction == .left ? -300 : direction == .right ? 300 : 0),
            top: \(direction == .up ? -300 : direction == .down ? 300 : 0),
            behavior: 'smooth'
        });
        """
        
        do {
            _ = try await webViewManager.webView.evaluateJavaScript(scrollScript)
            addLogEntry("Scrolled \(direction.rawValue)", type: .success)
            return true
        } catch {
            addLogEntry("Scroll failed: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    private func executeWaitAction(duration: TimeInterval) async -> Bool {
        addLogEntry("Waiting for \(duration) seconds", type: .info)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        return true
    }
    
    private func executeScreenshotAction() async -> Bool {
        guard let screenshot = await captureScreenshot() else {
            return false
        }
        
        lastScreenshot = screenshot
        addLogEntry("Screenshot captured", type: .success)
        return true
    }
    
    private func executeCustomAction(_ action: String, analysis: ScreenAnalysisResult) async -> Bool {
        addLogEntry("Executing custom action: \(action)", type: .info)
        
        // Custom action implementation would go here
        // For now, just simulate success
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func findElement(selector: String, in elements: [UIElement]) -> UIElement? {
        // Simple selector matching - in a real implementation, this would be more sophisticated
        return elements.first { element in
            element.text.lowercased().contains(selector.lowercased()) ||
            selector.lowercased().contains(element.text.lowercased())
        }
    }
    
    private func updateExecutionMetrics(startTime: Date) {
        let executionTime = Date().timeIntervalSince(startTime)
        executionTimes.append(executionTime)
        
        if executionTimes.count > 20 {
            executionTimes.removeFirst()
        }
        
        averageExecutionTime = executionTimes.reduce(0, +) / Double(executionTimes.count)
    }
    
    private func addLogEntry(_ message: String, type: AutomationLogType) {
        let entry = AutomationLogEntry(
            message: message,
            type: type,
            timestamp: Date()
        )
        
        executionLog.append(entry)
        
        // Keep log size manageable
        if executionLog.count > maxLogEntries {
            executionLog.removeFirst()
        }
        
        if config.enableLogging {
            print("AutomationController: [\(type.rawValue.uppercased())] \(message)")
        }
    }
    
    // MARK: - Public Interface
    
    func setAutomationMode(_ mode: AutomationMode) {
        automationMode = mode
        addLogEntry("Automation mode changed to: \(mode.displayName)", type: .info)
    }
    
    func stopAutomation() {
        isAutomationActive = false
        currentTask = nil
        addLogEntry("Automation stopped by user", type: .info)
    }
    
    func clearLog() {
        executionLog.removeAll()
    }
    
    func getAutomationStatus() -> AutomationStatus {
        return AutomationStatus(
            isActive: isAutomationActive,
            currentTask: currentTask?.name,
            mode: automationMode,
            tasksCompleted: tasksCompleted,
            successRate: tasksCompleted > 0 ? Double(tasksSuccessful) / Double(tasksCompleted) : 0.0,
            averageExecutionTime: averageExecutionTime,
            componentsReady: getComponentsStatus()
        )
    }
    
    private func getComponentsStatus() -> [String: Bool] {
        return [
            "VisionManager": visionManager.lastAnalysisResult != nil,
            "TouchGridSystem": touchGridSystem.isCalibrated,
            "Qwen2VLManager": qwen2VLManager.isModelLoaded,
            "OpenRouterManager": openRouterManager.isConfigured,
            "WebViewManager": webViewManager != nil
        ]
    }
}

// MARK: - Supporting Data Models

struct AutomationConfig {
    let screenshotInterval: TimeInterval
    let maxRetries: Int
    let timeoutDuration: TimeInterval
    let enableLogging: Bool
}

struct AutomationTask {
    let id = UUID()
    let name: String
    let description: String
    let steps: [AutomationStep]
    let priority: TaskPriority
    let estimatedDuration: TimeInterval
}

struct AutomationStep {
    let description: String
    let action: AutomationStepAction
    let parameters: [String: String]
    let delayAfter: TimeInterval
    let isOptional: Bool
    
    init(description: String, action: AutomationStepAction, parameters: [String: String] = [:], delayAfter: TimeInterval = 1.0, isOptional: Bool = false) {
        self.description = description
        self.action = action
        self.parameters = parameters
        self.delayAfter = delayAfter
        self.isOptional = isOptional
    }
}

enum AutomationStepAction {
    case tap(selector: String)
    case typeText(text: String, selector: String)
    case scroll(direction: ScrollDirection)
    case wait(duration: TimeInterval)
    case screenshot
    case custom(action: String)
    
    var automationIntentType: AutomationIntentType {
        switch self {
        case .tap: return .tap
        case .typeText: return .fillForm
        case .scroll: return .scroll
        case .wait, .screenshot, .custom: return .navigate
        }
    }
}

enum ScrollDirection: String, CaseIterable {
    case up = "up"
    case down = "down"
    case left = "left"
    case right = "right"
}

enum TaskPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum AutomationMode: String, CaseIterable {
    case manual = "manual"
    case qwen2vl = "qwen2vl"
    case openRouter = "openRouter"
    case hybrid = "hybrid"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual (Vision Framework)"
        case .qwen2vl: return "Qwen2-VL"
        case .openRouter: return "OpenRouter"
        case .hybrid: return "Hybrid"
        }
    }
}

struct ScreenAnalysisResult {
    let elements: [UIElement]
    let textContent: String
    let confidence: Float
    let analysisMethod: String
}

struct AutomationLogEntry: Identifiable {
    let id = UUID()
    let message: String
    let type: AutomationLogType
    let timestamp: Date
}

enum AutomationLogType: String, CaseIterable {
    case info = "info"
    case success = "success"
    case warning = "warning"
    case error = "error"
    
    var color: UIColor {
        switch self {
        case .info: return .systemBlue
        case .success: return .systemGreen
        case .warning: return .systemOrange
        case .error: return .systemRed
        }
    }
}

struct AutomationStatus {
    let isActive: Bool
    let currentTask: String?
    let mode: AutomationMode
    let tasksCompleted: Int
    let successRate: Double
    let averageExecutionTime: TimeInterval
    let componentsReady: [String: Bool]
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var formattedExecutionTime: String {
        return String(format: "%.2f s", averageExecutionTime)
    }
}

enum AutomationError: Error, LocalizedError {
    case screenshotFailed
    case analysisFailed
    case elementNotFound
    case actionFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .screenshotFailed: return "Failed to capture screenshot"
        case .analysisFailed: return "Failed to analyze screenshot"
        case .elementNotFound: return "UI element not found"
        case .actionFailed: return "Action execution failed"
        case .timeout: return "Operation timed out"
        }
    }
}

// MARK: - Extensions

extension Qwen2VLElementType {
    var uiElementType: UIElementType {
        switch self {
        case .button: return .button
        case .textField: return .textField
        case .label: return .label
        case .image: return .image
        case .link: return .button // Treat links as buttons for interaction
        case .searchField: return .textField
        case .scrollView: return .unknown
        }
    }
}
