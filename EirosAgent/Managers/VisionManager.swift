
//
//  VisionManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import Vision
import UIKit
import AVFoundation
import Combine

@MainActor
class VisionManager: NSObject, ObservableObject {
    static let shared = VisionManager()
    
    @Published var isProcessing = false
    @Published var lastAnalysisResult: ScreenAnalysisResult?
    @Published var detectedText: [DetectedText] = []
    @Published var detectedObjects: [DetectedObject] = []
    @Published var analysisError: String?
    
    // Performance metrics
    @Published var lastProcessingTime: TimeInterval = 0
    @Published var averageProcessingTime: TimeInterval = 0
    
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingHistory = 10
    
    override init() {
        super.init()
    }
    
    // MARK: - Text Recognition
    
    func recognizeText(in image: UIImage) async -> [DetectedText] {
        let startTime = Date()
        isProcessing = true
        analysisError = nil
        
        defer {
            isProcessing = false
            updateProcessingMetrics(startTime: startTime)
        }
        
        guard let cgImage = image.cgImage else {
            analysisError = "Failed to convert image to CGImage"
            return []
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "ru-RU"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02
        
        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try await handler.perform([request])
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return []
            }
            
            let detectedTexts = observations.compactMap { observation -> DetectedText? in
                guard let topCandidate = observation.topCandidates(1).first,
                      topCandidate.confidence > 0.5 else {
                    return nil
                }
                
                let boundingBox = observation.boundingBox
                let rect = VNImageRectForNormalizedRect(boundingBox, 
                                                       Int(image.size.width), 
                                                       Int(image.size.height))
                
                return DetectedText(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: rect,
                    normalizedBoundingBox: boundingBox
                )
            }
            
            self.detectedText = detectedTexts
            return detectedTexts
            
        } catch {
            analysisError = "Text recognition failed: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - Object Detection
    
    func detectObjects(in image: UIImage) async -> [DetectedObject] {
        let startTime = Date()
        isProcessing = true
        analysisError = nil
        
        defer {
            isProcessing = false
            updateProcessingMetrics(startTime: startTime)
        }
        
        guard let cgImage = image.cgImage else {
            analysisError = "Failed to convert image to CGImage"
            return []
        }
        
        // Use built-in object detection
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.1
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.01
        request.maximumObservations = 20
        
        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try await handler.perform([request])
            
            guard let observations = request.results as? [VNRectangleObservation] else {
                return []
            }
            
            let detectedObjects = observations.enumerated().map { index, observation -> DetectedObject in
                let boundingBox = observation.boundingBox
                let rect = VNImageRectForNormalizedRect(boundingBox,
                                                       Int(image.size.width),
                                                       Int(image.size.height))
                
                return DetectedObject(
                    label: "Rectangle \(index + 1)",
                    confidence: observation.confidence,
                    boundingBox: rect,
                    normalizedBoundingBox: boundingBox,
                    objectType: .rectangle
                )
            }
            
            self.detectedObjects = detectedObjects
            return detectedObjects
            
        } catch {
            analysisError = "Object detection failed: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - UI Element Analysis
    
    func analyzeUIElements(in image: UIImage) async -> [UIElement] {
        let startTime = Date()
        isProcessing = true
        analysisError = nil
        
        defer {
            isProcessing = false
            updateProcessingMetrics(startTime: startTime)
        }
        
        // Combine text and object detection for UI analysis
        async let textResults = recognizeText(in: image)
        async let objectResults = detectObjects(in: image)
        
        let texts = await textResults
        let objects = await objectResults
        
        var uiElements: [UIElement] = []
        
        // Convert detected text to UI elements
        for text in texts {
            let element = UIElement(
                type: classifyTextAsUIElement(text.text),
                text: text.text,
                boundingBox: text.boundingBox,
                confidence: text.confidence,
                isInteractable: isTextInteractable(text.text)
            )
            uiElements.append(element)
        }
        
        // Convert detected objects to UI elements
        for object in objects {
            let element = UIElement(
                type: .button, // Default classification
                text: object.label,
                boundingBox: object.boundingBox,
                confidence: object.confidence,
                isInteractable: true
            )
            uiElements.append(element)
        }
        
        return uiElements
    }
    
    // MARK: - Screen Analysis
    
    func analyzeScreen(_ image: UIImage) async -> ScreenAnalysisResult {
        let startTime = Date()
        isProcessing = true
        analysisError = nil
        
        defer {
            isProcessing = false
            updateProcessingMetrics(startTime: startTime)
        }
        
        // Use Qwen2-VL for enhanced analysis when available
        let qwen2VLManager = Qwen2VLManager.shared
        if qwen2VLManager.isModelLoaded {
            let qwenResult = await qwen2VLManager.analyzeImage(image, prompt: "Perform comprehensive screen analysis including text, objects, and UI elements.")
            
            // Convert Qwen2-VL result to ScreenAnalysisResult format
            let detectedTexts = qwenResult.detectedText.map { text in
                DetectedText(
                    text: text,
                    confidence: qwenResult.confidence,
                    boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), // Placeholder bounds
                    normalizedBoundingBox: CGRect(x: 0, y: 0, width: 0.25, height: 0.025)
                )
            }
            
            let result = ScreenAnalysisResult(
                timestamp: Date(),
                detectedText: detectedTexts,
                detectedObjects: qwenResult.detectedObjects,
                uiElements: convertToUIElements(from: qwenResult.detectedObjects),
                screenDescription: qwenResult.description,
                processingTime: qwenResult.processingTime
            )
            
            self.lastAnalysisResult = result
            return result
        }
        
        // Fallback to traditional Vision framework analysis
        async let textResults = recognizeText(in: image)
        async let objectResults = detectObjects(in: image)
        async let uiElements = analyzeUIElements(in: image)
        
        let texts = await textResults
        let objects = await objectResults
        let elements = await uiElements
        
        let result = ScreenAnalysisResult(
            timestamp: Date(),
            detectedText: texts,
            detectedObjects: objects,
            uiElements: elements,
            screenDescription: generateScreenDescription(texts: texts, objects: objects, elements: elements),
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        self.lastAnalysisResult = result
        return result
    }
    
    private func convertToUIElements(from objects: [DetectedObject]) -> [UIElement] {
        return objects.map { object in
            UIElement(
                type: mapObjectTypeToUIElementType(object.objectType),
                text: object.label,
                boundingBox: object.boundingBox,
                confidence: object.confidence,
                isInteractable: object.isInteractable
            )
        }
    }
    
    private func mapObjectTypeToUIElementType(_ objectType: ObjectType) -> UIElementType {
        switch objectType {
        case .button:
            return .button
        case .rectangle:
            return .textField
        case .image:
            return .image
        default:
            return .unknown
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateProcessingMetrics(startTime: Date) {
        let processingTime = Date().timeIntervalSince(startTime)
        lastProcessingTime = processingTime
        
        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingHistory {
            processingTimes.removeFirst()
        }
        
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    private func classifyTextAsUIElement(_ text: String) -> UIElementType {
        let lowercased = text.lowercased()
        
        if lowercased.contains("button") || lowercased.contains("tap") || lowercased.contains("click") {
            return .button
        } else if lowercased.contains("text") || lowercased.contains("input") || lowercased.contains("field") {
            return .textField
        } else if lowercased.contains("label") || lowercased.contains("title") {
            return .label
        } else if lowercased.contains("image") || lowercased.contains("photo") {
            return .image
        } else {
            return .text
        }
    }
    
    private func isTextInteractable(_ text: String) -> Bool {
        let interactableKeywords = ["button", "tap", "click", "input", "field", "search", "login", "submit"]
        let lowercased = text.lowercased()
        return interactableKeywords.contains { lowercased.contains($0) }
    }
    
    private func generateScreenDescription(texts: [DetectedText], objects: [DetectedObject], elements: [UIElement]) -> String {
        var description = "Screen Analysis:\n"
        
        if !texts.isEmpty {
            description += "- Found \(texts.count) text elements\n"
            let highConfidenceTexts = texts.filter { $0.confidence > 0.8 }
            if !highConfidenceTexts.isEmpty {
                description += "- High confidence text: \(highConfidenceTexts.map { $0.text }.joined(separator: ", "))\n"
            }
        }
        
        if !objects.isEmpty {
            description += "- Detected \(objects.count) objects/shapes\n"
        }
        
        if !elements.isEmpty {
            let interactableElements = elements.filter { $0.isInteractable }
            description += "- Found \(interactableElements.count) potentially interactable elements\n"
        }
        
        return description
    }
}

// MARK: - Data Models

struct DetectedText: Identifiable, Codable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let normalizedBoundingBox: CGRect
    let timestamp: Date
    
    init(text: String, confidence: Float, boundingBox: CGRect, normalizedBoundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.normalizedBoundingBox = normalizedBoundingBox
        self.timestamp = Date()
    }
}

struct DetectedObject: Identifiable, Codable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
    let normalizedBoundingBox: CGRect
    let objectType: ObjectType
    let timestamp: Date
    
    init(label: String, confidence: Float, boundingBox: CGRect, normalizedBoundingBox: CGRect, objectType: ObjectType) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.normalizedBoundingBox = normalizedBoundingBox
        self.objectType = objectType
        self.timestamp = Date()
    }
}

enum ObjectType: String, Codable, CaseIterable {
    case rectangle = "rectangle"
    case circle = "circle"
    case button = "button"
    case image = "image"
    case unknown = "unknown"
}

struct UIElement: Identifiable, Codable {
    let id = UUID()
    let type: UIElementType
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let isInteractable: Bool
    let timestamp: Date
    
    init(type: UIElementType, text: String, boundingBox: CGRect, confidence: Float, isInteractable: Bool) {
        self.type = type
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.isInteractable = isInteractable
        self.timestamp = Date()
    }
}

enum UIElementType: String, Codable, CaseIterable {
    case button = "button"
    case textField = "textField"
    case label = "label"
    case image = "image"
    case text = "text"
    case unknown = "unknown"
}

struct ScreenAnalysisResult: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let detectedText: [DetectedText]
    let detectedObjects: [DetectedObject]
    let uiElements: [UIElement]
    let screenDescription: String
    let processingTime: TimeInterval
}
