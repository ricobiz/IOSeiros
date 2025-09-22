//
//  LLMManagerProtocol.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//  Purpose: Protocol to standardize LLM manager implementations and reduce code duplication
//

import Foundation
import UIKit

/// Protocol defining the common interface for LLM managers
/// This helps reduce code duplication between LLMManager and EnhancedLLMManager
protocol LLMManagerProtocol: ObservableObject {
    /// Chat history containing all messages
    var chatHistory: [ChatMessage] { get set }
    
    /// Indicates if the model is currently loaded and ready
    var isModelLoaded: Bool { get }
    
    /// Indicates if the manager is currently processing a request
    var isProcessing: Bool { get }
    
    /// Load the LLM model
    func loadModel() async
    
    /// Send a text message and get a response
    /// - Parameter message: The user's message
    func sendMessage(_ message: String) async
    
    /// Clear the chat history
    func clearHistory()
}

/// Protocol for LLM managers that support vision capabilities
protocol VisionCapableLLMManager: LLMManagerProtocol {
    /// Send a message with an image for vision analysis
    /// - Parameters:
    ///   - message: The user's message
    ///   - image: The image to analyze
    func sendMessageWithVision(_ message: String, image: UIImage) async
}

/// Protocol for LLM managers that support different AI modes
protocol MultiModalLLMManager: VisionCapableLLMManager {
    /// Current AI mode (local, cloud, hybrid)
    var currentMode: AIMode { get set }
    
    /// Available AI models for the current mode
    var availableModels: [String] { get }
    
    /// Currently selected model
    var selectedModel: String? { get set }
    
    /// Switch between different AI modes
    /// - Parameter mode: The new AI mode to use
    func switchMode(to mode: AIMode) async
}

/// Enumeration of available AI modes
enum AIMode: String, CaseIterable {
    case local = "Local"
    case cloud = "Cloud"
    case hybrid = "Hybrid"
    
    var displayName: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .local:
            return "Uses local AI models for privacy and offline capability"
        case .cloud:
            return "Uses cloud-based AI models for enhanced capabilities"
        case .hybrid:
            return "Intelligently switches between local and cloud based on task complexity"
        }
    }
}
