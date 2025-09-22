//
//  ContentView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var touchGridSystem = TouchGridSystem.shared
    @StateObject private var qwen2VLManager = Qwen2VLManager.shared
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Main AI Control Room
                EnhancedControlRoomView()
                    .tabItem {
                        Label("AI Control", systemImage: "brain.head.profile")
                    }
                    .tag(0)
                
                // Qwen2-VL Vision Model
                Qwen2VLControlView()
                    .tabItem {
                        Label("Vision AI", systemImage: "eye.circle.fill")
                    }
                    .tag(1)
                    .badge(qwen2VLManager.isModelLoaded ? nil : "Loading")
                
                // Vision Analysis Tools
                VisionAnalysisView()
                    .tabItem {
                        Label("Analysis", systemImage: "viewfinder.circle")
                    }
                    .tag(2)
                
                // Web Browser
                BrowserView()
                    .tabItem {
                        Label("Browser", systemImage: "safari")
                    }
                    .tag(3)
                
                // Settings & Configuration
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .accentColor(.blue)
            
            // Touch Grid Overlay (when enabled)
            if touchGridSystem.isGridVisible {
                TouchGridOverlayView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: touchGridSystem.isGridVisible)
            }
            
            // Floating Action Button for Quick Actions
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    FloatingActionButton(selectedTab: $selectedTab)
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Above tab bar
                }
            }
        }
        .onAppear {
            // Configure tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    @Binding var selectedTab: Int
    @State private var isExpanded = false
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            if isExpanded {
                // Quick action buttons
                VStack(spacing: 8) {
                    ActionButton(
                        icon: "camera.viewfinder",
                        color: .blue,
                        action: {
                            Task {
                                await screenCaptureManager.captureScreen()
                                selectedTab = 2 // Switch to Vision Analysis
                            }
                        }
                    )
                    
                    ActionButton(
                        icon: "eye.fill",
                        color: .green,
                        action: {
                            selectedTab = 1 // Switch to Qwen2-VL
                        }
                    )
                    
                    ActionButton(
                        icon: "grid",
                        color: .orange,
                        action: {
                            TouchGridSystem.shared.toggleGrid()
                        }
                    )
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Main FAB
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(Circle())
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    ContentView()
}
