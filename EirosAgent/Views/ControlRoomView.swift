//
//  ControlRoomView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct ControlRoomView: View {
    @StateObject private var llmManager = LLMManager.shared
    @State private var userInput = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Eiros Agent")
                            .font(.largeTitle)
                            .bold()
                        Text("Local AI Assistant")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Model status indicator
                    HStack {
                        Circle()
                            .fill(llmManager.isModelLoaded ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(llmManager.isModelLoaded ? "Ready" : "Loading...")
                            .font(.caption)
                    }
                }
                .padding()
                
                Divider()
                
                // Chat Interface
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(llmManager.chatHistory, id: \.id) { message in
                            ChatMessageView(message: message)
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Input Area
                VStack {
                    Divider()
                    HStack {
                        TextField("Ask Eiros anything...", text: $userInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isLoading || !llmManager.isModelLoaded)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(userInput.isEmpty || isLoading ? .gray : .blue)
                        }
                        .disabled(userInput.isEmpty || isLoading || !llmManager.isModelLoaded)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                llmManager.loadModel()
            }
        }
    }
    
    private func sendMessage() {
        guard !userInput.isEmpty else { return }
        
        let message = userInput
        userInput = ""
        isLoading = true
        
        Task {
            await llmManager.sendMessage(message)
            isLoading = false
        }
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                }
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.purple)
                        Text("Eiros")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.purple)
                    }
                    Text(message.content)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                }
                Spacer()
            }
        }
    }
}

#Preview {
    ControlRoomView()
}
