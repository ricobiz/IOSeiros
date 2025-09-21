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
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                EnhancedControlRoomView()
                    .tabItem {
                        Image(systemName: "brain")
                        Text("Enhanced AI")
                    }
                    .tag(0)
                
                Qwen2VLControlView()
                    .tabItem {
                        Image(systemName: "eye.circle")
                        Text("Qwen2-VL")
                    }
                    .tag(1)
                
                VisionAnalysisView()
                    .tabItem {
                        Image(systemName: "eye")
                        Text("Vision")
                    }
                    .tag(2)
                
                BrowserView()
                    .tabItem {
                        Image(systemName: "globe")
                        Text("Browser")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(4)
            }
            
            // Touch Grid Overlay
            TouchGridOverlayView()
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
