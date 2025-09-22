
//
//  PlannerRole.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit

class PlannerRole: AIRoleProtocol {
    let id = "planner"
    let name = "Планировщик"
    let description = "Анализирует задачи и создает детальные планы выполнения"
    let communicationStyle: CommunicationStyle = .analytical
    let specialization: RoleSpecialization = .taskPlanning
    let capabilities: [RoleCapability] = [
        .strategicPlanning,
        .contextualAnalysis,
        .prioritization,
        .riskAssessment
    ]
    
    var memoryContext = RoleMemoryContext()
    
    let systemPrompt = """
    Ты - ИИ Планировщик в системе Eiros Agent. Твоя основная роль - анализировать задачи и создавать детальные, выполнимые планы.
    
    ТВОИ КЛЮЧЕВЫЕ ОБЯЗАННОСТИ:
    • Анализ входящих задач и определение их сложности
    • Создание пошаговых планов выполнения
    • Оценка рисков и потенциальных препятствий
    • Определение необходимых ресурсов и времени
    • Приоритизация задач по важности и срочности
    
    СТИЛЬ ОБЩЕНИЯ:
    • Аналитический и детальный подход
    • Структурированные ответы с четкой логикой
    • Использование данных и фактов для обоснования решений
    • Предвидение возможных проблем и их решений
    
    ПРИНЦИПЫ РАБОТЫ:
    1. Всегда начинай с анализа контекста задачи
    2. Разбивай сложные цели на измеримые этапы
    3. Учитывай ограничения и доступные ресурсы
    4. Предлагай альтернативные варианты выполнения
    5. Оценивай временные рамки реалистично
    
    При создании планов используй формат:
    - Цель: [четкое описание]
    - Анализ: [оценка сложности и контекста]
    - Этапы: [пронумерованный список шагов]
    - Ресурсы: [что потребуется]
    - Риски: [потенциальные проблемы]
    - Временные рамки: [оценка времени]
    """
    
    func processTask(_ task: AITask) async -> AITaskResult {
        let startTime = Date()
        
        // Analyze task complexity and context
        let analysis = analyzeTask(task)
        
        // Generate detailed plan
        let plan = await generatePlan(for: task, analysis: analysis)
        
        // Assess risks and create mitigation strategies
        let riskAssessment = assessRisks(for: task, plan: plan)
        
        // Determine if task needs decomposition
        let needsDecomposition = shouldDecompose(task, plan: plan)
        
        var delegatedTasks: [AITask] = []
        var nextSteps: [String] = []
        
        if needsDecomposition {
            // Create decomposition task
            let decompositionTask = AITask(
                title: "Декомпозиция: \(task.title)",
                description: "Разбить задачу '\(task.title)' на выполнимые шаги",
                type: .decomposition,
                priority: task.priority,
                context: plan,
                parameters: ["original_task_id": task.id.uuidString]
            )
            delegatedTasks.append(decompositionTask)
            nextSteps.append("Задача направлена на декомпозицию")
        } else {
            // Create execution steps
            nextSteps = extractExecutionSteps(from: plan)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        let confidence = calculateConfidence(for: task, analysis: analysis)
        
        let result = AITaskResult(
            taskId: task.id,
            success: true,
            result: plan,
            confidence: confidence,
            executionTime: executionTime,
            nextSteps: nextSteps,
            delegatedTasks: delegatedTasks,
            metadata: [
                "analysis": analysis,
                "risk_assessment": riskAssessment,
                "needs_decomposition": String(needsDecomposition)
            ]
        )
        
        // Update memory with learning
        updateMemoryWithResult(task: task, result: result)
        
        return result
    }
    
    func generatePrompt(for task: AITask, with context: String) -> String {
        let memoryContext = getRelevantMemoryContext(for: task)
        
        return """
        \(systemPrompt)
        
        КОНТЕКСТ ПАМЯТИ:
        \(memoryContext)
        
        ТЕКУЩАЯ ЗАДАЧА:
        Название: \(task.title)
        Описание: \(task.description)
        Тип: \(task.type.displayName)
        Приоритет: \(task.priority.displayName)
        Контекст: \(context)
        
        ДОПОЛНИТЕЛЬНЫЕ ПАРАМЕТРЫ:
        \(task.parameters.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        
        Создай детальный план выполнения этой задачи, учитывая все указанные факторы.
        """
    }
    
    func shouldHandleTask(_ task: AITask) -> Bool {
        switch task.type {
        case .planning, .analysis:
            return true
        case .coordination:
            return task.description.lowercased().contains("план") || 
                   task.description.lowercased().contains("стратег")
        default:
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func analyzeTask(_ task: AITask) -> String {
        var analysis = "АНАЛИЗ ЗАДАЧИ:\n"
        
        // Complexity assessment
        let complexity = assessComplexity(task)
        analysis += "Сложность: \(complexity)\n"
        
        // Context analysis
        if !task.context.isEmpty {
            analysis += "Контекст: \(task.context)\n"
        }
        
        // Priority analysis
        analysis += "Приоритет: \(task.priority.displayName)\n"
        
        // Resource requirements
        let resources = estimateResources(for: task)
        analysis += "Ресурсы: \(resources)\n"
        
        // Similar tasks from memory
        let similarTasks = findSimilarTasks(task)
        if !similarTasks.isEmpty {
            analysis += "Похожие задачи: \(similarTasks.count) найдено\n"
        }
        
        return analysis
    }
    
    private func generatePlan(for task: AITask, analysis: String) async -> String {
        // Use OpenRouter or Qwen2VL for plan generation
        let openRouterManager = OpenRouterManager.shared
        let qwen2VLManager = Qwen2VLManager.shared
        
        let prompt = generatePrompt(for: task, with: analysis)
        
        var plan: String
        
        if openRouterManager.isConfigured {
            let messages = [ChatMessage(content: prompt, isUser: true)]
            plan = await openRouterManager.generateResponse(for: messages)
        } else if qwen2VLManager.isModelLoaded {
            // For text-only tasks, use Qwen2VL in text mode
            plan = await qwen2VLManager.generateTextResponse(prompt: prompt) ?? "План не может быть создан"
        } else {
            // Fallback to template-based planning
            plan = generateTemplatePlan(for: task, analysis: analysis)
        }
        
        return plan
    }
    
    private func generateTemplatePlan(for task: AITask, analysis: String) -> String {
        return """
        ПЛАН ВЫПОЛНЕНИЯ: \(task.title)
        
        ЦЕЛЬ: \(task.description)
        
        АНАЛИЗ:
        \(analysis)
        
        ЭТАПЫ ВЫПОЛНЕНИЯ:
        1. Подготовительный этап
           - Анализ требований
           - Подготовка ресурсов
           
        2. Основной этап
           - Выполнение ключевых действий
           - Мониторинг прогресса
           
        3. Завершающий этап
           - Проверка результатов
           - Документирование
        
        РЕСУРСЫ:
        - Время: \(estimateTimeRequired(for: task))
        - Инструменты: \(getRequiredTools(for: task))
        
        РИСКИ:
        - Потенциальные препятствия
        - Стратегии митигации
        
        КРИТЕРИИ УСПЕХА:
        - Измеримые результаты
        - Качественные показатели
        """
    }
    
    private func assessRisks(for task: AITask, plan: String) -> String {
        var risks: [String] = []
        
        // Common risks based on task type
        switch task.type {
        case .planning:
            risks.append("Неполная информация для планирования")
            risks.append("Изменение требований в процессе")
        case .analysis:
            risks.append("Недостаточность данных для анализа")
            risks.append("Субъективность интерпретации")
        case .execution:
            risks.append("Технические сложности")
            risks.append("Нехватка ресурсов")
        default:
            risks.append("Неопределенность требований")
        }
        
        // Priority-based risks
        if task.priority == .critical {
            risks.append("Высокое давление времени")
        }
        
        return "ОЦЕНКА РИСКОВ:\n" + risks.enumerated().map { "• \($0.element)" }.joined(separator: "\n")
    }
    
    private func shouldDecompose(_ task: AITask, plan: String) -> Bool {
        // Decompose if task is complex or has multiple steps
        let planLines = plan.components(separatedBy: .newlines)
        let stepCount = planLines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("•") || 
                                          $0.trimmingCharacters(in: .whitespaces).matches(regex: "^\\d+\\.") }.count
        
        return stepCount > 5 || task.type == .planning || task.description.count > 200
    }
    
    private func extractExecutionSteps(from plan: String) -> [String] {
        let lines = plan.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("•") || trimmed.matches(regex: "^\\d+\\.") {
                return trimmed
            }
            return nil
        }
    }
    
    private func assessComplexity(_ task: AITask) -> String {
        var score = 0
        
        // Length of description
        if task.description.count > 100 { score += 1 }
        if task.description.count > 300 { score += 1 }
        
        // Number of parameters
        score += min(task.parameters.count, 2)
        
        // Task type complexity
        switch task.type {
        case .planning, .coordination: score += 2
        case .analysis, .optimization: score += 1
        default: break
        }
        
        switch score {
        case 0...1: return "Низкая"
        case 2...3: return "Средняя"
        case 4...5: return "Высокая"
        default: return "Очень высокая"
        }
    }
    
    private func estimateResources(for task: AITask) -> String {
        var resources: [String] = []
        
        switch task.type {
        case .planning:
            resources.append("Аналитические инструменты")
        case .analysis:
            resources.append("Данные для анализа")
        case .execution:
            resources.append("Исполнительные системы")
        default:
            resources.append("Базовые ресурсы")
        }
        
        return resources.joined(separator: ", ")
    }
    
    private func estimateTimeRequired(for task: AITask) -> String {
        let baseTime: Int
        
        switch task.type {
        case .planning: baseTime = 30
        case .analysis: baseTime = 20
        case .execution: baseTime = 60
        default: baseTime = 15
        }
        
        let complexity = assessComplexity(task)
        let multiplier: Double
        
        switch complexity {
        case "Низкая": multiplier = 1.0
        case "Средняя": multiplier = 1.5
        case "Высокая": multiplier = 2.0
        default: multiplier = 2.5
        }
        
        let estimatedMinutes = Int(Double(baseTime) * multiplier)
        
        if estimatedMinutes < 60 {
            return "\(estimatedMinutes) минут"
        } else {
            let hours = estimatedMinutes / 60
            let minutes = estimatedMinutes % 60
            return minutes > 0 ? "\(hours) ч \(minutes) мин" : "\(hours) ч"
        }
    }
    
    private func getRequiredTools(for task: AITask) -> String {
        var tools: [String] = []
        
        switch task.type {
        case .planning:
            tools.append("Планировщик задач")
        case .analysis:
            tools.append("Аналитические модули")
        case .execution:
            tools.append("Система автоматизации")
        default:
            tools.append("Базовые инструменты")
        }
        
        return tools.joined(separator: ", ")
    }
    
    private func findSimilarTasks(_ task: AITask) -> [LearningEntry] {
        return memoryContext.learningHistory.filter { entry in
            entry.task.lowercased().contains(task.title.lowercased()) ||
            task.title.lowercased().contains(entry.task.lowercased())
        }
    }
    
    private func calculateConfidence(for task: AITask, analysis: String) -> Float {
        var confidence: Float = 0.7 // Base confidence
        
        // Increase confidence based on similar past experiences
        let similarTasks = findSimilarTasks(task)
        if !similarTasks.isEmpty {
            let avgConfidence = similarTasks.map { $0.confidence }.reduce(0, +) / Float(similarTasks.count)
            confidence += avgConfidence * 0.2
        }
        
        // Adjust based on task complexity
        let complexity = assessComplexity(task)
        switch complexity {
        case "Низкая": confidence += 0.1
        case "Высокая", "Очень высокая": confidence -= 0.1
        default: break
        }
        
        return min(confidence, 1.0)
    }
    
    private func getRelevantMemoryContext(for task: AITask) -> String {
        let similarTasks = findSimilarTasks(task)
        
        if similarTasks.isEmpty {
            return "Нет релевантного опыта для данной задачи."
        }
        
        let recentTasks = similarTasks.suffix(3)
        return "Релевантный опыт:\n" + recentTasks.map { 
            "• \($0.task): \($0.outcome) (уверенность: \(Int($0.confidence * 100))%)"
        }.joined(separator: "\n")
    }
    
    private func updateMemoryWithResult(task: AITask, result: AITaskResult) {
        let learningEntry = LearningEntry(
            task: task.title,
            outcome: result.success ? "План создан успешно" : "Ошибка создания плана",
            feedback: result.result,
            confidence: result.confidence
        )
        
        memoryContext.addLearning(learningEntry)
        
        // Update preferences based on successful patterns
        if result.success {
            memoryContext.updatePreference(key: "preferred_task_type", value: task.type.rawValue)
            memoryContext.updatePreference(key: "successful_approach", value: "analytical_planning")
        }
    }
}

// MARK: - String Extension for Regex

extension String {
    func matches(regex: String) -> Bool {
        return range(of: regex, options: .regularExpression) != nil
    }
}
