
//
//  AutomationMonitorView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct AutomationMonitorView: View {
    @StateObject private var automationController = AutomationController.shared
    @StateObject private var touchGridSystem = TouchGridSystem.shared
    @StateObject private var qwen2VLManager = Qwen2VLManager.shared
    @StateObject private var openRouterManager = OpenRouterManager.shared
    @State private var selectedLogType: AutomationLogType? = nil
    @State private var showingTaskHistory = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Header
                statusHeaderView
                
                // Main Content
                TabView {
                    // Real-time Log
                    logView
                        .tabItem {
                            Image(systemName: "list.bullet.rectangle")
                            Text("Log")
                        }
                    
                    // System Status
                    systemStatusView
                        .tabItem {
                            Image(systemName: "gauge")
                            Text("Status")
                        }
                    
                    // Performance Metrics
                    metricsView
                        .tabItem {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Metrics")
                        }
                    
                    // Screenshot View
                    screenshotView
                        .tabItem {
                            Image(systemName: "camera")
                            Text("Screenshot")
                        }
                }
            }
            .navigationTitle("Automation Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: HStack {
                    Button(action: { showingTaskHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    
                    Button(action: clearLog) {
                        Image(systemName: "trash")
                    }
                }
            )
        }
        .sheet(isPresented: $showingTaskHistory) {
            TaskHistoryView()
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeaderView: some View {
        HStack {
            // Automation Status
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(automationController.isAutomationActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(automationController.isAutomationActive ? "Active" : "Idle")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                if let currentTask = automationController.currentTask {
                    Text(currentTask.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Mode Indicator
            VStack(alignment: .center, spacing: 4) {
                Text("Mode")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(automationController.automationMode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Quick Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("Tasks: \(automationController.tasksCompleted)")
                    .font(.caption)
                Text("Success: \(automationController.getAutomationStatus().formattedSuccessRate)")
                    .font(.caption)
                    .foregroundColor(automationController.tasksSuccessful > 0 ? .green : .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Log View
    
    private var logView: some View {
        VStack {
            // Log Filter
            HStack {
                Text("Filter:")
                    .font(.caption)
                
                Picker("Log Type", selection: $selectedLogType) {
                    Text("All").tag(nil as AutomationLogType?)
                    ForEach(AutomationLogType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type as AutomationLogType?)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            // Log Entries
            List {
                ForEach(filteredLogEntries) { entry in
                    LogEntryRow(entry: entry)
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private var filteredLogEntries: [AutomationLogEntry] {
        if let selectedType = selectedLogType {
            return automationController.executionLog.filter { $0.type == selectedType }
        }
        return automationController.executionLog
    }
    
    // MARK: - System Status View
    
    private var systemStatusView: some View {
        List {
            Section("Core Components") {
                ComponentStatusRow(
                    name: "Vision Manager",
                    isReady: VisionManager.shared.lastAnalysisResult != nil,
                    details: "Text & Object Detection"
                )
                
                ComponentStatusRow(
                    name: "Touch Grid System",
                    isReady: touchGridSystem.isCalibrated,
                    details: "Grid: \(Int(touchGridSystem.gridSize.width))x\(Int(touchGridSystem.gridSize.height))"
                )
                
                ComponentStatusRow(
                    name: "Qwen2-VL Manager",
                    isReady: qwen2VLManager.isModelLoaded,
                    details: qwen2VLManager.isAvailable ? "Model Available" : "Not Available"
                )
                
                ComponentStatusRow(
                    name: "OpenRouter Manager",
                    isReady: openRouterManager.isConfigured,
                    details: openRouterManager.isConfigured ? "API Configured" : "Not Configured"
                )
            }
            
            Section("Performance") {
                HStack {
                    Text("Average Execution Time")
                    Spacer()
                    Text(automationController.getAutomationStatus().formattedExecutionTime)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Touch History")
                    Spacer()
                    Text("\(touchGridSystem.touchHistory.count) events")
                        .foregroundColor(.secondary)
                }
                
                if qwen2VLManager.isModelLoaded {
                    HStack {
                        Text("Qwen2VL Inferences")
                        Spacer()
                        Text("\(qwen2VLManager.totalInferences)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Avg Inference Time")
                        Spacer()
                        Text(qwen2VLManager.getModelStatus().performanceMetrics.formattedAverageInferenceTime)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Configuration") {
                HStack {
                    Text("Automation Mode")
                    Spacer()
                    Text(automationController.automationMode.displayName)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Grid Enabled")
                    Spacer()
                    Text(touchGridSystem.isEnabled ? "Yes" : "No")
                        .foregroundColor(touchGridSystem.isEnabled ? .green : .orange)
                }
            }
        }
    }
    
    // MARK: - Metrics View
    
    private var metricsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Task Success Rate
                MetricCard(
                    title: "Task Success Rate",
                    value: automationController.getAutomationStatus().formattedSuccessRate,
                    subtitle: "\(automationController.tasksSuccessful) of \(automationController.tasksCompleted) tasks",
                    color: .green
                )
                
                // Touch Accuracy
                MetricCard(
                    title: "Touch Accuracy",
                    value: touchGridSystem.getTouchAnalytics().formattedAccuracy,
                    subtitle: "\(touchGridSystem.touchHistory.count) touch events",
                    color: .blue
                )
                
                // Processing Performance
                if qwen2VLManager.isModelLoaded {
                    MetricCard(
                        title: "AI Processing",
                        value: qwen2VLManager.getModelStatus().performanceMetrics.formattedAverageInferenceTime,
                        subtitle: "\(qwen2VLManager.totalInferences) inferences",
                        color: .purple
                    )
                }
                
                // OpenRouter Usage
                if openRouterManager.isConfigured {
                    MetricCard(
                        title: "Cloud API Usage",
                        value: "\(openRouterManager.totalTokensUsed) tokens",
                        subtitle: "Cost: \(String(format: "$%.4f", openRouterManager.totalCost))",
                        color: .orange
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Screenshot View
    
    private var screenshotView: some View {
        VStack {
            if let screenshot = automationController.lastScreenshot {
                Image(uiImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(10)
                    .padding()
                
                Text("Last captured: \(Date(), formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No screenshot available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Take a screenshot from the browser or run an automation task")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func clearLog() {
        automationController.clearLog()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Supporting Views

struct LogEntryRow: View {
    let entry: AutomationLogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type Indicator
            Circle()
                .fill(Color(entry.type.color))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(entry.timestamp, formatter: timeFormatter)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }
}

struct ComponentStatusRow: View {
    let name: String
    let isReady: Bool
    let details: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(isReady ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isReady ? "Ready" : "Not Ready")
                    .font(.caption)
                    .foregroundColor(isReady ? .green : .red)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TaskHistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var automationController = AutomationController.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Recent Tasks") {
                    // This would show task history if we tracked it
                    Text("Task history feature coming soon")
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Total Tasks")
                        Spacer()
                        Text("\(automationController.tasksCompleted)")
                    }
                    
                    HStack {
                        Text("Successful Tasks")
                        Spacer()
                        Text("\(automationController.tasksSuccessful)")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Success Rate")
                        Spacer()
                        Text(automationController.getAutomationStatus().formattedSuccessRate)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Task History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#Preview {
    AutomationMonitorView()
}
