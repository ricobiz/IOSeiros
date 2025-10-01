
//
//  VisionAnalysisView.swift
//  EirosAgent
//
//  Vision Analysis UI with DECODO Screenshot Integration
//  Created: 2025-09-22
//

import SwiftUI

struct VisionAnalysisView: View {
    @StateObject private var visionManager = VisionManager.shared
    @StateObject private var proxyManager = ProxyManager.shared
    @StateObject private var decodoConfig = DECODOConfiguration.shared
    
    @State private var selectedImage: UIImage?
    @State private var analysisResult: VisionAnalysisResult?
    @State private var isAnalyzing = false
    @State private var showingImagePicker = false
    @State private var showingURLInput = false
    @State private var urlToAnalyze = ""
    @State private var analysisPrompt = "Analyze this image and describe what you see, including any text, UI elements, and interactive components."
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    statusSection
                    imageInputSection
                    analysisOptionsSection
                    if let result = analysisResult {
                        resultsSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Vision Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Options") {
                        Button("Analyze URL Screenshot") {
                            showingURLInput = true
                        }
                        .disabled(!decodoConfig.isConfigured || !proxyManager.isProxyEnabled)
                        
                        Button("Pick Image") {
                            showingImagePicker = true
                        }
                        
                        Button("Clear Results") {
                            clearResults()
                        }
                        .disabled(analysisResult == nil)
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingURLInput) {
                URLInputView(url: $urlToAnalyze) { url in
                    analyzeURLScreenshot(url)
                }
            }
            .sheet(isPresented: $showingResults) {
                if let result = analysisResult {
                    DetailedResultsView(result: result)
                }
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            HStack {
                StatusIndicator(
                    title: "Vision Analysis",
                    status: visionManager.isEnabled ? "Enabled" : "Disabled",
                    color: visionManager.isEnabled ? .green : .gray,
                    icon: "eye"
                )
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { visionManager.isEnabled },
                    set: { enabled in
                        visionManager.isEnabled = enabled
                    }
                ))
                .labelsHidden()
            }
            
            HStack {
                StatusIndicator(
                    title: "DECODO Proxy",
                    status: proxyManager.connectionStatus.description,
                    color: Color(proxyManager.connectionStatus.color),
                    icon: "network"
                )
                
                Spacer()
                
                if decodoConfig.isConfigured {
                    Button(proxyManager.isProxyEnabled ? "Disable" : "Enable") {
                        Task {
                            if proxyManager.isProxyEnabled {
                                proxyManager.disableProxy()
                            } else {
                                await proxyManager.enableDECODOSiteUnblocker()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Configure") {
                        // Navigate to DECODO settings
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if visionManager.isProcessing {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Analyzing image...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Image Input Section
    
    private var imageInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Image Input")
                .font(.headline)
            
            if let image = selectedImage {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    HStack {
                        Button("Analyze Image") {
                            analyzeSelectedImage()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!visionManager.isEnabled || isAnalyzing)
                        
                        Spacer()
                        
                        Button("Remove") {
                            selectedImage = nil
                            analysisResult = nil
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No image selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("Pick Image") {
                            showingImagePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Analyze URL") {
                            showingURLInput = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(!decodoConfig.isConfigured || !proxyManager.isProxyEnabled)
                    }
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Analysis Options Section
    
    private var analysisOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Options")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis Prompt")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter analysis prompt", text: $analysisPrompt, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PromptTemplate(
                    title: "UI Elements",
                    description: "Identify buttons, forms, links",
                    prompt: "Identify and describe all UI elements in this image, including buttons, forms, input fields, links, and navigation elements."
                ) {
                    analysisPrompt = $0
                }
                
                PromptTemplate(
                    title: "Text Extraction",
                    description: "Extract all visible text",
                    prompt: "Extract and transcribe all visible text in this image, maintaining the original structure and formatting."
                ) {
                    analysisPrompt = $0
                }
                
                PromptTemplate(
                    title: "Layout Analysis",
                    description: "Analyze page structure",
                    prompt: "Analyze the layout and structure of this webpage or interface, describing the organization of content and visual hierarchy."
                ) {
                    analysisPrompt = $0
                }
                
                PromptTemplate(
                    title: "Automation Guide",
                    description: "Generate automation steps",
                    prompt: "Analyze this interface and suggest specific automation steps, including CSS selectors and actions needed to interact with elements."
                ) {
                    analysisPrompt = $0
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Results Section
    
    private func resultsSection(_ result: VisionAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Analysis Results")
                    .font(.headline)
                
                Spacer()
                
                Button("View Details") {
                    showingResults = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Success indicator
                HStack {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.success ? .green : .red)
                    
                    Text(result.success ? "Analysis completed" : "Analysis failed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Confidence: \(Int(result.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Detected objects
                if !result.detectedObjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected Objects (\(result.detectedObjects.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(result.detectedObjects.prefix(6), id: \.label) { object in
                                VStack(spacing: 4) {
                                    Text(object.label)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("\(Int(object.confidence * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.systemGray6))
                                )
                            }
                        }
                        
                        if result.detectedObjects.count > 6 {
                            Text("+ \(result.detectedObjects.count - 6) more objects")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Extracted text preview
                if !result.text.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Text")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(result.text.prefix(200) + (result.text.count > 200 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
                
                // Metadata
                if let processingTime = result.metadata["processingTime"] as? TimeInterval {
                    Text("Processing time: \(String(format: "%.2f", processingTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Actions
    
    private func analyzeSelectedImage() {
        guard let image = selectedImage else { return }
        
        isAnalyzing = true
        
        Task {
            let options = VisionAnalysisOptions(analysisPrompt: analysisPrompt)
            let result = await visionManager.analyzeImage(image, options: options)
            
            await MainActor.run {
                self.analysisResult = result
                self.isAnalyzing = false
            }
        }
    }
    
    private func analyzeURLScreenshot(_ url: String) {
        isAnalyzing = true
        
        Task {
            let options = VisionAnalysisOptions(analysisPrompt: analysisPrompt)
            let result = await visionManager.analyzeScreenshot(from: url, using: proxyManager, options: options)
            
            await MainActor.run {
                self.analysisResult = result
                self.isAnalyzing = false
                
                // If successful, also set the screenshot as selected image
                if result.success,
                   let screenshotData = result.metadata["screenshotData"] as? Data,
                   let image = UIImage(data: screenshotData) {
                    self.selectedImage = image
                }
            }
        }
    }
    
    private func clearResults() {
        analysisResult = nil
        selectedImage = nil
    }
}

// MARK: - Supporting Views

struct PromptTemplate: View {
    let title: String
    let description: String
    let prompt: String
    let onSelect: (String) -> Void
    
    var body: some View {
        Button(action: { onSelect(prompt) }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct URLInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    let onAnalyze: (String) -> Void
    
    @State private var geoLocation = ""
    @State private var deviceType: DeviceType = .desktop
    
    var body: some View {
        NavigationView {
            Form {
                Section("URL") {
                    TextField("Enter URL to analyze", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Screenshot Options") {
                    TextField("Geo Location (optional)", text: $geoLocation)
                        .placeholder(when: geoLocation.isEmpty) {
                            Text("e.g., United States, Germany")
                                .foregroundColor(.secondary)
                        }
                    
                    Picker("Device Type", selection: $deviceType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Analyze URL Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Analyze") {
                        onAnalyze(url)
                        dismiss()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}

struct DetailedResultsView: View {
    @Environment(\.dismiss) private var dismiss
    let result: VisionAnalysisResult
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis Summary")
                            .font(.headline)
                        
                        HStack {
                            Label(result.success ? "Success" : "Failed", systemImage: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                            
                            Spacer()
                            
                            Text("Confidence: \(Int(result.confidence * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Full text
                    if !result.text.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Extracted Text")
                                .font(.headline)
                            
                            Text(result.text)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                        }
                    }
                    
                    // Detected objects
                    if !result.detectedObjects.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Detected Objects")
                                .font(.headline)
                            
                            ForEach(result.detectedObjects, id: \.label) { object in
                                HStack {
                                    Text(object.label)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(object.confidence * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadata")
                            .font(.headline)
                        
                        ForEach(Array(result.metadata.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(result.metadata[key] ?? "N/A")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
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
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

struct VisionAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        VisionAnalysisView()
    }
}
