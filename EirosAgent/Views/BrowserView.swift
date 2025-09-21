//
//  BrowserView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI
import WebKit

struct BrowserView: View {
    @StateObject private var webViewManager = WebViewManager()
    @StateObject private var automationController = AutomationController.shared
    @State private var urlText = "https://www.google.com"
    @State private var isLoading = false
    @State private var showAutomationPanel = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Navigation Bar
                HStack {
                    Button(action: { webViewManager.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    .disabled(!webViewManager.canGoBack)
                    
                    Button(action: { webViewManager.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                    }
                    .disabled(!webViewManager.canGoForward)
                    
                    Button(action: { webViewManager.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    // Automation Panel Toggle
                    Button(action: { showAutomationPanel.toggle() }) {
                        Image(systemName: "gearshape.2")
                            .font(.title2)
                            .foregroundColor(showAutomationPanel ? .blue : .gray)
                    }
                    
                    // OCR Button
                    Button(action: captureAndOCR) {
                        Image(systemName: "text.viewfinder")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                    
                    // AI Action Button
                    Button(action: executeAIAction) {
                        Image(systemName: "brain")
                            .font(.title2)
                            .foregroundColor(automationController.isAutomationActive ? .green : .blue)
                    }
                }
                .padding(.horizontal)
                
                // URL Bar
                HStack {
                    TextField("Enter URL", text: $urlText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            loadURL()
                        }
                    
                    Button("Go") {
                        loadURL()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                // Progress Bar
                if isLoading || automationController.isProcessing {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                }
                
                // Automation Panel
                if showAutomationPanel {
                    AutomationPanelView()
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                // WebView
                WebViewRepresentable(webViewManager: webViewManager)
                    .onChange(of: webViewManager.isLoading) { loading in
                        isLoading = loading
                    }
                    .onChange(of: webViewManager.currentURL) { url in
                        if let url = url {
                            urlText = url.absoluteString
                        }
                    }
                    .onAppear {
                        // Integrate WebView with AutomationController
                        automationController.setWebViewManager(webViewManager)
                    }
            }
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadURL()
            }
        }
    }
    
    private func loadURL() {
        guard let url = URL(string: urlText.hasPrefix("http") ? urlText : "https://\(urlText)") else { return }
        webViewManager.load(url: url)
    }
    
    private func captureAndOCR() {
        Task {
            await webViewManager.performOCR()
        }
    }
    
    private func executeAIAction() {
        // Create a simple automation task
        let task = AutomationTask(
            name: "AI Web Analysis",
            description: "Analyze current webpage and suggest actions",
            steps: [
                AutomationStep(
                    description: "Take screenshot and analyze",
                    action: .screenshot
                )
            ],
            priority: .medium,
            estimatedDuration: 5.0
        )
        
        Task {
            await automationController.executeTask(task)
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var webViewManager: WebViewManager
    
    func makeUIView(context: Context) -> WKWebView {
        return webViewManager.webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
}

#Preview {
    BrowserView()
}
