
//
//  ScreenCaptureManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit
import Combine

@MainActor
class ScreenCaptureManager: ObservableObject {
    static let shared = ScreenCaptureManager()
    
    @Published var lastScreenshot: UIImage?
    @Published var isCapturing = false
    @Published var captureError: String?
    @Published var screenshotHistory: [ScreenshotRecord] = []
    
    private let maxHistoryCount = 50
    
    private init() {}
    
    // MARK: - Screenshot Capture
    
    func captureScreen() async -> UIImage? {
        isCapturing = true
        captureError = nil
        
        defer {
            isCapturing = false
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    self.captureError = "No active window found"
                    continuation.resume(returning: nil)
                    return
                }
                
                let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
                let screenshot = renderer.image { context in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                
                self.lastScreenshot = screenshot
                self.addToHistory(screenshot)
                continuation.resume(returning: screenshot)
            }
        }
    }
    
    func captureView(_ view: UIView) -> UIImage? {
        isCapturing = true
        captureError = nil
        
        defer {
            isCapturing = false
        }
        
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        let screenshot = renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        
        lastScreenshot = screenshot
        addToHistory(screenshot)
        return screenshot
    }
    
    // MARK: - SwiftUI View Capture
    
    func captureSwiftUIView<Content: View>(_ view: Content) -> UIImage? {
        isCapturing = true
        captureError = nil
        
        defer {
            isCapturing = false
        }
        
        let controller = UIHostingController(rootView: view)
        let targetSize = controller.view.intrinsicContentSize
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let screenshot = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        
        lastScreenshot = screenshot
        addToHistory(screenshot)
        return screenshot
    }
    
    // MARK: - Scheduled Capture
    
    private var captureTimer: Timer?
    
    func startPeriodicCapture(interval: TimeInterval) {
        stopPeriodicCapture()
        
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.captureScreen()
            }
        }
    }
    
    func stopPeriodicCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
    }
    
    // MARK: - History Management
    
    private func addToHistory(_ image: UIImage) {
        let record = ScreenshotRecord(image: image, timestamp: Date())
        screenshotHistory.insert(record, at: 0)
        
        if screenshotHistory.count > maxHistoryCount {
            screenshotHistory.removeLast()
        }
    }
    
    func clearHistory() {
        screenshotHistory.removeAll()
    }
    
    func getScreenshotAt(index: Int) -> UIImage? {
        guard index >= 0 && index < screenshotHistory.count else {
            return nil
        }
        return screenshotHistory[index].image
    }
    
    // MARK: - Save to Photos
    
    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            captureError = "Failed to save screenshot: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Utility Methods
    
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Data Models

struct ScreenshotRecord: Identifiable {
    let id = UUID()
    let image: UIImage
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - SwiftUI Extensions

extension View {
    func screenshot() -> UIImage? {
        return ScreenCaptureManager.shared.captureSwiftUIView(self)
    }
}
