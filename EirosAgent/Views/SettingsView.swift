//
//  SettingsView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @StateObject private var openRouterManager = OpenRouterManager.shared
    @AppStorage("selectedModel") private var selectedModel = "llama-2-7b-chat"
    @AppStorage("maxTokens") private var maxTokens = 512
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("enableOCR") private var enableOCR = true
    @AppStorage("enableBrowserAutomation") private var enableBrowserAutomation = true
    @State private var showingOpenRouterSettings = false
    @State private var showingUsageStatistics = false
    
    private let availableModels = [
        "llama-2-7b-chat",
        "llama-2-13b-chat", 
        "codellama-7b-instruct",
        "mistral-7b-instruct"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // AI Mode Selection Section
                Section("AI Processing Mode") {
                    LLMModeSelectorView()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                // OpenRouter Cloud Settings
                Section("Cloud AI Settings") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("OpenRouter API")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(openRouterManager.isConfigured ? "Configured" : "Not configured")
                                .font(.caption)
                                .foregroundColor(openRouterManager.isConfigured ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        Button("Configure") {
                            showingOpenRouterSettings = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    if openRouterManager.isConfigured {
                        HStack {
                            Text("Selected Model")
                            Spacer()
                            Text(openRouterManager.selectedModel.displayName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Total Usage")
                            Spacer()
                            Text("\(openRouterManager.requestCount) requests")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Total Cost")
                            Spacer()
                            Text(String(format: "$%.4f", openRouterManager.totalCost))
                                .foregroundColor(.green)
                        }
                        
                        Button("View Usage Statistics") {
                            showingUsageStatistics = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Local Model Configuration Section
                Section("Local Model Configuration") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model.capitalized).tag(model)
                        }
                    }
                    .onChange(of: selectedModel) { _ in
                        enhancedLLMManager.reloadModel()
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
                        Text("Current Mode")
                        Spacer()
                        HStack {
                            Image(systemName: enhancedLLMManager.currentMode.icon)
                                .foregroundColor(.blue)
                            Text(enhancedLLMManager.currentMode.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack {
                            Circle()
                                .fill(enhancedLLMManager.isModelLoaded ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(enhancedLLMManager.isModelLoaded ? "Ready" : "Not Ready")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let modelInfo = enhancedLLMManager.modelInfo {
                        HStack {
                            Text("Active Model")
                            Spacer()
                            Text(modelInfo.name)
                                .foregroundColor(.secondary)
                        }
                        
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
                        
                        HStack {
                            Text("Parameters")
                            Spacer()
                            Text(modelInfo.parameters)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Reload Model") {
                        enhancedLLMManager.reloadModel()
                    }
                    .foregroundColor(.blue)
                }
                
                // Performance Section
                Section("Performance") {
                    let stats = enhancedLLMManager.getUsageStatistics()
                    
                    HStack {
                        Text("Total Requests")
                        Spacer()
                        Text("\(stats.totalRequests)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Local Inference Time")
                        Spacer()
                        Text(stats.averageLocalResponseTime)
                            .foregroundColor(.secondary)
                    }
                    
                    if openRouterManager.isConfigured {
                        HStack {
                            Text("Cloud Response Time")
                            Spacer()
                            Text(stats.averageCloudResponseTime)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Cloud Tokens Used")
                            Spacer()
                            Text("\(stats.cloudTokensUsed)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if enhancedLLMManager.isGenerating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Generating response...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
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
                    
                    Link("OpenRouter Documentation", destination: URL(string: "https://openrouter.ai/docs")!)
                        .foregroundColor(.blue)
                }
                
                // Actions Section
                Section("Actions") {
                    Button("Clear Chat History") {
                        enhancedLLMManager.clearChatHistory()
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset Usage Statistics") {
                        enhancedLLMManager.resetUsageStatistics()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingOpenRouterSettings) {
                OpenRouterSettingsView()
            }
            .sheet(isPresented: $showingUsageStatistics) {
                UsageStatisticsView()
            }
        }
    }
    
    private func resetToDefaults() {
        selectedModel = "llama-2-7b-chat"
        maxTokens = 512
        temperature = 0.7
        enableOCR = true
        enableBrowserAutomation = true
        enhancedLLMManager.reloadModel()
    }
}

struct UsageStatisticsView: View {
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                let stats = enhancedLLMManager.getUsageStatistics()
                
                Section("Overall Statistics") {
                    DetailRow(title: "Current Mode", value: stats.currentMode.displayName)
                    DetailRow(title: "Total Requests", value: "\(stats.totalRequests)")
                    DetailRow(title: "Local Inferences", value: "\(stats.localInferences)")
                    DetailRow(title: "Cloud Requests", value: "\(stats.cloudRequests)")
                }
                
                Section("Performance") {
                    DetailRow(title: "Avg Local Response", value: stats.averageLocalResponseTime)
                    DetailRow(title: "Avg Cloud Response", value: stats.averageCloudResponseTime)
                }
                
                if stats.cloudRequests > 0 {
                    Section("Cloud Usage") {
                        DetailRow(title: "Tokens Consumed", value: "\(stats.cloudTokensUsed)")
                        DetailRow(title: "Total Cost", value: stats.formattedCloudCost)
                        DetailRow(title: "Avg Cost per Request", value: String(format: "$%.6f", stats.cloudCost / Double(max(stats.cloudRequests, 1))))
                    }
                }
                
                Section {
                    Button("Reset All Statistics") {
                        enhancedLLMManager.resetUsageStatistics()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Usage Statistics")
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

#Preview {
    SettingsView()
}
