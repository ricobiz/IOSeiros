
//
//  EnhancedControlRoomView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct EnhancedControlRoomView: View {
    @StateObject private var enhancedLLMManager = EnhancedLLMManager.shared
    @StateObject private var openRouterManager = OpenRouterManager.shared
    @StateObject private var visionManager = VisionManager.shared
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    
    @State private var messageText = ""
    @State private var showingModeSelector = false
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
                                MessageBubble(message: message)
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
            .sheet(isPresented: $showingModeSelector) {
                LLMModeSelectorView()
            }
            .sheet(isPresented: $showingVisionAnalysis) {
                VisionAnalysisView()
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { image in
                if let image = image {
                    Task {
                        await enhancedLLMManager.sendMessageWithVision("Analyze this image", image: image)
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
                    
                    HStack(spacing: 8) {
                        Image(systemName: enhancedLLMManager.currentMode.icon)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(enhancedLLMManager.currentMode.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let modelInfo = enhancedLLMManager.modelInfo {
                            Text("• \(modelInfo.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                        showingModeSelector = true
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
                            await captureAndAnalyzeScreen()
                        }
                    }
                    
                    QuickActionButton(
                        title: "Extract Text",
                        icon: "doc.text.viewfinder",
                        color: .green
                    ) {
                        Task {
                            await extractTextFromScreen()
                        }
                    }
                    
                    QuickActionButton(
                        title: "Mode: \(enhancedLLMManager.currentMode.displayName)",
                        icon: enhancedLLMManager.currentMode.icon,
                        color: .orange
                    ) {
                        showingModeSelector = true
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
                    
                    if enhancedLLMManager.currentMode == .cloud && openRouterManager.isConfigured {
                        MetricBadge(
                            title: "Tokens",
                            value: "\(openRouterManager.totalTokensUsed)",
                            icon: "number"
                        )
                        
                        MetricBadge(
                            title: "Cost",
                            value: String(format: "$%.4f", openRouterManager.totalCost),
                            icon: "dollarsign.circle"
                        )
                    }
                    
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
    
    private func captureAndAnalyzeScreen() async {
        // Simulate screen capture and analysis
        await enhancedLLMManager.sendMessage("Please analyze the current screen and provide insights about what you see.")
    }
    
    private func extractTextFromScreen() async {
        // Simulate text extraction
        await enhancedLLMManager.sendMessage("Please extract and list all text visible on the current screen.")
    }
}

// MARK: - Supporting Views

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Message content
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser ? Color.blue : Color(UIColor.systemGray5))
                    )
                
                // Message metadata
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
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

// MARK: - Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
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
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
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

#Preview {
    EnhancedControlRoomView()
}
