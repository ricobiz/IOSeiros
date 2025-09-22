
//
//  CoordinateMapper.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit

class CoordinateMapper {
    static let shared = CoordinateMapper()
    
    private init() {}
    
    // MARK: - Coordinate System Conversion
    
    /// Converts normalized coordinates (0-1) to screen coordinates
    func convertNormalizedToScreen(_ normalizedPoint: CGPoint, screenSize: CGSize) -> CGPoint {
        return CGPoint(
            x: normalizedPoint.x * screenSize.width,
            y: normalizedPoint.y * screenSize.height
        )
    }
    
    /// Converts screen coordinates to normalized coordinates (0-1)
    func convertScreenToNormalized(_ screenPoint: CGPoint, screenSize: CGSize) -> CGPoint {
        return CGPoint(
            x: screenPoint.x / screenSize.width,
            y: screenPoint.y / screenSize.height
        )
    }
    
    /// Converts image coordinates to screen coordinates
    func convertImageToScreen(_ imagePoint: CGPoint, imageSize: CGSize, screenSize: CGSize) -> CGPoint {
        let scaleX = screenSize.width / imageSize.width
        let scaleY = screenSize.height / imageSize.height
        
        return CGPoint(
            x: imagePoint.x * scaleX,
            y: imagePoint.y * scaleY
        )
    }
    
    /// Converts bounding box from image coordinates to screen coordinates
    func convertToScreenCoordinates(_ boundingBox: CGRect, imageSize: CGSize) -> CGPoint {
        let screenSize = UIScreen.main.bounds.size
        
        // Convert center point of bounding box
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        
        let screenPoint = convertImageToScreen(
            CGPoint(x: centerX, y: centerY),
            imageSize: imageSize,
            screenSize: screenSize
        )
        
        return screenPoint
    }
    
    /// Converts Vision framework normalized coordinates to screen coordinates
    func convertVisionToScreen(_ visionPoint: CGPoint, screenSize: CGSize) -> CGPoint {
        // Vision framework uses bottom-left origin, iOS uses top-left
        let flippedY = 1.0 - visionPoint.y
        
        return CGPoint(
            x: visionPoint.x * screenSize.width,
            y: flippedY * screenSize.height
        )
    }
    
    /// Converts Vision framework bounding box to screen coordinates
    func convertVisionBoundingBoxToScreen(_ boundingBox: CGRect, screenSize: CGSize) -> CGRect {
        // Vision framework uses bottom-left origin, iOS uses top-left
        let flippedY = 1.0 - boundingBox.origin.y - boundingBox.height
        
        return CGRect(
            x: boundingBox.origin.x * screenSize.width,
            y: flippedY * screenSize.height,
            width: boundingBox.width * screenSize.width,
            height: boundingBox.height * screenSize.height
        )
    }
    
    // MARK: - Touch Grid Integration
    
    /// Maps coordinates to touch grid system
    func mapToTouchGrid(_ point: CGPoint, gridSize: CGSize) -> GridCoordinate {
        let gridX = Int(point.x / (UIScreen.main.bounds.width / gridSize.width))
        let gridY = Int(point.y / (UIScreen.main.bounds.height / gridSize.height))
        
        return GridCoordinate(
            x: min(max(gridX, 0), Int(gridSize.width) - 1),
            y: min(max(gridY, 0), Int(gridSize.height) - 1)
        )
    }
    
    /// Converts grid coordinates back to screen coordinates
    func convertGridToScreen(_ gridCoordinate: GridCoordinate, gridSize: CGSize) -> CGPoint {
        let screenSize = UIScreen.main.bounds.size
        let cellWidth = screenSize.width / gridSize.width
        let cellHeight = screenSize.height / gridSize.height
        
        return CGPoint(
            x: (CGFloat(gridCoordinate.x) + 0.5) * cellWidth,
            y: (CGFloat(gridCoordinate.y) + 0.5) * cellHeight
        )
    }
    
    // MARK: - Coordinate Validation
    
    /// Validates that coordinates are within screen bounds
    func validateScreenCoordinates(_ point: CGPoint) -> Bool {
        let screenBounds = UIScreen.main.bounds
        return screenBounds.contains(point)
    }
    
    /// Clamps coordinates to screen bounds
    func clampToScreenBounds(_ point: CGPoint) -> CGPoint {
        let screenBounds = UIScreen.main.bounds
        
        return CGPoint(
            x: min(max(point.x, 0), screenBounds.width),
            y: min(max(point.y, 0), screenBounds.height)
        )
    }
    
    // MARK: - Coordinate Utilities
    
    /// Calculates distance between two points
    func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Finds the closest point from a list of points
    func findClosestPoint(to target: CGPoint, from points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        
        return points.min { point1, point2 in
            distance(from: target, to: point1) < distance(from: target, to: point2)
        }
    }
    
    /// Converts multiple points with batch processing
    func batchConvertToScreen(_ points: [CGPoint], imageSize: CGSize) -> [CGPoint] {
        let screenSize = UIScreen.main.bounds.size
        
        return points.map { point in
            convertImageToScreen(point, imageSize: imageSize, screenSize: screenSize)
        }
    }
    
    // MARK: - Device-Specific Adjustments
    
    /// Adjusts coordinates for device-specific characteristics
    func adjustForDevice(_ point: CGPoint) -> CGPoint {
        let deviceModel = UIDevice.current.model
        var adjustedPoint = point
        
        // Device-specific adjustments
        if deviceModel.contains("iPhone") {
            // iPhone-specific adjustments (e.g., notch, home indicator)
            if hasNotch() {
                adjustedPoint.y = max(adjustedPoint.y, 44) // Avoid notch area
            }
            
            if hasHomeIndicator() {
                adjustedPoint.y = min(adjustedPoint.y, UIScreen.main.bounds.height - 34) // Avoid home indicator
            }
        }
        
        return adjustedPoint
    }
    
    private func hasNotch() -> Bool {
        if #available(iOS 11.0, *) {
            return UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0 > 20
        }
        return false
    }
    
    private func hasHomeIndicator() -> Bool {
        if #available(iOS 11.0, *) {
            return UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0 > 0
        }
        return false
    }
}

// MARK: - Supporting Data Structures

struct GridCoordinate {
    let x: Int
    let y: Int
    
    var description: String {
        return "(\(x), \(y))"
    }
}

struct CoordinateTransform {
    let sourceSize: CGSize
    let targetSize: CGSize
    let scaleX: CGFloat
    let scaleY: CGFloat
    
    init(from sourceSize: CGSize, to targetSize: CGSize) {
        self.sourceSize = sourceSize
        self.targetSize = targetSize
        self.scaleX = targetSize.width / sourceSize.width
        self.scaleY = targetSize.height / sourceSize.height
    }
    
    func apply(to point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * scaleX,
            y: point.y * scaleY
        )
    }
    
    func apply(to rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }
}

// MARK: - Extensions

extension CGPoint {
    /// Returns a point adjusted for the current device
    func adjustedForDevice() -> CGPoint {
        return CoordinateMapper.shared.adjustForDevice(self)
    }
    
    /// Returns true if the point is within screen bounds
    var isWithinScreenBounds: Bool {
        return CoordinateMapper.shared.validateScreenCoordinates(self)
    }
    
    /// Returns the point clamped to screen bounds
    var clampedToScreen: CGPoint {
        return CoordinateMapper.shared.clampToScreenBounds(self)
    }
}

extension CGRect {
    /// Returns the center point of the rectangle
    var centerPoint: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    /// Returns the rectangle adjusted for the current device
    func adjustedForDevice() -> CGRect {
        let adjustedOrigin = origin.adjustedForDevice()
        return CGRect(origin: adjustedOrigin, size: size)
    }
}
