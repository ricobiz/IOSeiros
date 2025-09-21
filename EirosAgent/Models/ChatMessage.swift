//
//  ChatMessage.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}

struct ModelInfo {
    let name: String
    let size: String
    let memoryUsage: String
    let parameters: String
}
