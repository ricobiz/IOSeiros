
//
//  UIElement.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import CoreGraphics

// MARK: - UI Element Models

struct UIElement: Codable, Identifiable {
    let id = UUID()
    let type: UIElementType
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let isInteractable: Bool
    
    init(type: UIElementType, text: String, boundingBox: CGRect, confidence: Float, isInteractable: Bool) {
        self.type = type
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.isInteractable = isInteractable
    }
}

enum UIElementType: String, CaseIterable, Codable {
    case button = "button"
    case textField = "textField"
    case label = "label"
    case image = "image"
    case link = "link"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .button: return "Кнопка"
        case .textField: return "Текстовое поле"
        case .label: return "Метка"
        case .image: return "Изображение"
        case .link: return "Ссылка"
        case .unknown: return "Неизвестно"
        }
    }
}

// MARK: - Vision Analysis Models

struct VisionAnalysisResult {
    let uiElements: [UIElement]
    let detectedText: [DetectedText]
    let confidence: Float
    let processingTime: TimeInterval
    let timestamp: Date
    
    init(uiElements: [UIElement], detectedText: [DetectedText], confidence: Float, processingTime: TimeInterval) {
        self.uiElements = uiElements
        self.detectedText = detectedText
        self.confidence = confidence
        self.processingTime = processingTime
        self.timestamp = Date()
    }
}

struct DetectedText: Codable, Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    
    init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

// MARK: - Automation Intent Models

struct AutomationIntent {
    let type: AutomationIntentType
    let description: String
    let parameters: [String: String]
    
    init(type: AutomationIntentType, description: String, parameters: [String: String] = [:]) {
        self.type = type
        self.description = description
        self.parameters = parameters
    }
}

enum AutomationIntentType: String, CaseIterable {
    case tap = "tap"
    case fillForm = "fillForm"
    case scroll = "scroll"
    case navigate = "navigate"
    case analyze = "analyze"
    
    var displayName: String {
        switch self {
        case .tap: return "Нажатие"
        case .fillForm: return "Заполнение формы"
        case .scroll: return "Прокрутка"
        case .navigate: return "Навигация"
        case .analyze: return "Анализ"
        }
    }
}

// MARK: - Qwen2VL Models

struct Qwen2VLAnalysisResult {
    let detectedElements: [Qwen2VLElement]
    let confidence: Float
    let processingTime: TimeInterval
    let timestamp: Date
    
    init(detectedElements: [Qwen2VLElement], confidence: Float, processingTime: TimeInterval) {
        self.detectedElements = detectedElements
        self.confidence = confidence
        self.processingTime = processingTime
        self.timestamp = Date()
    }
}

struct Qwen2VLElement: Codable, Identifiable {
    let id = UUID()
    let type: Qwen2VLElementType
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let isInteractable: Bool
    
    init(type: Qwen2VLElementType, text: String, boundingBox: CGRect, confidence: Float, isInteractable: Bool) {
        self.type = type
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.isInteractable = isInteractable
    }
}

enum Qwen2VLElementType: String, CaseIterable, Codable {
    case button = "button"
    case textField = "textField"
    case label = "label"
    case image = "image"
    case link = "link"
    case searchField = "searchField"
    case scrollView = "scrollView"
    
    var displayName: String {
        switch self {
        case .button: return "Кнопка"
        case .textField: return "Текстовое поле"
        case .label: return "Метка"
        case .image: return "Изображение"
        case .link: return "Ссылка"
        case .searchField: return "Поле поиска"
        case .scrollView: return "Область прокрутки"
        }
    }
}

// MARK: - OpenRouter Models

enum OpenRouterModel: String, CaseIterable {
    case gpt4o = "openai/gpt-4o"
    case gpt4oMini = "openai/gpt-4o-mini"
    case claude35Sonnet = "anthropic/claude-3.5-sonnet"
    case claude3Haiku = "anthropic/claude-3-haiku"
    case llama31_8b = "meta-llama/llama-3.1-8b-instruct"
    case llama31_70b = "meta-llama/llama-3.1-70b-instruct"
    
    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude3Haiku: return "Claude 3 Haiku"
        case .llama31_8b: return "Llama 3.1 8B"
        case .llama31_70b: return "Llama 3.1 70B"
        }
    }
    
    var parameters: String {
        switch self {
        case .gpt4o: return "~1.76T параметров"
        case .gpt4oMini: return "~8B параметров"
        case .claude35Sonnet: return "~200B параметров"
        case .claude3Haiku: return "~20B параметров"
        case .llama31_8b: return "8B параметров"
        case .llama31_70b: return "70B параметров"
        }
    }
}
