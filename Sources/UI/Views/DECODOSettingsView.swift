
//
//  DECODOSettingsView.swift
//  EirosAgent
//
//  DECODO Configuration and Settings UI
//  Created: 2025-09-22
//

import SwiftUI

struct DECODOSettingsView: View {
    @StateObject private var decodoConfig = DECODOConfiguration.shared
    @StateObject private var proxyManager = ProxyManager.shared
    
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var showPassword = false
    @State private var showApiKey = false
    @State private var isTestingConnection = false
    @State private var showingTestResults = false
    @State private var testResults: TestResult?
    
    var body: some View {
        NavigationView {
            Form {
                credentialsSection
                connectionStatusSection
                capabilitiesSection
                testingSection
                statisticsSection
            }
            .navigationTitle("DECODO Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadCredentials()
            }
            .alert("Connection Test Results", isPresented: $showingTestResults) {
                Button("OK") { }
            } message: {
                if let results = testResults {
                    Text(results.success ? 
                         "Connection successful!\nLatency: \(results.formattedLatency)" :
                         "Connection failed: \(results.error ?? "Unknown error")")
                }
            }
        }
    }
    
    // MARK: - Credentials Section
    
    private var credentialsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Enter your DECODO credentials from your dashboard")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "key.radiowaves.forward")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    
                    Group {
                        if showApiKey {
                            TextField("API Key (Optional)", text: $apiKey)
                        } else {
                            SecureField("API Key (Optional)", text: $apiKey)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    Button(action: { showApiKey.toggle() }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("API Key enables additional features like statistics and session management")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Save Credentials") {
                        saveCredentials()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty)
                    
                    Spacer()
                    
                    Button("Clear") {
                        clearCredentials()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        } header: {
            Label("Credentials", systemImage: "key.fill")
        } footer: {
            Text("Get your credentials from the DECODO dashboard at decodo.com")
                .font(.caption)
        }
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        Section {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text("Status")
                    .font(.headline)
                
                Spacer()
                
                Text(decodoConfig.connectionStatus.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if decodoConfig.isConfigured {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Credentials configured")
                        .font(.subheadline)
                    
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Credentials required")
                        .font(.subheadline)
                    
                    Spacer()
                }
            }
            
            if let lastTest = decodoConfig.lastTestResult {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Last Test:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(lastTest.success ? "Success" : "Failed")
                            .font(.caption)
                            .foregroundColor(lastTest.success ? .green : .red)
                    }
                    
                    if lastTest.success {
                        Text("Latency: \(lastTest.formattedLatency)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let error = lastTest.error {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        } header: {
            Label("Connection Status", systemImage: "network")
        }
    }
    
    // MARK: - Capabilities Section
    
    private var capabilitiesSection: some View {
        Section {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                CapabilityCard(
                    title: "Site Unblocker",
                    description: "Proxy-based web unblocking",
                    icon: "globe",
                    isAvailable: decodoConfig.isConfigured
                )
                
                CapabilityCard(
                    title: "Screenshots",
                    description: "Headless PNG capture",
                    icon: "camera",
                    isAvailable: decodoConfig.isConfigured
                )
                
                CapabilityCard(
                    title: "JavaScript",
                    description: "Dynamic content rendering",
                    icon: "doc.text",
                    isAvailable: decodoConfig.isConfigured
                )
                
                CapabilityCard(
                    title: "Geo Targeting",
                    description: "Location-based requests",
                    icon: "location",
                    isAvailable: decodoConfig.isConfigured
                )
                
                CapabilityCard(
                    title: "Web Scraping API",
                    description: "Structured data extraction",
                    icon: "square.and.arrow.down",
                    isAvailable: decodoConfig.isConfigured
                )
                
                CapabilityCard(
                    title: "Session Management",
                    description: "Persistent connections",
                    icon: "timer",
                    isAvailable: decodoConfig.isConfigured
                )
            }
        } header: {
            Label("Available Capabilities", systemImage: "star.fill")
        }
    }
    
    // MARK: - Testing Section
    
    private var testingSection: some View {
        Section {
            VStack(spacing: 12) {
                Button(action: testSiteUnblocker) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        
                        Text("Test Site Unblocker")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!decodoConfig.isConfigured || isTestingConnection)
                
                Button(action: testWebScrapingAPI) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        
                        Text("Test Web Scraping API")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!decodoConfig.isConfigured || isTestingConnection)
            }
        } header: {
            Label("Connection Testing", systemImage: "checkmark.circle")
        } footer: {
            Text("Test your DECODO connection to ensure everything is working properly")
                .font(.caption)
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        Section {
            if proxyManager.isProxyEnabled, let proxyInfo = proxyManager.getCurrentProxyInfo() {
                VStack(spacing: 8) {
                    StatRow(label: "Current Proxy", value: proxyInfo.name)
                    StatRow(label: "Connection Type", value: proxyInfo.type.description)
                    StatRow(label: "Average Latency", value: proxyInfo.formattedLatency)
                    StatRow(label: "Data Transferred", value: proxyInfo.formattedDataTransferred)
                    StatRow(label: "Uptime", value: proxyInfo.formattedUptime)
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    
                    Text("No active proxy connection")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        } header: {
            Label("Usage Statistics", systemImage: "chart.bar")
        }
    }
    
    // MARK: - Helper Views
    
    private var statusColor: Color {
        switch decodoConfig.connectionStatus {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func loadCredentials() {
        // Credentials are automatically loaded by DECODOConfiguration
        // We don't expose them in the UI for security reasons
    }
    
    private func saveCredentials() {
        let apiKeyValue = apiKey.isEmpty ? nil : apiKey
        decodoConfig.setCredentials(username: username, password: password, apiKey: apiKeyValue)
        
        // Clear the form for security
        username = ""
        password = ""
        apiKey = ""
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func clearCredentials() {
        decodoConfig.clearCredentials()
        username = ""
        password = ""
        apiKey = ""
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func testSiteUnblocker() {
        isTestingConnection = true
        
        Task {
            let result = await decodoConfig.testSiteUnblockerConnection()
            
            await MainActor.run {
                self.testResults = result
                self.isTestingConnection = false
                self.showingTestResults = true
                
                let impactFeedback = UIImpactFeedbackGenerator(style: result.success ? .medium : .heavy)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    private func testWebScrapingAPI() {
        isTestingConnection = true
        
        Task {
            let result = await decodoConfig.testWebScrapingAPI()
            
            await MainActor.run {
                self.testResults = result
                self.isTestingConnection = false
                self.showingTestResults = true
                
                let impactFeedback = UIImpactFeedbackGenerator(style: result.success ? .medium : .heavy)
                impactFeedback.impactOccurred()
            }
        }
    }
}

// MARK: - Supporting Views

struct CapabilityCard: View {
    let title: String
    let description: String
    let icon: String
    let isAvailable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isAvailable ? .blue : .gray)
                    .font(.title2)
                
                Spacer()
                
                if isAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(isAvailable ? .primary : .secondary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .opacity(isAvailable ? 1.0 : 0.5)
        )
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

struct DECODOSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DECODOSettingsView()
    }
}
