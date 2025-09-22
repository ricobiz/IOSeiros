//
//  BaseLLMManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//  Purpose: Base class providing common functionality for LLM managers
//

import Foundation
import SwiftUI

/// Base class providing common functionality for LLM managers
/// This reduces code duplication between different manager implementations
class BaseLLMManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var chatHistory: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    
    // MARK: - Internal Properties
    internal var modelPath: String?
    internal let maxHistoryCount = 50 // Prevent memory issues with long conversations
    
    // MARK: - Initialization
    init() {
        setupInitialState()
    }
    
    // MARK: - Common Methods
    
    /// Setup initial state for the manager
    private func setupInitialState() {
        // Add welcome message
        addSystemMessage("Hello! I'm Eiros, your AI assistant. How can I help you today?")
    }
    
    /// Add a message to chat history
    /// - Parameters:
    ///   - content: The message content
    ///   - isUser: Whether this is a user message
    ///   - timestamp: Optional timestamp (defaults to now)
    func addMessage(content: String, isUser: Bool, timestamp: Date = Date()) {
        DispatchQueue.main.async {
            let message = ChatMessage(
                id: UUID(),
                content: content,
                isUser: isUser,
                timestamp: timestamp
            )
            
            self.chatHistory.append(message)
            
            // Trim history if it gets too long
            if self.chatHistory.count > self.maxHistoryCount {
                self.chatHistory.removeFirst(self.chatHistory.count - self.maxHistoryCount)
            }
        }
    }
    
    /// Add a system message (from the AI)
    /// - Parameter content: The message content
    func addSystemMessage(_ content: String) {
        addMessage(content: content, isUser: false)
    }
    
    /// Add a user message
    /// - Parameter content: The message content
    func addUserMessage(_ content: String) {
        addMessage(content: content, isUser: true)
    }
    
    /// Clear all chat history
    func clearHistory() {
        DispatchQueue.main.async {
            self.chatHistory.removeAll()
            self.setupInitialState()
        }
    }
    
    /// Set processing state
    /// - Parameter processing: Whether currently processing
    func setProcessing(_ processing: Bool) {
        DispatchQueue.main.async {
            self.isProcessing = processing
        }
    }
    
    /// Get conversation context for the model
    /// - Parameter includeSystemMessages: Whether to include system messages
    /// - Returns: Formatted conversation context
    func getConversationContext(includeSystemMessages: Bool = true) -> String {
        let relevantMessages = includeSystemMessages ? 
            chatHistory : 
            chatHistory.filter { $0.isUser || !$0.content.hasPrefix("Hello!") }
        
        return relevantMessages
            .suffix(10) // Only use last 10 messages for context
            .map { message in
                let role = message.isUser ? "User" : "Assistant"
                return "\(role): \(message.content)"
            }
            .joined(separator: "\n")
    }
    
    /// Validate message before processing
    /// - Parameter message: The message to validate
    /// - Returns: True if message is valid
    func validateMessage(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 2000 // Reasonable length limit
    }
    
    /// Handle error during message processing
    /// - Parameter error: The error that occurred
    func handleError(_ error: Error) {
        print("LLM Manager Error: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.addSystemMessage("I apologize, but I encountered an error processing your request. Please try again.")
            self.setProcessing(false)
        }
    }
    
    /// Format model response for display
    /// - Parameter response: Raw model response
    /// - Returns: Formatted response
    func formatResponse(_ response: String) -> String {
        return response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\n", with: "\n")
    }
}

// MARK: - Error Types
enum LLMManagerError: LocalizedError {
    case modelNotLoaded
    case invalidMessage
    case processingFailed(String)
    case modelLoadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded. Please wait for initialization to complete."
        case .invalidMessage:
            return "Invalid message format or content."
        case .processingFailed(let reason):
            return "Failed to process message: \(reason)"
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        }
    }
}
