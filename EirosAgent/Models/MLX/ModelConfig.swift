//
//  ModelConfig.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//

import Foundation

struct MLXModelConfig {
    static let qwen2VL2B = MLXModelInfo(
        name: "Qwen2-VL-2B-4bit",
        path: "mlx-community/Qwen2-VL-2B-4bit",
        framework: .mlx,
        quantization: .int4,
        capabilities: [.imageAnalysis, .textGeneration, .visionLanguage, .uiAutomation],
        inputTypes: [.image, .text],
        outputType: .text,
        modelSize: "~1.2GB",
        parameters: "2B",
        contextLength: 32768,
        supportedLanguages: ["en", "zh", "ja", "ko", "ar", "es", "fr", "de", "ru"],
        requiresGPU: false,
        minimumRAM: "4GB",
        recommendedRAM: "8GB"
    )
}

struct MLXModelInfo {
    let name: String
    let path: String
    let framework: MLFramework
    let quantization: QuantizationType
    let capabilities: [ModelCapability]
    let inputTypes: [InputType]
    let outputType: OutputType
    let modelSize: String
    let parameters: String
    let contextLength: Int
    let supportedLanguages: [String]
    let requiresGPU: Bool
    let minimumRAM: String
    let recommendedRAM: String
}

enum MLFramework: String, CaseIterable {
    case mlx = "MLX"
    case coreml = "CoreML"
    case onnx = "ONNX"
    case pytorch = "PyTorch"
}

enum QuantizationType: String, CaseIterable {
    case float32 = "FP32"
    case float16 = "FP16"
    case int8 = "INT8"
    case int4 = "INT4"
    case none = "None"
    
    var description: String {
        switch self {
        case .float32:
            return "32-bit floating point (highest quality, largest size)"
        case .float16:
            return "16-bit floating point (good quality, medium size)"
        case .int8:
            return "8-bit integer (good quality, smaller size)"
        case .int4:
            return "4-bit integer (acceptable quality, smallest size)"
        case .none:
            return "No quantization applied"
        }
    }
    
    var compressionRatio: Float {
        switch self {
        case .float32:
            return 1.0
        case .float16:
            return 2.0
        case .int8:
            return 4.0
        case .int4:
            return 8.0
        case .none:
            return 1.0
        }
    }
}

enum ModelCapability: String, CaseIterable {
    case imageAnalysis = "Image Analysis"
    case textGeneration = "Text Generation"
    case visionLanguage = "Vision-Language Understanding"
    case uiAutomation = "UI Automation"
    case objectDetection = "Object Detection"
    case textRecognition = "Text Recognition"
    case multilingualSupport = "Multilingual Support"
    case conversational = "Conversational AI"
    
    var icon: String {
        switch self {
        case .imageAnalysis:
            return "photo.on.rectangle"
        case .textGeneration:
            return "text.bubble"
        case .visionLanguage:
            return "eye.circle"
        case .uiAutomation:
            return "gearshape.2"
        case .objectDetection:
            return "viewfinder.circle"
        case .textRecognition:
            return "doc.text.viewfinder"
        case .multilingualSupport:
            return "globe"
        case .conversational:
            return "message.circle"
        }
    }
}

enum InputType: String, CaseIterable {
    case image = "Image"
    case text = "Text"
    case video = "Video"
    case audio = "Audio"
    
    var icon: String {
        switch self {
        case .image:
            return "photo"
        case .text:
            return "text.cursor"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        }
    }
}

enum OutputType: String, CaseIterable {
    case text = "Text"
    case image = "Image"
    case structured = "Structured Data"
    case multimodal = "Multimodal"
    
    var icon: String {
        switch self {
        case .text:
            return "text.bubble"
        case .image:
            return "photo"
        case .structured:
            return "list.bullet.rectangle"
        case .multimodal:
            return "square.grid.3x3"
        }
    }
}

// MARK: - Model Performance Metrics

struct ModelPerformanceMetrics {
    let averageInferenceTime: TimeInterval
    let peakMemoryUsage: Int // in MB
    let averageMemoryUsage: Int // in MB
    let tokensPerSecond: Float
    let accuracy: Float // 0.0 to 1.0
    let batteryImpact: BatteryImpact
    let thermalState: ThermalState
}

enum BatteryImpact: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "orange"
        case .high:
            return "red"
        }
    }
}

enum ThermalState: String, CaseIterable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .nominal:
            return "green"
        case .fair:
            return "yellow"
        case .serious:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

// MARK: - Model Download and Management

struct ModelDownloadInfo {
    let url: String
    let checksum: String
    let size: Int64 // in bytes
    let version: String
    let releaseDate: Date
    let changelog: String
}

extension MLXModelInfo {
    var downloadInfo: ModelDownloadInfo {
        return ModelDownloadInfo(
            url: "https://huggingface.co/\(path)",
            checksum: "sha256:placeholder", // Would be actual checksum
            size: 1_200_000_000, // ~1.2GB
            version: "1.0.0",
            releaseDate: Date(),
            changelog: "Initial release of Qwen2-VL-2B 4-bit quantized model for MLX"
        )
    }
    
    var isCompatibleWithDevice: Bool {
        // Check device compatibility
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        let requiredMemory: UInt64 = 4_000_000_000 // 4GB minimum
        
        return availableMemory >= requiredMemory
    }
    
    var estimatedDownloadTime: TimeInterval {
        // Estimate based on average mobile connection speed (10 Mbps)
        let averageSpeedBytesPerSecond: Double = 1_250_000 // 10 Mbps in bytes/sec
        return Double(downloadInfo.size) / averageSpeedBytesPerSecond
    }
}
