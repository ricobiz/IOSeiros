//
//  SettingsView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var llmManager = LLMManager.shared
    @AppStorage("selectedModel") private var selectedModel = "llama-2-7b-chat"
    @AppStorage("maxTokens") private var maxTokens = 512
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("enableOCR") private var enableOCR = true
    @AppStorage("enableBrowserAutomation") private var enableBrowserAutomation = true
    
    private let availableModels = [
        "llama-2-7b-chat",
        "llama-2-13b-chat", 
        "codellama-7b-instruct",
        "mistral-7b-instruct"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Model Configuration Section
                Section("AI Model Configuration") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model.capitalized).tag(model)
                        }
                    }
                    .onChange(of: selectedModel) { _ in
                        llmManager.reloadModel()
                    }
                    
                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        Text("\(maxTokens)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(maxTokens) },
                        set: { maxTokens = Int($0) }
                    ), in: 128...2048, step: 64)
                    
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", temperature))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $temperature, in: 0.1...2.0, step: 0.1)
                }
                
                // Features Section
                Section("Features") {
                    Toggle("OCR Text Recognition", isOn: $enableOCR)
                    Toggle("Browser Automation", isOn: $enableBrowserAutomation)
                }
                
                // Model Status Section
                Section("Model Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack {
                            Circle()
                                .fill(llmManager.isModelLoaded ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(llmManager.isModelLoaded ? "Loaded" : "Not Loaded")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let modelInfo = llmManager.modelInfo {
                        HStack {
                            Text("Model Size")
                            Spacer()
                            Text(modelInfo.size)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Memory Usage")
                            Spacer()
                            Text(modelInfo.memoryUsage)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Reload Model") {
                        llmManager.reloadModel()
                    }
                    .foregroundColor(.blue)
                }
                
                // Performance Section
                Section("Performance") {
                    HStack {
                        Text("Inference Speed")
                        Spacer()
                        Text(llmManager.lastInferenceTime)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Average Response Time")
                        Spacer()
                        Text(llmManager.averageResponseTime)
                            .foregroundColor(.secondary)
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("001")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/ricobiz/IOSeiros")!)
                        .foregroundColor(.blue)
                }
                
                // Actions Section
                Section("Actions") {
                    Button("Clear Chat History") {
                        llmManager.clearChatHistory()
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func resetToDefaults() {
        selectedModel = "llama-2-7b-chat"
        maxTokens = 512
        temperature = 0.7
        enableOCR = true
        enableBrowserAutomation = true
        llmManager.reloadModel()
    }
}

#Preview {
    SettingsView()
}
