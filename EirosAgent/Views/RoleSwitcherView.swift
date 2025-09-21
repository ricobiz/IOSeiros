
//
//  RoleSwitcherView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct RoleSwitcherView: View {
    @StateObject private var roleManager = AIRoleManager.shared
    @State private var showingRoleDetails = false
    @State private var selectedRoleForDetails: AIRoleType?
    @State private var showingTaskCreation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with current role
                currentRoleHeader
                
                Divider()
                
                // Role selection grid
                roleSelectionGrid
                
                Divider()
                
                // System status
                systemStatusSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("ИИ Роли")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingRoleDetails) {
                if let selectedRole = selectedRoleForDetails {
                    RoleDetailsView(roleType: selectedRole)
                }
            }
            .sheet(isPresented: $showingTaskCreation) {
                TaskCreationView()
            }
        }
    }
    
    // MARK: - Current Role Header
    
    private var currentRoleHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: roleManager.activeRole.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Активная роль")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(roleManager.activeRole.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if roleManager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Current task indicator
            if let currentTask = roleManager.currentTask {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text(currentTask.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Role Selection Grid
    
    private var roleSelectionGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(roleManager.availableRoles, id: \.self) { roleType in
                RoleCard(
                    roleType: roleType,
                    isActive: roleType == roleManager.activeRole,
                    performance: roleManager.getRolePerformance(for: roleType),
                    onTap: {
                        if roleType != roleManager.activeRole {
                            roleManager.switchToRole(roleType)
                        }
                    },
                    onLongPress: {
                        selectedRoleForDetails = roleType
                        showingRoleDetails = true
                    }
                )
            }
        }
        .padding()
    }
    
    // MARK: - System Status Section
    
    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Статус системы")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                StatusItem(
                    icon: "list.bullet",
                    title: "В очереди",
                    value: "\(roleManager.taskQueue.count)",
                    color: .blue
                )
                
                StatusItem(
                    icon: "checkmark.circle",
                    title: "Выполнено",
                    value: "\(roleManager.completedTasks.count)",
                    color: .green
                )
                
                StatusItem(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Координация",
                    value: "\(roleManager.coordinationRequests.count)",
                    color: .orange
                )
                
                StatusItem(
                    icon: "clock",
                    title: "Среднее время",
                    value: String(format: "%.1fs", roleManager.averageProcessingTime),
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingTaskCreation = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Создать задачу")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    roleManager.clearTaskQueue()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Очистить очередь")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    roleManager.clearCompletedTasks()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Очистить выполненные")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

// MARK: - Role Card

struct RoleCard: View {
    let roleType: AIRoleType
    let isActive: Bool
    let performance: RolePerformanceMetrics?
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Role icon
                Image(systemName: roleType.icon)
                    .font(.title2)
                    .foregroundColor(isActive ? .white : .blue)
                
                // Role name
                Text(roleType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                // Performance indicator
                if let performance = performance {
                    VStack(spacing: 2) {
                        Text(performance.formattedSuccessRate)
                            .font(.caption2)
                            .foregroundColor(isActive ? .white.opacity(0.8) : .secondary)
                        
                        Text("\(performance.totalTasks) задач")
                            .font(.caption2)
                            .foregroundColor(isActive ? .white.opacity(0.8) : .secondary)
                    }
                } else {
                    Text("Новая роль")
                        .font(.caption2)
                        .foregroundColor(isActive ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(isActive ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Status Item

struct StatusItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Role Details View

struct RoleDetailsView: View {
    let roleType: AIRoleType
    @StateObject private var roleManager = AIRoleManager.shared
    @StateObject private var memoryStore = RoleMemoryStore.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Role header
                    roleHeader
                    
                    // Performance metrics
                    performanceSection
                    
                    // Memory usage
                    memorySection
                    
                    // Role capabilities
                    capabilitiesSection
                    
                    // Recent activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle(roleType.displayName)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Готово") { dismiss() })
        }
    }
    
    private var roleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: roleType.icon)
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(roleType.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(getRoleDescription())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if roleType == roleManager.activeRole {
                Label("Активная роль", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Производительность")
                .font(.headline)
            
            if let performance = roleManager.getRolePerformance(for: roleType) {
                VStack(spacing: 8) {
                    MetricRow(title: "Всего задач", value: "\(performance.totalTasks)")
                    MetricRow(title: "Успешных", value: "\(performance.successfulTasks)")
                    MetricRow(title: "Успешность", value: performance.formattedSuccessRate)
                    MetricRow(title: "Среднее время", value: performance.formattedProcessingTime)
                    
                    if let lastUsed = performance.lastUsed {
                        MetricRow(title: "Последнее использование", value: formatDate(lastUsed))
                    }
                }
            } else {
                Text("Нет данных о производительности")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Память")
                .font(.headline)
            
            let memoryUsage = memoryStore.getMemoryUsage(for: roleType)
            
            VStack(spacing: 8) {
                MetricRow(title: "Размер памяти", value: memoryUsage.formattedSize)
                MetricRow(title: "Статус", value: memoryUsage.exists ? "Активна" : "Пуста")
                
                if let lastModified = memoryUsage.lastModified {
                    MetricRow(title: "Последнее обновление", value: formatDate(lastModified))
                }
            }
            
            Button(action: {
                Task {
                    await memoryStore.clearMemory(for: roleType)
                }
            }) {
                Text("Очистить память")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Возможности")
                .font(.headline)
            
            let role = roleManager.getRoleInstance(for: roleType)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(role.capabilities, id: \.self) { capability in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(capability.description)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Недавняя активность")
                .font(.headline)
            
            let recentTasks = roleManager.completedTasks
                .filter { $0.metadata["role"] == roleType.rawValue }
                .suffix(5)
            
            if recentTasks.isEmpty {
                Text("Нет недавней активности")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recentTasks), id: \.taskId) { result in
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                                .font(.caption)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.result.prefix(50) + (result.result.count > 50 ? "..." : ""))
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Text(formatDate(result.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getRoleDescription() -> String {
        let role = roleManager.getRoleInstance(for: roleType)
        return role.description
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Task Creation View

struct TaskCreationView: View {
    @StateObject private var roleManager = AIRoleManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: AITaskType = .planning
    @State private var selectedPriority: TaskPriority = .medium
    @State private var context = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Основная информация") {
                    TextField("Название задачи", text: $title)
                    
                    TextField("Описание", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Параметры") {
                    Picker("Тип задачи", selection: $selectedType) {
                        ForEach(AITaskType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Приоритет", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }
                
                Section("Дополнительный контекст") {
                    TextField("Контекст (необязательно)", text: $context, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Отмена") { dismiss() },
                trailing: Button("Создать") {
                    createTask()
                    dismiss()
                }
                .disabled(title.isEmpty || description.isEmpty)
            )
        }
    }
    
    private func createTask() {
        let task = AITask(
            title: title,
            description: description,
            type: selectedType,
            priority: selectedPriority,
            context: context
        )
        
        roleManager.addTaskToQueue(task)
    }
}

#Preview {
    RoleSwitcherView()
}
