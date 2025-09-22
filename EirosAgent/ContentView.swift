
//
//  ContentView.swift
//  EirosAgent
//
//  Updated for DECODO Proxy Integration - 2025-09-22
//

import SwiftUI

struct ContentView: View {
    @StateObject private var proxyManager = ProxyManager.shared
    @StateObject private var automationController = AutomationController.shared
    @State private var selectedTab = 0
    @State private var showingProxyStatus = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Browser Tab
            BrowserView()
                .tabItem {
                    Image(systemName: "safari")
                    Text("Browser")
                }
                .tag(0)
            
            // Automation Tab
            VStack {
                AutomationPanelView()
                Spacer()
                AutomationMonitorView()
            }
            .tabItem {
                Image(systemName: "brain")
                Text("Automation")
            }
            .tag(1)
            
            // Qwen2VL Tab
            Qwen2VLControlView()
                .tabItem {
                    Image(systemName: "eye")
                    Text("Vision AI")
                }
                .tag(2)
            
            // Proxy Control Tab
            ProxyControlView()
                .tabItem {
                    Image(systemName: proxyManager.isProxyEnabled ? "shield.fill" : "shield.slash")
                    Text("Proxy")
                }
                .badge(proxyManager.isProxyEnabled ? "ON" : nil)
                .tag(3)
        }
        .overlay(
            // Floating Proxy Status Indicator
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { showingProxyStatus.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(proxyStatusColor)
                                .frame(width: 8, height: 8)
                            
                            Text(proxyManager.isProxyEnabled ? "DECODO" : "Direct")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                    .padding(.trailing)
                }
                
                Spacer()
            }
            .padding(.top, 50)
        )
        .sheet(isPresented: $showingProxyStatus) {
            ProxyStatusSheet()
        }
        .onAppear {
            initializeApp()
        }
    }
    
    private var proxyStatusColor: Color {
        switch proxyManager.proxyStatus {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private func initializeApp() {
        // Initialize DECODO proxy configurations
        proxyManager.loadDECODOConfigurations()
        
        // Auto-enable proxy if configured
        Task {
            if UserDefaults.standard.bool(forKey: "AutoEnableProxy") {
                await proxyManager.enableDECODOPrimary()
            }
        }
        
        print("🚀 Eiros Agent initialized with DECODO Unblocker support")
    }
}

struct ProxyStatusSheet: View {
    @ObservedObject private var proxyManager = ProxyManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Header
                VStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: proxyManager.isProxyEnabled ? "shield.fill" : "shield.slash")
                                .foregroundColor(.white)
                                .font(.title2)
                        )
                    
                    Text(proxyManager.proxyStatus.displayName)
                        .font(.headline)
                    
                    if let config = proxyManager.currentProxyConfig {
                        Text(config.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Quick Stats
                if proxyManager.isProxyEnabled {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Latency:")
                            Spacer()
                            Text("\(Int(proxyManager.connectionLatency * 1000))ms")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Data Transferred:")
                            Spacer()
                            Text(ByteCountFormatter().string(fromByteCount: proxyManager.dataTransferred))
                                .fontWeight(.medium)
                        }
                        
                        if let config = proxyManager.currentProxyConfig {
                            HStack {
                                Text("Endpoint:")
                                Spacer()
                                Text("\(config.host):\(config.port)")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Quick Actions
                VStack(spacing: 12) {
                    if proxyManager.isProxyEnabled {
                        Button("Disconnect Proxy") {
                            proxyManager.disableProxy()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    } else {
                        Button("Connect to DECODO Primary") {
                            Task {
                                await proxyManager.enableDECODOPrimary()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Connect to DECODO Backup") {
                            Task {
                                await proxyManager.enableDECODOSecondary()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Proxy Status")
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
    
    private var statusColor: Color {
        switch proxyManager.proxyStatus {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

#Preview {
    ContentView()
}
