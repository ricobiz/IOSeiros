
//
//  EnhancedControlRoomView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct EnhancedControlRoomView: View {
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @StateObject private var visionManager = VisionManager.shared
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    
    @State private var messageText = ""
    @State private var showingModelSelector = false
    @State private var showingVisionAnalysis = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with model info and controls
                headerView
                
                Divider()
                
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(enhancedLLMManager.chatHistory) { message in
                                EnhancedMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: enhancedLLMManager.chatHistory.count) { _ in
                        if let lastMessage = enhancedLLMManager.chatHistory.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area with enhanced controls
                inputArea
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingModelSelector) {
                ModelSelectorView()
            }
            .sheet(isPresented: $showingVisionAnalysis) {
                VisionAnalysisView()
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { image in
                if let image = image {
                    Task {
                        await enhancedLLMManager.analyzeImage(image)
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Eiros Enhanced")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let modelInfo = enhancedLLMManager.modelInfo {
                        Text(modelInfo.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Vision Analysis Button
                    Button(action: { showingVisionAnalysis = true }) {
                        Image(systemName: "eye")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    // Model Status Indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(enhancedLLMManager.isModelLoaded ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(enhancedLLMManager.isModelLoaded ? "Ready" : "Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        showingModelSelector = true
                    }
                }
            }
            
            // Quick Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickActionButton(
                        title: "Screenshot",
                        icon: "camera.viewfinder",
                        color: .blue
                    ) {
                        Task {
                            await enhancedLLMManager.analyzeScreenshot()
                        }
                    }
                    
                    QuickActionButton(
                        title: "Extract Text",
                        icon: "doc.text.viewfinder",
                        color: .green
                    ) {
                        Task {
                            await enhancedLLMManager.extractTextFromScreen()
                        }
                    }
                    
                    QuickActionButton(
                        title: "Find UI",
                        icon: "rectangle.3.group",
                        color: .orange
                    ) {
                        Task {
                            await enhancedLLMManager.findUIElements(matching: "button")
                        }
                    }
                    
                    QuickActionButton(
                        title: "Add Image",
                        icon: "photo.on.rectangle",
                        color: .purple
                    ) {
                        showingImagePicker = true
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 12) {
            // Performance metrics
            if enhancedLLMManager.isModelLoaded {
                HStack {
                    MetricBadge(
                        title: "Response",
                        value: enhancedLLMManager.lastInferenceTime,
                        icon: "clock"
                    )
                    
                    MetricBadge(
                        title: "Memory",
                        value: enhancedLLMManager.memoryUsage,
                        icon: "memorychip"
                    )
                    
                    Spacer()
                    
                    if enhancedLLMManager.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Message input
            HStack(spacing: 12) {
                TextField("Ask Eiros anything...", text: $messageText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty || enhancedLLMManager.isGenerating)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let message = messageText
        messageText = ""
        
        Task {
            await enhancedLLMManager.sendMessage(message)
        }
    }
}

// MARK: - Supporting Views

struct EnhancedMessageBubble: View {
    let message: EnhancedChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Message content
                VStack(alignment: .leading, spacing: 8) {
                    if !message.attachments.isEmpty {
                        ForEach(message.attachments) { attachment in
                            AttachmentView(attachment: attachment)
                        }
                    }
                    
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(message.isUser ? .white : .primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColorForMessage(message))
                )
                
                // Message metadata
                HStack(spacing: 8) {
                    if !message.isUser {
                        MessageTypeIndicator(type: message.messageType)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func backgroundColorForMessage(_ message: EnhancedChatMessage) -> Color {
        if message.isUser {
            return .blue
        } else {
            switch message.messageType {
            case .text: return Color(UIColor.systemGray5)
            case .vision: return Color.purple.opacity(0.1)
            case .system: return Color.orange.opacity(0.1)
            case .error: return Color.red.opacity(0.1)
            }
        }
    }
}

struct AttachmentView: View {
    let attachment: MessageAttachment
    
    var body: some View {
        switch attachment.type {
        case .image:
            if let image = UIImage(data: attachment.data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
            }
        case .document:
            HStack {
                Image(systemName: "doc")
                Text("Document")
                    .font(.caption)
            }
            .padding(8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        case .audio:
            HStack {
                Image(systemName: "waveform")
                Text("Audio")
                    .font(.caption)
            }
            .padding(8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

struct MessageTypeIndicator: View {
    let type: MessageType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForType(type))
                .font(.caption2)
                .foregroundColor(colorForType(type))
            
            Text(type.rawValue.capitalized)
                .font(.caption2)
                .foregroundColor(colorForType(type))
        }
    }
    
    private func iconForType(_ type: MessageType) -> String {
        switch type {
        case .text: return "text.bubble"
        case .vision: return "eye"
        case .system: return "gear"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    private func colorForType(_ type: MessageType) -> Color {
        switch type {
        case .text: return .blue
        case .vision: return .purple
        case .system: return .orange
        case .error: return .red
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(16)
        }
    }
}

struct MetricBadge: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(title): \(value)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Model Selector

struct ModelSelectorView: View {
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("Available Models") {
                    ForEach(LLMModel.allCases, id: \.self) { model in
                        ModelRow(
                            model: model,
                            isSelected: model == enhancedLLMManager.currentModel,
                            isLoaded: enhancedLLMManager.isModelLoaded
                        ) {
                            Task {
                                await enhancedLLMManager.switchModel(to: model)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
                
                if let modelInfo = enhancedLLMManager.modelInfo {
                    Section("Current Model Info") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Capabilities")
                                .font(.headline)
                            
                            ForEach(modelInfo.capabilities, id: \.self) { capability in
                                Text("• \(capability)")
                                    .font(.body)
                            }
                            
                            Text("Supported Modalities")
                                .font(.headline)
                                .padding(.top)
                            
                            ForEach(Array(modelInfo.supportedModalities), id: \.self) { modality in
                                Text("• \(modality.rawValue.capitalized)")
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ModelRow: View {
    let model: LLMModel
    let isSelected: Bool
    let isLoaded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(model.parameters) parameters • \(model.size)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(model.capabilities.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: isLoaded ? "checkmark.circle.fill" : "clock.circle")
                        .foregroundColor(isLoaded ? .green : .orange)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    EnhancedControlRoomView()
}
