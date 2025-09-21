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
            
            RoleSwitcherView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("ИИ Роли")
                }
                .tag(1)
            
            AIRoleMonitorView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Мониторинг")
                }
                .tag(2)
            
            VisionAnalysisView()
                .tabItem {
                    Image(systemName: "eye")
                    Text("Vision")
                }
                .tag(3)
            
            BrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Browser")
                }
                .tag(4)
            
            AutomationMonitorView()
                .tabItem {
                    Image(systemName: "gearshape.2.fill")
                    Text("Automation")
                }
                .tag(5)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(6)
        }
    }
}

#Preview {
    ContentView()
}
