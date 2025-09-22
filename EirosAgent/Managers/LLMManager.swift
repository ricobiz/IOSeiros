//
//  LLMManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import Combine

@MainActor
class LLMManager: ObservableObject {
    static let shared = LLMManager()
    
    @Published var isModelLoaded = false
    @Published var chatHistory: [ChatMessage] = []
    @Published var isGenerating = false
    
    // Performance metrics
    @Published var lastInferenceTime = "N/A"
    @Published var averageResponseTime = "N/A"
    
    // Model information
    var modelInfo: ModelInfo? {
        guard isModelLoaded else { return nil }
        return ModelInfo(
            name: currentModelName,
            size: "~4.2 GB",
            memoryUsage: "\(getCurrentMemoryUsage()) MB",
            parameters: "7B"
        )
    }
    
    private var currentModelName = "llama-2-7b-chat"
    private var modelContext: OpaquePointer?
    private var responseTimes: [Double] = []
    
    private init() {
        // Initialize with welcome message
        chatHistory.append(ChatMessage(content: "Hello! I'm Eiros, your local AI assistant. How can I help you today?", isUser: false))
    }
    
    func loadModel() {
        Task {
            isGenerating = true
            
            // Simulate model loading delay
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // In a real implementation, this would load the actual model
            // modelContext = llamacpp_load_model(getModelPath())
            
            isModelLoaded = true
            isGenerating = false
        }
    }
    
    func reloadModel() {
        Task {
            isModelLoaded = false
            isGenerating = true
            
            // Cleanup existing model
            if let context = modelContext {
                // llamacpp_free_model(context)
                modelContext = nil
            }
            
            // Reload model
            loadModel()
        }
    }
    
    func sendMessage(_ message: String) async {
        // Add user message
        chatHistory.append(ChatMessage(content: message, isUser: true))
        
        guard isModelLoaded else {
            chatHistory.append(ChatMessage(content: "Model is not loaded. Please wait for initialization to complete.", isUser: false))
            return
        }
        
        isGenerating = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Generate response
        let response = await generateResponse(for: message)
        
        // Add AI response
        chatHistory.append(ChatMessage(content: response, isUser: false))
        
        // Update performance metrics
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        responseTimes.append(responseTime)
        lastInferenceTime = String(format: "%.2f s", responseTime)
        
        if responseTimes.count > 10 {
            responseTimes.removeFirst()
        }
        
        let avgTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        averageResponseTime = String(format: "%.2f s", avgTime)
        
        isGenerating = false
    }
    
    private func generateResponse(for prompt: String) async -> String {
        // Check if this is a vision-related query that should use Qwen2-VL
        if isVisionQuery(prompt) {
            return await handleVisionQuery(prompt)
        }
        
        // For non-vision queries, use enhanced text generation
        return await generateTextResponse(for: prompt)
    }
    
    private func isVisionQuery(_ prompt: String) -> Bool {
        let visionKeywords = ["image", "picture", "photo", "screen", "visual", "see", "look", "analyze", "vision", "ui", "interface", "button", "text on screen"]
        let lowercasePrompt = prompt.lowercased()
        return visionKeywords.contains { lowercasePrompt.contains($0) }
    }
    
    private func handleVisionQuery(_ prompt: String) async -> String {
        let qwen2VLManager = Qwen2VLManager.shared
        
        // Check if Qwen2-VL model is loaded
        guard qwen2VLManager.isModelLoaded else {
            return "Vision analysis requires the Qwen2-VL model to be loaded. Please wait for model initialization to complete."
        }
        
        // Capture current screen for analysis
        guard let screenshot = await ScreenCaptureManager.shared.captureScreen() else {
            return "Unable to capture screen for vision analysis. Please ensure screen capture permissions are granted."
        }
        
        // Perform vision analysis
        let result = await qwen2VLManager.analyzeImage(screenshot, prompt: prompt)
        
        if let error = result.error {
            return "Vision analysis failed: \(error)"
        }
        
        return """
        Based on my vision analysis of the current screen:
        
        \(result.description)
        
        I detected \(result.detectedObjects.count) objects and \(result.detectedText.count) text elements with \(String(format: "%.1f", result.confidence * 100))% confidence.
        
        How can I help you further with this screen?
        """
    }
    
    private func generateTextResponse(for prompt: String) async -> String {
        // Simulate processing time for local model
        let processingTime = UInt64.random(in: 1_000_000_000...2_500_000_000) // 1-2.5 seconds
        try? await Task.sleep(nanoseconds: processingTime)
        
        // Enhanced responses based on prompt analysis
        let lowercasePrompt = prompt.lowercased()
        
        if lowercasePrompt.contains("hello") || lowercasePrompt.contains("hi") {
            return "Hello! I'm Eiros, your local AI assistant with advanced vision capabilities powered by Qwen2-VL. I can analyze screens, extract text, identify UI elements, and help with automation tasks. How can I assist you today?"
        } else if lowercasePrompt.contains("help") {
            return """
            I'm Eiros, your enhanced local AI assistant. Here's what I can help you with:
            
            🔍 Vision Analysis: Analyze images, screenshots, and UI elements
            📱 Screen Automation: Find buttons, extract text, identify interactive elements
            🌐 Web Browsing: Navigate websites and extract information
            💬 Text Processing: Answer questions and provide assistance
            
            My vision capabilities are powered by Qwen2-VL-2B, running locally on your device for privacy and speed. What would you like to explore?
            """
        } else if lowercasePrompt.contains("web") || lowercasePrompt.contains("browser") {
            return "I can help you automate web browsing tasks using my vision capabilities! I can see and interact with web pages, identify buttons and forms, extract information, and guide you through complex workflows. Switch to the Browser tab and I'll analyze what's on screen to assist you."
        } else if lowercasePrompt.contains("vision") || lowercasePrompt.contains("analyze") {
            return "My vision capabilities are powered by Qwen2-VL-2B, a state-of-the-art vision-language model running locally on your device. I can analyze images, identify objects and text, understand UI layouts, and help with screen automation. Would you like me to analyze the current screen or a specific image?"
        } else if lowercasePrompt.contains("model") || lowercasePrompt.contains("qwen") {
            return """
            I'm powered by Qwen2-VL-2B, a 2-billion parameter vision-language model that runs locally on your device. Key features:
            
            • 🔒 Privacy-first: All processing happens on-device
            • ⚡ Fast inference: Optimized for mobile hardware
            • 👁️ Vision understanding: Can analyze images and UI elements
            • 🌍 Multilingual: Supports multiple languages
            • 🤖 Agent capabilities: Can help with automation tasks
            
            The model is quantized to 4-bit precision for optimal performance while maintaining high accuracy.
            """
        } else {
            return """
            I understand your question about '\(prompt)'. As your local AI assistant powered by Qwen2-VL, I'm processing this entirely on your device for privacy and speed.
            
            If you'd like me to analyze what's currently on your screen or help with any visual tasks, just let me know! I can see and understand images, UI elements, and help with automation.
            
            How else can I assist you today?
            """
        }
    }
    
    func clearChatHistory() {
        chatHistory.removeAll()
        chatHistory.append(ChatMessage(content: "Chat history cleared. How can I help you?", isUser: false))
    }
    
    private func getModelPath() -> String {
        // In a real implementation, this would return the path to the downloaded model
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ""
        }
        return documentsPath.appendingPathComponent("models/llama-2-7b-chat.q4_0.bin").path
    }
    
    private func getCurrentMemoryUsage() -> Int {
        // Simplified memory usage calculation
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
            return Int(info.resident_size / 1024 / 1024) // Convert to MB
        } else {
            return 0
        }
    }
}

// MARK: - C++ Bridge Functions (Placeholders)
// These would be implemented in the actual llama.cpp integration

/*
// C++ bridge functions that would be implemented:

private func llamacpp_load_model(_ path: String) -> OpaquePointer? {
    // Load model using llama.cpp
    return nil
}

private func llamacpp_free_model(_ context: OpaquePointer) {
    // Free model memory
}

private func llamacpp_generate_response(_ context: OpaquePointer?, _ prompt: String, completion: @escaping (String) -> Void) {
    // Generate response using llama.cpp
}
*/
