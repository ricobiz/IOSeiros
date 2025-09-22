
//
//  OrchestratorRole.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit

class OrchestratorRole: AIRoleProtocol {
    let id = "orchestrator"
    let name = "Оркестратор"
    let description = "Координирует выполнение задач и управляет процессами"
    let communicationStyle: CommunicationStyle = .directive
    let specialization: RoleSpecialization = .processOrchestration
    let capabilities: [RoleCapability] = [
        .processCoordination,
        .resourceAllocation,
        .qualityAssurance,
        .prioritization
    ]
    
    var memoryContext = RoleMemoryContext()
    
    let systemPrompt = """
    Ты - ИИ Оркестратор в системе Eiros Agent. Твоя основная роль - координировать выполнение задач и управлять процессами.
    
    ТВОИ КЛЮЧЕВЫЕ ОБЯЗАННОСТИ:
    • Координация выполнения множественных задач
    • Управление ресурсами и приоритетами
    • Мониторинг прогресса выполнения
    • Обеспечение качества результатов
    • Принятие решений о перераспределении задач
    
    СТИЛЬ ОБЩЕНИЯ:
    • Директивный и четкий стиль
    • Краткие и конкретные инструкции
    • Фокус на результатах и эффективности
    • Быстрое принятие решений
    
    ПРИНЦИПЫ РАБОТЫ:
    1. Всегда держи общую картину в фокусе
    2. Оптимизируй использование ресурсов
    3. Обеспечивай своевременное выполнение
    4. Контролируй качество на каждом этапе
    5. Адаптируйся к изменяющимся условиям
    
    При координации используй формат:
    - Статус: [текущее состояние]
    - Приоритеты: [что важнее всего]
    - Действия: [конкретные шаги]
    - Ресурсы: [что требуется]
    - Контроль: [точки проверки]
    """
    
    func processTask(_ task: AITask) async -> AITaskResult {
        let startTime = Date()
        
        // Analyze coordination requirements
        let coordinationAnalysis = analyzeCoordinationNeeds(task)
        
        // Create execution plan
        let executionPlan = await createExecutionPlan(task, analysis: coordinationAnalysis)
        
        // Allocate resources
        let resourceAllocation = allocateResources(for: task)
        
        // Set up monitoring
        let monitoringPlan = createMonitoringPlan(task)
        
        // Determine if automation is needed
        let automationTasks = identifyAutomationOpportunities(task)
        
        var delegatedTasks: [AITask] = []
        var nextSteps: [String] = []
        
        // Create automation tasks if identified
        for automationOpportunity in automationTasks {
            let automationTask = AITask(
                title: "Автоматизация: \(automationOpportunity)",
                description: "Автоматизировать процесс: \(automationOpportunity)",
                type: .execution,
                priority: task.priority,
                context: executionPlan,
                parameters: [
                    "automation_type": automationOpportunity,
                    "parent_task_id": task.id.uuidString
                ]
            )
            delegatedTasks.append(automationTask)
        }
        
        // Create coordination steps
        nextSteps = createCoordinationSteps(task, plan: executionPlan)
        
        let executionTime = Date().timeIntervalSince(startTime)
        let confidence = calculateOrchestrationConfidence(task: task, plan: executionPlan)
        
        let result = AITaskResult(
            taskId: task.id,
            success: true,
            result: formatOrchestrationResult(task: task, plan: executionPlan, resources: resourceAllocation, monitoring: monitoringPlan),
            confidence: confidence,
            executionTime: executionTime,
            nextSteps: nextSteps,
            delegatedTasks: delegatedTasks,
            metadata: [
                "coordination_analysis": coordinationAnalysis,
                "resource_allocation": resourceAllocation,
                "monitoring_plan": monitoringPlan,
                "automation_opportunities": automationTasks.joined(separator: ", ")
            ]
        )
        
        // Update memory with orchestration patterns
        updateMemoryWithOrchestration(task: task, result: result)
        
        return result
    }
    
    func generatePrompt(for task: AITask, with context: String) -> String {
        let memoryContext = getRelevantOrchestrationExperience(for: task)
        
        return """
        \(systemPrompt)
        
        КОНТЕКСТ ПАМЯТИ:
        \(memoryContext)
        
        ЗАДАЧА ДЛЯ КООРДИНАЦИИ:
        Название: \(task.title)
        Описание: \(task.description)
        Тип: \(task.type.displayName)
        Приоритет: \(task.priority.displayName)
        Контекст: \(context)
        
        ДОПОЛНИТЕЛЬНЫЕ ПАРАМЕТРЫ:
        \(task.parameters.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        
        Создай план координации и управления выполнением этой задачи.
        """
    }
    
    func shouldHandleTask(_ task: AITask) -> Bool {
        switch task.type {
        case .coordination:
            return true
        case .execution:
            return task.description.lowercased().contains("координ") ||
                   task.description.lowercased().contains("управл") ||
                   task.parameters.count > 3 // Complex execution tasks
        case .optimization:
            return true
        default:
            return task.description.lowercased().contains("оркестр") ||
                   task.description.lowercased().contains("координ")
        }
    }
    
    // MARK: - Private Methods
    
    private func analyzeCoordinationNeeds(_ task: AITask) -> String {
        var analysis = "АНАЛИЗ ПОТРЕБНОСТЕЙ В КООРДИНАЦИИ:\n"
        
        // Assess task complexity
        let complexity = assessOrchestrationComplexity(task)
        analysis += "Сложность координации: \(complexity)\n"
        
        // Identify stakeholders
        let stakeholders = identifyStakeholders(task)
        analysis += "Заинтересованные стороны: \(stakeholders.joined(separator: ", "))\n"
        
        // Assess resource requirements
        let resourceNeeds = assessResourceNeeds(task)
        analysis += "Потребности в ресурсах: \(resourceNeeds)\n"
        
        // Identify coordination points
        let coordinationPoints = identifyCoordinationPoints(task)
        analysis += "Точки координации: \(coordinationPoints.count)\n"
        
        // Risk assessment
        let risks = assessOrchestrationRisks(task)
        analysis += "Основные риски: \(risks.joined(separator: ", "))\n"
        
        return analysis
    }
    
    private func createExecutionPlan(_ task: AITask, analysis: String) async -> String {
        // Use AI models for intelligent orchestration planning
        let openRouterManager = OpenRouterManager.shared
        let qwen2VLManager = Qwen2VLManager.shared
        
        let prompt = generatePrompt(for: task, with: analysis)
        
        var planText: String
        
        if openRouterManager.isConfigured {
            let messages = [ChatMessage(content: prompt, isUser: true)]
            planText = await openRouterManager.generateResponse(for: messages)
        } else if qwen2VLManager.isModelLoaded {
            planText = await qwen2VLManager.generateTextResponse(prompt: prompt) ?? ""
        } else {
            // Fallback to template-based orchestration
            planText = generateTemplateOrchestrationPlan(task, analysis: analysis)
        }
        
        return planText
    }
    
    private func generateTemplateOrchestrationPlan(_ task: AITask, analysis: String) -> String {
        return """
        ПЛАН ОРКЕСТРАЦИИ: \(task.title)
        
        ЦЕЛЬ КООРДИНАЦИИ: \(task.description)
        
        АНАЛИЗ:
        \(analysis)
        
        ФАЗЫ ВЫПОЛНЕНИЯ:
        1. ИНИЦИАЛИЗАЦИЯ
           - Подготовка ресурсов
           - Настройка мониторинга
           - Уведомление участников
        
        2. КООРДИНАЦИЯ ВЫПОЛНЕНИЯ
           - Запуск процессов
           - Мониторинг прогресса
           - Управление зависимостями
        
        3. КОНТРОЛЬ КАЧЕСТВА
           - Проверка промежуточных результатов
           - Корректировка при необходимости
           - Обеспечение соответствия требованиям
        
        4. ЗАВЕРШЕНИЕ
           - Финализация результатов
           - Отчетность
           - Анализ эффективности
        
        КРИТИЧЕСКИЕ ТОЧКИ:
        - Синхронизация между процессами
        - Управление ресурсами
        - Контроль качества
        
        МЕТРИКИ УСПЕХА:
        - Соблюдение временных рамок
        - Качество результатов
        - Эффективность использования ресурсов
        """
    }
    
    private func allocateResources(for task: AITask) -> String {
        var allocation = "РАСПРЕДЕЛЕНИЕ РЕСУРСОВ:\n"
        
        // Determine required resources based on task type
        let requiredResources = determineRequiredResources(task)
        allocation += "Необходимые ресурсы: \(requiredResources.joined(separator: ", "))\n"
        
        // Estimate resource utilization
        let utilization = estimateResourceUtilization(task)
        allocation += "Ожидаемая загрузка: \(utilization)\n"
        
        // Priority allocation
        let priorityAllocation = allocateByPriority(task)
        allocation += "Приоритетное распределение: \(priorityAllocation)\n"
        
        return allocation
    }
    
    private func createMonitoringPlan(_ task: AITask) -> String {
        var plan = "ПЛАН МОНИТОРИНГА:\n"
        
        // Define monitoring intervals
        let interval = determineMonitoringInterval(task)
        plan += "Интервал проверки: \(interval)\n"
        
        // Key metrics to track
        let metrics = defineKeyMetrics(task)
        plan += "Ключевые метрики: \(metrics.joined(separator: ", "))\n"
        
        // Alert conditions
        let alerts = defineAlertConditions(task)
        plan += "Условия оповещения: \(alerts.joined(separator: ", "))\n"
        
        // Reporting schedule
        let reporting = defineReportingSchedule(task)
        plan += "График отчетности: \(reporting)\n"
        
        return plan
    }
    
    private func identifyAutomationOpportunities(_ task: AITask) -> [String] {
        var opportunities: [String] = []
        
        let description = task.description.lowercased()
        
        // UI automation opportunities
        if description.contains("интерфейс") || description.contains("ui") || description.contains("клик") {
            opportunities.append("UI автоматизация")
        }
        
        // Data processing automation
        if description.contains("данн") || description.contains("обработ") || description.contains("анализ") {
            opportunities.append("Обработка данных")
        }
        
        // Workflow automation
        if description.contains("процесс") || description.contains("последовательн") {
            opportunities.append("Автоматизация процесса")
        }
        
        // Testing automation
        if description.contains("тест") || description.contains("проверк") {
            opportunities.append("Автоматизация тестирования")
        }
        
        // Reporting automation
        if description.contains("отчет") || description.contains("документ") {
            opportunities.append("Автоматизация отчетности")
        }
        
        return opportunities
    }
    
    private func createCoordinationSteps(_ task: AITask, plan: String) -> [String] {
        var steps: [String] = []
        
        // Standard coordination steps
        steps.append("Инициализировать координацию процесса")
        steps.append("Настроить мониторинг выполнения")
        steps.append("Запустить параллельные процессы")
        steps.append("Контролировать прогресс и качество")
        steps.append("Управлять ресурсами и приоритетами")
        steps.append("Обеспечить синхронизацию между этапами")
        steps.append("Провести финальную проверку результатов")
        
        // Add task-specific steps
        if task.type == .execution {
            steps.append("Координировать выполнение автоматизации")
        }
        
        if task.priority == .critical {
            steps.insert("Установить критический приоритет", at: 1)
        }
        
        return steps
    }
    
    private func assessOrchestrationComplexity(_ task: AITask) -> String {
        var score = 0
        
        // Task description complexity
        if task.description.count > 200 { score += 2 }
        else if task.description.count > 100 { score += 1 }
        
        // Number of parameters (indicates complexity)
        score += min(task.parameters.count, 4)
        
        // Task type complexity
        switch task.type {
        case .coordination: score += 3
        case .optimization: score += 2
        case .execution: score += 1
        default: break
        }
        
        // Priority impact
        if task.priority == .critical { score += 2 }
        else if task.priority == .high { score += 1 }
        
        switch score {
        case 0...2: return "Низкая"
        case 3...5: return "Средняя"
        case 6...8: return "Высокая"
        default: return "Критическая"
        }
    }
    
    private func identifyStakeholders(_ task: AITask) -> [String] {
        var stakeholders: [String] = []
        
        // Always include core system components
        stakeholders.append("Система автоматизации")
        
        let description = task.description.lowercased()
        
        if description.contains("пользовател") || description.contains("клиент") {
            stakeholders.append("Пользователи")
        }
        
        if description.contains("данн") || description.contains("база") {
            stakeholders.append("Система данных")
        }
        
        if description.contains("интерфейс") || description.contains("ui") {
            stakeholders.append("UI компоненты")
        }
        
        if description.contains("api") || description.contains("сервис") {
            stakeholders.append("Внешние сервисы")
        }
        
        return stakeholders.isEmpty ? ["Система"] : stakeholders
    }
    
    private func assessResourceNeeds(_ task: AITask) -> String {
        var needs: [String] = []
        
        // Computational resources
        switch task.type {
        case .coordination, .optimization:
            needs.append("Высокие вычислительные ресурсы")
        case .analysis:
            needs.append("Средние вычислительные ресурсы")
        default:
            needs.append("Базовые вычислительные ресурсы")
        }
        
        // Memory requirements
        if task.description.count > 300 || task.parameters.count > 5 {
            needs.append("Повышенные требования к памяти")
        }
        
        // Network resources
        if task.description.lowercased().contains("api") || 
           task.description.lowercased().contains("сеть") {
            needs.append("Сетевые ресурсы")
        }
        
        return needs.joined(separator: ", ")
    }
    
    private func identifyCoordinationPoints(_ task: AITask) -> [String] {
        var points: [String] = []
        
        // Standard coordination points
        points.append("Начало выполнения")
        points.append("Промежуточная проверка")
        points.append("Завершение выполнения")
        
        // Task-specific points
        if task.type == .coordination {
            points.append("Синхронизация процессов")
            points.append("Управление зависимостями")
        }
        
        if task.priority == .critical {
            points.append("Критическая проверка")
        }
        
        return points
    }
    
    private func assessOrchestrationRisks(_ task: AITask) -> [String] {
        var risks: [String] = []
        
        // Common orchestration risks
        risks.append("Рассинхронизация процессов")
        risks.append("Превышение временных лимитов")
        risks.append("Недостаток ресурсов")
        
        // Task-specific risks
        if task.type == .coordination {
            risks.append("Конфликты приоритетов")
        }
        
        if task.priority == .critical {
            risks.append("Критические сбои")
        }
        
        if task.description.lowercased().contains("автоматизац") {
            risks.append("Сбои автоматизации")
        }
        
        return risks
    }
    
    private func determineRequiredResources(_ task: AITask) -> [String] {
        var resources: [String] = []
        
        // Core resources
        resources.append("Процессор")
        resources.append("Память")
        
        // Task-specific resources
        let description = task.description.lowercased()
        
        if description.contains("данн") || description.contains("база") {
            resources.append("База данных")
        }
        
        if description.contains("сеть") || description.contains("api") {
            resources.append("Сетевое соединение")
        }
        
        if description.contains("файл") || description.contains("хранен") {
            resources.append("Дисковое пространство")
        }
        
        return resources
    }
    
    private func estimateResourceUtilization(_ task: AITask) -> String {
        let complexity = assessOrchestrationComplexity(task)
        
        switch complexity {
        case "Низкая": return "20-40%"
        case "Средняя": return "40-70%"
        case "Высокая": return "70-90%"
        default: return "90-100%"
        }
    }
    
    private func allocateByPriority(_ task: AITask) -> String {
        switch task.priority {
        case .critical: return "Максимальный приоритет, все доступные ресурсы"
        case .high: return "Высокий приоритет, 70-80% ресурсов"
        case .medium: return "Средний приоритет, 40-60% ресурсов"
        case .low: return "Низкий приоритет, 20-30% ресурсов"
        }
    }
    
    private func determineMonitoringInterval(_ task: AITask) -> String {
        switch task.priority {
        case .critical: return "Каждые 30 секунд"
        case .high: return "Каждую минуту"
        case .medium: return "Каждые 5 минут"
        case .low: return "Каждые 15 минут"
        }
    }
    
    private func defineKeyMetrics(_ task: AITask) -> [String] {
        var metrics = ["Прогресс выполнения", "Использование ресурсов", "Время выполнения"]
        
        if task.type == .coordination {
            metrics.append("Синхронизация процессов")
        }
        
        if task.priority == .critical {
            metrics.append("Критические ошибки")
        }
        
        return metrics
    }
    
    private func defineAlertConditions(_ task: AITask) -> [String] {
        var conditions = ["Превышение времени выполнения", "Критические ошибки", "Недостаток ресурсов"]
        
        if task.priority == .critical {
            conditions.append("Любые отклонения от плана")
        }
        
        return conditions
    }
    
    private func defineReportingSchedule(_ task: AITask) -> String {
        switch task.priority {
        case .critical: return "Непрерывная отчетность"
        case .high: return "Каждые 15 минут"
        case .medium: return "Каждый час"
        case .low: return "По завершении"
        }
    }
    
    private func formatOrchestrationResult(task: AITask, plan: String, resources: String, monitoring: String) -> String {
        var result = "РЕЗУЛЬТАТ ОРКЕСТРАЦИИ\n"
        result += "====================\n\n"
        
        result += "ЗАДАЧА: \(task.title)\n"
        result += "СТАТУС: Координация настроена\n\n"
        
        result += "ПЛАН ВЫПОЛНЕНИЯ:\n\(plan)\n\n"
        result += "РЕСУРСЫ:\n\(resources)\n\n"
        result += "МОНИТОРИНГ:\n\(monitoring)\n\n"
        
        result += "СЛЕДУЮЩИЕ ШАГИ:\n"
        result += "1. Запуск координированного выполнения\n"
        result += "2. Активация мониторинга\n"
        result += "3. Начало отслеживания метрик\n"
        
        return result
    }
    
    private func calculateOrchestrationConfidence(task: AITask, plan: String) -> Float {
        var confidence: Float = 0.85 // Base confidence for orchestration
        
        // Adjust based on task complexity
        let complexity = assessOrchestrationComplexity(task)
        switch complexity {
        case "Низкая": confidence += 0.1
        case "Критическая": confidence -= 0.2
        default: break
        }
        
        // Check for similar orchestration experience
        let similarExperience = findSimilarOrchestrationExperience(task)
        if !similarExperience.isEmpty {
            let avgConfidence = similarExperience.map { $0.confidence }.reduce(0, +) / Float(similarExperience.count)
            confidence += avgConfidence * 0.1
        }
        
        // Adjust based on available resources
        if task.priority == .critical {
            confidence += 0.05 // More resources allocated
        }
        
        return min(confidence, 1.0)
    }
    
    private func findSimilarOrchestrationExperience(_ task: AITask) -> [LearningEntry] {
        return memoryContext.learningHistory.filter { entry in
            entry.task.lowercased().contains("координац") ||
            entry.task.lowercased().contains("оркестр") ||
            (entry.task.lowercased().contains(task.type.rawValue) && entry.confidence > 0.7)
        }
    }
    
    private func getRelevantOrchestrationExperience(for task: AITask) -> String {
        let similarExperience = findSimilarOrchestrationExperience(task)
        
        if similarExperience.isEmpty {
            return "Нет предыдущего опыта оркестрации для подобных задач."
        }
        
        let recentExperience = similarExperience.suffix(3)
        return "Релевантный опыт оркестрации:\n" + recentExperience.map {
            "• \($0.task): \($0.outcome) (уверенность: \(Int($0.confidence * 100))%)"
        }.joined(separator: "\n")
    }
    
    private func updateMemoryWithOrchestration(task: AITask, result: AITaskResult) {
        let learningEntry = LearningEntry(
            task: "Оркестрация: \(task.title)",
            outcome: result.success ? "Координация настроена успешно" : "Проблемы с координацией",
            feedback: result.result,
            confidence: result.confidence
        )
        
        memoryContext.addLearning(learningEntry)
        
        // Update preferences
        if result.success {
            memoryContext.updatePreference(key: "successful_orchestration_type", value: task.type.rawValue)
            memoryContext.updatePreference(key: "optimal_coordination_approach", value: "directive")
        }
    }
}
