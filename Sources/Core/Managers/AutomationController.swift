
//
//  AutomationController.swift
//  EirosAgent
//
//  Enhanced Automation Controller with DECODO Integration
//  Created: 2025-09-22
//

import Foundation
import Combine
import UIKit

// MARK: - Automation Controller

@MainActor
public class AutomationController: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AutomationController()
    
    // MARK: - Published Properties
    @Published public var isAutomationEnabled = false
    @Published public var currentTask: AutomationTask?
    @Published public var executionStatus: ExecutionStatus = .idle
    @Published public var executionProgress: Double = 0.0
    @Published public var executionLog: [LogEntry] = []
    @Published public var availableActions: [AutomationActionTemplate] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let proxyManager = ProxyManager.shared
    private let visionManager = VisionManager.shared
    private var executionQueue: OperationQueue
    private var currentSession: AutomationSession?
    
    // MARK: - Initialization
    private init() {
        self.executionQueue = OperationQueue()
        self.executionQueue.maxConcurrentOperationCount = 1
        self.executionQueue.name = "AutomationExecutionQueue"
        
        setupBindings()
        loadActionTemplates()
    }
    
    // MARK: - Public Methods
    
    public func enableAutomation() {
        isAutomationEnabled = true
        addLogEntry("Automation enabled", type: .info)
    }
    
    public func disableAutomation() {
        isAutomationEnabled = false
        stopCurrentTask()
        addLogEntry("Automation disabled", type: .info)
    }
    
    public func executeTask(_ task: AutomationTask) async -> AutomationTaskResult {
        guard isAutomationEnabled else {
            return AutomationTaskResult(success: false, error: "Automation is disabled", data: nil, screenshots: [])
        }
        
        await MainActor.run {
            self.currentTask = task
            self.executionStatus = .running
            self.executionProgress = 0.0
        }
        
        addLogEntry("Starting task: \(task.name)", type: .info)
        
        let session = AutomationSession(task: task)
        self.currentSession = session
        
        do {
            let result = await executeTaskInternal(task, session: session)
            
            await MainActor.run {
                self.executionStatus = result.success ? .completed : .failed
                self.executionProgress = 1.0
                self.currentTask = nil
                self.currentSession = nil
            }
            
            addLogEntry("Task completed: \(result.success ? "Success" : "Failed")", 
                       type: result.success ? .success : .error)
            
            return result
        } catch {
            await MainActor.run {
                self.executionStatus = .failed
                self.executionProgress = 1.0
                self.currentTask = nil
                self.currentSession = nil
            }
            
            addLogEntry("Task failed with error: \(error.localizedDescription)", type: .error)
            
            return AutomationTaskResult(success: false, error: error.localizedDescription, data: nil, screenshots: [])
        }
    }
    
    public func stopCurrentTask() {
        guard let task = currentTask else { return }
        
        executionQueue.cancelAllOperations()
        currentTask = nil
        currentSession = nil
        executionStatus = .cancelled
        
        addLogEntry("Task cancelled: \(task.name)", type: .warning)
    }
    
    public func createScreenshotTask(url: String, options: ScreenshotTaskOptions = ScreenshotTaskOptions()) -> AutomationTask {
        let screenshotAction = AutomationAction(
            id: UUID().uuidString,
            type: .screenshot,
            target: url,
            parameters: [
                "geoLocation": options.geoLocation ?? "",
                "deviceType": options.deviceType.rawValue,
                "sessionId": options.sessionId ?? UUID().uuidString
            ]
        )
        
        return AutomationTask(
            id: UUID().uuidString,
            name: "Screenshot: \(url)",
            description: "Capture screenshot of \(url)",
            actions: [screenshotAction],
            options: AutomationTaskOptions(
                useProxy: true,
                enableJavaScript: true,
                timeout: 60.0
            )
        )
    }
    
    public func createWebScrapingTask(url: String, selectors: [String], options: WebScrapingTaskOptions = WebScrapingTaskOptions()) -> AutomationTask {
        var actions: [AutomationAction] = []
        
        // Navigate to URL
        let navigateAction = AutomationAction(
            id: UUID().uuidString,
            type: .navigate,
            target: url,
            parameters: [
                "geoLocation": options.geoLocation ?? "",
                "deviceType": options.deviceType.rawValue,
                "enableJavaScript": "true"
            ]
        )
        actions.append(navigateAction)
        
        // Wait for page load
        let waitAction = AutomationAction(
            id: UUID().uuidString,
            type: .wait,
            target: "",
            parameters: ["duration": "3.0"]
        )
        actions.append(waitAction)
        
        // Extract data using selectors
        for selector in selectors {
            let extractAction = AutomationAction(
                id: UUID().uuidString,
                type: .extract,
                target: selector,
                parameters: [
                    "attribute": options.extractAttribute ?? "text",
                    "multiple": options.extractMultiple ? "true" : "false"
                ]
            )
            actions.append(extractAction)
        }
        
        // Take final screenshot
        let screenshotAction = AutomationAction(
            id: UUID().uuidString,
            type: .screenshot,
            target: url,
            parameters: [:]
        )
        actions.append(screenshotAction)
        
        return AutomationTask(
            id: UUID().uuidString,
            name: "Web Scraping: \(url)",
            description: "Extract data from \(url) using selectors",
            actions: actions,
            options: AutomationTaskOptions(
                useProxy: true,
                enableJavaScript: true,
                timeout: 120.0
            )
        )
    }
    
    public func getAutomationStatus() -> AutomationStatusReport {
        return AutomationStatusReport(
            isEnabled: isAutomationEnabled,
            currentTask: currentTask?.name,
            executionStatus: executionStatus,
            progress: executionProgress,
            proxyEnabled: proxyManager.isProxyEnabled,
            proxyStatus: proxyManager.connectionStatus,
            visionEnabled: visionManager.isEnabled,
            componentsReady: getComponentsReadiness()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        proxyManager.$isProxyEnabled
            .sink { [weak self] isEnabled in
                if !isEnabled && self?.currentTask?.options.useProxy == true {
                    self?.addLogEntry("Proxy disabled during task execution", type: .warning)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadActionTemplates() {
        availableActions = [
            AutomationActionTemplate(
                id: "screenshot",
                name: "Take Screenshot",
                description: "Capture a screenshot of a webpage",
                type: .screenshot,
                requiredParameters: ["url"],
                optionalParameters: ["geoLocation", "deviceType", "sessionId"]
            ),
            AutomationActionTemplate(
                id: "navigate",
                name: "Navigate to URL",
                description: "Navigate to a specific URL",
                type: .navigate,
                requiredParameters: ["url"],
                optionalParameters: ["geoLocation", "deviceType", "enableJavaScript"]
            ),
            AutomationActionTemplate(
                id: "extract",
                name: "Extract Data",
                description: "Extract data using CSS selectors",
                type: .extract,
                requiredParameters: ["selector"],
                optionalParameters: ["attribute", "multiple"]
            ),
            AutomationActionTemplate(
                id: "click",
                name: "Click Element",
                description: "Click on a webpage element",
                type: .click,
                requiredParameters: ["selector"],
                optionalParameters: ["delay"]
            ),
            AutomationActionTemplate(
                id: "type",
                name: "Type Text",
                description: "Type text into an input field",
                type: .type,
                requiredParameters: ["selector", "text"],
                optionalParameters: ["delay"]
            ),
            AutomationActionTemplate(
                id: "wait",
                name: "Wait",
                description: "Wait for a specified duration",
                type: .wait,
                requiredParameters: ["duration"],
                optionalParameters: []
            ),
            AutomationActionTemplate(
                id: "scroll",
                name: "Scroll Page",
                description: "Scroll the webpage",
                type: .scroll,
                requiredParameters: ["direction"],
                optionalParameters: ["amount"]
            )
        ]
    }
    
    private func executeTaskInternal(_ task: AutomationTask, session: AutomationSession) async -> AutomationTaskResult {
        var results: [ActionResult] = []
        var screenshots: [Data] = []
        var extractedData: [String: Any] = [:]
        
        let totalActions = task.actions.count
        
        for (index, action) in task.actions.enumerated() {
            // Update progress
            await MainActor.run {
                self.executionProgress = Double(index) / Double(totalActions)
            }
            
            addLogEntry("Executing action: \(action.type.rawValue)", type: .info)
            
            do {
                let result = await executeAction(action, session: session)
                results.append(result)
                
                // Handle specific action results
                switch action.type {
                case .screenshot:
                    if let imageData = result.data {
                        screenshots.append(imageData)
                    }
                case .extract:
                    if let data = result.data,
                       let extractedText = String(data: data, encoding: .utf8) {
                        extractedData[action.target] = extractedText
                    }
                default:
                    break
                }
                
                if !result.success {
                    addLogEntry("Action failed: \(result.error ?? "Unknown error")", type: .error)
                    
                    if task.options.stopOnError {
                        return AutomationTaskResult(
                            success: false,
                            error: result.error,
                            data: extractedData.isEmpty ? nil : try? JSONSerialization.data(withJSONObject: extractedData),
                            screenshots: screenshots
                        )
                    }
                }
                
                // Add delay between actions
                if action.delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(action.delay * 1_000_000_000))
                }
                
            } catch {
                addLogEntry("Action execution error: \(error.localizedDescription)", type: .error)
                
                if task.options.stopOnError {
                    return AutomationTaskResult(
                        success: false,
                        error: error.localizedDescription,
                        data: extractedData.isEmpty ? nil : try? JSONSerialization.data(withJSONObject: extractedData),
                        screenshots: screenshots
                    )
                }
            }
        }
        
        let successfulActions = results.filter { $0.success }.count
        let success = successfulActions > 0 || !task.options.stopOnError
        
        return AutomationTaskResult(
            success: success,
            error: success ? nil : "Multiple actions failed",
            data: extractedData.isEmpty ? nil : try? JSONSerialization.data(withJSONObject: extractedData),
            screenshots: screenshots
        )
    }
    
    private func executeAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        switch action.type {
        case .screenshot:
            return await executeScreenshotAction(action, session: session)
        case .navigate:
            return await executeNavigateAction(action, session: session)
        case .extract:
            return await executeExtractAction(action, session: session)
        case .click:
            return await executeClickAction(action, session: session)
        case .type:
            return await executeTypeAction(action, session: session)
        case .wait:
            return await executeWaitAction(action, session: session)
        case .scroll:
            return await executeScrollAction(action, session: session)
        }
    }
    
    private func executeScreenshotAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        let url = action.target
        let geoLocation = action.parameters["geoLocation"]
        let deviceTypeString = action.parameters["deviceType"] ?? "desktop"
        let sessionId = action.parameters["sessionId"]
        
        let deviceType = DeviceType(rawValue: deviceTypeString) ?? .desktop
        
        let options = ScreenshotOptions(
            geoLocation: geoLocation?.isEmpty == false ? geoLocation : nil,
            sessionId: sessionId?.isEmpty == false ? sessionId : nil,
            target: "universal",
            deviceType: deviceType
        )
        
        let result = await proxyManager.captureScreenshotThroughProxy(url: url, options: options)
        
        if result.success {
            // Also analyze the screenshot with Vision if available
            if let imageData = result.imageData, let image = UIImage(data: imageData) {
                let visionResult = await visionManager.analyzeImage(image)
                session.addVisionAnalysis(visionResult)
            }
            
            return ActionResult(
                success: true,
                error: nil,
                data: result.imageData,
                metadata: ["url": url, "deviceType": deviceTypeString]
            )
        } else {
            return ActionResult(
                success: false,
                error: result.error,
                data: nil,
                metadata: ["url": url]
            )
        }
    }
    
    private func executeNavigateAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        // This would integrate with WebView or browser automation
        // For now, we'll simulate navigation
        let url = action.target
        
        addLogEntry("Navigating to: \(url)", type: .info)
        
        // Simulate navigation delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return ActionResult(
            success: true,
            error: nil,
            data: nil,
            metadata: ["url": url, "action": "navigate"]
        )
    }
    
    private func executeExtractAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        // This would use DECODO's structured parsing capabilities
        let selector = action.target
        let attribute = action.parameters["attribute"] ?? "text"
        let multiple = action.parameters["multiple"] == "true"
        
        addLogEntry("Extracting data with selector: \(selector)", type: .info)
        
        // For now, simulate data extraction
        let extractedData = "Extracted data for selector: \(selector)"
        let data = extractedData.data(using: .utf8)
        
        return ActionResult(
            success: true,
            error: nil,
            data: data,
            metadata: ["selector": selector, "attribute": attribute, "multiple": multiple]
        )
    }
    
    private func executeClickAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        let selector = action.target
        let delay = Double(action.parameters["delay"] ?? "0") ?? 0
        
        addLogEntry("Clicking element: \(selector)", type: .info)
        
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return ActionResult(
            success: true,
            error: nil,
            data: nil,
            metadata: ["selector": selector, "action": "click"]
        )
    }
    
    private func executeTypeAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        let selector = action.target
        let text = action.parameters["text"] ?? ""
        let delay = Double(action.parameters["delay"] ?? "0") ?? 0
        
        addLogEntry("Typing text into: \(selector)", type: .info)
        
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return ActionResult(
            success: true,
            error: nil,
            data: nil,
            metadata: ["selector": selector, "text": text, "action": "type"]
        )
    }
    
    private func executeWaitAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        let duration = Double(action.parameters["duration"] ?? "1.0") ?? 1.0
        
        addLogEntry("Waiting for \(duration) seconds", type: .info)
        
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        return ActionResult(
            success: true,
            error: nil,
            data: nil,
            metadata: ["duration": duration, "action": "wait"]
        )
    }
    
    private func executeScrollAction(_ action: AutomationAction, session: AutomationSession) async -> ActionResult {
        let direction = action.parameters["direction"] ?? "down"
        let amount = action.parameters["amount"] ?? "1"
        
        addLogEntry("Scrolling \(direction) by \(amount)", type: .info)
        
        return ActionResult(
            success: true,
            error: nil,
            data: nil,
            metadata: ["direction": direction, "amount": amount, "action": "scroll"]
        )
    }
    
    private func addLogEntry(_ message: String, type: LogEntryType) {
        let entry = LogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            message: message,
            type: type
        )
        
        DispatchQueue.main.async {
            self.executionLog.append(entry)
            
            // Keep only last 100 entries
            if self.executionLog.count > 100 {
                self.executionLog.removeFirst(self.executionLog.count - 100)
            }
        }
    }
    
    private func getComponentsReadiness() -> [String: Bool] {
        return [
            "ProxyManager": proxyManager.isProxyEnabled,
            "VisionManager": visionManager.isEnabled,
            "DECODOConfiguration": DECODOConfiguration.shared.isConfigured,
            "AutomationController": isAutomationEnabled
        ]
    }
}

// MARK: - Supporting Types

public struct AutomationTask: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let actions: [AutomationAction]
    public let options: AutomationTaskOptions
    
    public init(id: String, name: String, description: String, actions: [AutomationAction], options: AutomationTaskOptions) {
        self.id = id
        self.name = name
        self.description = description
        self.actions = actions
        self.options = options
    }
}

public struct AutomationAction: Identifiable {
    public let id: String
    public let type: ActionType
    public let target: String
    public let parameters: [String: String]
    public let delay: TimeInterval
    
    public init(id: String, type: ActionType, target: String, parameters: [String: String] = [:], delay: TimeInterval = 0) {
        self.id = id
        self.type = type
        self.target = target
        self.parameters = parameters
        self.delay = delay
    }
    
    public enum ActionType: String, CaseIterable {
        case screenshot = "screenshot"
        case navigate = "navigate"
        case extract = "extract"
        case click = "click"
        case type = "type"
        case wait = "wait"
        case scroll = "scroll"
    }
}

public struct AutomationTaskOptions {
    public let useProxy: Bool
    public let enableJavaScript: Bool
    public let timeout: TimeInterval
    public let stopOnError: Bool
    
    public init(useProxy: Bool = true, enableJavaScript: Bool = true, timeout: TimeInterval = 60.0, stopOnError: Bool = false) {
        self.useProxy = useProxy
        self.enableJavaScript = enableJavaScript
        self.timeout = timeout
        self.stopOnError = stopOnError
    }
}

public struct ScreenshotTaskOptions {
    public let geoLocation: String?
    public let deviceType: DeviceType
    public let sessionId: String?
    
    public init(geoLocation: String? = nil, deviceType: DeviceType = .desktop, sessionId: String? = nil) {
        self.geoLocation = geoLocation
        self.deviceType = deviceType
        self.sessionId = sessionId
    }
}

public struct WebScrapingTaskOptions {
    public let geoLocation: String?
    public let deviceType: DeviceType
    public let extractAttribute: String?
    public let extractMultiple: Bool
    
    public init(geoLocation: String? = nil, deviceType: DeviceType = .desktop, extractAttribute: String? = nil, extractMultiple: Bool = false) {
        self.geoLocation = geoLocation
        self.deviceType = deviceType
        self.extractAttribute = extractAttribute
        self.extractMultiple = extractMultiple
    }
}

public enum ExecutionStatus: String, CaseIterable {
    case idle = "idle"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .idle:
            return "gray"
        case .running:
            return "blue"
        case .completed:
            return "green"
        case .failed:
            return "red"
        case .cancelled:
            return "orange"
        }
    }
}

public struct AutomationTaskResult {
    public let success: Bool
    public let error: String?
    public let data: Data?
    public let screenshots: [Data]
    
    public init(success: Bool, error: String?, data: Data?, screenshots: [Data]) {
        self.success = success
        self.error = error
        self.data = data
        self.screenshots = screenshots
    }
}

public struct ActionResult {
    public let success: Bool
    public let error: String?
    public let data: Data?
    public let metadata: [String: Any]
    
    public init(success: Bool, error: String?, data: Data?, metadata: [String: Any] = [:]) {
        self.success = success
        self.error = error
        self.data = data
        self.metadata = metadata
    }
}

public struct AutomationActionTemplate: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let type: AutomationAction.ActionType
    public let requiredParameters: [String]
    public let optionalParameters: [String]
    
    public init(id: String, name: String, description: String, type: AutomationAction.ActionType, requiredParameters: [String], optionalParameters: [String]) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.requiredParameters = requiredParameters
        self.optionalParameters = optionalParameters
    }
}

public struct LogEntry: Identifiable {
    public let id: String
    public let timestamp: Date
    public let message: String
    public let type: LogEntryType
    
    public init(id: String, timestamp: Date, message: String, type: LogEntryType) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.type = type
    }
}

public enum LogEntryType: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case success = "success"
    
    var color: String {
        switch self {
        case .info:
            return "blue"
        case .warning:
            return "orange"
        case .error:
            return "red"
        case .success:
            return "green"
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .success:
            return "checkmark.circle"
        }
    }
}

public struct AutomationStatusReport {
    public let isEnabled: Bool
    public let currentTask: String?
    public let executionStatus: ExecutionStatus
    public let progress: Double
    public let proxyEnabled: Bool
    public let proxyStatus: ProxyConnectionStatus
    public let visionEnabled: Bool
    public let componentsReady: [String: Bool]
    
    public init(isEnabled: Bool, currentTask: String?, executionStatus: ExecutionStatus, progress: Double, proxyEnabled: Bool, proxyStatus: ProxyConnectionStatus, visionEnabled: Bool, componentsReady: [String: Bool]) {
        self.isEnabled = isEnabled
        self.currentTask = currentTask
        self.executionStatus = executionStatus
        self.progress = progress
        self.proxyEnabled = proxyEnabled
        self.proxyStatus = proxyStatus
        self.visionEnabled = visionEnabled
        self.componentsReady = componentsReady
    }
}

// MARK: - Automation Session

private class AutomationSession {
    let task: AutomationTask
    let startTime: Date
    private var visionAnalyses: [VisionAnalysisResult] = []
    private var sessionData: [String: Any] = [:]
    
    init(task: AutomationTask) {
        self.task = task
        self.startTime = Date()
    }
    
    func addVisionAnalysis(_ result: VisionAnalysisResult) {
        visionAnalyses.append(result)
    }
    
    func setSessionData(key: String, value: Any) {
        sessionData[key] = value
    }
    
    func getSessionData(key: String) -> Any? {
        return sessionData[key]
    }
    
    var duration: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
}

// MARK: - Vision Manager Placeholder

public class VisionManager: ObservableObject {
    public static let shared = VisionManager()
    
    @Published public var isEnabled = true
    
    private init() {}
    
    public func analyzeImage(_ image: UIImage) async -> VisionAnalysisResult {
        // Placeholder implementation
        return VisionAnalysisResult(
            success: true,
            confidence: 0.95,
            detectedObjects: [],
            text: "Vision analysis placeholder",
            metadata: [:]
        )
    }
}

public struct VisionAnalysisResult {
    public let success: Bool
    public let confidence: Double
    public let detectedObjects: [DetectedObject]
    public let text: String
    public let metadata: [String: Any]
    
    public init(success: Bool, confidence: Double, detectedObjects: [DetectedObject], text: String, metadata: [String: Any]) {
        self.success = success
        self.confidence = confidence
        self.detectedObjects = detectedObjects
        self.text = text
        self.metadata = metadata
    }
}

public struct DetectedObject {
    public let label: String
    public let confidence: Double
    public let boundingBox: CGRect
    
    public init(label: String, confidence: Double, boundingBox: CGRect) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
