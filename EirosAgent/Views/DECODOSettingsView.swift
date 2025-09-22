//
//  DECODOSettingsView.swift
//  EirosAgent
//
//  Created for DECODO Real API Integration - 2025-09-22
//

import SwiftUI

struct DECODOSettingsView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResult: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("DECODO Site Unblocker API Credentials")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Real decodo.com API Configuration")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Enter your DECODO Site Unblocker credentials from the dashboard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Link("Get credentials at decodo.com dashboard", 
                             destination: URL(string: "https://dashboard.decodo.com")!)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    HStack {
                        Image(systemName: "lock.circle")
                            .foregroundColor(.blue)
                        
                        if showPassword {
                            TextField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        Button(action: {
                            showPassword.toggle()
                        }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("API Configuration")) {
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
                            Text("Protocol:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("HTTP/HTTPS Proxy")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Features:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("JS Rendering, CAPTCHA Bypass, Geo-targeting")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section(header: Text("Connection Test")) {
                    VStack(spacing: 12) {
                        Button(action: testConnection) {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text(isTestingConnection ? "Testing..." : "Test Connection")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(username.isEmpty || password.isEmpty || isTestingConnection)
                        
                        if !testResult.isEmpty {
                            Text(testResult)
                                .font(.caption)
                                .foregroundColor(testResult.contains("✅") ? .green : .red)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button(action: saveCredentials) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Save Credentials")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                    
                    Button(action: clearCredentials) {
                        HStack {
                            Image(systemName: "trash.circle")
                            Text("Clear Credentials")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("DECODO Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadSavedCredentials)
            .alert("Settings", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadSavedCredentials() {
        DECODOConfiguration.loadCredentials()
        username = DECODOConfiguration.username ?? ""
        password = DECODOConfiguration.password ?? ""
    }
    
    private func saveCredentials() {
        DECODOConfiguration.setCredentials(username: username, password: password)
        alertMessage = "✅ DECODO credentials saved successfully!"
        showAlert = true
        
        // Reload proxy configurations
        Task {
            await MainActor.run {
                ProxyManager.shared.loadDECODOConfigurations()
            }
        }
    }
    
    private func clearCredentials() {
        DECODOConfiguration.clearCredentials()
        username = ""
        password = ""
        testResult = ""
        alertMessage = "🗑️ DECODO credentials cleared"
        showAlert = true
    }
    
    private func testConnection() {
        guard !username.isEmpty && !password.isEmpty else { return }
        
        isTestingConnection = true
        testResult = ""
        
        Task {
            // Temporarily set credentials for testing
            DECODOConfiguration.setCredentials(username: username, password: password)
            
            if let testConfig = DECODOConfiguration.getDefaultProxyConfiguration() {
                let result = await DECODOConfiguration.testProxyConnection(testConfig)
                
                await MainActor.run {
                    isTestingConnection = false
                    if result.success {
                        testResult = "✅ Connection successful! Latency: \(result.formattedLatency)"
                    } else {
                        testResult = "❌ Connection failed: \(result.error ?? "Unknown error")"
                    }
                }
            } else {
                await MainActor.run {
                    isTestingConnection = false
                    testResult = "❌ Failed to create test configuration"
                }
            }
        }
    }
}

struct DECODOSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DECODOSettingsView()
    }
}
