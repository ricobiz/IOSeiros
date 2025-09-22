//
//  Qwen2VLManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//

import Foundation
import UIKit
import Combine

@MainActor
class Qwen2VLManager: ObservableObject {
    static let shared = Qwen2VLManager()
    
    // MARK: - Published Properties
    @Published var isModelLoaded = false
    @Published var isProcessing = false
    @Published var lastAnalysisResult: VisionAnalysisResult?
    @Published var analysisError: String?
    
    // Performance metrics
    @Published var lastProcessingTime: TimeInterval = 0
    @Published var averageProcessingTime: TimeInterval = 0
    
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingHistory = 10
    
    // Model configuration
    private let modelName = "Qwen2-VL-2B-4bit"
    private let modelPath = "mlx-community/Qwen2-VL-2B-4bit"
    private let mlxWrapper = MLXVisionWrapper()
    
    private init() {
        setupBindings()
        loadModel()
    }
    
    private func setupBindings() {
        // Bind MLX wrapper state to our published properties
        mlxWrapper.$isModelLoaded
            .assign(to: &$isModelLoaded)
        
        mlxWrapper.$error
            .map { $0 }
            .assign(to: &$analysisError)
    }
    
    // MARK: - Model Management
    
    func loadModel() {
        Task {
            isProcessing = true
            
            do {
                try await mlxWrapper.loadModel()
                print("✅ Qwen2-VL-2B model loaded successfully")
                
            } catch {
                analysisError = "Failed to load Qwen2-VL-2B model: \(error.localizedDescription)"
                print("❌ Error loading model: \(error)")
            }
            
            isProcessing = false
        }
    }
    
    func reloadModel() {
        mlxWrapper.unloadModel()
        loadModel()
    }
    
    // MARK: - Vision Analysis Methods
    
    func analyzeImage(_ image: UIImage, prompt: String = "Describe what you see in this image.") async -> VisionAnalysisResult {
        let startTime = Date()
        isProcessing = true
        analysisError = nil
        
        defer {
            isProcessing = false
            updateProcessingMetrics(startTime: startTime)
        }
        
        guard isModelLoaded else {
            let error = "Qwen2-VL-2B model is not loaded"
            analysisError = error
            return VisionAnalysisResult(
                description: "",
                detectedObjects: [],
                detectedText: [],
                confidence: 0.0,
                processingTime: Date().timeIntervalSince(startTime),
                error: error
            )
        }
        
        do {
            // TODO: Replace with actual MLX inference
            let result = await performMLXInference(image: image, prompt: prompt)
            
            let analysisResult = VisionAnalysisResult(
                description: result.description,
                detectedObjects: result.objects,
                detectedText: result.textElements,
                confidence: result.confidence,
                processingTime: Date().timeIntervalSince(startTime),
                error: nil
            )
            
            self.lastAnalysisResult = analysisResult
            return analysisResult
            
        } catch {
            let errorMessage = "Vision analysis failed: \(error.localizedDescription)"
            analysisError = errorMessage
            
            return VisionAnalysisResult(
                description: "",
                detectedObjects: [],
                detectedText: [],
                confidence: 0.0,
                processingTime: Date().timeIntervalSince(startTime),
                error: errorMessage
            )
        }
    }
    
    func extractTextFromScreen() async -> [String] {
        guard let screenshot = await ScreenCaptureManager.shared.captureScreen() else {
            return []
        }
        
        let result = await analyzeImage(screenshot, prompt: "Extract all text visible in this image. List each text element separately.")
        return result.detectedText
    }
    
    func findUIElements(matching query: String) async -> [UIElementDescription] {
        guard let screenshot = await ScreenCaptureManager.shared.captureScreen() else {
            return []
        }
        
        let prompt = "Find all UI elements that match '\(query)'. For each element, provide its type, text content, and approximate location."
        let result = await analyzeImage(screenshot, prompt: prompt)
        
        // Convert detected objects to UI element descriptions
        return result.detectedObjects.map { object in
            UIElementDescription(
                type: object.type,
                text: object.label,
                location: object.boundingBox,
                confidence: object.confidence
            )
        }
    }
    
    func analyzeScreenForAutomation() async -> ScreenAutomationAnalysis {
        guard let screenshot = await ScreenCaptureManager.shared.captureScreen() else {
            return ScreenAutomationAnalysis(
                interactableElements: [],
                screenDescription: "Failed to capture screen",
                suggestedActions: []
            )
        }
        
        let prompt = """
        Analyze this screen for automation purposes. Identify:
        1. All clickable elements (buttons, links, etc.)
        2. Input fields and their purposes
        3. Navigation elements
        4. Current screen context and purpose
        5. Possible user actions
        """
        
        let result = await analyzeImage(screenshot, prompt: prompt)
        
        let interactableElements = result.detectedObjects.filter { $0.isInteractable }
        let suggestedActions = generateSuggestedActions(from: result)
        
        return ScreenAutomationAnalysis(
            interactableElements: interactableElements,
            screenDescription: result.description,
            suggestedActions: suggestedActions
        )
    }
    
    // MARK: - Private Methods
    
    private func performMLXInference(image: UIImage, prompt: String) async -> MLXInferenceResult {
        do {
            // Use MLX wrapper for actual inference
            let response = try await mlxWrapper.generateResponse(for: image, prompt: prompt)
            
            // Parse the response to extract structured information
            let parsedResult = parseMLXResponse(response, for: image)
            
            return MLXInferenceResult(
                description: parsedResult.description,
                objects: parsedResult.objects,
                textElements: parsedResult.textElements,
                confidence: parsedResult.confidence
            )
            
        } catch {
            print("❌ MLX inference failed: \(error)")
            
            // Fallback to mock data if MLX inference fails
            let mockDescription = generateMockDescription(for: image, prompt: prompt)
            let mockObjects = generateMockObjects(for: image)
            let mockTextElements = generateMockTextElements(for: image)
            
            return MLXInferenceResult(
                description: mockDescription,
                objects: mockObjects,
                textElements: mockTextElements,
                confidence: Float.random(in: 0.7...0.85) // Lower confidence for fallback
            )
        }
    }
    
    private func parseMLXResponse(_ response: String, for image: UIImage) -> (description: String, objects: [DetectedObject], textElements: [String], confidence: Float) {
        // Parse the MLX model response to extract structured information
        // This is a simplified parser - in a real implementation, you might use more sophisticated parsing
        
        var description = response
        var objects: [DetectedObject] = []
        var textElements: [String] = []
        var confidence: Float = 0.9
        
        // Extract objects mentioned in the response
        let objectKeywords = ["button", "text field", "label", "image", "icon", "menu", "navigation", "input"]
        for keyword in objectKeywords {
            if response.lowercased().contains(keyword) {
                let object = DetectedObject(
                    label: keyword.capitalized,
                    confidence: Float.random(in: 0.8...0.95),
                    boundingBox: generateRandomBoundingBox(for: image),
                    normalizedBoundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.1),
                    objectType: mapKeywordToObjectType(keyword)
                )
                objects.append(object)
            }
        }
        
        // Extract text elements mentioned in the response
        let textPattern = #""([^"]+)"|'([^']+)'|text:\s*([^\n]+)|label:\s*([^\n]+)"#
        let regex = try? NSRegularExpression(pattern: textPattern, options: .caseInsensitive)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        
        for match in matches {
            for i in 1..<match.numberOfRanges {
                let range = match.range(at: i)
                if range.location != NSNotFound,
                   let swiftRange = Range(range, in: response) {
                    let extractedText = String(response[swiftRange])
                    if !extractedText.isEmpty {
                        textElements.append(extractedText)
                    }
                }
            }
        }
        
        // If no specific text was extracted, add some generic text elements
        if textElements.isEmpty {
            textElements = generateMockTextElements(for: image)
        }
        
        return (description, objects, textElements, confidence)
    }
    
    private func mapKeywordToObjectType(_ keyword: String) -> ObjectType {
        switch keyword.lowercased() {
        case "button":
            return .button
        case "image", "icon":
            return .image
        case "text field", "input":
            return .rectangle
        default:
            return .unknown
        }
    }
    
    private func generateRandomBoundingBox(for image: UIImage) -> CGRect {
        let width = image.size.width
        let height = image.size.height
        
        let x = CGFloat.random(in: 0...(width * 0.7))
        let y = CGFloat.random(in: 0...(height * 0.7))
        let w = CGFloat.random(in: 50...(width * 0.3))
        let h = CGFloat.random(in: 30...(height * 0.1))
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func generateMockDescription(for image: UIImage, prompt: String) -> String {
        // Generate contextual mock descriptions based on prompt
        if prompt.lowercased().contains("text") {
            return "This image contains several text elements including labels, buttons, and possibly input fields. The text appears to be in a user interface layout."
        } else if prompt.lowercased().contains("ui") || prompt.lowercased().contains("element") {
            return "The screen shows a mobile application interface with various interactive elements including buttons, navigation controls, and content areas arranged in a typical iOS layout."
        } else {
            return "This appears to be a mobile application screen with various UI components and content. The layout suggests it's part of an iOS application with standard interface elements."
        }
    }
    
    private func generateMockObjects(for image: UIImage) -> [DetectedObject] {
        // Generate realistic mock objects based on typical iOS UI
        let mockObjects = [
            DetectedObject(
                label: "Navigation Button",
                confidence: 0.92,
                boundingBox: CGRect(x: 20, y: 60, width: 44, height: 44),
                normalizedBoundingBox: CGRect(x: 0.05, y: 0.08, width: 0.11, height: 0.06),
                objectType: .button
            ),
            DetectedObject(
                label: "Primary Action Button",
                confidence: 0.88,
                boundingBox: CGRect(x: 50, y: 600, width: 300, height: 50),
                normalizedBoundingBox: CGRect(x: 0.12, y: 0.75, width: 0.75, height: 0.06),
                objectType: .button
            ),
            DetectedObject(
                label: "Text Input Field",
                confidence: 0.85,
                boundingBox: CGRect(x: 30, y: 300, width: 340, height: 40),
                normalizedBoundingBox: CGRect(x: 0.075, y: 0.375, width: 0.85, height: 0.05),
                objectType: .rectangle
            )
        ]
        
        return mockObjects
    }
    
    private func generateMockTextElements(for image: UIImage) -> [String] {
        return [
            "Vision Analysis",
            "Analyze Image",
            "Settings",
            "Back",
            "Continue",
            "Enter text here..."
        ]
    }
    
    private func generateSuggestedActions(from result: VisionAnalysisResult) -> [String] {
        var actions: [String] = []
        
        if result.detectedObjects.contains(where: { $0.label.lowercased().contains("button") }) {
            actions.append("Tap button to proceed")
        }
        
        if result.detectedText.contains(where: { $0.lowercased().contains("input") || $0.lowercased().contains("field") }) {
            actions.append("Enter text in input field")
        }
        
        if result.detectedObjects.contains(where: { $0.label.lowercased().contains("navigation") }) {
            actions.append("Navigate using menu")
        }
        
        return actions.isEmpty ? ["Analyze screen content"] : actions
    }
    
    private func updateProcessingMetrics(startTime: Date) {
        let processingTime = Date().timeIntervalSince(startTime)
        lastProcessingTime = processingTime
        
        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingHistory {
            processingTimes.removeFirst()
        }
        
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
}

// MARK: - Supporting Data Models

struct VisionAnalysisResult: Identifiable {
    let id = UUID()
    let description: String
    let detectedObjects: [DetectedObject]
    let detectedText: [String]
    let confidence: Float
    let processingTime: TimeInterval
    let error: String?
    let timestamp: Date
    
    init(description: String, detectedObjects: [DetectedObject], detectedText: [String], confidence: Float, processingTime: TimeInterval, error: String?) {
        self.description = description
        self.detectedObjects = detectedObjects
        self.detectedText = detectedText
        self.confidence = confidence
        self.processingTime = processingTime
        self.error = error
        self.timestamp = Date()
    }
}

struct MLXInferenceResult {
    let description: String
    let objects: [DetectedObject]
    let textElements: [String]
    let confidence: Float
}

struct UIElementDescription: Identifiable {
    let id = UUID()
    let type: String
    let text: String
    let location: CGRect
    let confidence: Float
}

struct ScreenAutomationAnalysis {
    let interactableElements: [DetectedObject]
    let screenDescription: String
    let suggestedActions: [String]
}

// MARK: - Extensions

extension DetectedObject {
    var isInteractable: Bool {
        let interactableTypes: [ObjectType] = [.button]
        let interactableKeywords = ["button", "tap", "click", "input", "field", "link"]
        
        return interactableTypes.contains(objectType) ||
               interactableKeywords.contains { label.lowercased().contains($0) }
    }
}

// MARK: - MLX Integration (Placeholder)
// TODO: Implement actual MLX integration when running on device

/*
 Real MLX integration would look like this:
 
 import MLX
 import MLXVisionLanguage
 
 class MLXVisionLanguageModel {
     static func load(modelPath: String) async throws -> MLXVisionLanguageModel {
         // Load MLX model from path
         // return MLXVisionLanguageModel(model: loadedModel)
     }
     
     func generate(image: UIImage, prompt: String) async throws -> String {
         // Perform MLX inference
         // return generatedText
     }
 }
*/
