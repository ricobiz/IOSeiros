
//
//  VisionManager.swift
//  EirosAgent
//
//  Enhanced Vision Manager with DECODO Screenshot Integration
//  Created: 2025-09-22
//

import Foundation
import UIKit
import Vision
import Combine

// MARK: - Vision Manager

@MainActor
public class VisionManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = VisionManager()
    
    // MARK: - Published Properties
    @Published public var isEnabled = true
    @Published public var isProcessing = false
    @Published public var lastAnalysisResult: VisionAnalysisResult?
    @Published public var processingQueue: [VisionTask] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let qwen2vlService = Qwen2VLService()
    private let visionQueue = DispatchQueue(label: "VisionProcessingQueue", qos: .userInitiated)
    private var currentTask: VisionTask?
    
    // MARK: - Initialization
    private init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    public func analyzeImage(_ image: UIImage, options: VisionAnalysisOptions = VisionAnalysisOptions()) async -> VisionAnalysisResult {
        guard isEnabled else {
            return VisionAnalysisResult(
                success: false,
                confidence: 0.0,
                detectedObjects: [],
                text: "",
                metadata: ["error": "Vision analysis is disabled"]
            )
        }
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        let task = VisionTask(
            id: UUID().uuidString,
            image: image,
            options: options,
            timestamp: Date()
        )
        
        await MainActor.run {
            self.processingQueue.append(task)
            self.currentTask = task
        }
        
        do {
            let result = await performVisionAnalysis(task)
            
            await MainActor.run {
                self.lastAnalysisResult = result
                self.isProcessing = false
                self.currentTask = nil
                self.processingQueue.removeAll { $0.id == task.id }
            }
            
            return result
        } catch {
            let errorResult = VisionAnalysisResult(
                success: false,
                confidence: 0.0,
                detectedObjects: [],
                text: "",
                metadata: ["error": error.localizedDescription]
            )
            
            await MainActor.run {
                self.lastAnalysisResult = errorResult
                self.isProcessing = false
                self.currentTask = nil
                self.processingQueue.removeAll { $0.id == task.id }
            }
            
            return errorResult
        }
    }
    
    public func analyzeScreenshot(from url: String, using proxyManager: ProxyManager, options: VisionAnalysisOptions = VisionAnalysisOptions()) async -> VisionAnalysisResult {
        // Capture screenshot through DECODO proxy
        let screenshotOptions = ScreenshotOptions(
            geoLocation: options.geoLocation,
            sessionId: options.sessionId,
            target: "universal",
            deviceType: options.deviceType
        )
        
        let screenshotResult = await proxyManager.captureScreenshotThroughProxy(url: url, options: screenshotOptions)
        
        guard screenshotResult.success,
              let imageData = screenshotResult.imageData,
              let image = UIImage(data: imageData) else {
            return VisionAnalysisResult(
                success: false,
                confidence: 0.0,
                detectedObjects: [],
                text: "",
                metadata: ["error": "Failed to capture screenshot: \(screenshotResult.error ?? "Unknown error")"]
            )
        }
        
        // Analyze the captured screenshot
        var analysisOptions = options
        analysisOptions.sourceURL = url
        analysisOptions.captureMethod = "DECODO Proxy"
        
        return await analyzeImage(image, options: analysisOptions)
    }
    
    public func batchAnalyzeImages(_ images: [UIImage], options: VisionAnalysisOptions = VisionAnalysisOptions()) async -> [VisionAnalysisResult] {
        var results: [VisionAnalysisResult] = []
        
        for (index, image) in images.enumerated() {
            var batchOptions = options
            batchOptions.batchIndex = index
            batchOptions.batchTotal = images.count
            
            let result = await analyzeImage(image, options: batchOptions)
            results.append(result)
        }
        
        return results
    }
    
    public func extractTextFromImage(_ image: UIImage) async -> TextExtractionResult {
        return await withCheckedContinuation { continuation in
            visionQueue.async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        continuation.resume(returning: TextExtractionResult(
                            success: false,
                            text: "",
                            confidence: 0.0,
                            error: error.localizedDescription
                        ))
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: TextExtractionResult(
                            success: false,
                            text: "",
                            confidence: 0.0,
                            error: "No text observations found"
                        ))
                        return
                    }
                    
                    var extractedText = ""
                    var totalConfidence = 0.0
                    var observationCount = 0
                    
                    for observation in observations {
                        guard let topCandidate = observation.topCandidates(1).first else { continue }
                        extractedText += topCandidate.string + "\n"
                        totalConfidence += Double(topCandidate.confidence)
                        observationCount += 1
                    }
                    
                    let averageConfidence = observationCount > 0 ? totalConfidence / Double(observationCount) : 0.0
                    
                    continuation.resume(returning: TextExtractionResult(
                        success: true,
                        text: extractedText.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidence: averageConfidence,
                        error: nil
                    ))
                }
                
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: TextExtractionResult(
                        success: false,
                        text: "",
                        confidence: 0.0,
                        error: "Failed to get CGImage"
                    ))
                    return
                }
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: TextExtractionResult(
                        success: false,
                        text: "",
                        confidence: 0.0,
                        error: error.localizedDescription
                    ))
                }
            }
        }
    }
    
    public func detectObjects(in image: UIImage) async -> ObjectDetectionResult {
        return await withCheckedContinuation { continuation in
            visionQueue.async {
                let request = VNRecognizeObjectsRequest { request, error in
                    if let error = error {
                        continuation.resume(returning: ObjectDetectionResult(
                            success: false,
                            objects: [],
                            error: error.localizedDescription
                        ))
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                        continuation.resume(returning: ObjectDetectionResult(
                            success: false,
                            objects: [],
                            error: "No object observations found"
                        ))
                        return
                    }
                    
                    let detectedObjects = observations.compactMap { observation -> DetectedObject? in
                        guard let topLabel = observation.labels.first else { return nil }
                        
                        return DetectedObject(
                            label: topLabel.identifier,
                            confidence: Double(topLabel.confidence),
                            boundingBox: observation.boundingBox
                        )
                    }
                    
                    continuation.resume(returning: ObjectDetectionResult(
                        success: true,
                        objects: detectedObjects,
                        error: nil
                    ))
                }
                
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: ObjectDetectionResult(
                        success: false,
                        objects: [],
                        error: "Failed to get CGImage"
                    ))
                    return
                }
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: ObjectDetectionResult(
                        success: false,
                        objects: [],
                        error: error.localizedDescription
                    ))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Setup any necessary bindings
    }
    
    private func performVisionAnalysis(_ task: VisionTask) async -> VisionAnalysisResult {
        // Perform multiple vision analyses in parallel
        async let textResult = extractTextFromImage(task.image)
        async let objectResult = detectObjects(in: task.image)
        async let qwenResult = analyzeWithQwen2VL(task)
        
        let (text, objects, qwen) = await (textResult, objectResult, qwenResult)
        
        // Combine results
        var detectedObjects = objects.success ? objects.objects : []
        var extractedText = text.success ? text.text : ""
        var confidence = (text.confidence + (objects.success ? 0.9 : 0.0)) / 2.0
        var metadata: [String: Any] = [
            "textExtractionSuccess": text.success,
            "objectDetectionSuccess": objects.success,
            "qwen2vlSuccess": qwen.success,
            "processingTime": Date().timeIntervalSince(task.timestamp)
        ]
        
        // Enhance with Qwen2VL results if available
        if qwen.success {
            extractedText += qwen.description.isEmpty ? "" : "\n\nAI Analysis:\n\(qwen.description)"
            confidence = max(confidence, qwen.confidence)
            metadata["qwen2vlDescription"] = qwen.description
            metadata["qwen2vlElements"] = qwen.detectedElements
        }
        
        // Add task-specific metadata
        if let sourceURL = task.options.sourceURL {
            metadata["sourceURL"] = sourceURL
        }
        
        if let captureMethod = task.options.captureMethod {
            metadata["captureMethod"] = captureMethod
        }
        
        if let batchIndex = task.options.batchIndex, let batchTotal = task.options.batchTotal {
            metadata["batchIndex"] = batchIndex
            metadata["batchTotal"] = batchTotal
        }
        
        return VisionAnalysisResult(
            success: true,
            confidence: confidence,
            detectedObjects: detectedObjects,
            text: extractedText,
            metadata: metadata
        )
    }
    
    private func analyzeWithQwen2VL(_ task: VisionTask) async -> Qwen2VLResult {
        do {
            let result = await qwen2vlService.analyzeImage(task.image, prompt: task.options.analysisPrompt)
            return result
        } catch {
            return Qwen2VLResult(
                success: false,
                confidence: 0.0,
                description: "",
                detectedElements: [],
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Supporting Types

public struct VisionAnalysisOptions {
    public var analysisPrompt: String
    public var geoLocation: String?
    public var sessionId: String?
    public var deviceType: DeviceType
    public var sourceURL: String?
    public var captureMethod: String?
    public var batchIndex: Int?
    public var batchTotal: Int?
    
    public init(
        analysisPrompt: String = "Analyze this image and describe what you see, including any text, UI elements, and interactive components.",
        geoLocation: String? = nil,
        sessionId: String? = nil,
        deviceType: DeviceType = .desktop,
        sourceURL: String? = nil,
        captureMethod: String? = nil,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil
    ) {
        self.analysisPrompt = analysisPrompt
        self.geoLocation = geoLocation
        self.sessionId = sessionId
        self.deviceType = deviceType
        self.sourceURL = sourceURL
        self.captureMethod = captureMethod
        self.batchIndex = batchIndex
        self.batchTotal = batchTotal
    }
}

public struct VisionAnalysisResult {
    public let success: Bool
    public let confidence: Double
    public let detectedObjects: [DetectedObject]
    public let text: String
    public let metadata: [String: Any]
    
    public init(success: Bool, confidence: Double, detectedObjects: [DetectedObject], text: String, metadata: [String: Any]) {
        self.success = success
        self.confidence = confidence
        self.detectedObjects = detectedObjects
        self.text = text
        self.metadata = metadata
    }
}

public struct DetectedObject {
    public let label: String
    public let confidence: Double
    public let boundingBox: CGRect
    
    public init(label: String, confidence: Double, boundingBox: CGRect) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct TextExtractionResult {
    public let success: Bool
    public let text: String
    public let confidence: Double
    public let error: String?
    
    public init(success: Bool, text: String, confidence: Double, error: String?) {
        self.success = success
        self.text = text
        self.confidence = confidence
        self.error = error
    }
}

public struct ObjectDetectionResult {
    public let success: Bool
    public let objects: [DetectedObject]
    public let error: String?
    
    public init(success: Bool, objects: [DetectedObject], error: String?) {
        self.success = success
        self.objects = objects
        self.error = error
    }
}

private struct VisionTask {
    let id: String
    let image: UIImage
    let options: VisionAnalysisOptions
    let timestamp: Date
}

// MARK: - Qwen2VL Service

private class Qwen2VLService {
    private let serverURL = "http://localhost:8000"
    
    func analyzeImage(_ image: UIImage, prompt: String) async -> Qwen2VLResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Qwen2VLResult(
                success: false,
                confidence: 0.0,
                description: "",
                detectedElements: [],
                error: "Failed to convert image to JPEG"
            )
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let payload: [String: Any] = [
            "image": base64Image,
            "prompt": prompt,
            "max_tokens": 1000
        ]
        
        guard let url = URL(string: "\(serverURL)/analyze") else {
            return Qwen2VLResult(
                success: false,
                confidence: 0.0,
                description: "",
                detectedElements: [],
                error: "Invalid server URL"
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return Qwen2VLResult(
                    success: false,
                    confidence: 0.0,
                    description: "",
                    detectedElements: [],
                    error: "Server returned error status"
                )
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            let description = json?["description"] as? String ?? ""
            let confidence = json?["confidence"] as? Double ?? 0.0
            let elements = json?["detected_elements"] as? [String] ?? []
            
            return Qwen2VLResult(
                success: true,
                confidence: confidence,
                description: description,
                detectedElements: elements,
                error: nil
            )
            
        } catch {
            return Qwen2VLResult(
                success: false,
                confidence: 0.0,
                description: "",
                detectedElements: [],
                error: error.localizedDescription
            )
        }
    }
}

private struct Qwen2VLResult {
    let success: Bool
    let confidence: Double
    let description: String
    let detectedElements: [String]
    let error: String?
}
