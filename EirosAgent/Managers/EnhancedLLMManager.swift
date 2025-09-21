
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
        // Simulate processing time based on model
        let processingTime = UInt64.random(in: 1_000_000_000...3_000_000_000)
        try? await Task.sleep(nanoseconds: processingTime)
        
        // Enhanced responses based on prompt content
        let lowercased = prompt.lowercased()
        
        if lowercased.contains("hello") || lowercased.contains("hi") {
            return EnhancedChatMessage(
                content: "Hello! I'm your enhanced AI assistant with visual capabilities. I can analyze images, capture screenshots, extract text, and help automate tasks. What would you like to explore?",
                isUser: false,
                messageType: .text,
                attachments: []
            )
        } else if lowercased.contains("help") {
            return EnhancedChatMessage(
                content: """
                I'm Eiros, your enhanced AI assistant! Here's what I can help you with:
                
                🧠 **Text Conversations**: Answer questions and have discussions
                👁️ **Visual Analysis**: Analyze images and screenshots
                📱 **Screen Automation**: Capture and analyze your screen
                📝 **Text Recognition**: Extract text from images
                🎯 **UI Analysis**: Identify and describe interface elements
                
                Try asking me to:
                • "Analyze this screenshot"
                • "Extract text from screen"
                • "Find buttons on screen"
                • "What do you see in this image?"
                
                What would you like to try?
                """,
                isUser: false,
                messageType: .text,
                attachments: []
            )
        } else if lowercased.contains("model") || lowercased.contains("capability") {
            return EnhancedChatMessage(
                content: """
                Current Model: \(currentModel.displayName)
                
                **Capabilities:**
                \(currentModel.capabilities.map { "• \($0)" }.joined(separator: "\n"))
                
                **Supported Modalities:**
                \(supportedModalities.map { "• \($0.rawValue.capitalized)" }.joined(separator: "\n"))
                
                **Performance:**
                • Memory Usage: \(memoryUsage)
                • Last Response Time: \(lastInferenceTime)
                • Average Response Time: \(averageResponseTime)
                
                I'm running entirely on your device for privacy and speed!
                """,
                isUser: false,
                messageType: .text,
                attachments: []
            )
        } else {
            return EnhancedChatMessage(
                content: "I understand your question about '\(prompt)'. As an enhanced AI assistant with visual capabilities, I'm processing this locally on your device. I can also analyze images and screenshots if you'd like to share any visual content. How else can I help you?",
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
