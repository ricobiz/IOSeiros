//
//  OpenRouterManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import Combine
import Security

@MainActor
class OpenRouterManager: ObservableObject {
    static let shared = OpenRouterManager()
    
    // MARK: - Published Properties
    @Published var isConfigured = false
    @Published var isGenerating = false
    @Published var selectedModel: OpenRouterModel = .gpt4o
    @Published var availableModels: [OpenRouterModel] = OpenRouterModel.allCases
    @Published var lastError: String?
    
    // Usage tracking
    @Published var totalTokensUsed: Int = 0
    @Published var totalCost: Double = 0.0
    @Published var requestCount: Int = 0
    @Published var lastRequestTime: Date?
    
    // Performance metrics
    @Published var lastResponseTime: TimeInterval = 0
    @Published var averageResponseTime: TimeInterval = 0
    
    // MARK: - Private Properties
    private let baseURL = "https://openrouter.ai/api/v1"
    private let keychainService = "EirosAgent.OpenRouter"
    private let apiKeyKey = "openrouter_api_key"
    private var responseTimes: [TimeInterval] = []
    private let maxResponseHistory = 10
    
    private var apiKey: String? {
        get { getAPIKeyFromKeychain() }
        set { 
            if let key = newValue {
                saveAPIKeyToKeychain(key)
            } else {
                deleteAPIKeyFromKeychain()
            }
            isConfigured = (newValue != nil && !newValue!.isEmpty)
        }
    }
    
    private init() {
        loadConfiguration()
        loadUsageData()
    }
    
    // MARK: - Configuration
    
    func configure(with apiKey: String) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        saveConfiguration()
    }
    
    func clearConfiguration() {
        apiKey = nil
        isConfigured = false
        saveConfiguration()
    }
    
    private func loadConfiguration() {
        isConfigured = apiKey != nil && !apiKey!.isEmpty
    }
    
    private func saveConfiguration() {
        // Configuration is automatically saved via keychain
    }
    
    // MARK: - Model Management
    
    func selectModel(_ model: OpenRouterModel) {
        selectedModel = model
        saveConfiguration()
    }
    
    func getModelInfo() -> ModelInfo {
        return ModelInfo(
            name: selectedModel.displayName,
            size: "Cloud-based",
            memoryUsage: "Remote",
            parameters: selectedModel.parameters
        )
    }
    
    // MARK: - Chat Completion
    
    func generateResponse(for messages: [ChatMessage]) async -> String {
        guard isConfigured, let apiKey = apiKey else {
            lastError = "OpenRouter API key not configured"
            return "Error: OpenRouter API key not configured. Please add your API key in settings."
        }
        
        isGenerating = true
        lastError = nil
        let startTime = Date()
        
        defer {
            isGenerating = false
            updatePerformanceMetrics(startTime: startTime)
        }
        
        do {
            let response = await performChatCompletion(messages: messages, apiKey: apiKey)
            updateUsageMetrics(response: response)
            return response.choices.first?.message.content ?? "No response generated"
        } catch {
            lastError = error.localizedDescription
            return "Error: \(error.localizedDescription)"
        }
    }
    
    func generateResponse(for prompt: String) async -> String {
        let message = ChatMessage(content: prompt, isUser: true)
        return await generateResponse(for: [message])
    }
    
    // MARK: - Vision Analysis Integration
    
    func analyzeScreenWithContext(image: UIImage, context: String) async -> String {
        guard isConfigured else {
            return "OpenRouter API key not configured"
        }
        
        // For vision analysis, we'll use a vision-capable model
        let originalModel = selectedModel
        if !selectedModel.supportsVision {
            selectedModel = .gpt4Vision // Switch to vision model temporarily
        }
        
        defer {
            selectedModel = originalModel // Restore original model
        }
        
        // Convert image to base64 for API
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return "Failed to process image"
        }
        
        let base64Image = imageData.base64EncodedString()
        let prompt = """
        Analyze this screenshot and provide insights based on the context: \(context)
        
        Please describe what you see and provide actionable insights for automation or interaction.
        """
        
        return await generateVisionResponse(prompt: prompt, base64Image: base64Image)
    }
    
    private func generateVisionResponse(prompt: String, base64Image: String) async -> String {
        guard let apiKey = apiKey else { return "API key not configured" }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let request = OpenRouterVisionRequest(
                model: selectedModel.rawValue,
                messages: [
                    OpenRouterVisionMessage(
                        role: "user",
                        content: [
                            OpenRouterVisionContent(type: "text", text: prompt),
                            OpenRouterVisionContent(type: "image_url", imageUrl: OpenRouterImageURL(url: "data:image/jpeg;base64,\(base64Image)"))
                        ]
                    )
                ],
                maxTokens: 1000
            )
            
            let response = await performVisionRequest(request: request, apiKey: apiKey)
            return response.choices.first?.message.content ?? "No vision analysis generated"
        } catch {
            lastError = error.localizedDescription
            return "Vision analysis error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - API Requests
    
    private func performChatCompletion(messages: [ChatMessage], apiKey: String) async throws -> OpenRouterResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("EirosAgent/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("EirosAgent iOS App", forHTTPHeaderField: "X-Title")
        
        let openRouterMessages = messages.map { message in
            OpenRouterMessage(
                role: message.isUser ? "user" : "assistant",
                content: message.content
            )
        }
        
        let requestBody = OpenRouterRequest(
            model: selectedModel.rawValue,
            messages: openRouterMessages,
            maxTokens: selectedModel.maxTokens,
            temperature: 0.7,
            topP: 1.0,
            stream: false
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data) {
                throw OpenRouterError.apiError(errorData.error.message)
            }
            throw OpenRouterError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(OpenRouterResponse.self, from: data)
    }
    
    private func performVisionRequest(request: OpenRouterVisionRequest, apiKey: String) async throws -> OpenRouterResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("EirosAgent/1.0", forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue("EirosAgent iOS App", forHTTPHeaderField: "X-Title")
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data) {
                throw OpenRouterError.apiError(errorData.error.message)
            }
            throw OpenRouterError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(OpenRouterResponse.self, from: data)
    }
    
    // MARK: - Usage Tracking
    
    private func updateUsageMetrics(response: OpenRouterResponse) {
        if let usage = response.usage {
            totalTokensUsed += usage.totalTokens
            requestCount += 1
            lastRequestTime = Date()
            
            // Estimate cost based on model pricing
            let estimatedCost = Double(usage.totalTokens) * selectedModel.costPer1KTokens / 1000.0
            totalCost += estimatedCost
            
            saveUsageData()
        }
    }
    
    private func updatePerformanceMetrics(startTime: Date) {
        let responseTime = Date().timeIntervalSince(startTime)
        lastResponseTime = responseTime
        
        responseTimes.append(responseTime)
        if responseTimes.count > maxResponseHistory {
            responseTimes.removeFirst()
        }
        
        averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    func resetUsageMetrics() {
        totalTokensUsed = 0
        totalCost = 0.0
        requestCount = 0
        lastRequestTime = nil
        responseTimes.removeAll()
        averageResponseTime = 0
        lastResponseTime = 0
        saveUsageData()
    }
    
    private func saveUsageData() {
        UserDefaults.standard.set(totalTokensUsed, forKey: "openrouter_total_tokens")
        UserDefaults.standard.set(totalCost, forKey: "openrouter_total_cost")
        UserDefaults.standard.set(requestCount, forKey: "openrouter_request_count")
        if let lastRequestTime = lastRequestTime {
            UserDefaults.standard.set(lastRequestTime, forKey: "openrouter_last_request")
        }
    }
    
    private func loadUsageData() {
        totalTokensUsed = UserDefaults.standard.integer(forKey: "openrouter_total_tokens")
        totalCost = UserDefaults.standard.double(forKey: "openrouter_total_cost")
        requestCount = UserDefaults.standard.integer(forKey: "openrouter_request_count")
        lastRequestTime = UserDefaults.standard.object(forKey: "openrouter_last_request") as? Date
    }
    
    // MARK: - Keychain Management
    
    private func saveAPIKeyToKeychain(_ apiKey: String) {
        let data = apiKey.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyKey,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
    
    private func deleteAPIKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Models

enum OpenRouterModel: String, CaseIterable, Identifiable {
    case gpt4o = "openai/gpt-4o"
    case gpt4oMini = "openai/gpt-4o-mini"
    case gpt4Vision = "openai/gpt-4-vision-preview"
    case claude3Opus = "anthropic/claude-3-opus"
    case claude3Sonnet = "anthropic/claude-3.5-sonnet"
    case claude3Haiku = "anthropic/claude-3-haiku"
    case geminiPro = "google/gemini-pro"
    case geminiProVision = "google/gemini-pro-vision"
    case llama3_70b = "meta-llama/llama-3-70b-instruct"
    case llama3_8b = "meta-llama/llama-3-8b-instruct"
    case mixtral8x7b = "mistralai/mixtral-8x7b-instruct"
    case qwen2_72b = "qwen/qwen-2-72b-instruct"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .gpt4Vision: return "GPT-4 Vision"
        case .claude3Opus: return "Claude 3 Opus"
        case .claude3Sonnet: return "Claude 3.5 Sonnet"
        case .claude3Haiku: return "Claude 3 Haiku"
        case .geminiPro: return "Gemini Pro"
        case .geminiProVision: return "Gemini Pro Vision"
        case .llama3_70b: return "Llama 3 70B"
        case .llama3_8b: return "Llama 3 8B"
        case .mixtral8x7b: return "Mixtral 8x7B"
        case .qwen2_72b: return "Qwen2 72B"
        }
    }
    
    var parameters: String {
        switch self {
        case .gpt4o, .gpt4Vision: return "~1.76T"
        case .gpt4oMini: return "~8B"
        case .claude3Opus: return "~175B"
        case .claude3Sonnet: return "~175B"
        case .claude3Haiku: return "~175B"
        case .geminiPro, .geminiProVision: return "~540B"
        case .llama3_70b: return "70B"
        case .llama3_8b: return "8B"
        case .mixtral8x7b: return "8x7B"
        case .qwen2_72b: return "72B"
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .gpt4o, .gpt4oMini, .gpt4Vision: return 4096
        case .claude3Opus, .claude3Sonnet, .claude3Haiku: return 4096
        case .geminiPro, .geminiProVision: return 2048
        case .llama3_70b, .llama3_8b: return 8192
        case .mixtral8x7b: return 32768
        case .qwen2_72b: return 32768
        }
    }
    
    var supportsVision: Bool {
        switch self {
        case .gpt4Vision, .geminiProVision, .gpt4o: return true
        default: return false
        }
    }
    
    var costPer1KTokens: Double {
        switch self {
        case .gpt4o: return 0.005
        case .gpt4oMini: return 0.00015
        case .gpt4Vision: return 0.01
        case .claude3Opus: return 0.015
        case .claude3Sonnet: return 0.003
        case .claude3Haiku: return 0.00025
        case .geminiPro, .geminiProVision: return 0.0005
        case .llama3_70b: return 0.0009
        case .llama3_8b: return 0.00018
        case .mixtral8x7b: return 0.0007
        case .qwen2_72b: return 0.0009
        }
    }
    
    var provider: String {
        switch self {
        case .gpt4o, .gpt4oMini, .gpt4Vision: return "OpenAI"
        case .claude3Opus, .claude3Sonnet, .claude3Haiku: return "Anthropic"
        case .geminiPro, .geminiProVision: return "Google"
        case .llama3_70b, .llama3_8b: return "Meta"
        case .mixtral8x7b: return "Mistral AI"
        case .qwen2_72b: return "Alibaba"
        }
    }
}

struct OpenRouterRequest: Codable {
    let model: String
    let messages: [OpenRouterMessage]
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

struct OpenRouterMessage: Codable {
    let role: String
    let content: String
}

struct OpenRouterVisionRequest: Codable {
    let model: String
    let messages: [OpenRouterVisionMessage]
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

struct OpenRouterVisionMessage: Codable {
    let role: String
    let content: [OpenRouterVisionContent]
}

struct OpenRouterVisionContent: Codable {
    let type: String
    let text: String?
    let imageUrl: OpenRouterImageURL?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.imageUrl = nil
    }
    
    init(type: String, imageUrl: OpenRouterImageURL) {
        self.type = type
        self.text = nil
        self.imageUrl = imageUrl
    }
}

struct OpenRouterImageURL: Codable {
    let url: String
}

struct OpenRouterResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenRouterChoice]
    let usage: OpenRouterUsage?
}

struct OpenRouterChoice: Codable {
    let index: Int
    let message: OpenRouterMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct OpenRouterUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct OpenRouterErrorResponse: Codable {
    let error: OpenRouterErrorDetail
}

struct OpenRouterErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

enum OpenRouterError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case httpError(Int)
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenRouter API"
        case .apiError(let message):
            return "OpenRouter API Error: \(message)"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .encodingError:
            return "Failed to encode request"
        }
    }
}
