
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

