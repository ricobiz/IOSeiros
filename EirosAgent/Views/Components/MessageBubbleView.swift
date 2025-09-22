//
//  MessageBubbleView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//  Purpose: Reusable message bubble component with modern iOS design patterns
//

import SwiftUI

/// Modern, reusable message bubble component that replaces the deprecated UIScreen.main usage
/// Uses GeometryReader for proper responsive design
struct MessageBubbleView: View {
    let message: ChatMessage
    let maxWidthRatio: CGFloat
    
    init(message: ChatMessage, maxWidthRatio: CGFloat = 0.75) {
        self.message = message
        self.maxWidthRatio = maxWidthRatio
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
                userMessageBubble
            } else {
                assistantMessageBubble
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    // MARK: - User Message Bubble
    private var userMessageBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(MessageBubbleShape(isUser: true))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    // MARK: - Assistant Message Bubble
    private var assistantMessageBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text("Eiros")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            Text(message.content)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemGray6))
                )
                .clipShape(MessageBubbleShape(isUser: false))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Helper Methods
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Custom Message Bubble Shape
struct MessageBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isUser ? 
                [.topLeft, .topRight, .bottomLeft] : 
                [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Responsive Container
/// Container that provides responsive width constraints without using deprecated UIScreen.main
struct ResponsiveMessageContainer<Content: View>: View {
    let maxWidthRatio: CGFloat
    let content: Content
    
    init(maxWidthRatio: CGFloat = 0.75, @ViewBuilder content: () -> Content) {
        self.maxWidthRatio = maxWidthRatio
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            content
                .frame(maxWidth: geometry.size.width * maxWidthRatio)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: ChatMessage(
                id: UUID(),
                content: "Hello! How can I help you today?",
                isUser: false,
                timestamp: Date()
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                id: UUID(),
                content: "I need help with my iOS app development project.",
                isUser: true,
                timestamp: Date()
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                id: UUID(),
                content: "I'd be happy to help you with iOS development! What specific aspect are you working on? Are you dealing with SwiftUI, UIKit, or perhaps some specific functionality like networking, data persistence, or UI design?",
                isUser: false,
                timestamp: Date()
            )
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
