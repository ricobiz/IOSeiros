
//
//  AIRoleManager.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import Combine
import UIKit

@MainActor
class AIRoleManager: ObservableObject {
    static let shared = AIRoleManager()
    
    // MARK: - Published Properties
    @Published var activeRole: AIRoleType = .planner
    @Published var availableRoles: [AIRoleType] = AIRoleType.allCases
    @Published var isProcessing = false
    @Published var currentTask: AITask?
    @Published var taskQueue: [AITask] = []
    @Published var completedTasks: [AITaskResult] = []
    @Published var coordinationRequests: [RoleCoordinationRequest] = []
    
    // Role instances
    @Published var plannerRole: PlannerRole
    @Published var decomposerRole: DecomposerRole
    @Published var orchestratorRole: OrchestratorRole
    
    // Performance metrics
    @Published var rolePerformance: [AIRoleType: RolePerformanceMetrics] = [:]
    @Published var totalTasksProcessed = 0
    @Published var averageProcessingTime: TimeInterval = 0
    
    // MARK: - Dependencies
    private let openRouterManager = OpenRouterManager.shared
    private let qwen2VLManager = Qwen2VLManager.shared
    private let memoryStore = RoleMemoryStore.shared
    private let automationController = AutomationController.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingHistory = 50
    
    private init() {
        // Initialize roles
        self.plannerRole = PlannerRole()
        self.decomposerRole = DecomposerRole()
        self.orchestratorRole = OrchestratorRole()
        
        setupRolePerformanceTracking()
        loadRoleMemories()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor processing states
        Publishers.CombineLatest3(
            openRouterManager.$isGenerating,
            qwen2VLManager.$isProcessing,
            automationController.$isProcessing
        )
        .map { openRouter, qwen, automation in
            openRouter || qwen || automation
        }
        .assign(to: &$isProcessing)
    }
    
    private func setupRolePerformanceTracking() {
        for roleType in AIRoleType.allCases {
            rolePerformance[roleType] = RolePerformanceMetrics()
        }
    }
    
    private func loadRoleMemories() {
        Task {
            plannerRole.memoryContext = await memoryStore.loadMemory(for: .planner)
            decomposerRole.memoryContext = await memoryStore.loadMemory(for: .decomposer)
            orchestratorRole.memoryContext = await memoryStore.loadMemory(for: .orchestrator)
        }
    }
    
    // MARK: - Role Management
    
    func switchToRole(_ roleType: AIRoleType) {
        guard roleType != activeRole else { return }
        
        let previousRole = activeRole
        activeRole = roleType
        
        // Save context from previous role
        Task {
            await saveRoleMemory(for: previousRole)
        }
        
        logRoleSwitch(from: previousRole, to: roleType)
    }
    
    func getCurrentRole() -> AIRoleProtocol {
        switch activeRole {
        case .planner: return plannerRole
        case .decomposer: return decomposerRole
        case .orchestrator: return orchestratorRole
        }
    }
    
    func getRoleInstance(for type: AIRoleType) -> AIRoleProtocol {
        switch type {
        case .planner: return plannerRole
        case .decomposer: return decomposerRole
        case .orchestrator: return orchestratorRole
        }
    }
    
    // MARK: - Task Processing
    
    func processTask(_ task: AITask) async -> AITaskResult {
        let startTime = Date()
        currentTask = task
        
        // Determine best role for task
        let bestRole = determineBestRole(for: task)
        if bestRole != activeRole {
            switchToRole(bestRole)
        }
        
        let role = getCurrentRole()
        
        // Process task with selected role
        let result = await role.processTask(task)
        
        // Update metrics
        let processingTime = Date().timeIntervalSince(startTime)
        updatePerformanceMetrics(for: activeRole, processingTime: processingTime, success: result.success)
        
        // Handle coordination if needed
        await handleTaskCoordination(task: task, result: result)
        
        // Save results
        completedTasks.append(result)
        currentTask = nil
        totalTasksProcessed += 1
        
        // Update role memory
        await updateRoleMemory(for: activeRole, task: task, result: result)
        
        return result
    }
    
    func addTaskToQueue(_ task: AITask) {
        taskQueue.append(task)
        
        // Auto-process if not currently processing
        if !isProcessing && currentTask == nil {
            Task {
                await processNextTask()
            }
        }
    }
    
    func processNextTask() async {
        guard !taskQueue.isEmpty, !isProcessing else { return }
        
        let task = taskQueue.removeFirst()
        _ = await processTask(task)
        
        // Continue processing queue
        if !taskQueue.isEmpty {
            await processNextTask()
        }
    }
    
    private func determineBestRole(for task: AITask) -> AIRoleType {
        // Score each role for the task
        var roleScores: [AIRoleType: Float] = [:]
        
        for roleType in AIRoleType.allCases {
            let role = getRoleInstance(for: roleType)
            let score = calculateRoleScore(role: role, task: task)
            roleScores[roleType] = score
        }
        
        // Return role with highest score
        return roleScores.max(by: { $0.value < $1.value })?.key ?? .planner
    }
    
    private func calculateRoleScore(role: AIRoleProtocol, task: AITask) -> Float {
        var score: Float = 0.0
        
        // Base score from role's ability to handle task
        if role.shouldHandleTask(task) {
            score += 0.5
        }
        
        // Task type alignment
        switch (role.id, task.type) {
        case ("planner", .planning), ("planner", .analysis):
            score += 0.8
        case ("decomposer", .decomposition), ("decomposer", .planning):
            score += 0.8
        case ("orchestrator", .coordination), ("orchestrator", .execution):
            score += 0.8
        default:
            score += 0.2
        }
        
        // Performance history
        if let performance = rolePerformance[AIRoleType(rawValue: role.id) ?? .planner] {
            score += performance.successRate * 0.3
        }
        
        // Specialization match
        let specializationBonus = role.specialization == getRequiredSpecialization(for: task) ? 0.4 : 0.0
        score += specializationBonus
        
        return min(score, 1.0)
    }
    
    private func getRequiredSpecialization(for task: AITask) -> RoleSpecialization {
        switch task.type {
        case .planning: return .taskPlanning
        case .decomposition: return .taskDecomposition
        case .coordination: return .processOrchestration
        case .analysis: return .contextAnalysis
        case .execution, .optimization: return .decisionMaking
        }
    }
    
    // MARK: - Role Coordination
    
    private func handleTaskCoordination(task: AITask, result: AITaskResult) async {
        // Process delegated tasks
        for delegatedTask in result.delegatedTasks {
            let bestRole = determineBestRole(for: delegatedTask)
            
            if bestRole != activeRole {
                let request = RoleCoordinationRequest(
                    fromRole: activeRole,
                    toRole: bestRole,
                    task: delegatedTask,
                    context: "Delegated from \(activeRole.displayName): \(result.result)"
                )
                
                coordinationRequests.append(request)
                await processCoordinationRequest(request)
            } else {
                addTaskToQueue(delegatedTask)
            }
        }
    }
    
    func processCoordinationRequest(_ request: RoleCoordinationRequest) async {
        // Switch to target role
        let originalRole = activeRole
        switchToRole(request.toRole)
        
        // Process the delegated task
        var taskWithContext = request.task
        taskWithContext.parameters["coordination_context"] = request.context
        
        let result = await processTask(taskWithContext)
        
        // Switch back to original role if needed
        if originalRole != request.toRole {
            switchToRole(originalRole)
        }
        
        // Remove processed request
        coordinationRequests.removeAll { $0.id == request.id }
    }
    
    // MARK: - Memory Management
    
    private func updateRoleMemory(for roleType: AIRoleType, task: AITask, result: AITaskResult) async {
        let role = getRoleInstance(for: roleType)
        var memory = role.memoryContext
        
        let learningEntry = LearningEntry(
            task: task.title,
            outcome: result.result,
            feedback: result.success ? "Success" : "Failed",
            confidence: result.confidence
        )
        
        memory.addLearning(learningEntry)
        
        // Update role's memory
        switch roleType {
        case .planner:
            plannerRole.memoryContext = memory
        case .decomposer:
            decomposerRole.memoryContext = memory
        case .orchestrator:
            orchestratorRole.memoryContext = memory
        }
        
        await memoryStore.saveMemory(memory, for: roleType)
    }
    
    private func saveRoleMemory(for roleType: AIRoleType) async {
        let role = getRoleInstance(for: roleType)
        await memoryStore.saveMemory(role.memoryContext, for: roleType)
    }
    
    // MARK: - Performance Tracking
    
    private func updatePerformanceMetrics(for roleType: AIRoleType, processingTime: TimeInterval, success: Bool) {
        guard var metrics = rolePerformance[roleType] else { return }
        
        metrics.totalTasks += 1
        if success {
            metrics.successfulTasks += 1
        }
        
        metrics.processingTimes.append(processingTime)
        if metrics.processingTimes.count > maxProcessingHistory {
            metrics.processingTimes.removeFirst()
        }
        
        metrics.successRate = Float(metrics.successfulTasks) / Float(metrics.totalTasks)
        metrics.averageProcessingTime = metrics.processingTimes.reduce(0, +) / Double(metrics.processingTimes.count)
        metrics.lastUsed = Date()
        
        rolePerformance[roleType] = metrics
        
        // Update global metrics
        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingHistory {
            processingTimes.removeFirst()
        }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    private func logRoleSwitch(from: AIRoleType, to: AIRoleType) {
        print("AIRoleManager: Switched from \(from.displayName) to \(to.displayName)")
    }
    
    // MARK: - Public Interface
    
    func getRolePerformance(for roleType: AIRoleType) -> RolePerformanceMetrics? {
        return rolePerformance[roleType]
    }
    
    func clearTaskQueue() {
        taskQueue.removeAll()
    }
    
    func clearCompletedTasks() {
        completedTasks.removeAll()
    }
    
    func getSystemStatus() -> AIRoleSystemStatus {
        return AIRoleSystemStatus(
            activeRole: activeRole,
            isProcessing: isProcessing,
            queuedTasks: taskQueue.count,
            completedTasks: completedTasks.count,
            coordinationRequests: coordinationRequests.count,
            totalTasksProcessed: totalTasksProcessed,
            averageProcessingTime: averageProcessingTime,
            rolePerformance: rolePerformance
        )
    }
}

// MARK: - Performance Metrics

struct RolePerformanceMetrics: Codable {
    var totalTasks: Int = 0
    var successfulTasks: Int = 0
    var successRate: Float = 0.0
    var averageProcessingTime: TimeInterval = 0.0
    var processingTimes: [TimeInterval] = []
    var lastUsed: Date?
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var formattedProcessingTime: String {
        return String(format: "%.2f s", averageProcessingTime)
    }
}

struct AIRoleSystemStatus {
    let activeRole: AIRoleType
    let isProcessing: Bool
    let queuedTasks: Int
    let completedTasks: Int
    let coordinationRequests: Int
    let totalTasksProcessed: Int
    let averageProcessingTime: TimeInterval
    let rolePerformance: [AIRoleType: RolePerformanceMetrics]
    
    var formattedProcessingTime: String {
        return String(format: "%.2f s", averageProcessingTime)
    }
}
