//
//  ContentView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            EnhancedControlRoomView()
                .tabItem {
                    Image(systemName: "brain")
                    Text("Enhanced AI")
                }
                .tag(0)
            
            VisionAnalysisView()
                .tabItem {
                    Image(systemName: "eye")
                    Text("Vision")
                }
                .tag(1)
            
            BrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Browser")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
