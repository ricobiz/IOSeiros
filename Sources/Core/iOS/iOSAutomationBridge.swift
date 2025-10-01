
//
//  iOSAutomationBridge.swift
//  EirosAgent
//
//  iOS Automation Bridge for DECODO Integration
//  Created: 2025-09-22
//

import Foundation
import UIKit
import WebKit
import Combine

// MARK: - iOS Automation Bridge

@MainActor
public class iOSAutomationBridge: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = iOSAutomationBridge()
    
    // MARK: - Published Properties
    @Published public var isEnabled = false
    @Published public var currentWebView: WKWebView?
    @Published public var automationStatus: iOSAutomationStatus = .idle
    @Published public var lastScreenshot: UIImage?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let proxyManager = ProxyManager.shared
    private let visionManager = VisionManager.shared
    private var webViewConfiguration: WKWebViewConfiguration?
    private var currentSession: iOSAutomationSession?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupWebViewConfiguration()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    public func enableAutomation() {
        isEnabled = true
        automationStatus = .ready
    }
    
    public func disableAutomation() {
        isEnabled = false
        automationStatus = .idle
        currentWebView = nil
        currentSession = nil
    }
    
    public func createWebView(with proxyConfiguration: ProxyConfiguration? = nil) -> WKWebView {
        let config = createWebViewConfiguration(with: proxyConfiguration)
        let webView = WKWebView(frame: .zero, configuration: config)
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        currentWebView = webView
        
        return webView
    }
    
    public func navigateToURL(_ urlString: String, in webView: WKWebView? = nil) async -> NavigationResult {
        guard let targetWebView = webView ?? currentWebView else {
            return NavigationResult(success: false, error: "No WebView available")
        }
        
        guard let url = URL(string: urlString) else {
            return NavigationResult(success: false, error: "Invalid URL")
        }
        
        automationStatus = .navigating
        
        return await withCheckedContinuation { continuation in
            let request = URLRequest(url: url)
            targetWebView.load(request)
            
            // Set up a timeout and completion handler
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                if self.automationStatus == .navigating {
                    self.automationStatus = .error("Navigation timeout")
                    continuation.resume(returning: NavigationResult(success: false, error: "Navigation timeout"))
                }
            }
            
            // Store continuation for completion in delegate methods
            self.navigationContinuation = continuation
        }
    }
    
    public func captureScreenshot(of webView: WKWebView? = nil) async -> ScreenshotResult {
        guard let targetWebView = webView ?? currentWebView else {
            return ScreenshotResult(success: false, error: "No WebView available", imageData: nil)
        }
        
        automationStatus = .capturingScreenshot
        
        return await withCheckedContinuation { continuation in
            let config = WKSnapshotConfiguration()
            config.rect = targetWebView.bounds
            
            targetWebView.takeSnapshot(with: config) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.automationStatus = .error("Screenshot failed: \(error.localizedDescription)")
                        continuation.resume(returning: ScreenshotResult(
                            success: false,
                            error: error.localizedDescription,
                            imageData: nil
                        ))
                    } else if let image = image {
                        self?.lastScreenshot = image
                        self?.automationStatus = .ready
                        
                        let imageData = image.pngData()
                        continuation.resume(returning: ScreenshotResult(
                            success: true,
                            error: nil,
                            imageData: imageData
                        ))
                    } else {
                        self?.automationStatus = .error("Screenshot failed: Unknown error")
                        continuation.resume(returning: ScreenshotResult(
                            success: false,
                            error: "Unknown error",
                            imageData: nil
                        ))
                    }
                }
            }
        }
    }
    
    public func executeJavaScript(_ script: String, in webView: WKWebView? = nil) async -> JavaScriptResult {
        guard let targetWebView = webView ?? currentWebView else {
            return JavaScriptResult(success: false, result: nil, error: "No WebView available")
        }
        
        automationStatus = .executingScript
        
        return await withCheckedContinuation { continuation in
            targetWebView.evaluateJavaScript(script) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.automationStatus = .error("JavaScript failed: \(error.localizedDescription)")
                        continuation.resume(returning: JavaScriptResult(
                            success: false,
                            result: nil,
                            error: error.localizedDescription
                        ))
                    } else {
                        self?.automationStatus = .ready
                        continuation.resume(returning: JavaScriptResult(
                            success: true,
                            result: result,
                            error: nil
                        ))
                    }
                }
            }
        }
    }
    
    public func clickElement(selector: String, in webView: WKWebView? = nil) async -> ActionResult {
        let script = """
            (function() {
                var element = document.querySelector('\(selector)');
                if (element) {
                    element.click();
                    return { success: true, message: 'Element clicked' };
                } else {
                    return { success: false, message: 'Element not found' };
                }
            })();
        """
        
        let jsResult = await executeJavaScript(script, in: webView)
        
        if jsResult.success {
            if let resultDict = jsResult.result as? [String: Any],
               let success = resultDict["success"] as? Bool {
                return ActionResult(
                    success: success,
                    error: success ? nil : (resultDict["message"] as? String),
                    data: nil,
                    metadata: ["selector": selector, "action": "click"]
                )
            }
        }
        
        return ActionResult(
            success: false,
            error: jsResult.error ?? "Failed to click element",
            data: nil,
            metadata: ["selector": selector, "action": "click"]
        )
    }
    
    public func typeText(_ text: String, in selector: String, webView: WKWebView? = nil) async -> ActionResult {
        let script = """
            (function() {
                var element = document.querySelector('\(selector)');
                if (element) {
                    element.value = '\(text.replacingOccurrences(of: "'", with: "\\'"))';
                    element.dispatchEvent(new Event('input', { bubbles: true }));
                    element.dispatchEvent(new Event('change', { bubbles: true }));
                    return { success: true, message: 'Text entered' };
                } else {
                    return { success: false, message: 'Element not found' };
                }
            })();
        """
        
        let jsResult = await executeJavaScript(script, in: webView)
        
        if jsResult.success {
            if let resultDict = jsResult.result as? [String: Any],
               let success = resultDict["success"] as? Bool {
                return ActionResult(
                    success: success,
                    error: success ? nil : (resultDict["message"] as? String),
                    data: nil,
                    metadata: ["selector": selector, "text": text, "action": "type"]
                )
            }
        }
        
        return ActionResult(
            success: false,
            error: jsResult.error ?? "Failed to type text",
            data: nil,
            metadata: ["selector": selector, "text": text, "action": "type"]
        )
    }
    
    public func extractText(from selector: String, webView: WKWebView? = nil) async -> ExtractionResult {
        let script = """
            (function() {
                var elements = document.querySelectorAll('\(selector)');
                var results = [];
                for (var i = 0; i < elements.length; i++) {
                    results.push({
                        text: elements[i].textContent || elements[i].innerText || '',
                        html: elements[i].innerHTML || '',
                        attributes: {}
                    });
                }
                return { success: true, results: results };
            })();
        """
        
        let jsResult = await executeJavaScript(script, in: webView)
        
        if jsResult.success {
            if let resultDict = jsResult.result as? [String: Any],
               let success = resultDict["success"] as? Bool,
               success,
               let results = resultDict["results"] as? [[String: Any]] {
                
                let extractedData = results.compactMap { result -> ExtractedElement? in
                    guard let text = result["text"] as? String else { return nil }
                    return ExtractedElement(
                        text: text,
                        html: result["html"] as? String ?? "",
                        attributes: result["attributes"] as? [String: String] ?? [:]
                    )
                }
                
                return ExtractionResult(
                    success: true,
                    elements: extractedData,
                    error: nil
                )
            }
        }
        
        return ExtractionResult(
            success: false,
            elements: [],
            error: jsResult.error ?? "Failed to extract text"
        )
    }
    
    public func scrollPage(direction: ScrollDirection, amount: Int = 1, webView: WKWebView? = nil) async -> ActionResult {
        let script: String
        
        switch direction {
        case .up:
            script = "window.scrollBy(0, -\(amount * 100));"
        case .down:
            script = "window.scrollBy(0, \(amount * 100));"
        case .left:
            script = "window.scrollBy(-\(amount * 100), 0);"
        case .right:
            script = "window.scrollBy(\(amount * 100), 0);"
        case .top:
            script = "window.scrollTo(0, 0);"
        case .bottom:
            script = "window.scrollTo(0, document.body.scrollHeight);"
        }
        
        let jsResult = await executeJavaScript(script, in: webView)
        
        return ActionResult(
            success: jsResult.success,
            error: jsResult.error,
            data: nil,
            metadata: ["direction": direction.rawValue, "amount": amount, "action": "scroll"]
        )
    }
    
    public func waitForElement(selector: String, timeout: TimeInterval = 10.0, webView: WKWebView? = nil) async -> ActionResult {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let script = """
                (function() {
                    var element = document.querySelector('\(selector)');
                    return element !== null;
                })();
            """
            
            let jsResult = await executeJavaScript(script, in: webView)
            
            if jsResult.success, let exists = jsResult.result as? Bool, exists {
                return ActionResult(
                    success: true,
                    error: nil,
                    data: nil,
                    metadata: ["selector": selector, "waitTime": Date().timeIntervalSince(startTime), "action": "wait"]
                )
            }
            
            // Wait 0.5 seconds before checking again
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        return ActionResult(
            success: false,
            error: "Element not found within timeout",
            data: nil,
            metadata: ["selector": selector, "timeout": timeout, "action": "wait"]
        )
    }
    
    // MARK: - Integration with DECODO
    
    public func executeAutomationWithDECODO(task: iOSAutomationTask) async -> iOSAutomationResult {
        guard isEnabled else {
            return iOSAutomationResult(success: false, error: "iOS automation is disabled", data: nil, screenshots: [])
        }
        
        let session = iOSAutomationSession(task: task)
        currentSession = session
        automationStatus = .executing
        
        var results: [ActionResult] = []
        var screenshots: [Data] = []
        var extractedData: [String: Any] = [:]
        
        // Create WebView with proxy if needed
        let webView: WKWebView
        if task.useProxy, let proxyConfig = proxyManager.currentProxy {
            webView = createWebView(with: proxyConfig)
        } else {
            webView = createWebView()
        }
        
        for action in task.actions {
            do {
                let result = await executeAction(action, webView: webView, session: session)
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
                
                if !result.success && task.stopOnError {
                    automationStatus = .error("Action failed: \(result.error ?? "Unknown error")")
                    break
                }
                
                // Add delay between actions
                if action.delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(action.delay * 1_000_000_000))
                }
                
            } catch {
                let errorResult = ActionResult(
                    success: false,
                    error: error.localizedDescription,
                    data: nil,
                    metadata: ["action": action.type.rawValue]
                )
                results.append(errorResult)
                
                if task.stopOnError {
                    automationStatus = .error("Action execution error: \(error.localizedDescription)")
                    break
                }
            }
        }
        
        let successfulActions = results.filter { $0.success }.count
        let success = successfulActions > 0 || !task.stopOnError
        
        automationStatus = success ? .completed : .error("Multiple actions failed")
        currentSession = nil
        
        return iOSAutomationResult(
            success: success,
            error: success ? nil : "Multiple actions failed",
            data: extractedData.isEmpty ? nil : try? JSONSerialization.data(withJSONObject: extractedData),
            screenshots: screenshots
        )
    }
    
    // MARK: - Private Methods
    
    private func setupWebViewConfiguration() {
        let config = WKWebViewConfiguration()
        
        // Enable JavaScript
        config.preferences.javaScriptEnabled = true
        
        // Allow arbitrary loads for development
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        // Set up user content controller for JavaScript injection
        let userContentController = WKUserContentController()
        config.userContentController = userContentController
        
        self.webViewConfiguration = config
    }
    
    private func createWebViewConfiguration(with proxyConfiguration: ProxyConfiguration? = nil) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // Copy base configuration
        config.preferences.javaScriptEnabled = true
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        // Set up proxy if provided
        if let proxy = proxyConfiguration {
            // Configure proxy settings
            // Note: WKWebView proxy configuration is limited on iOS
            // For full proxy support, we rely on DECODO's Site Unblocker approach
        }
        
        return config
    }
    
    private func setupBindings() {
        proxyManager.$isProxyEnabled
            .sink { [weak self] isEnabled in
                if !isEnabled && self?.currentSession?.task.useProxy == true {
                    self?.automationStatus = .error("Proxy disabled during automation")
                }
            }
            .store(in: &cancellables)
    }
    
    private func executeAction(_ action: iOSAutomationAction, webView: WKWebView, session: iOSAutomationSession) async -> ActionResult {
        switch action.type {
        case .navigate:
            let navResult = await navigateToURL(action.target, in: webView)
            return ActionResult(
                success: navResult.success,
                error: navResult.error,
                data: nil,
                metadata: ["url": action.target, "action": "navigate"]
            )
            
        case .screenshot:
            let screenshotResult = await captureScreenshot(of: webView)
            return ActionResult(
                success: screenshotResult.success,
                error: screenshotResult.error,
                data: screenshotResult.imageData,
                metadata: ["action": "screenshot"]
            )
            
        case .click:
            return await clickElement(selector: action.target, in: webView)
            
        case .type:
            let text = action.parameters["text"] ?? ""
            return await typeText(text, in: action.target, webView: webView)
            
        case .extract:
            let extractResult = await extractText(from: action.target, webView: webView)
            let jsonData = try? JSONSerialization.data(withJSONObject: extractResult.elements.map { element in
                ["text": element.text, "html": element.html, "attributes": element.attributes]
            })
            
            return ActionResult(
                success: extractResult.success,
                error: extractResult.error,
                data: jsonData,
                metadata: ["selector": action.target, "action": "extract"]
            )
            
        case .wait:
            let duration = Double(action.parameters["duration"] ?? "1.0") ?? 1.0
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            return ActionResult(
                success: true,
                error: nil,
                data: nil,
                metadata: ["duration": duration, "action": "wait"]
            )
            
        case .scroll:
            let direction = ScrollDirection(rawValue: action.parameters["direction"] ?? "down") ?? .down
            let amount = Int(action.parameters["amount"] ?? "1") ?? 1
            
            return await scrollPage(direction: direction, amount: amount, webView: webView)
        }
    }
    
    // MARK: - Navigation Continuation
    private var navigationContinuation: CheckedContinuation<NavigationResult, Never>?
}

// MARK: - WKNavigationDelegate

extension iOSAutomationBridge: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        automationStatus = .ready
        
        if let continuation = navigationContinuation {
            navigationContinuation = nil
            continuation.resume(returning: NavigationResult(success: true, error: nil))
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        automationStatus = .error("Navigation failed: \(error.localizedDescription)")
        
        if let continuation = navigationContinuation {
            navigationContinuation = nil
            continuation.resume(returning: NavigationResult(success: false, error: error.localizedDescription))
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        automationStatus = .error("Navigation failed: \(error.localizedDescription)")
        
        if let continuation = navigationContinuation {
            navigationContinuation = nil
            continuation.resume(returning: NavigationResult(success: false, error: error.localizedDescription))
        }
    }
}

// MARK: - WKUIDelegate

extension iOSAutomationBridge: WKUIDelegate {
    // Handle JavaScript alerts, confirms, etc.
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        // Auto-dismiss alerts during automation
        completionHandler()
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        // Auto-confirm during automation
        completionHandler(true)
    }
}

// MARK: - Supporting Types

public enum iOSAutomationStatus {
    case idle
    case ready
    case navigating
    case capturingScreenshot
    case executingScript
    case executing
    case completed
    case error(String)
    
    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .ready:
            return "Ready"
        case .navigating:
            return "Navigating"
        case .capturingScreenshot:
            return "Capturing Screenshot"
        case .executingScript:
            return "Executing Script"
        case .executing:
            return "Executing"
        case .completed:
            return "Completed"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

public struct NavigationResult {
    public let success: Bool
    public let error: String?
    
    public init(success: Bool, error: String?) {
        self.success = success
        self.error = error
    }
}

public struct JavaScriptResult {
    public let success: Bool
    public let result: Any?
    public let error: String?
    
    public init(success: Bool, result: Any?, error: String?) {
        self.success = success
        self.result = result
        self.error = error
    }
}

public struct ExtractionResult {
    public let success: Bool
    public let elements: [ExtractedElement]
    public let error: String?
    
    public init(success: Bool, elements: [ExtractedElement], error: String?) {
        self.success = success
        self.elements = elements
        self.error = error
    }
}

public struct ExtractedElement {
    public let text: String
    public let html: String
    public let attributes: [String: String]
    
    public init(text: String, html: String, attributes: [String: String]) {
        self.text = text
        self.html = html
        self.attributes = attributes
    }
}

public enum ScrollDirection: String, CaseIterable {
    case up = "up"
    case down = "down"
    case left = "left"
    case right = "right"
    case top = "top"
    case bottom = "bottom"
}

public struct iOSAutomationTask {
    public let id: String
    public let name: String
    public let actions: [iOSAutomationAction]
    public let useProxy: Bool
    public let stopOnError: Bool
    
    public init(id: String, name: String, actions: [iOSAutomationAction], useProxy: Bool = true, stopOnError: Bool = false) {
        self.id = id
        self.name = name
        self.actions = actions
        self.useProxy = useProxy
        self.stopOnError = stopOnError
    }
}

public struct iOSAutomationAction {
    public let id: String
    public let type: AutomationAction.ActionType
    public let target: String
    public let parameters: [String: String]
    public let delay: TimeInterval
    
    public init(id: String, type: AutomationAction.ActionType, target: String, parameters: [String: String] = [:], delay: TimeInterval = 0) {
        self.id = id
        self.type = type
        self.target = target
        self.parameters = parameters
        self.delay = delay
    }
}

public struct iOSAutomationResult {
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

private class iOSAutomationSession {
    let task: iOSAutomationTask
    let startTime: Date
    private var sessionData: [String: Any] = [:]
    
    init(task: iOSAutomationTask) {
        self.task = task
        self.startTime = Date()
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
