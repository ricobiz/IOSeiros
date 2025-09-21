
//
//  EnhancedLLMManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import Combine
import UIKit

@MainActor
class EnhancedLLMManager: ObservableObject {
    static let shared = EnhancedLLMManager()
    
    @Published var isModelLoaded = false
    @Published var chatHistory: [EnhancedChatMessage] = []
    @Published var isGenerating = false
    @Published var currentModel: LLMModel = .llama2_7b
    @Published var supportedModalities: Set<Modality> = [.text, .vision]
    
    // Performance metrics
    @Published var lastInferenceTime = "N/A"
    @Published var averageResponseTime = "N/A"
    @Published var memoryUsage = "N/A"
    
    // Vision integration
    private let visionManager = VisionManager.shared
    private let screenCaptureManager = ScreenCaptureManager.shared
    private let qwen2VLManager = Qwen2VLManager.shared
    private let touchGridSystem = TouchGridSystem.shared
    
    // Model information
    var modelInfo: EnhancedModelInfo? {
        guard isModelLoaded else { return nil }
        return EnhancedModelInfo(
            name: currentModel.displayName,
            size: currentModel.size,
            memoryUsage: memoryUsage,
            parameters: currentModel.parameters,
            supportedModalities: supportedModalities,
            capabilities: currentModel.capabilities
        )
    }
    
    private var modelContext: OpaquePointer?
    private var responseTimes: [Double] = []
    
    private init() {
        setupInitialMessage()
    }
    
    private func setupInitialMessage() {
        let welcomeMessage = EnhancedChatMessage(
            content: "Hello! I'm Eiros, your enhanced AI assistant with visual capabilities. I can analyze screenshots, recognize text, detect objects, and help you automate tasks. How can I assist you today?",
            isUser: false,
            messageType: .text,
            attachments: []
        )
        chatHistory.append(welcomeMessage)
    }
    
    // MARK: - Model Management
    
    func loadModel(_ model: LLMModel = .llama2_7b) {
        Task {
            isGenerating = true
            currentModel = model
            
            // Simulate model loading with different times based on model size
            let loadingTime = model.loadingTime
            try? await Task.sleep(nanoseconds: UInt64(loadingTime * 1_000_000_000))
            
            // In a real implementation, this would load the actual model
            // modelContext = llamacpp_load_model(getModelPath(for: model))
            
            isModelLoaded = true
            isGenerating = false
            
            updateMemoryUsage()
        }
    }
    
    func switchModel(to model: LLMModel) {
        Task {
            isModelLoaded = false
            isGenerating = true
            
            // Cleanup existing model
            if let context = modelContext {
                // llamacpp_free_model(context)
                modelContext = nil
            }
            
            await loadModel(model)
            
            let switchMessage = EnhancedChatMessage(
                content: "Switched to \(model.displayName). Ready to assist with \(model.capabilities.joined(separator: ", ")).",
                isUser: false,
                messageType: .system,
                attachments: []
            )
            chatHistory.append(switchMessage)
        }
    }
    
    // MARK: - Enhanced Messaging
    
    func sendMessage(_ message: String, attachments: [MessageAttachment] = []) async {
        let userMessage = EnhancedChatMessage(
            content: message,
            isUser: true,
            messageType: determineMessageType(content: message, attachments: attachments),
            attachments: attachments
        )
        chatHistory.append(userMessage)
        
        guard isModelLoaded else {
            let errorMessage = EnhancedChatMessage(
                content: "Model is not loaded. Please wait for initialization to complete.",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(errorMessage)
            return
        }
        
        isGenerating = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Generate enhanced response based on message type and attachments
        let response = await generateEnhancedResponse(for: message, attachments: attachments)
        
        chatHistory.append(response)
        
        // Update performance metrics
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        updatePerformanceMetrics(responseTime: responseTime)
        
        isGenerating = false
    }
    
    // MARK: - Vision-Enhanced Features
    
    func analyzeScreenshot() async {
        guard let screenshot = await screenCaptureManager.captureScreen() else {
            let errorMessage = EnhancedChatMessage(
                content: "Failed to capture screenshot. Please try again.",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(errorMessage)
            return
        }
        
        let attachment = MessageAttachment(type: .image, data: screenshot.pngData() ?? Data(), metadata: ["source": "screenshot"])
        
        await sendMessage("Analyze this screenshot", attachments: [attachment])
    }
    
    func analyzeImage(_ image: UIImage, prompt: String = "Analyze this image") async {
        let attachment = MessageAttachment(type: .image, data: image.pngData() ?? Data(), metadata: ["source": "user_provided"])
        await sendMessage(prompt, attachments: [attachment])
    }
    
    func extractTextFromScreen() async {
        guard let screenshot = await screenCaptureManager.captureScreen() else {
            let errorMessage = EnhancedChatMessage(
                content: "Failed to capture screenshot for text extraction.",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(errorMessage)
            return
        }
        
        let detectedTexts = await visionManager.recognizeText(in: screenshot)
        
        if detectedTexts.isEmpty {
            let message = EnhancedChatMessage(
                content: "No text detected in the current screen.",
                isUser: false,
                messageType: .text,
                attachments: []
            )
            chatHistory.append(message)
        } else {
            let extractedText = detectedTexts.map { $0.text }.joined(separator: "\n")
            let message = EnhancedChatMessage(
                content: "Extracted text from screen:\n\n\(extractedText)",
                isUser: false,
                messageType: .text,
                attachments: []
            )
            chatHistory.append(message)
        }
    }
    
    func findUIElements(matching description: String) async {
        guard let screenshot = await screenCaptureManager.captureScreen() else {
            let errorMessage = EnhancedChatMessage(
                content: "Failed to capture screenshot for UI analysis.",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(errorMessage)
            return
        }
        
        let analysisResult = await visionManager.analyzeScreen(screenshot)
        let matchingElements = analysisResult.uiElements.filter { element in
            element.text.lowercased().contains(description.lowercased()) ||
            element.type.rawValue.lowercased().contains(description.lowercased())
        }
        
        if matchingElements.isEmpty {
            let message = EnhancedChatMessage(
                content: "No UI elements found matching '\(description)' in the current screen.",
                isUser: false,
                messageType: .text,
                attachments: []
            )
            chatHistory.append(message)
        } else {
            let elementDescriptions = matchingElements.map { element in
                "- \(element.type.rawValue.capitalized): '\(element.text)' (confidence: \(String(format: "%.1f", element.confidence * 100))%)"
            }.joined(separator: "\n")
            
            let message = EnhancedChatMessage(
                content: "Found \(matchingElements.count) UI elements matching '\(description)':\n\n\(elementDescriptions)",
                isUser: false,
                messageType: .text,
                attachments: []
            )
            chatHistory.append(message)
        }
    }
    
    // MARK: - Qwen2-VL Enhanced Features
    
    func performUIAutomation(task: String) async {
        guard let screenshot = await screenCaptureManager.captureScreen() else {
            let errorMessage = EnhancedChatMessage(
                content: "Failed to capture screenshot for UI automation.",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(errorMessage)
            return
        }
        
        // Determine task type from natural language
        let automationTask = parseUIAutomationTask(from: task)
        let result = await qwen2VLManager.analyzeScreenForUIAutomation(screenshot, task: automationTask)
        
        var responseContent = ""
        
        if result.success {
            responseContent = """
            🎯 **UI Automation Analysis Complete**
            
            **Task**: \(task)
            **Elements Found**: \(result.elements.count)
            **Confidence**: \(Int(result.confidence * 100))%
            **Processing Time**: \(String(format: "%.2fs", result.processingTime))
            
            """
            
            if !result.elements.isEmpty {
                responseContent += "**Detected Elements**:\n"
                for (index, element) in result.elements.enumerated() {
                    responseContent += "\(index + 1). \(element.type.rawValue.capitalized): '\(element.text)'\n"
                    responseContent += "   Position: (\(Int(element.boundingBox.midX)), \(Int(element.boundingBox.midY)))\n"
                    if element.isInteractable {
                        responseContent += "   ✅ Interactable\n"
                    }
                }
            }
            
            if !result.coordinates.isEmpty {
                responseContent += "\n**Touch Coordinates**:\n"
                for (index, coordinate) in result.coordinates.enumerated() {
                    responseContent += "\(index + 1). (\(Int(coordinate.x)), \(Int(coordinate.y)))\n"
                }
                
                // Highlight elements on touch grid
                touchGridSystem.highlightElementsOnGrid(result.elements)
            }
            
            if let modelResponse = result.modelResponse {
                responseContent += "\n**Qwen2-VL Analysis**:\n\(modelResponse)"
            }
            
        } else {
            responseContent = "❌ UI Automation failed: \(result.error ?? "Unknown error")"
        }
        
        let message = EnhancedChatMessage(
            content: responseContent,
            isUser: false,
            messageType: .vision,
            attachments: []
        )
        chatHistory.append(message)
    }
    
    func simulateTouch(at description: String) async {
        guard let screenshot = await screenCaptureManager.captureScreen() else {
            let errorMessage = EnhancedChatMessage(
                content: "Failed to capture screenshot for touch simulation.",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(errorMessage)
            return
        }
        
        let task = UIAutomationTask(type: .clickElement, target: description)
        let result = await qwen2VLManager.analyzeScreenForUIAutomation(screenshot, task: task)
        
        if result.success && !result.coordinates.isEmpty {
            let touchPoint = result.coordinates.first!
            
            // Map to grid system
            let gridCoordinate = touchGridSystem.coordinateMapper.mapToTouchGrid(touchPoint, gridSize: touchGridSystem.gridSize)
            touchGridSystem.selectCell(at: gridCoordinate)
            
            let message = EnhancedChatMessage(
                content: """
                🎯 **Touch Simulation Ready**
                
                **Target**: \(description)
                **Touch Point**: (\(Int(touchPoint.x)), \(Int(touchPoint.y)))
                **Grid Cell**: \(gridCoordinate.description)
                **Confidence**: \(Int(result.confidence * 100))%
                
                The touch point has been highlighted on the grid. You can now execute the touch action.
                """,
                isUser: false,
                messageType: .vision,
                attachments: []
            )
            chatHistory.append(message)
        } else {
            let message = EnhancedChatMessage(
                content: "❌ Could not locate '\(description)' for touch simulation. \(result.error ?? "")",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(message)
        }
    }
    
    func analyzeScreenWithQwen2VL() async {
        guard let screenshot = await screenCaptureManager.captureScreen() else {
            let errorMessage = EnhancedChatMessage(
                content: "Failed to capture screenshot for Qwen2-VL analysis.",
                isUser: false,
                messageType: .error,
                attachments: []
            )
            chatHistory.append(errorMessage)
            return
        }
        
        let task = UIAutomationTask(type: .describeScreen, target: "comprehensive analysis")
        let result = await qwen2VLManager.analyzeScreenForUIAutomation(screenshot, task: task)
        
        var responseContent = """
        🔍 **Qwen2-VL Screen Analysis**
        
        **Model**: Qwen2-VL-2B (2B parameters)
        **Processing Time**: \(String(format: "%.2fs", result.processingTime))
        **Confidence**: \(Int(result.confidence * 100))%
        
        """
        
        if result.success {
            responseContent += """
            **UI Elements Detected**: \(result.elements.count)
            **Interactive Elements**: \(result.elements.filter { $0.isInteractable }.count)
            **Touch Points**: \(result.coordinates.count)
            
            """
            
            // Group elements by type
            let elementsByType = Dictionary(grouping: result.elements) { $0.type }
            
            for (type, elements) in elementsByType {
                responseContent += "**\(type.rawValue.capitalized)s** (\(elements.count)):\n"
                for element in elements.prefix(3) {
                    responseContent += "• \(element.text.isEmpty ? "Unnamed \(type.rawValue)" : element.text)\n"
                }
                if elements.count > 3 {
                    responseContent += "• ... and \(elements.count - 3) more\n"
                }
                responseContent += "\n"
            }
            
            if let modelResponse = result.modelResponse {
                responseContent += "**Detailed Analysis**:\n\(modelResponse)"
            }
            
            // Highlight elements on grid
            touchGridSystem.highlightElementsOnGrid(result.elements)
            
        } else {
            responseContent += "❌ Analysis failed: \(result.error ?? "Unknown error")"
        }
        
        let message = EnhancedChatMessage(
            content: responseContent,
            isUser: false,
            messageType: .vision,
            attachments: []
        )
        chatHistory.append(message)
    }
    
    private func parseUIAutomationTask(from description: String) -> UIAutomationTask {
        let lowercased = description.lowercased()
        
        if lowercased.contains("find") && lowercased.contains("button") {
            let target = extractTarget(from: description, keywords: ["button"])
            return UIAutomationTask(type: .findButton, target: target)
        } else if lowercased.contains("find") && (lowercased.contains("text") || lowercased.contains("field")) {
            let target = extractTarget(from: description, keywords: ["text", "field", "input"])
            return UIAutomationTask(type: .findTextField, target: target)
        } else if lowercased.contains("click") || lowercased.contains("tap") {
            let target = extractTarget(from: description, keywords: ["click", "tap"])
            return UIAutomationTask(type: .clickElement, target: target)
        } else if lowercased.contains("extract") && lowercased.contains("text") {
            return UIAutomationTask(type: .extractText, target: "all text")
        } else if lowercased.contains("describe") || lowercased.contains("analyze") {
            return UIAutomationTask(type: .describeScreen, target: "screen analysis")
        } else if lowercased.contains("navigate") || lowercased.contains("go to") {
            let target = extractTarget(from: description, keywords: ["navigate", "go to"])
            return UIAutomationTask(type: .navigateToElement, target: target)
        } else {
            // Default to finding element
            return UIAutomationTask(type: .findElement, target: description)
        }
    }
    
    private func extractTarget(from description: String, keywords: [String]) -> String {
        var target = description
        
        // Remove common keywords to extract the actual target
        for keyword in keywords {
            target = target.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
        }
        
        // Clean up the target string
        target = target.trimmingCharacters(in: .whitespacesAndPunctuationCharacters)
        
        return target.isEmpty ? description : target
    }
    
    // MARK: - Response Generation
    
    private func generateEnhancedResponse(for prompt: String, attachments: [MessageAttachment]) async -> EnhancedChatMessage {
        // Handle different types of requests
        if !attachments.isEmpty {
            return await generateVisionResponse(for: prompt, attachments: attachments)
        } else if prompt.lowercased().contains("screenshot") || prompt.lowercased().contains("screen") {
            return await generateScreenAnalysisResponse(for: prompt)
        } else {
            return await generateTextResponse(for: prompt)
        }
    }
    
    private func generateVisionResponse(for prompt: String, attachments: [MessageAttachment]) async -> EnhancedChatMessage {
        // Process image attachments
        for attachment in attachments where attachment.type == .image {
            if let image = UIImage(data: attachment.data) {
                let analysisResult = await visionManager.analyzeScreen(image)
                
                let response = """
                I've analyzed the image and found:
                
                📝 Text Elements: \(analysisResult.detectedText.count)
                \(analysisResult.detectedText.prefix(5).map { "• \($0.text) (confidence: \(String(format: "%.1f", $0.confidence * 100))%)" }.joined(separator: "\n"))
                
                🔍 Objects: \(analysisResult.detectedObjects.count)
                \(analysisResult.detectedObjects.prefix(3).map { "• \($0.label)" }.joined(separator: "\n"))
                
                🎯 UI Elements: \(analysisResult.uiElements.count)
                \(analysisResult.uiElements.filter { $0.isInteractable }.prefix(3).map { "• \($0.type.rawValue.capitalized): \($0.text)" }.joined(separator: "\n"))
                
                \(analysisResult.screenDescription)
                
                Processing time: \(String(format: "%.2f", analysisResult.processingTime))s
                """
                
                return EnhancedChatMessage(
                    content: response,
                    isUser: false,
                    messageType: .vision,
                    attachments: []
                )
            }
        }
        
        return EnhancedChatMessage(
            content: "I couldn't process the attached image. Please try again.",
            isUser: false,
            messageType: .error,
            attachments: []
        )
    }
    
    private func generateScreenAnalysisResponse(for prompt: String) async -> EnhancedChatMessage {
        // Simulate processing time
        let processingTime = UInt64.random(in: 1_000_000_000...2_000_000_000)
        try? await Task.sleep(nanoseconds: processingTime)
        
        let response = """
        I can help you analyze the current screen! Here's what I can do:
        
        📸 **Screenshot Analysis**: Capture and analyze the current screen
        📝 **Text Extraction**: Find and extract all readable text
        🎯 **UI Element Detection**: Identify buttons, fields, and interactive elements
        🔍 **Object Recognition**: Detect shapes and visual elements
        
        Would you like me to:
        1. Take a screenshot and analyze it
        2. Extract text from the current screen
        3. Find specific UI elements
        4. Detect objects in the current view
        
        Just let me know what you'd like to explore!
        """
        
        return EnhancedChatMessage(
            content: response,
            isUser: false,
            messageType: .text,
            attachments: []
        )
    }
    
    private func generateTextResponse(for prompt: String) async -> EnhancedChatMessage {
        // Check for Qwen2-VL specific commands first
        let lowercased = prompt.lowercased()
        
        // UI Automation commands
        if lowercased.contains("find") && (lowercased.contains("button") || lowercased.contains("element") || lowercased.contains("field")) {
            await performUIAutomation(task: prompt)
            return EnhancedChatMessage(content: "", isUser: false, messageType: .vision, attachments: []) // Empty as performUIAutomation handles the response
        } else if lowercased.contains("click") || lowercased.contains("tap") {
            await simulateTouch(at: prompt)
            return EnhancedChatMessage(content: "", isUser: false, messageType: .vision, attachments: [])
        } else if lowercased.contains("analyze") && lowercased.contains("qwen") {
            await analyzeScreenWithQwen2VL()
            return EnhancedChatMessage(content: "", isUser: false, messageType: .vision, attachments: [])
        } else if lowercased.contains("grid") || lowercased.contains("touch grid") {
            let gridStats = touchGridSystem.getGridStatistics()
            return EnhancedChatMessage(
                content: """
                📊 **Touch Grid System Status**
                
                **Grid Configuration**: \(Int(gridStats.gridSize.width))×\(Int(gridStats.gridSize.height))
                **Total Cells**: \(gridStats.totalCells)
                **Cell Size**: \(Int(gridStats.cellSize.width))×\(Int(gridStats.cellSize.height)) pixels
                **Grid Visible**: \(touchGridSystem.isGridVisible ? "Yes" : "No")
                
                **Commands**:
                • "Show grid" - Display touch grid overlay
                • "Hide grid" - Hide touch grid overlay
                • "Find button [name]" - Locate and highlight UI elements
                • "Click [element]" - Simulate touch on element
                
                The touch grid helps visualize and target UI elements for automation.
                """,
                isUser: false,
                messageType: .text,
                attachments: []
            )
        }
        
        // Simulate processing time based on model
        let processingTime = UInt64.random(in: 1_000_000_000...3_000_000_000)
        try? await Task.sleep(nanoseconds: processingTime)
        
        // Enhanced responses based on prompt content
        if lowercased.contains("hello") || lowercased.contains("hi") {
            return EnhancedChatMessage(
                content: """
                Hello! I'm your enhanced AI assistant powered by Qwen2-VL-2B for advanced UI automation. 
                
                🎯 **New Capabilities**:
                • Mobile UI element detection (90.8% accuracy on Android Control)
                • Screen element positioning (84.7% accuracy on ScreenSpot)
                • Natural language UI automation
                • Touch grid system for precise interactions
                
                Try commands like:
                • "Find the login button"
                • "Click on settings"
                • "Analyze screen with Qwen2-VL"
                • "Show touch grid"
                
                What would you like to explore?
                """,
                isUser: false,
                messageType: .text,
                attachments: []
            )
        } else if lowercased.contains("help") {
            return EnhancedChatMessage(
                content: """
                I'm Eiros with Qwen2-VL-2B integration! Here's what I can help you with:
                
                🧠 **Text Conversations**: Answer questions and have discussions
                👁️ **Visual Analysis**: Analyze images and screenshots with Qwen2-VL
                📱 **UI Automation**: Advanced mobile interface automation
                📝 **Text Recognition**: Multi-language OCR with high accuracy
                🎯 **Element Detection**: Precise UI element identification
                🔲 **Touch Grid**: Visual grid system for touch targeting
                
                **Qwen2-VL Commands**:
                • "Find [element name]" - Locate UI elements
                • "Click [element]" - Simulate touch interactions
                • "Analyze screen with Qwen2-VL" - Comprehensive screen analysis
                • "Extract text from screen" - OCR text extraction
                • "Show/hide touch grid" - Toggle grid overlay
                
                **Model Info**:
                • Qwen2-VL-2B (2 billion parameters)
                • Specialized for mobile UI automation
                • 90.8% accuracy on Android Control tasks
                • Supports arbitrary image resolutions
                
                What would you like to try?
                """,
                isUser: false,
                messageType: .text,
                attachments: []
            )
        } else if lowercased.contains("model") || lowercased.contains("capability") || lowercased.contains("qwen") {
            let qwenInfo = qwen2VLManager.modelInfo
            return EnhancedChatMessage(
                content: """
                **Current Models**:
                
                🔹 **Primary LLM**: \(currentModel.displayName)
                \(currentModel.capabilities.map { "• \($0)" }.joined(separator: "\n"))
                
                🔹 **Vision Model**: \(qwenInfo.name) (\(qwenInfo.version))
                • Parameters: \(qwenInfo.parameters)
                • Status: \(qwen2VLManager.isModelLoaded ? "✅ Loaded" : "⏳ Loading")
                
                **Qwen2-VL Capabilities**:
                \(qwenInfo.capabilities.map { "• \($0)" }.joined(separator: "\n"))
                
                **Benchmark Performance**:
                \(qwenInfo.benchmarkScores.map { "• \($0.key): \($0.value)%" }.joined(separator: "\n"))
                
                **Performance Metrics**:
                • Memory Usage: \(qwen2VLManager.memoryUsage)
                • Last Inference: \(String(format: "%.2fs", qwen2VLManager.lastInferenceTime))
                • Average Time: \(String(format: "%.2fs", qwen2VLManager.averageInferenceTime))
                
                **Supported Features**:
                • Resolution: \(qwenInfo.supportedResolutions)
                • Video Length: \(qwenInfo.maxVideoLength)
                • Languages: Multi-language OCR support
                
                Both models run entirely on your device for privacy and speed!
                """,
                isUser: false,
                messageType: .text,
                attachments: []
            )
        } else {
            return EnhancedChatMessage(
                content: """
                I understand your question about '\(prompt)'. As an enhanced AI assistant with Qwen2-VL-2B integration, I can help with both text conversations and advanced UI automation tasks.
                
                💡 **Suggestions**:
                • Ask me to analyze the current screen
                • Request UI element detection
                • Try natural language automation commands
                • Upload images for visual analysis
                
                How else can I help you with UI automation or visual analysis?
                """,
                isUser: false,
                messageType: .text,
                attachments: []
            )
        }
    }
    
    // MARK: - Utility Methods
    
    private func determineMessageType(content: String, attachments: [MessageAttachment]) -> MessageType {
        if !attachments.isEmpty && attachments.contains(where: { $0.type == .image }) {
            return .vision
        } else if content.lowercased().contains("screenshot") || content.lowercased().contains("analyze") {
            return .vision
        } else {
            return .text
        }
    }
    
    private func updatePerformanceMetrics(responseTime: Double) {
        responseTimes.append(responseTime)
        lastInferenceTime = String(format: "%.2f s", responseTime)
        
        if responseTimes.count > 10 {
            responseTimes.removeFirst()
        }
        
        let avgTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        averageResponseTime = String(format: "%.2f s", avgTime)
    }
    
    private func updateMemoryUsage() {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryMB = Int(info.resident_size / 1024 / 1024)
            memoryUsage = "\(memoryMB) MB"
        } else {
            memoryUsage = "Unknown"
        }
    }
    
    func clearChatHistory() {
        chatHistory.removeAll()
        setupInitialMessage()
    }
}

// MARK: - Enhanced Data Models

struct EnhancedChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let messageType: MessageType
    let attachments: [MessageAttachment]
    let timestamp: Date
    
    init(content: String, isUser: Bool, messageType: MessageType, attachments: [MessageAttachment]) {
        self.content = content
        self.isUser = isUser
        self.messageType = messageType
        self.attachments = attachments
        self.timestamp = Date()
    }
}

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case vision = "vision"
    case system = "system"
    case error = "error"
}

struct MessageAttachment: Identifiable, Codable {
    let id = UUID()
    let type: AttachmentType
    let data: Data
    let metadata: [String: String]
    
    init(type: AttachmentType, data: Data, metadata: [String: String] = [:]) {
        self.type = type
        self.data = data
        self.metadata = metadata
    }
}

enum AttachmentType: String, Codable, CaseIterable {
    case image = "image"
    case document = "document"
    case audio = "audio"
}

enum Modality: String, Codable, CaseIterable {
    case text = "text"
    case vision = "vision"
    case audio = "audio"
}

enum LLMModel: String, Codable, CaseIterable {
    case llama2_7b = "llama2_7b"
    case llama2_13b = "llama2_13b"
    case codellama_7b = "codellama_7b"
    case mistral_7b = "mistral_7b"
    
    var displayName: String {
        switch self {
        case .llama2_7b: return "Llama 2 7B"
        case .llama2_13b: return "Llama 2 13B"
        case .codellama_7b: return "Code Llama 7B"
        case .mistral_7b: return "Mistral 7B"
        }
    }
    
    var size: String {
        switch self {
        case .llama2_7b: return "~4.2 GB"
        case .llama2_13b: return "~8.1 GB"
        case .codellama_7b: return "~4.1 GB"
        case .mistral_7b: return "~4.0 GB"
        }
    }
    
    var parameters: String {
        switch self {
        case .llama2_7b, .codellama_7b, .mistral_7b: return "7B"
        case .llama2_13b: return "13B"
        }
    }
    
    var loadingTime: Double {
        switch self {
        case .llama2_7b, .codellama_7b, .mistral_7b: return 2.0
        case .llama2_13b: return 4.0
        }
    }
    
    var capabilities: [String] {
        switch self {
        case .llama2_7b: return ["General conversation", "Text analysis", "Vision integration"]
        case .llama2_13b: return ["Advanced reasoning", "Complex analysis", "Vision integration"]
        case .codellama_7b: return ["Code generation", "Programming help", "Technical analysis"]
        case .mistral_7b: return ["Fast responses", "Efficient processing", "General tasks"]
        }
    }
}

struct EnhancedModelInfo {
    let name: String
    let size: String
    let memoryUsage: String
    let parameters: String
    let supportedModalities: Set<Modality>
    let capabilities: [String]
}
