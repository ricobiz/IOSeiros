
//
//  AutomationPanelView.swift
//  EirosAgent
//
//  Enhanced Automation Panel with DECODO Integration
//  Created: 2025-09-22
//

import SwiftUI

struct AutomationPanelView: View {
    @StateObject private var automationController = AutomationController.shared
    @StateObject private var proxyManager = ProxyManager.shared
    @StateObject private var decodoConfig = DECODOConfiguration.shared
    
    @State private var showingTaskCreator = false
    @State private var showingScreenshotOptions = false
    @State private var showingWebScrapingOptions = false
    @State private var selectedTask: AutomationTask?
    @State private var screenshotURL = ""
    @State private var scrapingURL = ""
    @State private var scrapingSelectors = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    statusSection
                    quickActionsSection
                    currentTaskSection
                    executionLogSection
                }
                .padding()
            }
            .navigationTitle("Automation")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Task") {
                        showingTaskCreator = true
                    }
                    .disabled(!automationController.isAutomationEnabled)
                }
            }
            .sheet(isPresented: $showingTaskCreator) {
                TaskCreatorView()
            }
            .sheet(isPresented: $showingScreenshotOptions) {
                ScreenshotOptionsView(url: $screenshotURL) { options in
                    createScreenshotTask(url: screenshotURL, options: options)
                }
            }
            .sheet(isPresented: $showingWebScrapingOptions) {
                WebScrapingOptionsView(url: $scrapingURL, selectors: $scrapingSelectors) { options in
                    createWebScrapingTask(url: scrapingURL, selectors: scrapingSelectors.components(separatedBy: "\n"), options: options)
                }
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            // Automation Status
            HStack {
                StatusIndicator(
                    title: "Automation",
                    status: automationController.isAutomationEnabled ? "Enabled" : "Disabled",
                    color: automationController.isAutomationEnabled ? .green : .gray,
                    icon: "gearshape.2"
                )
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { automationController.isAutomationEnabled },
                    set: { enabled in
                        if enabled {
                            automationController.enableAutomation()
                        } else {
                            automationController.disableAutomation()
                        }
                    }
                ))
                .labelsHidden()
            }
            
            // Proxy Status
            HStack {
                StatusIndicator(
                    title: "DECODO Proxy",
                    status: proxyManager.connectionStatus.description,
                    color: Color(proxyManager.connectionStatus.color),
                    icon: "network"
                )
                
                Spacer()
                
                if decodoConfig.isConfigured {
                    Button(proxyManager.isProxyEnabled ? "Disable" : "Enable") {
                        Task {
                            if proxyManager.isProxyEnabled {
                                proxyManager.disableProxy()
                            } else {
                                await proxyManager.enableDECODOSiteUnblocker()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Configure") {
                        // Navigate to DECODO settings
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // Execution Status
            if automationController.executionStatus != .idle {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Execution Status")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(automationController.executionStatus.description)
                            .font(.subheadline)
                            .foregroundColor(Color(automationController.executionStatus.color))
                    }
                    
                    if automationController.executionStatus == .running {
                        ProgressView(value: automationController.executionProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("\(Int(automationController.executionProgress * 100))% Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    title: "Screenshot",
                    description: "Capture webpage screenshot",
                    icon: "camera",
                    color: .blue,
                    isEnabled: automationController.isAutomationEnabled && decodoConfig.isConfigured
                ) {
                    showingScreenshotOptions = true
                }
                
                QuickActionCard(
                    title: "Web Scraping",
                    description: "Extract data from webpage",
                    icon: "doc.text.magnifyingglass",
                    color: .green,
                    isEnabled: automationController.isAutomationEnabled && decodoConfig.isConfigured
                ) {
                    showingWebScrapingOptions = true
                }
                
                QuickActionCard(
                    title: "Form Automation",
                    description: "Fill and submit forms",
                    icon: "doc.text",
                    color: .orange,
                    isEnabled: automationController.isAutomationEnabled && decodoConfig.isConfigured
                ) {
                    // TODO: Implement form automation
                }
                
                QuickActionCard(
                    title: "Monitor Page",
                    description: "Watch for changes",
                    icon: "eye",
                    color: .purple,
                    isEnabled: automationController.isAutomationEnabled && decodoConfig.isConfigured
                ) {
                    // TODO: Implement page monitoring
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Current Task Section
    
    private var currentTaskSection: some View {
        Group {
            if let task = automationController.currentTask {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Task")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Stop") {
                            automationController.stopCurrentTask()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .controlSize(.small)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(task.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("\(task.actions.count) actions", systemImage: "list.bullet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if task.options.useProxy {
                                Label("Proxy enabled", systemImage: "network")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            if task.options.enableJavaScript {
                                Label("JavaScript enabled", systemImage: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
            }
        }
    }
    
    // MARK: - Execution Log Section
    
    private var executionLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Execution Log")
                    .font(.headline)
                
                Spacer()
                
                if !automationController.executionLog.isEmpty {
                    Button("Clear") {
                        // Clear log functionality would need to be added to AutomationController
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if automationController.executionLog.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    
                    Text("No log entries")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(automationController.executionLog.suffix(20).reversed(), id: \.id) { entry in
                            LogEntryView(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Actions
    
    private func createScreenshotTask(url: String, options: ScreenshotTaskOptions) {
        let task = automationController.createScreenshotTask(url: url, options: options)
        
        Task {
            let result = await automationController.executeTask(task)
            
            if result.success && !result.screenshots.isEmpty {
                // Handle successful screenshot
                // Could show the image or save it
            }
        }
    }
    
    private func createWebScrapingTask(url: String, selectors: [String], options: WebScrapingTaskOptions) {
        let task = automationController.createWebScrapingTask(url: url, selectors: selectors, options: options)
        
        Task {
            let result = await automationController.executeTask(task)
            
            if result.success {
                // Handle successful scraping
                // Could display the extracted data
            }
        }
    }
}

// MARK: - Supporting Views

struct StatusIndicator: View {
    let title: String
    let status: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(isEnabled ? color : .gray)
                        .font(.title2)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .opacity(isEnabled ? 1.0 : 0.5)
            )
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

struct LogEntryView: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.type.icon)
                .foregroundColor(Color(entry.type.color))
                .font(.caption)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sheet Views

struct TaskCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Task Creator")
                .navigationTitle("New Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct ScreenshotOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    let onComplete: (ScreenshotTaskOptions) -> Void
    
    @State private var geoLocation = ""
    @State private var deviceType: DeviceType = .desktop
    @State private var sessionId = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("URL") {
                    TextField("Enter URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Options") {
                    TextField("Geo Location (optional)", text: $geoLocation)
                        .placeholder(when: geoLocation.isEmpty) {
                            Text("e.g., United States, Germany")
                                .foregroundColor(.secondary)
                        }
                    
                    Picker("Device Type", selection: $deviceType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }
                    
                    TextField("Session ID (optional)", text: $sessionId)
                        .placeholder(when: sessionId.isEmpty) {
                            Text("Leave empty for new session")
                                .foregroundColor(.secondary)
                        }
                }
            }
            .navigationTitle("Screenshot Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let options = ScreenshotTaskOptions(
                            geoLocation: geoLocation.isEmpty ? nil : geoLocation,
                            deviceType: deviceType,
                            sessionId: sessionId.isEmpty ? nil : sessionId
                        )
                        onComplete(options)
                        dismiss()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}

struct WebScrapingOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    @Binding var selectors: String
    let onComplete: (WebScrapingTaskOptions) -> Void
    
    @State private var geoLocation = ""
    @State private var deviceType: DeviceType = .desktop
    @State private var extractAttribute = "text"
    @State private var extractMultiple = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("URL") {
                    TextField("Enter URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("CSS Selectors") {
                    TextField("CSS Selectors (one per line)", text: $selectors, axis: .vertical)
                        .lineLimit(3...6)
                        .placeholder(when: selectors.isEmpty) {
                            Text("e.g., .title\n.price\n.description")
                                .foregroundColor(.secondary)
                        }
                }
                
                Section("Options") {
                    TextField("Geo Location (optional)", text: $geoLocation)
                    
                    Picker("Device Type", selection: $deviceType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }
                    
                    TextField("Extract Attribute", text: $extractAttribute)
                    
                    Toggle("Extract Multiple", isOn: $extractMultiple)
                }
            }
            .navigationTitle("Web Scraping Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let options = WebScrapingTaskOptions(
                            geoLocation: geoLocation.isEmpty ? nil : geoLocation,
                            deviceType: deviceType,
                            extractAttribute: extractAttribute.isEmpty ? nil : extractAttribute,
                            extractMultiple: extractMultiple
                        )
                        onComplete(options)
                        dismiss()
                    }
                    .disabled(url.isEmpty || selectors.isEmpty)
                }
            }
        }
    }
}

// MARK: - Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview

struct AutomationPanelView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationPanelView()
    }
}
