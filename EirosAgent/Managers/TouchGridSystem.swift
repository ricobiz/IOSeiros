
//
//  TouchGridSystem.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit
import Vision

@MainActor
class TouchGridSystem: ObservableObject {
    static let shared = TouchGridSystem()
    
    // MARK: - Published Properties
    @Published var isEnabled = false
    @Published var gridSize: CGSize = CGSize(width: 20, height: 20)
    @Published var lastTouchPoint: CGPoint?
    @Published var touchHistory: [TouchEvent] = []
    @Published var isCalibrated = false
    
    // MARK: - Private Properties
    private var screenBounds: CGRect = UIScreen.main.bounds
    private var webViewFrame: CGRect = .zero
    private var coordinateMapping: CoordinateMapping?
    
    private init() {
        setupCoordinateMapping()
    }
    
    // MARK: - Setup and Configuration
    
    func setupCoordinateMapping() {
        screenBounds = UIScreen.main.bounds
        coordinateMapping = CoordinateMapping(
            screenSize: screenBounds.size,
            webViewFrame: webViewFrame
        )
        isCalibrated = true
    }
    
    func updateWebViewFrame(_ frame: CGRect) {
        webViewFrame = frame
        setupCoordinateMapping()
    }
    
    // MARK: - Coordinate Conversion
    
    func convertVisionToScreen(_ visionRect: CGRect, imageSize: CGSize) -> CGRect {
        guard let mapping = coordinateMapping else {
            return .zero
        }
        
        // Convert normalized Vision coordinates to screen coordinates
        let screenRect = VNImageRectForNormalizedRect(visionRect, Int(imageSize.width), Int(imageSize.height))
        
        // Map to webview coordinates
        let webViewRect = CGRect(
            x: webViewFrame.origin.x + (screenRect.origin.x * webViewFrame.width / imageSize.width),
            y: webViewFrame.origin.y + (screenRect.origin.y * webViewFrame.height / imageSize.height),
            width: screenRect.width * webViewFrame.width / imageSize.width,
            height: screenRect.height * webViewFrame.height / imageSize.height
        )
        
        return webViewRect
    }
    
    func convertScreenToWebView(_ screenPoint: CGPoint) -> CGPoint {
        let relativeX = (screenPoint.x - webViewFrame.origin.x) / webViewFrame.width
        let relativeY = (screenPoint.y - webViewFrame.origin.y) / webViewFrame.height
        
        return CGPoint(
            x: relativeX * webViewFrame.width,
            y: relativeY * webViewFrame.height
        )
    }
    
    func getOptimalTouchPoint(for element: UIElement) -> CGPoint {
        let elementRect = element.boundingBox
        
        // Calculate center point of the element
        let centerX = elementRect.origin.x + elementRect.width / 2
        let centerY = elementRect.origin.y + elementRect.height / 2
        
        // Convert to screen coordinates
        let screenPoint = CGPoint(x: centerX, y: centerY)
        
        // Ensure point is within bounds
        let clampedPoint = CGPoint(
            x: max(0, min(screenBounds.width, screenPoint.x)),
            y: max(0, min(screenBounds.height, screenPoint.y))
        )
        
        return clampedPoint
    }
    
    // MARK: - Touch Event Generation
    
    func generateTouchEvent(at point: CGPoint, type: TouchEventType) -> TouchEvent {
        let touchEvent = TouchEvent(
            point: point,
            type: type,
            timestamp: Date(),
            screenBounds: screenBounds
        )
        
        touchHistory.append(touchEvent)
        lastTouchPoint = point
        
        // Keep history limited
        if touchHistory.count > 100 {
            touchHistory.removeFirst()
        }
        
        return touchEvent
    }
    
    // MARK: - Grid System
    
    func getGridPoints() -> [CGPoint] {
        var points: [CGPoint] = []
        
        let stepX = webViewFrame.width / gridSize.width
        let stepY = webViewFrame.height / gridSize.height
        
        for x in 0..<Int(gridSize.width) {
            for y in 0..<Int(gridSize.height) {
                let point = CGPoint(
                    x: webViewFrame.origin.x + CGFloat(x) * stepX + stepX / 2,
                    y: webViewFrame.origin.y + CGFloat(y) * stepY + stepY / 2
                )
                points.append(point)
            }
        }
        
        return points
    }
    
    func getNearestGridPoint(to point: CGPoint) -> CGPoint {
        let gridPoints = getGridPoints()
        
        var nearestPoint = gridPoints.first ?? point
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        for gridPoint in gridPoints {
            let distance = sqrt(pow(point.x - gridPoint.x, 2) + pow(point.y - gridPoint.y, 2))
            if distance < minDistance {
                minDistance = distance
                nearestPoint = gridPoint
            }
        }
        
        return nearestPoint
    }
    
    // MARK: - Touch Validation
    
    func validateTouchPoint(_ point: CGPoint) -> TouchValidationResult {
        // Check if point is within screen bounds
        guard screenBounds.contains(point) else {
            return TouchValidationResult(
                isValid: false,
                adjustedPoint: nil,
                reason: "Point is outside screen bounds"
            )
        }
        
        // Check if point is within webview bounds
        guard webViewFrame.contains(point) else {
            return TouchValidationResult(
                isValid: false,
                adjustedPoint: nil,
                reason: "Point is outside webview bounds"
            )
        }
        
        // Adjust to nearest grid point if grid is enabled
        let adjustedPoint = isEnabled ? getNearestGridPoint(to: point) : point
        
        return TouchValidationResult(
            isValid: true,
            adjustedPoint: adjustedPoint,
            reason: nil
        )
    }
    
    // MARK: - Touch Execution
    
    func executeTouchAt(_ point: CGPoint, type: TouchEventType = .tap) async -> Bool {
        let validation = validateTouchPoint(point)
        
        guard validation.isValid, let validPoint = validation.adjustedPoint else {
            print("Touch validation failed: \(validation.reason ?? "Unknown error")")
            return false
        }
        
        let touchEvent = generateTouchEvent(at: validPoint, type: type)
        
        // Here we would integrate with the actual touch simulation
        // For now, we'll simulate the touch execution
        await simulateTouchExecution(touchEvent)
        
        return true
    }
    
    private func simulateTouchExecution(_ touchEvent: TouchEvent) async {
        // Simulate touch execution delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        print("Executed touch: \(touchEvent.type.rawValue) at \(touchEvent.point)")
        
        // In a real implementation, this would use:
        // - JavaScript injection for web content
        // - Private APIs for system-level touches (jailbreak required)
        // - UI testing frameworks for app automation
    }
    
    // MARK: - Calibration
    
    func calibrateWithScreenshot(_ image: UIImage) async {
        // Use the image to calibrate coordinate mapping
        let imageSize = image.size
        
        // Update coordinate mapping based on actual screenshot
        coordinateMapping = CoordinateMapping(
            screenSize: imageSize,
            webViewFrame: webViewFrame
        )
        
        isCalibrated = true
        print("TouchGridSystem calibrated with image size: \(imageSize)")
    }
    
    // MARK: - Analytics
    
    func getTouchAnalytics() -> TouchAnalytics {
        let totalTouches = touchHistory.count
        let touchTypes = Dictionary(grouping: touchHistory, by: { $0.type })
        
        return TouchAnalytics(
            totalTouches: totalTouches,
            touchTypeDistribution: touchTypes.mapValues { $0.count },
            averageAccuracy: calculateAverageAccuracy(),
            lastTouchTime: touchHistory.last?.timestamp
        )
    }
    
    private func calculateAverageAccuracy() -> Double {
        // Calculate accuracy based on grid alignment
        guard !touchHistory.isEmpty else { return 0.0 }
        
        let accuracyScores = touchHistory.map { touchEvent -> Double in
            let nearestGrid = getNearestGridPoint(to: touchEvent.point)
            let distance = sqrt(pow(touchEvent.point.x - nearestGrid.x, 2) + pow(touchEvent.point.y - nearestGrid.y, 2))
            return max(0.0, 1.0 - (distance / 50.0)) // Normalize to 0-1 scale
        }
        
        return accuracyScores.reduce(0, +) / Double(accuracyScores.count)
    }
    
    // MARK: - Reset and Cleanup
    
    func reset() {
        touchHistory.removeAll()
        lastTouchPoint = nil
        isCalibrated = false
    }
    
    func clearHistory() {
        touchHistory.removeAll()
    }
}

// MARK: - Supporting Data Models

struct TouchEvent: Identifiable, Codable {
    let id = UUID()
    let point: CGPoint
    let type: TouchEventType
    let timestamp: Date
    let screenBounds: CGRect
    
    var relativePoint: CGPoint {
        return CGPoint(
            x: point.x / screenBounds.width,
            y: point.y / screenBounds.height
        )
    }
}

enum TouchEventType: String, Codable, CaseIterable {
    case tap = "tap"
    case doubleTap = "doubleTap"
    case longPress = "longPress"
    case swipeUp = "swipeUp"
    case swipeDown = "swipeDown"
    case swipeLeft = "swipeLeft"
    case swipeRight = "swipeRight"
    case pinch = "pinch"
    case zoom = "zoom"
    case scroll = "scroll"
    
    var displayName: String {
        switch self {
        case .tap: return "Tap"
        case .doubleTap: return "Double Tap"
        case .longPress: return "Long Press"
        case .swipeUp: return "Swipe Up"
        case .swipeDown: return "Swipe Down"
        case .swipeLeft: return "Swipe Left"
        case .swipeRight: return "Swipe Right"
        case .pinch: return "Pinch"
        case .zoom: return "Zoom"
        case .scroll: return "Scroll"
        }
    }
}

struct CoordinateMapping {
    let screenSize: CGSize
    let webViewFrame: CGRect
    let scaleFactor: CGFloat
    
    init(screenSize: CGSize, webViewFrame: CGRect) {
        self.screenSize = screenSize
        self.webViewFrame = webViewFrame
        self.scaleFactor = UIScreen.main.scale
    }
    
    func mapToWebView(_ screenPoint: CGPoint) -> CGPoint {
        let relativeX = (screenPoint.x - webViewFrame.origin.x) / webViewFrame.width
        let relativeY = (screenPoint.y - webViewFrame.origin.y) / webViewFrame.height
        
        return CGPoint(x: relativeX, y: relativeY)
    }
    
    func mapToScreen(_ webViewPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: webViewFrame.origin.x + webViewPoint.x * webViewFrame.width,
            y: webViewFrame.origin.y + webViewPoint.y * webViewFrame.height
        )
    }
}

struct TouchValidationResult {
    let isValid: Bool
    let adjustedPoint: CGPoint?
    let reason: String?
}

struct TouchAnalytics {
    let totalTouches: Int
    let touchTypeDistribution: [TouchEventType: Int]
    let averageAccuracy: Double
    let lastTouchTime: Date?
    
    var formattedAccuracy: String {
        return String(format: "%.1f%%", averageAccuracy * 100)
    }
}

// MARK: - Extensions

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
    
    func isWithin(_ rect: CGRect) -> Bool {
        return rect.contains(self)
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    func scaled(by factor: CGFloat) -> CGRect {
        return CGRect(
            x: origin.x * factor,
            y: origin.y * factor,
            width: size.width * factor,
            height: size.height * factor
        )
    }
}
