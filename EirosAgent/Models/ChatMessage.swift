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

// MARK: - Vision Analysis Data Models

struct VisionAnalysisData: Codable {
    let detectedText: [String]
    let detectedObjects: [String]
    let confidence: Float
    let processingTime: TimeInterval
    let timestamp: Date
    
    init(detectedText: [String], detectedObjects: [String], confidence: Float, processingTime: TimeInterval) {
        self.detectedText = detectedText
        self.detectedObjects = detectedObjects
        self.confidence = confidence
        self.processingTime = processingTime
        self.timestamp = Date()
    }
}

struct ScreenCaptureData: Codable {
    let timestamp: Date
    let imageSize: CGSize
    let captureMethod: String
    
    init(imageSize: CGSize, captureMethod: String) {
        self.timestamp = Date()
        self.imageSize = imageSize
        self.captureMethod = captureMethod
    }
}
