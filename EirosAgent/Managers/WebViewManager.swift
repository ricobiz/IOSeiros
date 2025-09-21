//
//  WebViewManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import WebKit
import Vision
import UIKit
import Combine

@MainActor
class WebViewManager: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
    @Published var ocrResults: [String] = []
    
    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        
        // Inject agent.js script
        if let agentScript = loadAgentScript() {
            let userScript = WKUserScript(source: agentScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            configuration.userContentController.addUserScript(userScript)
        }
        
        // Add message handler for agent communication
        configuration.userContentController.add(self, name: "eirosAgent")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        return webView
    }()
    
    override init() {
        super.init()
    }
    
    // MARK: - Navigation Methods
    
    func load(url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func goBack() {
        webView.goBack()
    }
    
    func goForward() {
        webView.goForward()
    }
    
    func reload() {
        webView.reload()
    }
    
    // MARK: - OCR Methods
    
    func performOCR() async {
        do {
            let image = try await captureScreenshot()
            let recognizedText = try await recognizeText(in: image)
            ocrResults = recognizedText
            
            // Send OCR results to LLM for analysis
            let ocrText = recognizedText.joined(separator: "\n")
            await LLMManager.shared.sendMessage("I captured text from the current webpage: \(ocrText). What should I do with this information?")
        } catch {
            print("OCR failed: \(error)")
        }
    }
    
    private func captureScreenshot() async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "Screenshot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture screenshot"]))
                }
            }
        }
    }
    
    private func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "Vision", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognizedStrings = observations.compactMap { observation in
                    return try? observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedStrings)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - Agent Script Methods
    
    func executeAgentScript() async {
        // Execute agent.js functions for automation
        let script = """
        if (window.EirosAgent) {
            window.EirosAgent.analyzeCurrentPage();
        }
        """
        
        do {
            _ = try await webView.evaluateJavaScript(script)
        } catch {
            print("Agent script execution failed: \(error)")
        }
    }
    
    func clickElement(selector: String) async {
        let script = """
        if (window.EirosAgent) {
            window.EirosAgent.clickElement('\(selector)');
        }
        """
        
        do {
            _ = try await webView.evaluateJavaScript(script)
        } catch {
            print("Click element failed: \(error)")
        }
    }
    
    func typeText(_ text: String, selector: String) async {
        let script = """
        if (window.EirosAgent) {
            window.EirosAgent.typeText('\(text)', '\(selector)');
        }
        """
        
        do {
            _ = try await webView.evaluateJavaScript(script)
        } catch {
            print("Type text failed: \(error)")
        }
    }
    
    func getPageContent() async -> String? {
        let script = """
        if (window.EirosAgent) {
            return window.EirosAgent.getPageContent();
        }
        return document.body.innerText;
        """
        
        do {
            let result = try await webView.evaluateJavaScript(script)
            return result as? String
        } catch {
            print("Get page content failed: \(error)")
            return nil
        }
    }
    
    private func loadAgentScript() -> String? {
        // In a real implementation, this would load from a file
        // For now, return a basic inline script
        return """
        window.EirosAgent = {
            clickElement: function(selector) {
                const element = document.querySelector(selector);
                if (element) {
                    element.click();
                    webkit.messageHandlers.eirosAgent.postMessage({
                        type: 'elementClicked',
                        selector: selector
                    });
                }
            },
            
            typeText: function(text, selector) {
                const element = document.querySelector(selector);
                if (element) {
                    element.value = text;
                    element.dispatchEvent(new Event('input', { bubbles: true }));
                    webkit.messageHandlers.eirosAgent.postMessage({
                        type: 'textTyped',
                        selector: selector,
                        text: text
                    });
                }
            },
            
            getPageContent: function() {
                return {
                    title: document.title,
                    url: window.location.href,
                    text: document.body.innerText,
                    links: Array.from(document.links).map(link => ({
                        href: link.href,
                        text: link.textContent
                    })),
                    forms: Array.from(document.forms).map(form => ({
                        action: form.action,
                        method: form.method,
                        inputs: Array.from(form.elements).map(input => ({
                            type: input.type,
                            name: input.name,
                            placeholder: input.placeholder
                        }))
                    }))
                };
            },
            
            analyzeCurrentPage: function() {
                const analysis = this.getPageContent();
                webkit.messageHandlers.eirosAgent.postMessage({
                    type: 'pageAnalysis',
                    data: analysis
                });
            }
        };
        
        // Auto-analyze page when loaded
        window.addEventListener('load', function() {
            setTimeout(function() {
                if (window.EirosAgent) {
                    window.EirosAgent.analyzeCurrentPage();
                }
            }, 1000);
        });
        """
    }
}

// MARK: - WKNavigationDelegate

extension WebViewManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url
        pageTitle = webView.title ?? ""
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }
}

// MARK: - WKUIDelegate

extension WebViewManager: WKUIDelegate {
    // Handle JavaScript alerts, confirmations, etc.
}

// MARK: - WKScriptMessageHandler

extension WebViewManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "eirosAgent",
              let messageBody = message.body as? [String: Any],
              let type = messageBody["type"] as? String else {
            return
        }
        
        Task {
            switch type {
            case "pageAnalysis":
                if let data = messageBody["data"] {
                    await handlePageAnalysis(data)
                }
            case "elementClicked":
                if let selector = messageBody["selector"] as? String {
                    await handleElementClick(selector)
                }
            case "textTyped":
                if let selector = messageBody["selector"] as? String,
                   let text = messageBody["text"] as? String {
                    await handleTextInput(selector: selector, text: text)
                }
            default:
                break
            }
        }
    }
    
    private func handlePageAnalysis(_ data: Any) async {
        // Send page analysis to LLM for processing
        let analysisText = "Page analysis completed. I can see the current webpage structure and content."
        await LLMManager.shared.sendMessage("Web page analyzed: \(analysisText)")
    }
    
    private func handleElementClick(_ selector: String) async {
        print("Element clicked: \(selector)")
    }
    
    private func handleTextInput(selector: String, text: String) async {
        print("Text typed in \(selector): \(text)")
    }
}
