
//
//  Qwen2VLModels.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit

// MARK: - Qwen2-VL Model Configuration

struct Qwen2VLConfiguration {
    let modelName: String
    let version: String
    let parameters: String
    let maxInputTokens: Int
    let maxOutputTokens: Int
    let supportedImageFormats: [String]
    let maxImageResolution: CGSize
    let batchSize: Int
    let useNeuralEngine: Bool
    
    static let qwen2VL2B = Qwen2VLConfiguration(
        modelName: "Qwen2-VL-2B-Instruct",
        version: "2B",
        parameters: "2 billion",
        maxInputTokens: 32768,
        maxOutputTokens: 8192,
        supportedImageFormats: ["jpg", "jpeg", "png", "webp"],
        maxImageResolution: CGSize(width: 4096, height: 4096),
        batchSize: 1,
        useNeuralEngine: true
    )
}

// MARK: - UI Element Types Extended

enum UIElementType: String, Codable, CaseIterable {
    case button = "button"
    case textField = "textField"
    case label = "label"
    case image = "image"
    case text = "text"
    case icon = "icon"
    case switch_ = "switch"
    case slider = "slider"
    case segmentedControl = "segmentedControl"
    case navigationBar = "navigationBar"
    case tabBar = "tabBar"
    case toolbar = "toolbar"
    case cell = "cell"
    case header = "header"
    case footer = "footer"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .switch_: return "Switch"
        case .segmentedControl: return "Segmented Control"
        case .navigationBar: return "Navigation Bar"
        case .tabBar: return "Tab Bar"
        case .toolbar: return "Toolbar"
        default: return rawValue.capitalized
        }
    }
    
    var isInteractable: Bool {
        switch self {
        case .button, .textField, .switch_, .slider, .segmentedControl, .cell:
            return true
        default:
            return false
        }
    }
}

// MARK: - Screen Context

struct ScreenContext {
    let screenSize: CGSize
    let orientation: UIInterfaceOrientation
    let safeAreaInsets: UIEdgeInsets
    let deviceType: DeviceType
    let timestamp: Date
    
    enum DeviceType: String, Codable {
        case iPhone = "iPhone"
        case iPad = "iPad"
        case unknown = "unknown"
        
        static var current: DeviceType {
            let deviceModel = UIDevice.current.model
            if deviceModel.contains("iPhone") {
                return .iPhone
            } else if deviceModel.contains("iPad") {
                return .iPad
            } else {
                return .unknown
            }
        }
    }
    
    static var current: ScreenContext {
        let screen = UIScreen.main
        let bounds = screen.bounds
        
        var safeAreaInsets = UIEdgeInsets.zero
        if #available(iOS 11.0, *) {
            safeAreaInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? UIEdgeInsets.zero
        }
        
        return ScreenContext(
            screenSize: bounds.size,
            orientation: UIApplication.shared.statusBarOrientation,
            safeAreaInsets: safeAreaInsets,
            deviceType: DeviceType.current,
            timestamp: Date()
        )
    }
}

// MARK: - Qwen2-VL Prompt Templates

struct Qwen2VLPromptTemplate {
    static func uiAutomationPrompt(task: UIAutomationTaskType, target: String, context: ScreenContext) -> String {
        let basePrompt = """
        You are Qwen2-VL-2B, a vision-language model specialized in mobile UI automation. 
        Analyze this \(context.deviceType.rawValue) screen (\(Int(context.screenSize.width))x\(Int(context.screenSize.height))) and perform the requested task.
        
        Task: \(task.description)
        Target: \(target)
        
        """
        
        switch task {
        case .findElement:
            return basePrompt + """
            Find the UI element '\(target)' in this screen. Provide:
            1. Element type (button, text field, label, etc.)
            2. Exact bounding box coordinates
            3. Text content if any
            4. Whether it's interactable
            5. Confidence score (0-1)
            
            Format your response as structured data with precise coordinates.
            """
            
        case .clickElement:
            return basePrompt + """
            Locate the clickable element '\(target)' and provide the optimal touch coordinates.
            Consider:
            1. Element center point for best touch accuracy
            2. Minimum touch target size (44x44 points on iOS)
            3. Avoid overlapping elements
            4. Account for safe area insets
            
            Return the exact (x, y) coordinates for touch simulation.
            """
            
        case .extractText:
            return basePrompt + """
            Extract all readable text from this screen. Organize the text by:
            1. UI sections (navigation, content, footer)
            2. Element types (buttons, labels, text fields)
            3. Reading order (top to bottom, left to right)
            4. Include confidence scores for each text element
            
            Preserve text hierarchy and spatial relationships.
            """
            
        case .describeScreen:
            return basePrompt + """
            Provide a comprehensive description of this mobile screen including:
            1. Overall layout and structure
            2. All interactive elements and their purposes
            3. Navigation elements (back button, tabs, etc.)
            4. Content areas and their organization
            5. Visual hierarchy and design patterns
            6. Accessibility considerations
            
            Focus on elements relevant for UI automation.
            """
            
        case .findButton:
            return basePrompt + """
            Find all buttons on this screen, with special attention to '\(target)'.
            For each button, provide:
            1. Button text or label
            2. Button type (primary, secondary, icon, etc.)
            3. Exact coordinates and size
            4. Visual state (enabled, disabled, highlighted)
            5. Accessibility information
            
            Prioritize buttons matching '\(target)' in your response.
            """
            
        case .findTextField:
            return basePrompt + """
            Locate text input fields on this screen, focusing on '\(target)'.
            For each field, identify:
            1. Field type (text, password, email, etc.)
            2. Placeholder text or label
            3. Current content if visible
            4. Input constraints or formatting
            5. Associated labels or hints
            
            Provide precise coordinates for text input simulation.
            """
            
        case .navigateToElement:
            return basePrompt + """
            Analyze the navigation path to reach '\(target)' element.
            Consider:
            1. Current screen context and available navigation
            2. Required user actions (taps, swipes, scrolling)
            3. Intermediate screens or steps
            4. Alternative navigation paths
            5. Potential obstacles or confirmations
            
            Provide step-by-step navigation instructions.
            """
        }
    }
    
    static func visionAnalysisPrompt(context: ScreenContext) -> String {
        return """
        Analyze this \(context.deviceType.rawValue) screen using your vision capabilities.
        Screen dimensions: \(Int(context.screenSize.width))x\(Int(context.screenSize.height))
        Orientation: \(context.orientation.rawValue)
        
        Provide detailed analysis including:
        1. UI element detection and classification
        2. Text recognition and extraction
        3. Layout structure and hierarchy
        4. Interactive elements identification
        5. Visual design patterns
        6. Accessibility features
        7. Navigation structure
        
        Focus on actionable information for UI automation tasks.
        Use your training on mobile UI patterns to provide accurate element identification.
        """
    }
}

// MARK: - Extensions

extension UIAutomationTaskType {
    var description: String {
        switch self {
        case .findElement: return "Find UI Element"
        case .clickElement: return "Click Element"
        case .extractText: return "Extract Text"
        case .describeScreen: return "Describe Screen"
        case .findButton: return "Find Button"
        case .findTextField: return "Find Text Field"
        case .navigateToElement: return "Navigate to Element"
        }
    }
}

extension UIInterfaceOrientation {
    var rawValue: String {
        switch self {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Qwen2-VL Response Parser

struct Qwen2VLResponseParser {
    static func parseUIElements(from response: String) -> [UIAutomationElement] {
        // This would parse the actual Qwen2-VL model response
        // For now, we'll return mock data based on response content
        var elements: [UIAutomationElement] = []
        
        // Parse structured response from Qwen2-VL
        // In a real implementation, this would parse JSON or structured text output
        
        return elements
    }
    
    static func parseCoordinates(from response: String) -> [CGPoint] {
        // Parse coordinate information from model response
        var coordinates: [CGPoint] = []
        
        // Extract coordinate patterns like (x, y) or [x, y]
        let coordinatePattern = #"\((\d+),\s*(\d+)\)"#
        let regex = try? NSRegularExpression(pattern: coordinatePattern)
        let matches = regex?.matches(in: response, range: NSRange(response.startIndex..., in: response)) ?? []
        
        for match in matches {
            if match.numberOfRanges >= 3 {
                let xRange = Range(match.range(at: 1), in: response)
                let yRange = Range(match.range(at: 2), in: response)
                
                if let xRange = xRange, let yRange = yRange,
                   let x = Double(String(response[xRange])),
                   let y = Double(String(response[yRange])) {
                    coordinates.append(CGPoint(x: x, y: y))
                }
            }
        }
        
        return coordinates
    }
    
    static func parseConfidence(from response: String) -> Double {
        // Extract confidence score from response
        let confidencePattern = #"confidence[:\s]+([0-9.]+)"#
        let regex = try? NSRegularExpression(pattern: confidencePattern, options: .caseInsensitive)
        
        if let match = regex?.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response),
           let confidence = Double(String(response[range])) {
            return min(max(confidence, 0.0), 1.0) // Clamp between 0 and 1
        }
        
        return 0.8 // Default confidence
    }
}
