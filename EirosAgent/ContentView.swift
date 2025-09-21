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
            ControlRoomView()
                .tabItem {
                    Image(systemName: "brain")
                    Text("Control Room")
                }
                .tag(0)
            
            BrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Browser")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
