//
//  LLMModeSelectorView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct LLMModeSelectorView: View {
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @StateObject private var openRouterManager = OpenRouterManager.shared
    @State private var showingModeInfo = false
    @State private var showingModelPicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("AI Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Choose how Eiros processes your requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingModeInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            // Mode Selection
            VStack(spacing: 12) {
                ForEach(enhancedLLMManager.availableModes) { mode in
                    ModeSelectionCard(
                        mode: mode,
                        isSelected: enhancedLLMManager.currentMode == mode,
                        isAvailable: enhancedLLMManager.availableModes.contains(mode)
                    ) {
                        enhancedLLMManager.switchMode(to: mode)
                    }
                }
            }
            
            // Current Model Info
            if let modelInfo = enhancedLLMManager.modelInfo {
                ModelInfoCard(modelInfo: modelInfo)
            }
            
            // Cloud Model Selection (if in cloud mode)
            if enhancedLLMManager.currentMode == .cloud && openRouterManager.isConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cloud Model")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Change") {
                            showingModelPicker = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    CloudModelCard(model: openRouterManager.selectedModel)
                }
            }
            
            // Status Indicators
            StatusIndicatorsView()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingModeInfo) {
            ModeInfoView()
        }
        .sheet(isPresented: $showingModelPicker) {
            CloudModelPickerView()
        }
    }
}

struct ModeSelectionCard: View {
    let mode: LLMMode
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Mode Icon
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 24, height: 24)
                
                // Mode Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                } else if !isAvailable {
                    Image(systemName: "lock.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.6)
    }
}

struct ModelInfoCard: View {
    let modelInfo: ModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Model")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelInfo.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Size: \(modelInfo.size)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(modelInfo.parameters)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Memory: \(modelInfo.memoryUsage)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct CloudModelCard: View {
    let model: OpenRouterModel
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(model.provider)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.parameters)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if model.supportsVision {
                    HStack(spacing: 2) {
                        Image(systemName: "eye")
                            .font(.caption2)
                        Text("Vision")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(6)
    }
}

struct StatusIndicatorsView: View {
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @StateObject private var openRouterManager = OpenRouterManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Model Status
            StatusIndicator(
                icon: "brain",
                title: "Model",
                status: enhancedLLMManager.isModelLoaded ? "Ready" : "Loading",
                color: enhancedLLMManager.isModelLoaded ? .green : .orange
            )
            
            // Cloud Status (if applicable)
            if enhancedLLMManager.currentMode != .local {
                StatusIndicator(
                    icon: "cloud",
                    title: "Cloud",
                    status: openRouterManager.isConfigured ? "Connected" : "Not Configured",
                    color: openRouterManager.isConfigured ? .green : .red
                )
            }
            
            // Generation Status
            if enhancedLLMManager.isGenerating {
                StatusIndicator(
                    icon: "waveform",
                    title: "Status",
                    status: "Generating",
                    color: .blue,
                    isAnimated: true
                )
            }
        }
    }
}

struct StatusIndicator: View {
    let icon: String
    let title: String
    let status: String
    let color: Color
    var isAnimated: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .scaleEffect(isAnimated ? 1.2 : 1.0)
                .animation(isAnimated ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .none, value: isAnimated)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(status)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ModeInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(LLMMode.allCases) { mode in
                        ModeDetailCard(mode: mode)
                    }
                    
                    // Additional Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Best Performance")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "lightbulb", text: "Use Local mode for quick, private responses")
                            TipRow(icon: "cloud", text: "Use Cloud mode for complex analysis and vision tasks")
                            TipRow(icon: "arrow.triangle.2.circlepath", text: "Use Hybrid mode for automatic optimization")
                            TipRow(icon: "key", text: "Configure OpenRouter API key to unlock cloud features")
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("AI Modes")
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

struct ModeDetailCard: View {
    let mode: LLMMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(mode.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(mode.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Mode-specific details
            VStack(alignment: .leading, spacing: 6) {
                switch mode {
                case .local:
                    DetailPoint(text: "✓ Complete privacy - data never leaves your device")
                    DetailPoint(text: "✓ Fast response times")
                    DetailPoint(text: "✓ No internet required")
                    DetailPoint(text: "✓ No usage costs")
                    DetailPoint(text: "⚠ Limited to device capabilities")
                    
                case .cloud:
                    DetailPoint(text: "✓ Access to most powerful AI models")
                    DetailPoint(text: "✓ Advanced reasoning capabilities")
                    DetailPoint(text: "✓ Vision and image analysis")
                    DetailPoint(text: "✓ Constantly updated models")
                    DetailPoint(text: "⚠ Requires internet connection")
                    DetailPoint(text: "⚠ Usage costs apply")
                    
                case .hybrid:
                    DetailPoint(text: "✓ Best of both worlds")
                    DetailPoint(text: "✓ Automatic optimization")
                    DetailPoint(text: "✓ Cost-effective")
                    DetailPoint(text: "✓ Intelligent task routing")
                    DetailPoint(text: "⚠ Requires both local and cloud setup")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

struct DetailPoint: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CloudModelPickerView: View {
    @StateObject private var openRouterManager = OpenRouterManager.shared
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(openRouterManager.availableModels) { model in
                    CloudModelRow(
                        model: model,
                        isSelected: openRouterManager.selectedModel == model
                    ) {
                        enhancedLLMManager.selectCloudModel(model)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Select Cloud Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CloudModelRow: View {
    let model: OpenRouterModel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(model.provider) • \(model.parameters)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Text("$\(String(format: "%.6f", model.costPer1KTokens))/1K tokens")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        if model.supportsVision {
                            HStack(spacing: 2) {
                                Image(systemName: "eye")
                                Text("Vision")
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LLMModeSelectorView()
        .padding()
}
