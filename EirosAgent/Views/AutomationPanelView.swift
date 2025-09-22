
//
//  AutomationPanelView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct AutomationPanelView: View {
    @StateObject private var automationController = AutomationController.shared
    @StateObject private var touchGridSystem = TouchGridSystem.shared
    @StateObject private var qwen2VLManager = Qwen2VLManager.shared
    @StateObject private var proxyManager = ProxyManager.shared
    @State private var selectedMode: AutomationMode = .hybrid
    @State private var showingTaskCreator = false
    @State private var showingProxyControl = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Automation Control")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status Indicator
                Circle()
                    .fill(automationController.isAutomationActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(automationController.isAutomationActive ? "Active" : "Idle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mode Selection
            HStack {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Automation Mode", selection: $selectedMode) {
                    ForEach(AutomationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedMode) { mode in
                    automationController.setAutomationMode(mode)
                }
            }
            
            // Proxy Status Section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Proxy Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(proxyStatusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(proxyManager.isProxyEnabled ? "DECODO Active" : "Direct")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if proxyManager.connectionLatency > 0 {
                            Text("(\(Int(proxyManager.connectionLatency * 1000))ms)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { showingProxyControl = true }) {
                    Image(systemName: "gear")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
            
            // Quick Actions
            HStack(spacing: 8) {
                // Screenshot Button
                Button(action: takeScreenshot) {
                    VStack(spacing: 4) {
                        Image(systemName: "camera")
                            .font(.title3)
                        Text("Screenshot")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(automationController.isAutomationActive)
                
                // Quick Tap Button
                Button(action: enableQuickTap) {
                    VStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.title3)
                        Text("Quick Tap")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(automationController.isAutomationActive)
                
                // Proxy Toggle Button
                Button(action: toggleProxy) {
                    VStack(spacing: 4) {
                        Image(systemName: proxyManager.isProxyEnabled ? "shield.fill" : "shield.slash")
                            .font(.title3)
                            .foregroundColor(proxyManager.isProxyEnabled ? .green : .gray)
                        Text("Proxy")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(automationController.isAutomationActive)
                
                // Create Task Button
                Button(action: { showingTaskCreator = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                        Text("New Task")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(automationController.isAutomationActive)
                
                Spacer()
                
                // Stop Button
                if automationController.isAutomationActive {
                    Button(action: stopAutomation) {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            Text("Stop")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Status Information
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tasks: \(automationController.tasksCompleted)")
                        .font(.caption2)
                    Text("Success: \(automationController.getAutomationStatus().formattedSuccessRate)")
                        .font(.caption2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Grid: \(touchGridSystem.isCalibrated ? "Ready" : "Not Ready")")
                        .font(.caption2)
                        .foregroundColor(touchGridSystem.isCalibrated ? .green : .orange)
                    Text("Qwen2VL: \(qwen2VLManager.isModelLoaded ? "Loaded" : "Not Loaded")")
                        .font(.caption2)
                        .foregroundColor(qwen2VLManager.isModelLoaded ? .green : .gray)
                }
            }
            .foregroundColor(.secondary)
            
            // Current Task Info
            if let currentTask = automationController.currentTask {
                HStack {
                    Text("Running: \(currentTask.name)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    if automationController.isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .sheet(isPresented: $showingTaskCreator) {
            TaskCreatorView()
        }
        .sheet(isPresented: $showingProxyControl) {
            ProxyControlView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var proxyStatusColor: Color {
        switch proxyManager.proxyStatus {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    // MARK: - Action Methods
    
    private func takeScreenshot() {
        let task = AutomationTask(
            name: "Screenshot",
            description: "Take a screenshot for analysis",
            steps: [
                AutomationStep(
                    description: "Capture screenshot",
                    action: .screenshot
                )
            ],
            priority: .low,
            estimatedDuration: 1.0
        )
        
        Task {
            await automationController.executeTask(task)
        }
    }
    
    private func enableQuickTap() {
        // This would enable a mode where the user can tap anywhere on the screen
        // and the system will execute the tap through the automation system
        touchGridSystem.isEnabled = true
    }
    
    private func stopAutomation() {
        automationController.stopAutomation()
    }
    
    private func toggleProxy() {
        Task {
            if proxyManager.isProxyEnabled {
                await automationController.disableProxyForAutomation()
            } else {
                await automationController.enableProxyForAutomation()
            }
        }
    }
}

struct TaskCreatorView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var automationController = AutomationController.shared
    
    @State private var taskName = ""
    @State private var taskDescription = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var steps: [AutomationStep] = []
    @State private var showingStepCreator = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $taskName)
                    TextField("Description", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue.capitalized)
                                .tag(priority)
                        }
                    }
                }
                
                Section("Steps") {
                    ForEach(steps.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Step \(index + 1): \(steps[index].description)")
                                .font(.subheadline)
                            Text(stepActionDescription(steps[index].action))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteSteps)
                    
                    Button("Add Step") {
                        showingStepCreator = true
                    }
                }
            }
            .navigationTitle("Create Task")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    createTask()
                }
                .disabled(taskName.isEmpty || steps.isEmpty)
            )
        }
        .sheet(isPresented: $showingStepCreator) {
            StepCreatorView { step in
                steps.append(step)
            }
        }
    }
    
    private func stepActionDescription(_ action: AutomationStepAction) -> String {
        switch action {
        case .tap(let selector):
            return "Tap element: \(selector)"
        case .typeText(let text, let selector):
            return "Type '\(text)' in \(selector)"
        case .scroll(let direction):
            return "Scroll \(direction.rawValue)"
        case .wait(let duration):
            return "Wait \(duration) seconds"
        case .screenshot:
            return "Take screenshot"
        case .custom(let action):
            return "Custom: \(action)"
        }
    }
    
    private func deleteSteps(offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }
    
    private func createTask() {
        let task = AutomationTask(
            name: taskName,
            description: taskDescription,
            steps: steps,
            priority: selectedPriority,
            estimatedDuration: Double(steps.count) * 2.0
        )
        
        Task {
            await automationController.executeTask(task)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct StepCreatorView: View {
    @Environment(\.presentationMode) var presentationMode
    let onStepCreated: (AutomationStep) -> Void
    
    @State private var stepDescription = ""
    @State private var selectedActionType: StepActionType = .tap
    @State private var selector = ""
    @State private var text = ""
    @State private var scrollDirection: ScrollDirection = .down
    @State private var waitDuration: Double = 1.0
    @State private var customAction = ""
    @State private var delayAfter: Double = 1.0
    
    enum StepActionType: String, CaseIterable {
        case tap = "Tap"
        case typeText = "Type Text"
        case scroll = "Scroll"
        case wait = "Wait"
        case screenshot = "Screenshot"
        case custom = "Custom"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Step Details") {
                    TextField("Step Description", text: $stepDescription)
                    
                    Picker("Action Type", selection: $selectedActionType) {
                        ForEach(StepActionType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                }
                
                Section("Action Parameters") {
                    switch selectedActionType {
                    case .tap:
                        TextField("Element Selector", text: $selector)
                            .textInputAutocapitalization(.never)
                    case .typeText:
                        TextField("Element Selector", text: $selector)
                            .textInputAutocapitalization(.never)
                        TextField("Text to Type", text: $text)
                    case .scroll:
                        Picker("Direction", selection: $scrollDirection) {
                            ForEach(ScrollDirection.allCases, id: \.self) { direction in
                                Text(direction.rawValue.capitalized)
                                    .tag(direction)
                            }
                        }
                    case .wait:
                        HStack {
                            Text("Duration:")
                            Spacer()
                            TextField("Seconds", value: $waitDuration, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                        }
                    case .screenshot:
                        Text("No parameters required")
                            .foregroundColor(.secondary)
                    case .custom:
                        TextField("Custom Action", text: $customAction)
                    }
                }
                
                Section("Timing") {
                    HStack {
                        Text("Delay After Step:")
                        Spacer()
                        TextField("Seconds", value: $delayAfter, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("Create Step")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    createStep()
                }
                .disabled(stepDescription.isEmpty || !isValidStep())
            )
        }
    }
    
    private func isValidStep() -> Bool {
        switch selectedActionType {
        case .tap, .typeText:
            return !selector.isEmpty
        case .custom:
            return !customAction.isEmpty
        default:
            return true
        }
    }
    
    private func createStep() {
        let action: AutomationStepAction
        
        switch selectedActionType {
        case .tap:
            action = .tap(selector: selector)
        case .typeText:
            action = .typeText(text: text, selector: selector)
        case .scroll:
            action = .scroll(direction: scrollDirection)
        case .wait:
            action = .wait(duration: waitDuration)
        case .screenshot:
            action = .screenshot
        case .custom:
            action = .custom(action: customAction)
        }
        
        let step = AutomationStep(
            description: stepDescription,
            action: action,
            delayAfter: delayAfter
        )
        
        onStepCreated(step)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    AutomationPanelView()
}
