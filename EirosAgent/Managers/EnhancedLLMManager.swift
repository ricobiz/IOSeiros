//
//  EnhancedLLMManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import Combine

@MainActor
class EnhancedLLMManager: ObservableObject {
    static let shared = EnhancedLLMManager()
    
    // MARK: - Published Properties
    @Published var isModelLoaded = false
    @Published var chatHistory: [ChatMessage] = []
    @Published var isGenerating = false
    @Published var currentMode: LLMMode = .local
    @Published var availableModes: [LLMMode] = LLMMode.allCases
    
    // Performance metrics
    @Published var lastInferenceTime = "N/A"
    @Published var averageResponseTime = "N/A"
    @Published var modelSwitchingEnabled = true
    
    // Model information
    var modelInfo: ModelInfo? {
        switch currentMode {
        case .local:
            return localLLMManager.modelInfo
        case .cloud:
            return openRouterManager.getModelInfo()
        case .hybrid:
            return ModelInfo(
                name: "Hybrid Mode",
                size: "Local + Cloud",
                memoryUsage: "Variable",
                parameters: "Mixed"
            )
        }
    }
    
    // MARK: - Private Properties
    private let localLLMManager = LLMManager.shared
    private let openRouterManager = OpenRouterManager.shared
    private var responseTimes: [Double] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Hybrid mode configuration
    private let hybridThreshold = 100 // Switch to cloud for prompts longer than this
    private let complexityKeywords = ["analyze", "complex", "detailed", "comprehensive", "vision", "image"]
    
    private init() {
        setupBindings()
        initializeWithWelcomeMessage()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind local LLM manager properties
        localLLMManager.$isModelLoaded
            .sink { [weak self] isLoaded in
                self?.updateModelLoadedStatus()
            }
            .store(in: &cancellables)
        
        localLLMManager.$isGenerating
            .sink { [weak self] isGenerating in
                if self?.currentMode == .local {
                    self?.isGenerating = isGenerating
                }
            }
            .store(in: &cancellables)
        
        // Bind OpenRouter manager properties
        openRouterManager.$isGenerating
            .sink { [weak self] isGenerating in
                if self?.currentMode == .cloud {
                    self?.isGenerating = isGenerating
                }
            }
            .store(in: &cancellables)
        
        openRouterManager.$isConfigured
            .sink { [weak self] _ in
                self?.updateAvailableModes()
            }
            .store(in: &cancellables)
    }
    
    private func initializeWithWelcomeMessage() {
        let welcomeMessage = """
        Hello! I'm Eiros, your enhanced AI assistant with both local and cloud capabilities.
        
        🏠 Local Mode: Fast, private processing on your device
        ☁️ Cloud Mode: Access to powerful models like GPT-4, Claude, and Gemini
        🔄 Hybrid Mode: Intelligent switching based on task complexity
        
        Current mode: \(currentMode.displayName)
        How can I help you today?
        """
        
        chatHistory.append(ChatMessage(content: welcomeMessage, isUser: false))
    }
    
    private func updateModelLoadedStatus() {
        switch currentMode {
        case .local:
            isModelLoaded = localLLMManager.isModelLoaded
        case .cloud:
            isModelLoaded = openRouterManager.isConfigured
        case .hybrid:
            isModelLoaded = localLLMManager.isModelLoaded || openRouterManager.isConfigured
        }
    }
    
    private func updateAvailableModes() {
        var modes: [LLMMode] = [.local]
        
        if openRouterManager.isConfigured {
            modes.append(.cloud)
            modes.append(.hybrid)
        }
        
        availableModes = modes
        
        // Switch to local if current mode is not available
        if !modes.contains(currentMode) {
            currentMode = .local
        }
    }
    
    // MARK: - Mode Management
    
    func switchMode(to mode: LLMMode) {
        guard availableModes.contains(mode) else {
            addSystemMessage("Mode \(mode.displayName) is not available. Please configure OpenRouter API key for cloud features.")
            return
        }
        
        currentMode = mode
        updateModelLoadedStatus()
        
        let modeMessage = "Switched to \(mode.displayName). \(mode.description)"
        addSystemMessage(modeMessage)
    }
    
    func loadModel() {
        switch currentMode {
        case .local, .hybrid:
            localLLMManager.loadModel()
        case .cloud:
            // Cloud models don't need loading
            isModelLoaded = openRouterManager.isConfigured
        }
    }
    
    func reloadModel() {
        switch currentMode {
        case .local, .hybrid:
            localLLMManager.reloadModel()
        case .cloud:
            // Refresh cloud configuration
            isModelLoaded = openRouterManager.isConfigured
        }
    }
    
    // MARK: - Message Handling
    
    func sendMessage(_ message: String) async {
        // Add user message
        chatHistory.append(ChatMessage(content: message, isUser: true))
        
        guard isModelLoaded else {
            let errorMessage = currentMode == .cloud ? 
                "OpenRouter API is not configured. Please add your API key in settings." :
                "Model is not loaded. Please wait for initialization to complete."
            addSystemMessage(errorMessage)
            return
        }
        
        isGenerating = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Determine which engine to use
        let selectedMode = currentMode == .hybrid ? determineOptimalMode(for: message) : currentMode
        
        // Generate response
        let response = await generateResponse(for: message, using: selectedMode)
        
        // Add AI response
        chatHistory.append(ChatMessage(content: response, isUser: false))
        
        // Update performance metrics
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        updatePerformanceMetrics(responseTime: responseTime)
        
        isGenerating = false
    }
    
    func sendMessageWithVision(_ message: String, image: UIImage) async {
        // Add user message
        chatHistory.append(ChatMessage(content: message, isUser: true))
        
        // Vision analysis requires cloud models
        if !openRouterManager.isConfigured {
            addSystemMessage("Vision analysis requires cloud models. Please configure OpenRouter API key.")
            return
        }
        
        isGenerating = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use OpenRouter for vision analysis
        let response = await openRouterManager.analyzeScreenWithContext(image: image, context: message)
        
        // Add AI response
        chatHistory.append(ChatMessage(content: response, isUser: false))
        
        // Update performance metrics
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        updatePerformanceMetrics(responseTime: responseTime)
        
        isGenerating = false
    }
    
    private func generateResponse(for message: String, using mode: LLMMode) async -> String {
        switch mode {
        case .local:
            return await generateLocalResponse(for: message)
        case .cloud:
            return await generateCloudResponse(for: message)
        case .hybrid:
            // This shouldn't happen as hybrid mode determines the actual mode
            return await generateLocalResponse(for: message)
        }
    }
    
    private func generateLocalResponse(for message: String) async -> String {
        // Use existing local LLM logic
        return await withCheckedContinuation { continuation in
            Task {
                await localLLMManager.sendMessage(message)
                // Get the last response from local manager
                if let lastMessage = localLLMManager.chatHistory.last, !lastMessage.isUser {
                    continuation.resume(returning: lastMessage.content)
                } else {
                    continuation.resume(returning: "Local model response not available")
                }
            }
        }
    }
    
    private func generateCloudResponse(for message: String) async -> String {
        // Convert chat history to OpenRouter format
        let recentHistory = Array(chatHistory.suffix(10)) // Last 10 messages for context
        return await openRouterManager.generateResponse(for: recentHistory)
    }
    
    // MARK: - Hybrid Mode Intelligence
    
    private func determineOptimalMode(for message: String) -> LLMMode {
        let messageLength = message.count
        let lowercaseMessage = message.lowercased()
        
        // Use cloud for long or complex queries
        if messageLength > hybridThreshold {
            return .cloud
        }
        
        // Use cloud for complex analysis tasks
        if complexityKeywords.contains(where: { lowercaseMessage.contains($0) }) {
            return .cloud
        }
        
        // Use cloud if local model is not loaded but cloud is available
        if !localLLMManager.isModelLoaded && openRouterManager.isConfigured {
            return .cloud
        }
        
        // Default to local for simple queries
        return .local
    }
    
    // MARK: - Utility Methods
    
    private func addSystemMessage(_ message: String) {
        chatHistory.append(ChatMessage(content: message, isUser: false))
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
    
    func clearChatHistory() {
        chatHistory.removeAll()
        initializeWithWelcomeMessage()
    }
    
    // MARK: - Model Selection for Cloud Mode
    
    func selectCloudModel(_ model: OpenRouterModel) {
        openRouterManager.selectModel(model)
        if currentMode == .cloud {
            addSystemMessage("Switched to \(model.displayName) (\(model.provider))")
        }
    }
    
    func getAvailableCloudModels() -> [OpenRouterModel] {
        return openRouterManager.availableModels
    }
    
    func getCurrentCloudModel() -> OpenRouterModel {
        return openRouterManager.selectedModel
    }
    
    // MARK: - Configuration
    
    func configureOpenRouter(apiKey: String) {
        openRouterManager.configure(with: apiKey)
        updateAvailableModes()
        addSystemMessage("OpenRouter API configured successfully! Cloud and Hybrid modes are now available.")
    }
    
    func isOpenRouterConfigured() -> Bool {
        return openRouterManager.isConfigured
    }
    
    // MARK: - Usage Statistics
    
    func getUsageStatistics() -> LLMUsageStatistics {
        return LLMUsageStatistics(
            localInferences: responseTimes.count,
            cloudTokensUsed: openRouterManager.totalTokensUsed,
            cloudCost: openRouterManager.totalCost,
            cloudRequests: openRouterManager.requestCount,
            averageLocalResponseTime: averageResponseTime,
            averageCloudResponseTime: String(format: "%.2f s", openRouterManager.averageResponseTime),
            currentMode: currentMode
        )
    }
    
    func resetUsageStatistics() {
        responseTimes.removeAll()
        lastInferenceTime = "N/A"
        averageResponseTime = "N/A"
        openRouterManager.resetUsageMetrics()
    }
    
    // MARK: - Vision Analysis Methods (Integration with Qwen2VLManager)
    
    func analyzeImage(_ image: UIImage, prompt: String) async {
        let qwen2VLManager = Qwen2VLManager.shared
        let result = await qwen2VLManager.analyzeImage(image, prompt: prompt)
        
        let responseMessage = if let error = result.error {
            "Vision analysis failed: \(error)"
        } else {
            """
            Vision Analysis Results:
            
            Description: \(result.description)
            
            Detected Objects: \(result.detectedObjects.count)
            \(result.detectedObjects.map { "• \($0.label) (confidence: \(String(format: "%.1f", $0.confidence * 100))%)" }.joined(separator: "\n"))
            
            Detected Text: \(result.detectedText.count) elements
            \(result.detectedText.map { "• \($0)" }.joined(separator: "\n"))
            
            Processing Time: \(String(format: "%.2f", result.processingTime))s
            Overall Confidence: \(String(format: "%.1f", result.confidence * 100))%
            """
        }
        
        addSystemMessage(responseMessage)
    }
    
    func extractTextFromScreen() async {
        let qwen2VLManager = Qwen2VLManager.shared
        let textElements = await qwen2VLManager.extractTextFromScreen()
        
        let responseMessage = if textElements.isEmpty {
            "No text elements found on the current screen."
        } else {
            """
            Extracted Text Elements (\(textElements.count) found):
            
            \(textElements.enumerated().map { index, text in
                "\(index + 1). \(text)"
            }.joined(separator: "\n"))
            """
        }
        
        addSystemMessage(responseMessage)
    }
    
    func findUIElements(matching query: String) async {
        let qwen2VLManager = Qwen2VLManager.shared
        let elements = await qwen2VLManager.findUIElements(matching: query)
        
        let responseMessage = if elements.isEmpty {
            "No UI elements matching '\(query)' were found on the current screen."
        } else {
            """
            Found \(elements.count) UI elements matching '\(query)':
            
            \(elements.enumerated().map { index, element in
                let location = "(\(Int(element.location.origin.x)), \(Int(element.location.origin.y)))"
                return "\(index + 1). \(element.type): \(element.text) at \(location) (confidence: \(String(format: "%.1f", element.confidence * 100))%)"
            }.joined(separator: "\n"))
            """
        }
        
        addSystemMessage(responseMessage)
    }
    
    func analyzeScreenForAutomation() async {
        let qwen2VLManager = Qwen2VLManager.shared
        let analysis = await qwen2VLManager.analyzeScreenForAutomation()
        
        let responseMessage = """
        Screen Automation Analysis:
        
        Screen Description:
        \(analysis.screenDescription)
        
        Interactable Elements (\(analysis.interactableElements.count) found):
        \(analysis.interactableElements.enumerated().map { index, element in
            let location = "(\(Int(element.boundingBox.origin.x)), \(Int(element.boundingBox.origin.y)))"
            return "\(index + 1). \(element.label) at \(location)"
        }.joined(separator: "\n"))
        
        Suggested Actions:
        \(analysis.suggestedActions.enumerated().map { index, action in
            "\(index + 1). \(action)"
        }.joined(separator: "\n"))
        """
        
        addSystemMessage(responseMessage)
    }
}

// MARK: - Supporting Types

enum LLMMode: String, CaseIterable, Identifiable {
    case local = "local"
    case cloud = "cloud"
    case hybrid = "hybrid"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .local: return "Local"
        case .cloud: return "Cloud"
        case .hybrid: return "Hybrid"
        }
    }
    
    var description: String {
        switch self {
        case .local:
            return "Fast, private processing on your device using local models."
        case .cloud:
            return "Access to powerful cloud models like GPT-4, Claude, and Gemini."
        case .hybrid:
            return "Intelligent switching between local and cloud based on task complexity."
        }
    }
    
    var icon: String {
        switch self {
        case .local: return "iphone"
        case .cloud: return "cloud"
        case .hybrid: return "arrow.triangle.2.circlepath"
        }
    }
}

struct LLMUsageStatistics {
    let localInferences: Int
    let cloudTokensUsed: Int
    let cloudCost: Double
    let cloudRequests: Int
    let averageLocalResponseTime: String
    let averageCloudResponseTime: String
    let currentMode: LLMMode
    
    var formattedCloudCost: String {
        return String(format: "$%.4f", cloudCost)
    }
    
    var totalRequests: Int {
        return localInferences + cloudRequests
    }
}

// MARK: - Extensions

extension EnhancedLLMManager {
    
    // MARK: - Batch Processing
    
    func processBatchMessages(_ messages: [String]) async -> [String] {
        var responses: [String] = []
        
        for message in messages {
            let response = await generateResponse(for: message, using: currentMode)
            responses.append(response)
            
            // Add small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        return responses
    }
    
    // MARK: - Context Management
    
    func setSystemContext(_ context: String) {
        let contextMessage = "System context updated: \(context)"
        addSystemMessage(contextMessage)
    }
    
    func getConversationSummary() -> String {
        let messageCount = chatHistory.count
        let userMessages = chatHistory.filter { $0.isUser }.count
        let aiMessages = chatHistory.filter { !$0.isUser }.count
        
        return """
        Conversation Summary:
        • Total messages: \(messageCount)
        • User messages: \(userMessages)
        • AI responses: \(aiMessages)
        • Current mode: \(currentMode.displayName)
        • Model loaded: \(isModelLoaded ? "Yes" : "No")
        """
    }
    
    // MARK: - Export/Import
    
    func exportChatHistory() -> Data? {
        do {
            return try JSONEncoder().encode(chatHistory)
        } catch {
            print("Failed to export chat history: \(error)")
            return nil
        }
    }
    
    func importChatHistory(from data: Data) -> Bool {
        do {
            let importedHistory = try JSONDecoder().decode([ChatMessage].self, from: data)
            chatHistory = importedHistory
            return true
        } catch {
            print("Failed to import chat history: \(error)")
            return false
        }
    }
}
