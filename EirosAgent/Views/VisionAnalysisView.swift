
//
//  VisionAnalysisView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct VisionAnalysisView: View {
    @StateObject private var visionManager = VisionManager.shared
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var analysisMode: AnalysisMode = .fullAnalysis
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vision Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Analyze images, capture screenshots, and extract information using AI vision capabilities.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Quick Actions
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        QuickActionCard(
                            title: "Capture Screen",
                            icon: "camera.viewfinder",
                            color: .blue
                        ) {
                            Task {
                                await captureAndAnalyzeScreen()
                            }
                        }
                        
                        QuickActionCard(
                            title: "Extract Text",
                            icon: "doc.text.viewfinder",
                            color: .green
                        ) {
                            Task {
                                await extractTextFromScreen()
                            }
                        }
                        
                        QuickActionCard(
                            title: "Find UI Elements",
                            icon: "rectangle.3.group",
                            color: .orange
                        ) {
                            Task {
                                await findUIElements()
                            }
                        }
                        
                        QuickActionCard(
                            title: "Choose Image",
                            icon: "photo.on.rectangle",
                            color: .purple
                        ) {
                            showingImagePicker = true
                        }
                    }
                    .padding(.horizontal)
                    
                    // Analysis Mode Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis Mode")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("Analysis Mode", selection: $analysisMode) {
                            ForEach(AnalysisMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    
                    // Current Image Preview
                    if let image = selectedImage ?? screenCaptureManager.lastScreenshot {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Image")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            
                            Button("Analyze This Image") {
                                Task {
                                    await analyzeCurrentImage(image)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Performance Metrics
                    if visionManager.lastProcessingTime > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Performance")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack {
                                MetricCard(
                                    title: "Last Processing",
                                    value: String(format: "%.2fs", visionManager.lastProcessingTime),
                                    icon: "clock"
                                )
                                
                                MetricCard(
                                    title: "Average Time",
                                    value: String(format: "%.2fs", visionManager.averageProcessingTime),
                                    icon: "chart.line.uptrend.xyaxis"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Recent Results
                    if let result = visionManager.lastAnalysisResult {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Latest Analysis")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            AnalysisResultCard(result: result)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Error Display
                    if let error = visionManager.analysisError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                            
                            Text(error)
                                .font(.body)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .overlay(
                Group {
                    if visionManager.isProcessing || screenCaptureManager.isCapturing {
                        ProcessingOverlay()
                    }
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func captureAndAnalyzeScreen() async {
        guard let screenshot = await screenCaptureManager.captureScreen() else {
            return
        }
        
        selectedImage = screenshot
        await analyzeCurrentImage(screenshot)
    }
    
    private func extractTextFromScreen() async {
        await enhancedLLMManager.extractTextFromScreen()
    }
    
    private func findUIElements() async {
        await enhancedLLMManager.findUIElements(matching: "button")
    }
    
    private func analyzeCurrentImage(_ image: UIImage) async {
        switch analysisMode {
        case .textOnly:
            _ = await visionManager.recognizeText(in: image)
        case .objectsOnly:
            _ = await visionManager.detectObjects(in: image)
        case .uiElements:
            _ = await visionManager.analyzeUIElements(in: image)
        case .fullAnalysis:
            _ = await visionManager.analyzeScreen(image)
        }
        
        await enhancedLLMManager.analyzeImage(image, prompt: "Analyze this image using \(analysisMode.displayName.lowercased()) mode")
    }
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

struct AnalysisResultCard: View {
    let result: ScreenAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Analysis Results")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ResultRow(icon: "doc.text", title: "Text Elements", count: result.detectedText.count)
                ResultRow(icon: "cube", title: "Objects", count: result.detectedObjects.count)
                ResultRow(icon: "rectangle.3.group", title: "UI Elements", count: result.uiElements.count)
            }
            
            if !result.screenDescription.isEmpty {
                Text(result.screenDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ResultRow: View {
    let icon: String
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Analysis Mode

enum AnalysisMode: String, CaseIterable {
    case textOnly = "text"
    case objectsOnly = "objects"
    case uiElements = "ui"
    case fullAnalysis = "full"
    
    var displayName: String {
        switch self {
        case .textOnly: return "Text Only"
        case .objectsOnly: return "Objects Only"
        case .uiElements: return "UI Elements"
        case .fullAnalysis: return "Full Analysis"
        }
    }
}

#Preview {
    VisionAnalysisView()
}
