//
//  OpenRouterSettingsView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct OpenRouterSettingsView: View {
    @StateObject private var openRouterManager = OpenRouterManager.shared
    @State private var apiKeyInput = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingUsageDetails = false
    @State private var showingModelInfo = false
    
    var body: some View {
        NavigationView {
            Form {
                // Configuration Section
                Section(header: Text("API Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: openRouterManager.isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(openRouterManager.isConfigured ? .green : .red)
                            Text("OpenRouter API Status")
                            Spacer()
                            Text(openRouterManager.isConfigured ? "Configured" : "Not Configured")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !openRouterManager.isConfigured {
                            VStack(alignment: .leading, spacing: 4) {
                                SecureField("Enter OpenRouter API Key", text: $apiKeyInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button("Configure API Key") {
                                    configureAPIKey()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                Text("Get your API key from openrouter.ai")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button("Remove API Key") {
                                showingAPIKeyAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                // Model Selection Section
                if openRouterManager.isConfigured {
                    Section(header: Text("Model Selection")) {
                        Picker("Selected Model", selection: $openRouterManager.selectedModel) {
                            ForEach(openRouterManager.availableModels) { model in
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                    Text("\(model.provider) • \(model.parameters)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(NavigationLinkPickerStyle())
                        
                        Button("Model Information") {
                            showingModelInfo = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Usage Statistics Section
                    Section(header: Text("Usage Statistics")) {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Requests")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(openRouterManager.requestCount)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Tokens Used")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(openRouterManager.totalTokensUsed)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                            }
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Cost")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "$%.4f", openRouterManager.totalCost))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Avg Response Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2fs", openRouterManager.averageResponseTime))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                            }
                            
                            if let lastRequestTime = openRouterManager.lastRequestTime {
                                HStack {
                                    Text("Last Request")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(lastRequestTime, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button("View Detailed Usage") {
                            showingUsageDetails = true
                        }
                        .foregroundColor(.blue)
                        
                        Button("Reset Statistics") {
                            openRouterManager.resetUsageMetrics()
                        }
                        .foregroundColor(.orange)
                    }
                    
                    // Performance Section
                    Section(header: Text("Performance")) {
                        HStack {
                            Text("Last Response Time")
                            Spacer()
                            Text(String(format: "%.2fs", openRouterManager.lastResponseTime))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Average Response Time")
                            Spacer()
                            Text(String(format: "%.2fs", openRouterManager.averageResponseTime))
                                .foregroundColor(.secondary)
                        }
                        
                        if openRouterManager.isGenerating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating response...")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                
                // Information Section
                Section(header: Text("Information")) {
                    Link("OpenRouter Documentation", destination: URL(string: "https://openrouter.ai/docs")!)
                        .foregroundColor(.blue)
                    
                    Link("API Pricing", destination: URL(string: "https://openrouter.ai/models")!)
                        .foregroundColor(.blue)
                    
                    Link("Get API Key", destination: URL(string: "https://openrouter.ai/keys")!)
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("OpenRouter Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Remove API Key", isPresented: $showingAPIKeyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                openRouterManager.clearConfiguration()
            }
        } message: {
            Text("Are you sure you want to remove the OpenRouter API key? This will disable cloud model access.")
        }
        .sheet(isPresented: $showingUsageDetails) {
            UsageDetailsView()
        }
        .sheet(isPresented: $showingModelInfo) {
            ModelInfoView(model: openRouterManager.selectedModel)
        }
    }
    
    private func configureAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        
        openRouterManager.configure(with: trimmedKey)
        apiKeyInput = ""
        
        // Provide feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

struct UsageDetailsView: View {
    @StateObject private var openRouterManager = OpenRouterManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Session")) {
                    DetailRow(title: "Requests Made", value: "\(openRouterManager.requestCount)")
                    DetailRow(title: "Tokens Consumed", value: "\(openRouterManager.totalTokensUsed)")
                    DetailRow(title: "Estimated Cost", value: String(format: "$%.6f", openRouterManager.totalCost))
                }
                
                Section(header: Text("Performance Metrics")) {
                    DetailRow(title: "Last Response Time", value: String(format: "%.2f seconds", openRouterManager.lastResponseTime))
                    DetailRow(title: "Average Response Time", value: String(format: "%.2f seconds", openRouterManager.averageResponseTime))
                    
                    if let lastRequestTime = openRouterManager.lastRequestTime {
                        DetailRow(title: "Last Request", value: DateFormatter.localizedString(from: lastRequestTime, dateStyle: .short, timeStyle: .medium))
                    }
                }
                
                Section(header: Text("Model Information")) {
                    DetailRow(title: "Current Model", value: openRouterManager.selectedModel.displayName)
                    DetailRow(title: "Provider", value: openRouterManager.selectedModel.provider)
                    DetailRow(title: "Parameters", value: openRouterManager.selectedModel.parameters)
                    DetailRow(title: "Cost per 1K tokens", value: String(format: "$%.6f", openRouterManager.selectedModel.costPer1KTokens))
                    DetailRow(title: "Max Tokens", value: "\(openRouterManager.selectedModel.maxTokens)")
                    DetailRow(title: "Vision Support", value: openRouterManager.selectedModel.supportsVision ? "Yes" : "No")
                }
                
                Section {
                    Button("Reset All Statistics") {
                        openRouterManager.resetUsageMetrics()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Usage Details")
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

struct ModelInfoView: View {
    let model: OpenRouterModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Model Details")) {
                    DetailRow(title: "Name", value: model.displayName)
                    DetailRow(title: "Provider", value: model.provider)
                    DetailRow(title: "Model ID", value: model.rawValue)
                    DetailRow(title: "Parameters", value: model.parameters)
                }
                
                Section(header: Text("Capabilities")) {
                    DetailRow(title: "Max Tokens", value: "\(model.maxTokens)")
                    DetailRow(title: "Vision Support", value: model.supportsVision ? "Yes" : "No")
                }
                
                Section(header: Text("Pricing")) {
                    DetailRow(title: "Cost per 1K tokens", value: String(format: "$%.6f", model.costPer1KTokens))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated costs:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("1K tokens:")
                            Spacer()
                            Text(String(format: "$%.6f", model.costPer1KTokens))
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("10K tokens:")
                            Spacer()
                            Text(String(format: "$%.4f", model.costPer1KTokens * 10))
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("100K tokens:")
                            Spacer()
                            Text(String(format: "$%.2f", model.costPer1KTokens * 100))
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                
                if model.supportsVision {
                    Section(header: Text("Vision Features")) {
                        Text("This model supports image analysis and can process screenshots, photos, and other visual content alongside text prompts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Best Use Cases")) {
                    VStack(alignment: .leading, spacing: 4) {
                        switch model {
                        case .gpt4o, .gpt4Vision:
                            Text("• Complex reasoning and analysis")
                            Text("• Code generation and debugging")
                            Text("• Image analysis and description")
                            Text("• Creative writing and content creation")
                        case .gpt4oMini:
                            Text("• Quick responses and simple tasks")
                            Text("• Cost-effective general purpose use")
                            Text("• High-volume applications")
                        case .claude3Opus:
                            Text("• Long-form content creation")
                            Text("• Complex analysis and research")
                            Text("• Creative and literary tasks")
                        case .claude3Sonnet:
                            Text("• Balanced performance and cost")
                            Text("• General purpose conversations")
                            Text("• Code assistance")
                        case .claude3Haiku:
                            Text("• Fast responses")
                            Text("• Simple tasks and queries")
                            Text("• Cost-effective option")
                        case .geminiPro, .geminiProVision:
                            Text("• Multimodal understanding")
                            Text("• Factual information retrieval")
                            Text("• Reasoning tasks")
                        case .llama3_70b, .llama3_8b:
                            Text("• Open source alternative")
                            Text("• General conversation")
                            Text("• Privacy-focused applications")
                        case .mixtral8x7b:
                            Text("• Multilingual support")
                            Text("• Code generation")
                            Text("• Efficient performance")
                        case .qwen2_72b:
                            Text("• Multilingual capabilities")
                            Text("• Mathematical reasoning")
                            Text("• Technical discussions")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Model Information")
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

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    OpenRouterSettingsView()
}
