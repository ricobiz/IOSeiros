
//
//  ProxyControlView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-22.
//

import SwiftUI

struct ProxyControlView: View {
    @StateObject private var proxyManager = ProxyManager.shared
    @State private var showingProxySettings = false
    @State private var showingAddProxy = false
    @State private var selectedProxy: ProxyConfiguration?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Card
                ProxyStatusCard()
                
                // Quick Controls
                ProxyQuickControls()
                
                // Available Proxies
                ProxyListSection()
                
                // Statistics
                ProxyStatisticsSection()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Proxy Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingProxySettings = true
                    }
                }
            }
            .sheet(isPresented: $showingProxySettings) {
                ProxySettingsView()
            }
            .sheet(isPresented: $showingAddProxy) {
                AddProxyView()
            }
        }
    }
}

struct ProxyStatusCard: View {
    @ObservedObject private var proxyManager = ProxyManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(proxyManager.proxyStatus.displayName)
                    .font(.headline)
                
                Spacer()
                
                if proxyManager.isProxyEnabled {
                    Button("Disconnect") {
                        proxyManager.disableProxy()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if let config = proxyManager.currentProxyConfig {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(config.host):\(config.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if proxyManager.connectionLatency > 0 {
                        Text("Latency: \(Int(proxyManager.connectionLatency * 1000))ms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let error = proxyManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

struct ProxyQuickControls: View {
    @ObservedObject private var proxyManager = ProxyManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                Button(action: connectToPrimaryDECODO) {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text("DECODO Primary")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .disabled(proxyManager.isProxyEnabled)
                
                Button(action: connectToBackupDECODO) {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("DECODO Backup")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .disabled(proxyManager.isProxyEnabled)
            }
        }
    }
    
    private func connectToPrimaryDECODO() {
        if let primaryProxy = proxyManager.availableProxies.first(where: { $0.id == "decodo-primary" }) {
            Task {
                await proxyManager.enableProxy(with: primaryProxy)
            }
        }
    }
    
    private func connectToBackupDECODO() {
        if let backupProxy = proxyManager.availableProxies.first(where: { $0.id == "decodo-secondary" }) {
            Task {
                await proxyManager.enableProxy(with: backupProxy)
            }
        }
    }
}

struct ProxyListSection: View {
    @ObservedObject private var proxyManager = ProxyManager.shared
    @State private var showingAddProxy = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Available Proxies")
                    .font(.headline)
                
                Spacer()
                
                Button("Add") {
                    showingAddProxy = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(proxyManager.availableProxies) { proxy in
                    ProxyRowView(proxy: proxy)
                }
            }
        }
        .sheet(isPresented: $showingAddProxy) {
            AddProxyView()
        }
    }
}

struct ProxyRowView: View {
    let proxy: ProxyConfiguration
    @ObservedObject private var proxyManager = ProxyManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(proxy.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(proxy.type.displayName) • \(proxy.host):\(proxy.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Capabilities
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(proxy.capabilities, id: \.self) { capability in
                            Text(capability.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            if proxyManager.currentProxyConfig?.id == proxy.id && proxyManager.isProxyEnabled {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            } else {
                Button("Connect") {
                    Task {
                        await proxyManager.enableProxy(with: proxy)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(proxyManager.isProxyEnabled)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ProxyStatisticsSection: View {
    @ObservedObject private var proxyManager = ProxyManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let stats = proxyManager.getProxyStatistics()
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                StatCard(
                    title: "Latency",
                    value: stats.formattedLatency,
                    icon: "speedometer"
                )
                
                StatCard(
                    title: "Data Transferred",
                    value: stats.formattedDataTransferred,
                    icon: "arrow.up.arrow.down"
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ProxySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var proxyManager = ProxyManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("General") {
                    Toggle("Auto-connect on startup", isOn: .constant(false))
                    Toggle("Auto-fallback on failure", isOn: .constant(true))
                }
                
                Section("DECODO Real API Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Endpoint:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("unblock.decodo.com:60000")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Status:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(DECODOConfiguration.hasValidCredentials() ? "✅ Configured" : "❌ Not Configured")
                                .font(.caption)
                                .foregroundColor(DECODOConfiguration.hasValidCredentials() ? .green : .red)
                        }
                        
                        NavigationLink(destination: DECODOSettingsView()) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Configure DECODO Credentials")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Section("Advanced") {
                    Stepper("Connection Timeout: 30s", value: .constant(30), in: 10...60)
                    Stepper("Retry Attempts: 3", value: .constant(3), in: 1...5)
                }
            }
            .navigationTitle("Proxy Settings")
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
}

struct AddProxyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var proxyManager = ProxyManager.shared
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = "8080"
    @State private var username = ""
    @State private var password = ""
    @State private var proxyType: ProxyType = .http
    @State private var selectedCapabilities: Set<ProxyCapability> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Proxy Name", text: $name)
                    TextField("Host", text: $host)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    
                    Picker("Type", selection: $proxyType) {
                        ForEach(ProxyType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section("Authentication (Optional)") {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
                
                Section("Capabilities") {
                    ForEach(ProxyCapability.allCases, id: \.self) { capability in
                        Toggle(capability.displayName, isOn: Binding(
                            get: { selectedCapabilities.contains(capability) },
                            set: { isSelected in
                                if isSelected {
                                    selectedCapabilities.insert(capability)
                                } else {
                                    selectedCapabilities.remove(capability)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Add Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProxy()
                    }
                    .disabled(name.isEmpty || host.isEmpty || port.isEmpty)
                }
            }
        }
    }
    
    private func saveProxy() {
        guard let portNumber = Int(port) else { return }
        
        let config = ProxyConfiguration(
            id: UUID().uuidString,
            name: name,
            type: proxyType,
            host: host,
            port: portNumber,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            isDefault: false,
            capabilities: Array(selectedCapabilities)
        )
        
        proxyManager.saveCustomProxyConfiguration(config)
        dismiss()
    }
}

#Preview {
    ProxyControlView()
}
