
//
//  AIRole.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation

// MARK: - AI Role Protocol

protocol AIRoleProtocol {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var systemPrompt: String { get }
    var communicationStyle: CommunicationStyle { get }
    var specialization: RoleSpecialization { get }
    var capabilities: [RoleCapability] { get }
    var memoryContext: RoleMemoryContext { get set }
    
    func processTask(_ task: AITask) async -> AITaskResult
    func generatePrompt(for task: AITask, with context: String) -> String
    func shouldHandleTask(_ task: AITask) -> Bool
}

// MARK: - AI Role Types

enum AIRoleType: String, CaseIterable, Identifiable {
    case planner = "planner"
    case decomposer = "decomposer" 
    case orchestrator = "orchestrator"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .planner: return "Планировщик"
        case .decomposer: return "Декомпозитор"
        case .orchestrator: return "Оркестратор"
        }
    }
    
    var icon: String {
        switch self {
        case .planner: return "brain.head.profile"
        case .decomposer: return "list.bullet.rectangle"
        case .orchestrator: return "gearshape.2"
        }
    }
}

// MARK: - Communication Styles

enum CommunicationStyle: String, CaseIterable {
    case analytical = "analytical"
    case methodical = "methodical"
    case directive = "directive"
    case collaborative = "collaborative"
    
    var description: String {
        switch self {
        case .analytical: return "Аналитический, детальный подход"
        case .methodical: return "Методичный, пошаговый стиль"
        case .directive: return "Директивный, четкий и краткий"
        case .collaborative: return "Коллаборативный, координирующий"
        }
    }
}

// MARK: - Role Specializations

enum RoleSpecialization: String, CaseIterable {
    case taskPlanning = "task_planning"
    case taskDecomposition = "task_decomposition"
    case processOrchestration = "process_orchestration"
    case contextAnalysis = "context_analysis"
    case decisionMaking = "decision_making"
    
    var description: String {
        switch self {
        case .taskPlanning: return "Планирование и стратегия"
        case .taskDecomposition: return "Разбиение сложных задач"
        case .processOrchestration: return "Координация процессов"
        case .contextAnalysis: return "Анализ контекста"
        case .decisionMaking: return "Принятие решений"
        }
    }
}

// MARK: - Role Capabilities

enum RoleCapability: String, CaseIterable {
    case strategicPlanning = "strategic_planning"
    case taskBreakdown = "task_breakdown"
    case processCoordination = "process_coordination"
    case contextualAnalysis = "contextual_analysis"
    case prioritization = "prioritization"
    case resourceAllocation = "resource_allocation"
    case qualityAssurance = "quality_assurance"
    case riskAssessment = "risk_assessment"
    
    var description: String {
        switch self {
        case .strategicPlanning: return "Стратегическое планирование"
        case .taskBreakdown: return "Декомпозиция задач"
        case .processCoordination: return "Координация процессов"
        case .contextualAnalysis: return "Контекстуальный анализ"
        case .prioritization: return "Приоритизация"
        case .resourceAllocation: return "Распределение ресурсов"
        case .qualityAssurance: return "Контроль качества"
        case .riskAssessment: return "Оценка рисков"
        }
    }
}

// MARK: - Memory Context

struct RoleMemoryContext: Codable {
    var shortTermMemory: [String: Any] = [:]
    var longTermMemory: [String: Any] = [:]
    var preferences: [String: Any] = [:]
    var learningHistory: [LearningEntry] = []
    var lastInteraction: Date?
    
    private enum CodingKeys: String, CodingKey {
        case lastInteraction, learningHistory
    }
    
    init() {
        self.lastInteraction = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastInteraction = try container.decodeIfPresent(Date.self, forKey: .lastInteraction)
        learningHistory = try container.decodeIfPresent([LearningEntry].self, forKey: .learningHistory) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lastInteraction, forKey: .lastInteraction)
        try container.encode(learningHistory, forKey: .learningHistory)
    }
    
    mutating func addLearning(_ entry: LearningEntry) {
        learningHistory.append(entry)
        if learningHistory.count > 100 {
            learningHistory.removeFirst()
        }
        lastInteraction = Date()
    }
    
    mutating func updatePreference(key: String, value: Any) {
        preferences[key] = value
        lastInteraction = Date()
    }
}

struct LearningEntry: Codable, Identifiable {
    let id = UUID()
    let task: String
    let outcome: String
    let feedback: String?
    let timestamp: Date
    let confidence: Float
    
    init(task: String, outcome: String, feedback: String? = nil, confidence: Float = 0.5) {
        self.task = task
        self.outcome = outcome
        self.feedback = feedback
        self.confidence = confidence
        self.timestamp = Date()
    }
}

// MARK: - AI Task Models

struct AITask: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let type: AITaskType
    let priority: TaskPriority
    let context: String
    let parameters: [String: String]
    let createdAt: Date
    var status: AITaskStatus
    var assignedRole: AIRoleType?
    
    init(title: String, description: String, type: AITaskType, priority: TaskPriority = .medium, context: String = "", parameters: [String: String] = [:]) {
        self.title = title
        self.description = description
        self.type = type
        self.priority = priority
        self.context = context
        self.parameters = parameters
        self.createdAt = Date()
        self.status = .pending
    }
}

enum AITaskType: String, CaseIterable, Codable {
    case planning = "planning"
    case decomposition = "decomposition"
    case execution = "execution"
    case coordination = "coordination"
    case analysis = "analysis"
    case optimization = "optimization"
    
    var displayName: String {
        switch self {
        case .planning: return "Планирование"
        case .decomposition: return "Декомпозиция"
        case .execution: return "Выполнение"
        case .coordination: return "Координация"
        case .analysis: return "Анализ"
        case .optimization: return "Оптимизация"
        }
    }
}

enum AITaskStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case delegated = "delegated"
    
    var displayName: String {
        switch self {
        case .pending: return "Ожидает"
        case .inProgress: return "В процессе"
        case .completed: return "Завершено"
        case .failed: return "Ошибка"
        case .delegated: return "Делегировано"
        }
    }
}

struct AITaskResult: Codable {
    let taskId: UUID
    let success: Bool
    let result: String
    let confidence: Float
    let executionTime: TimeInterval
    let nextSteps: [String]
    let delegatedTasks: [AITask]
    let metadata: [String: String]
    let timestamp: Date
    
    init(taskId: UUID, success: Bool, result: String, confidence: Float = 0.8, executionTime: TimeInterval = 0, nextSteps: [String] = [], delegatedTasks: [AITask] = [], metadata: [String: String] = [:]) {
        self.taskId = taskId
        self.success = success
        self.result = result
        self.confidence = confidence
        self.executionTime = executionTime
        self.nextSteps = nextSteps
        self.delegatedTasks = delegatedTasks
        self.metadata = metadata
        self.timestamp = Date()
    }
}

// MARK: - Role Coordination

struct RoleCoordinationRequest: Identifiable, Codable {
    let id = UUID()
    let fromRole: AIRoleType
    let toRole: AIRoleType
    let task: AITask
    let context: String
    let urgency: CoordinationUrgency
    let timestamp: Date
    
    init(fromRole: AIRoleType, toRole: AIRoleType, task: AITask, context: String, urgency: CoordinationUrgency = .normal) {
        self.fromRole = fromRole
        self.toRole = toRole
        self.task = task
        self.context = context
        self.urgency = urgency
        self.timestamp = Date()
    }
}

enum CoordinationUrgency: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Низкая"
        case .normal: return "Обычная"
        case .high: return "Высокая"
        case .critical: return "Критическая"
        }
    }
}
