
//
//  Qwen2VLControlView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct Qwen2VLControlView: View {
    @StateObject private var qwen2VLManager = Qwen2VLManager.shared
    @StateObject private var touchGridSystem = TouchGridSystem.shared
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    
    @State private var selectedTask: UIAutomationTaskType = .findElement
    @State private var taskTarget = ""
    @State private var isAnalyzing = false
    @State private var lastResult: UIAutomationResult?
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Model Status Section
                modelStatusSection
                
                // Task Configuration Section
                taskConfigurationSection
                
                // Action Buttons Section
                actionButtonsSection
                
                // Results Section
                if let result = lastResult {
                    resultsSection(result)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Qwen2-VL Control")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingResults) {
                if let result = lastResult {
                    ResultsDetailView(result: result)
                }
            }
        }
    }
    
    // MARK: - Model Status Section
    
    private var modelStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: qwen2VLManager.isModelLoaded ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(qwen2VLManager.isModelLoaded ? .green : .orange)
                
                Text("Qwen2-VL-2B Status")
                    .font(.headline)
                
                Spacer()
                
                if qwen2VLManager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if !qwen2VLManager.isModelLoaded {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: qwen2VLManager.modelLoadingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("Loading model... \(Int(qwen2VLManager.modelLoadingProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Memory Usage:")
                        Spacer()
                        Text(qwen2VLManager.memoryUsage)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Last Inference:")
                        Spacer()
                        Text(String(format: "%.2fs", qwen2VLManager.lastInferenceTime))
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Average Time:")
                        Spacer()
                        Text(String(format: "%.2fs", qwen2VLManager.averageInferenceTime))
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            
            if let error = qwen2VLManager.modelError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Task Configuration Section
    
    private var taskConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UI Automation Task")
                .font(.headline)
            
            Picker("Task Type", selection: $selectedTask) {
                Text("Find Element").tag(UIAutomationTaskType.findElement)
                Text("Find Button").tag(UIAutomationTaskType.findButton)
                Text("Find Text Field").tag(UIAutomationTaskType.findTextField)
                Text("Extract Text").tag(UIAutomationTaskType.extractText)
                Text("Describe Screen").tag(UIAutomationTaskType.describeScreen)
                Text("Click Element").tag(UIAutomationTaskType.clickElement)
                Text("Navigate To").tag(UIAutomationTaskType.navigateToElement)
            }
            .pickerStyle(MenuPickerStyle())
            
            if needsTargetInput {
                TextField("Target (e.g., 'Login button', 'Username field')", text: $taskTarget)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Touch Grid Toggle
            HStack {
                Toggle("Show Touch Grid", isOn: $touchGridSystem.isGridVisible)
                
                Spacer()
                
                Text("\(Int(touchGridSystem.gridSize.width))×\(Int(touchGridSystem.gridSize.height))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var needsTargetInput: Bool {
        switch selectedTask {
        case .extractText, .describeScreen:
            return false
        default:
            return true
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: captureAndAnalyze) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        Text("Capture & Analyze")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(qwen2VLManager.isModelLoaded ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!qwen2VLManager.isModelLoaded || isAnalyzing)
                
                Button(action: analyzeCurrentScreen) {
                    HStack {
                        Image(systemName: "eye")
                        Text("Analyze Screen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(qwen2VLManager.isModelLoaded ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!qwen2VLManager.isModelLoaded || isAnalyzing)
            }
            
            HStack(spacing: 12) {
                Button(action: showModelInfo) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Model Info")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: clearResults) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Results Section
    
    private func resultsSection(_ result: UIAutomationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Analysis Results")
                    .font(.headline)
                
                Spacer()
                
                Button("View Details") {
                    showingResults = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.success ? .green : .red)
                    
                    Text(result.success ? "Success" : "Failed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let error = result.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Elements found: \(result.elements.count)")
                            .font(.caption)
                        
                        Text("Coordinates: \(result.coordinates.count)")
                            .font(.caption)
                        
                        Text("Confidence: \(Int(result.confidence * 100))%")
                            .font(.caption)
                        
                        Text("Processing time: \(String(format: "%.2fs", result.processingTime))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let response = result.modelResponse {
                    Text(response)
                        .font(.caption)
                        .padding(.top, 4)
                        .lineLimit(3)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func captureAndAnalyze() {
        Task {
            isAnalyzing = true
            
            guard let screenshot = await screenCaptureManager.captureScreen() else {
                isAnalyzing = false
                return
            }
            
            let task = UIAutomationTask(type: selectedTask, target: taskTarget)
            let result = await qwen2VLManager.analyzeScreenForUIAutomation(screenshot, task: task)
            
            lastResult = result
            
            // Highlight found elements on grid
            if result.success && !result.elements.isEmpty {
                touchGridSystem.highlightElementsOnGrid(result.elements)
            }
            
            isAnalyzing = false
        }
    }
    
    private func analyzeCurrentScreen() {
        Task {
            isAnalyzing = true
            
            // Simulate screen analysis without capture
            let task = UIAutomationTask(type: selectedTask, target: taskTarget)
            
            // Create a dummy image for analysis
            let dummyImage = UIImage(systemName: "rectangle") ?? UIImage()
            let result = await qwen2VLManager.analyzeScreenForUIAutomation(dummyImage, task: task)
            
            lastResult = result
            
            isAnalyzing = false
        }
    }
    
    private func showModelInfo() {
        // This could show a detailed model info sheet
        print("Model Info: \(qwen2VLManager.modelInfo)")
    }
    
    private func clearResults() {
        lastResult = nil
        touchGridSystem.clearSelection()
    }
}

// MARK: - Results Detail View

struct ResultsDetailView: View {
    let result: UIAutomationResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary Section
                    summarySection
                    
                    // Elements Section
                    if !result.elements.isEmpty {
                        elementsSection
                    }
                    
                    // Coordinates Section
                    if !result.coordinates.isEmpty {
                        coordinatesSection
                    }
                    
                    // Model Response Section
                    if let response = result.modelResponse {
                        modelResponseSection(response)
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(result.success ? "Success" : "Failed")
                        .foregroundColor(result.success ? .green : .red)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Confidence:")
                    Spacer()
                    Text("\(Int(result.confidence * 100))%")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Processing Time:")
                    Spacer()
                    Text(String(format: "%.3fs", result.processingTime))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Elements Found:")
                    Spacer()
                    Text("\(result.elements.count)")
                        .fontWeight(.medium)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var elementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UI Elements")
                .font(.headline)
            
            ForEach(Array(result.elements.enumerated()), id: \.offset) { index, element in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(index + 1). \(element.type.rawValue.capitalized)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(element.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !element.text.isEmpty {
                        Text("Text: \(element.text)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Position: (\(Int(element.boundingBox.midX)), \(Int(element.boundingBox.midY)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Size: \(Int(element.boundingBox.width))×\(Int(element.boundingBox.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if element.isInteractable {
                        Text("Interactable")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Touch Coordinates")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(Array(result.coordinates.enumerated()), id: \.offset) { index, coordinate in
                    VStack {
                        Text("Point \(index + 1)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("(\(Int(coordinate.x)), \(Int(coordinate.y)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func modelResponseSection(_ response: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Response")
                .font(.headline)
            
            Text(response)
                .font(.subheadline)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview

struct Qwen2VLControlView_Previews: PreviewProvider {
    static var previews: some View {
        Qwen2VLControlView()
    }
}
