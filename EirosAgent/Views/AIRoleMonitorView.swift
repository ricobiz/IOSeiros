
//
//  AIRoleMonitorView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI
import Charts

struct AIRoleMonitorView: View {
    @StateObject private var roleManager = AIRoleManager.shared
    @StateObject private var memoryStore = RoleMemoryStore.shared
    @State private var selectedTimeRange: TimeRange = .hour
    @State private var showingMemoryDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // System overview
                    systemOverviewSection
                    
                    // Role performance chart
                    performanceChartSection
                    
                    // Task queue status
                    taskQueueSection
                    
                    // Memory usage
                    memoryUsageSection
                    
                    // Coordination requests
                    coordinationSection
                }
                .padding()
            }
            .navigationTitle("Мониторинг ИИ")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                // Refresh data
            }
            .sheet(isPresented: $showingMemoryDetails) {
                MemoryDetailsView()
            }
        }
    }
    
    // MARK: - System Overview
    
    private var systemOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Обзор системы")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                OverviewCard(
                    title: "Активная роль",
                    value: roleManager.activeRole.displayName,
                    icon: roleManager.activeRole.icon,
                    color: .blue
                )
                
                OverviewCard(
                    title: "Статус",
                    value: roleManager.isProcessing ? "Обработка" : "Готов",
                    icon: roleManager.isProcessing ? "gearshape.2" : "checkmark.circle",
                    color: roleManager.isProcessing ? .orange : .green
                )
                
                OverviewCard(
                    title: "Всего задач",
                    value: "\(roleManager.totalTasksProcessed)",
                    icon: "list.bullet",
                    color: .purple
                )
                
                OverviewCard(
                    title: "Среднее время",
                    value: String(format: "%.1fs", roleManager.averageProcessingTime),
                    icon: "clock",
                    color: .indigo
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Performance Chart
    
    private var performanceChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Производительность ролей")
                    .font(.headline)
                
                Spacer()
                
                Picker("Период", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(AIRoleType.allCases, id: \.self) { roleType in
                        if let performance = roleManager.getRolePerformance(for: roleType) {
                            BarMark(
                                x: .value("Role", roleType.displayName),
                                y: .value("Success Rate", performance.successRate * 100)
                            )
                            .foregroundStyle(getColorForRole(roleType))
                        }
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))%")
                            }
                        }
                    }
                }
            } else {
                // Fallback for iOS 15
                VStack(spacing: 8) {
                    ForEach(AIRoleType.allCases, id: \.self) { roleType in
                        if let performance = roleManager.getRolePerformance(for: roleType) {
                            HStack {
                                Text(roleType.displayName)
                                    .font(.caption)
                                    .frame(width: 80, alignment: .leading)
                                
                                ProgressView(value: performance.successRate)
                                    .progressViewStyle(LinearProgressViewStyle(tint: getColorForRole(roleType)))
                                
                                Text(performance.formattedSuccessRate)
                                    .font(.caption)
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Task Queue
    
    private var taskQueueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Очередь задач")
                    .font(.headline)
                
                Spacer()
                
                Text("\(roleManager.taskQueue.count) в очереди")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if roleManager.taskQueue.isEmpty {
                Text("Очередь пуста")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(roleManager.taskQueue.prefix(5)), id: \.id) { task in
                        TaskQueueRow(task: task)
                    }
                    
                    if roleManager.taskQueue.count > 5 {
                        Text("и еще \(roleManager.taskQueue.count - 5) задач...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Memory Usage
    
    private var memoryUsageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Использование памяти")
                    .font(.headline)
                
                Spacer()
                
                Button("Подробнее") {
                    showingMemoryDetails = true
                }
                .font(.caption)
            }
            
            let memoryStats = memoryStore.getMemoryStats()
            
            VStack(spacing: 12) {
                HStack {
                    Text("Общий размер:")
                    Spacer()
                    Text(memoryStats.formattedTotalSize)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Ролей с памятью:")
                    Spacer()
                    Text("\(memoryStats.rolesWithMemory) из \(AIRoleType.allCases.count)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Последнее сохранение:")
                    Spacer()
                    Text(memoryStats.formattedLastSaveTime)
                        .fontWeight(.medium)
                }
            }
            .font(.subheadline)
            
            // Memory by role
            VStack(spacing: 6) {
                ForEach(AIRoleType.allCases, id: \.self) { roleType in
                    let usage = memoryStore.getMemoryUsage(for: roleType)
                    
                    HStack {
                        Image(systemName: roleType.icon)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text(roleType.displayName)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(usage.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Coordination
    
    private var coordinationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Координация ролей")
                    .font(.headline)
                
                Spacer()
                
                Text("\(roleManager.coordinationRequests.count) запросов")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if roleManager.coordinationRequests.isEmpty {
                Text("Нет активных запросов координации")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(roleManager.coordinationRequests.prefix(3), id: \.id) { request in
                        CoordinationRequestRow(request: request)
                    }
                    
                    if roleManager.coordinationRequests.count > 3 {
                        Text("и еще \(roleManager.coordinationRequests.count - 3) запросов...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func getColorForRole(_ roleType: AIRoleType) -> Color {
        switch roleType {
        case .planner: return .blue
        case .decomposer: return .green
        case .orchestrator: return .orange
        }
    }
}

// MARK: - Supporting Views

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TaskQueueRow: View {
    let task: AITask
    
    var body: some View {
        HStack {
            Image(systemName: getIconForTaskType(task.type))
                .font(.caption)
                .foregroundColor(getColorForPriority(task.priority))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(task.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(task.priority.displayName)
                    .font(.caption2)
                    .foregroundColor(getColorForPriority(task.priority))
                
                Text(formatTimeAgo(task.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getIconForTaskType(_ type: AITaskType) -> String {
        switch type {
        case .planning: return "brain.head.profile"
        case .decomposition: return "list.bullet.rectangle"
        case .execution: return "play.circle"
        case .coordination: return "gearshape.2"
        case .analysis: return "magnifyingglass"
        case .optimization: return "speedometer"
        }
    }
    
    private func getColorForPriority(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "\(Int(interval))с"
        } else if interval < 3600 {
            return "\(Int(interval / 60))м"
        } else {
            return "\(Int(interval / 3600))ч"
        }
    }
}

struct CoordinationRequestRow: View {
    let request: RoleCoordinationRequest
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(request.fromRole.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(request.toRole.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Text(request.task.title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(request.urgency.displayName)
                    .font(.caption2)
                    .foregroundColor(getColorForUrgency(request.urgency))
                
                Text(formatTimeAgo(request.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getColorForUrgency(_ urgency: CoordinationUrgency) -> Color {
        switch urgency {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "\(Int(interval))с"
        } else if interval < 3600 {
            return "\(Int(interval / 60))м"
        } else {
            return "\(Int(interval / 3600))ч"
        }
    }
}

// MARK: - Memory Details View

struct MemoryDetailsView: View {
    @StateObject private var memoryStore = RoleMemoryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Общая информация") {
                    let stats = memoryStore.getMemoryStats()
                    
                    HStack {
                        Text("Общий размер")
                        Spacer()
                        Text(stats.formattedTotalSize)
                    }
                    
                    HStack {
                        Text("Ролей с памятью")
                        Spacer()
                        Text("\(stats.rolesWithMemory) из \(AIRoleType.allCases.count)")
                    }
                    
                    HStack {
                        Text("Последнее сохранение")
                        Spacer()
                        Text(stats.formattedLastSaveTime)
                    }
                }
                
                Section("Память по ролям") {
                    ForEach(AIRoleType.allCases, id: \.self) { roleType in
                        let usage = memoryStore.getMemoryUsage(for: roleType)
                        
                        HStack {
                            Image(systemName: roleType.icon)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(roleType.displayName)
                                    .fontWeight(.medium)
                                
                                if usage.exists {
                                    Text("Обновлено: \(usage.formattedLastModified)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Память пуста")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(usage.formattedSize)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Section("Действия") {
                    Button(action: {
                        showingClearAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Очистить всю память")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Память ИИ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Готово") { dismiss() })
            .alert("Очистить память?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Очистить", role: .destructive) {
                    Task {
                        await memoryStore.clearAllMemories()
                    }
                }
            } message: {
                Text("Это действие удалит всю память ролей ИИ. Данное действие нельзя отменить.")
            }
        }
    }
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable {
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
    
    var displayName: String {
        switch self {
        case .hour: return "Час"
        case .day: return "День"
        case .week: return "Неделя"
        case .month: return "Месяц"
        }
    }
}

#Preview {
    AIRoleMonitorView()
}
