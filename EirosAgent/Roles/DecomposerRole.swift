
//
//  DecomposerRole.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit

class DecomposerRole: AIRoleProtocol {
    let id = "decomposer"
    let name = "Декомпозитор"
    let description = "Разбивает сложные задачи на простые, выполнимые шаги"
    let communicationStyle: CommunicationStyle = .methodical
    let specialization: RoleSpecialization = .taskDecomposition
    let capabilities: [RoleCapability] = [
        .taskBreakdown,
        .prioritization,
        .resourceAllocation,
        .qualityAssurance
    ]
    
    var memoryContext = RoleMemoryContext()
    
    let systemPrompt = """
    Ты - ИИ Декомпозитор в системе Eiros Agent. Твоя основная роль - разбивать сложные задачи на простые, выполнимые шаги.
    
    ТВОИ КЛЮЧЕВЫЕ ОБЯЗАННОСТИ:
    • Анализ сложных задач и их структуры
    • Разбиение задач на логические подзадачи
    • Определение зависимостей между шагами
    • Создание последовательности выполнения
    • Оценка сложности каждого шага
    
    СТИЛЬ ОБЩЕНИЯ:
    • Методичный и пошаговый подход
    • Четкая структуризация информации
    • Логическая последовательность действий
    • Детальное описание каждого шага
    
    ПРИНЦИПЫ РАБОТЫ:
    1. Начинай с понимания конечной цели
    2. Выделяй ключевые компоненты задачи
    3. Создавай иерархию подзадач
    4. Определяй зависимости и последовательность
    5. Делай каждый шаг максимально простым
    
    При декомпозиции используй формат:
    - Исходная задача: [описание]
    - Анализ структуры: [компоненты и связи]
    - Подзадачи: [иерархический список]
    - Зависимости: [что от чего зависит]
    - Приоритеты: [порядок выполнения]
    """
    
    func processTask(_ task: AITask) async -> AITaskResult {
        let startTime = Date()
        
        // Analyze task structure
        let structureAnalysis = analyzeTaskStructure(task)
        
        // Decompose into subtasks
        let subtasks = await decomposeTask(task, analysis: structureAnalysis)
        
        // Determine dependencies
        let dependencies = analyzeDependencies(subtasks)
        
        // Create execution sequence
        let executionSequence = createExecutionSequence(subtasks, dependencies: dependencies)
        
        // Generate orchestration tasks if needed
        var delegatedTasks: [AITask] = []
        
        if subtasks.count > 3 {
            let orchestrationTask = AITask(
                title: "Оркестрация: \(task.title)",
                description: "Координировать выполнение \(subtasks.count) подзадач для '\(task.title)'",
                type: .coordination,
                priority: task.priority,
                context: executionSequence,
                parameters: [
                    "original_task_id": task.id.uuidString,
                    "subtask_count": String(subtasks.count)
                ]
            )
            delegatedTasks.append(orchestrationTask)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        let confidence = calculateDecompositionConfidence(task: task, subtasks: subtasks)
        
        let result = AITaskResult(
            taskId: task.id,
            success: true,
            result: formatDecompositionResult(task: task, subtasks: subtasks, sequence: executionSequence),
            confidence: confidence,
            executionTime: executionTime,
            nextSteps: subtasks.map { "• \($0)" },
            delegatedTasks: delegatedTasks,
            metadata: [
                "subtask_count": String(subtasks.count),
                "dependencies": dependencies,
                "structure_analysis": structureAnalysis
            ]
        )
        
        // Update memory with decomposition patterns
        updateMemoryWithDecomposition(task: task, result: result, subtasks: subtasks)
        
        return result
    }
    
    func generatePrompt(for task: AITask, with context: String) -> String {
        let memoryContext = getRelevantDecompositionPatterns(for: task)
        
        return """
        \(systemPrompt)
        
        КОНТЕКСТ ПАМЯТИ:
        \(memoryContext)
        
        ЗАДАЧА ДЛЯ ДЕКОМПОЗИЦИИ:
        Название: \(task.title)
        Описание: \(task.description)
        Тип: \(task.type.displayName)
        Приоритет: \(task.priority.displayName)
        Контекст: \(context)
        
        ДОПОЛНИТЕЛЬНЫЕ ПАРАМЕТРЫ:
        \(task.parameters.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        
        Разбей эту задачу на простые, выполнимые шаги с учетом всех зависимостей.
        """
    }
    
    func shouldHandleTask(_ task: AITask) -> Bool {
        switch task.type {
        case .decomposition:
            return true
        case .planning:
            return task.description.lowercased().contains("разбить") ||
                   task.description.lowercased().contains("шаги") ||
                   task.description.lowercased().contains("этапы")
        case .execution:
            return task.description.count > 200 // Complex execution tasks
        default:
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func analyzeTaskStructure(_ task: AITask) -> String {
        var analysis = "АНАЛИЗ СТРУКТУРЫ ЗАДАЧИ:\n"
        
        // Identify key components
        let components = identifyTaskComponents(task)
        analysis += "Компоненты: \(components.joined(separator: ", "))\n"
        
        // Assess complexity
        let complexity = assessTaskComplexity(task)
        analysis += "Сложность: \(complexity)\n"
        
        // Identify task patterns
        let patterns = identifyTaskPatterns(task)
        analysis += "Паттерны: \(patterns.joined(separator: ", "))\n"
        
        // Estimate decomposition depth
        let depth = estimateDecompositionDepth(task)
        analysis += "Глубина декомпозиции: \(depth) уровней\n"
        
        return analysis
    }
    
    private func decomposeTask(_ task: AITask, analysis: String) async -> [String] {
        // Use AI models for intelligent decomposition
        let openRouterManager = OpenRouterManager.shared
        let qwen2VLManager = Qwen2VLManager.shared
        
        let prompt = generatePrompt(for: task, with: analysis)
        
        var decompositionText: String
        
        if openRouterManager.isConfigured {
            let messages = [ChatMessage(content: prompt, isUser: true)]
            decompositionText = await openRouterManager.generateResponse(for: messages)
        } else if qwen2VLManager.isModelLoaded {
            decompositionText = await qwen2VLManager.generateTextResponse(prompt: prompt) ?? ""
        } else {
            // Fallback to rule-based decomposition
            decompositionText = generateRuleBasedDecomposition(task, analysis: analysis)
        }
        
        // Extract subtasks from the generated text
        return extractSubtasks(from: decompositionText)
    }
    
    private func generateRuleBasedDecomposition(_ task: AITask, analysis: String) -> String {
        var subtasks: [String] = []
        
        // Standard decomposition patterns based on task type
        switch task.type {
        case .planning:
            subtasks = [
                "Анализ требований и ограничений",
                "Определение ключевых этапов",
                "Создание временной шкалы",
                "Выделение ресурсов",
                "Создание плана контроля"
            ]
        case .execution:
            subtasks = [
                "Подготовка к выполнению",
                "Выполнение основных действий",
                "Мониторинг прогресса",
                "Корректировка при необходимости",
                "Завершение и проверка результатов"
            ]
        case .analysis:
            subtasks = [
                "Сбор необходимых данных",
                "Предварительный анализ",
                "Глубокий анализ",
                "Формирование выводов",
                "Подготовка рекомендаций"
            ]
        default:
            subtasks = [
                "Понимание задачи",
                "Планирование подхода",
                "Выполнение действий",
                "Проверка результатов"
            ]
        }
        
        // Customize based on task specifics
        let customizedSubtasks = customizeSubtasks(subtasks, for: task)
        
        return "ДЕКОМПОЗИЦИЯ ЗАДАЧИ:\n" + customizedSubtasks.enumerated().map { 
            "\($0.offset + 1). \($0.element)" 
        }.joined(separator: "\n")
    }
    
    private func extractSubtasks(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var subtasks: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Match numbered items (1., 2., etc.)
            if trimmed.matches(regex: "^\\d+\\.\\s*(.+)") {
                let subtask = trimmed.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                subtasks.append(subtask)
            }
            // Match bullet points
            else if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                let subtask = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !subtask.isEmpty {
                    subtasks.append(subtask)
                }
            }
        }
        
        // If no structured format found, try to extract meaningful sentences
        if subtasks.isEmpty {
            let sentences = text.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .filter { $0.count > 10 && $0.count < 200 }
            
            subtasks = Array(sentences.prefix(8)) // Limit to reasonable number
        }
        
        return subtasks.isEmpty ? ["Выполнить задачу: \(text.prefix(100))"] : subtasks
    }
    
    private func analyzeDependencies(_ subtasks: [String]) -> String {
        var dependencies: [String] = []
        
        // Simple dependency analysis based on keywords
        for (index, subtask) in subtasks.enumerated() {
            let lowerSubtask = subtask.lowercased()
            
            if lowerSubtask.contains("после") || lowerSubtask.contains("затем") {
                if index > 0 {
                    dependencies.append("Шаг \(index + 1) зависит от шага \(index)")
                }
            }
            
            if lowerSubtask.contains("подготов") || lowerSubtask.contains("настрой") {
                dependencies.append("Шаг \(index + 1) - подготовительный")
            }
            
            if lowerSubtask.contains("завершен") || lowerSubtask.contains("финал") {
                dependencies.append("Шаг \(index + 1) - завершающий")
            }
        }
        
        if dependencies.isEmpty {
            dependencies.append("Последовательное выполнение шагов")
        }
        
        return dependencies.joined(separator: "\n")
    }
    
    private func createExecutionSequence(_ subtasks: [String], dependencies: String) -> String {
        var sequence = "ПОСЛЕДОВАТЕЛЬНОСТЬ ВЫПОЛНЕНИЯ:\n\n"
        
        // Group subtasks by phases
        let phases = groupSubtasksByPhases(subtasks)
        
        for (phaseIndex, phase) in phases.enumerated() {
            sequence += "ФАЗА \(phaseIndex + 1):\n"
            for (stepIndex, step) in phase.enumerated() {
                sequence += "  \(stepIndex + 1). \(step)\n"
            }
            sequence += "\n"
        }
        
        sequence += "ЗАВИСИМОСТИ:\n\(dependencies)\n\n"
        
        sequence += "РЕКОМЕНДАЦИИ ПО ВЫПОЛНЕНИЮ:\n"
        sequence += "• Выполняйте шаги последовательно\n"
        sequence += "• Проверяйте результат каждого шага\n"
        sequence += "• При возникновении проблем обращайтесь к Оркестратору\n"
        
        return sequence
    }
    
    private func groupSubtasksByPhases(_ subtasks: [String]) -> [[String]] {
        var phases: [[String]] = []
        var currentPhase: [String] = []
        
        for subtask in subtasks {
            let lowerSubtask = subtask.lowercased()
            
            // Start new phase for preparation, execution, completion keywords
            if (lowerSubtask.contains("подготов") || lowerSubtask.contains("настрой")) && !currentPhase.isEmpty {
                phases.append(currentPhase)
                currentPhase = [subtask]
            } else if (lowerSubtask.contains("выполн") || lowerSubtask.contains("реализ")) && !currentPhase.isEmpty && !currentPhase.last!.lowercased().contains("выполн") {
                phases.append(currentPhase)
                currentPhase = [subtask]
            } else if (lowerSubtask.contains("завершен") || lowerSubtask.contains("проверк")) && !currentPhase.isEmpty {
                phases.append(currentPhase)
                currentPhase = [subtask]
            } else {
                currentPhase.append(subtask)
            }
        }
        
        if !currentPhase.isEmpty {
            phases.append(currentPhase)
        }
        
        // If no clear phases, group by thirds
        if phases.count == 1 && subtasks.count > 6 {
            let third = subtasks.count / 3
            phases = [
                Array(subtasks[0..<third]),
                Array(subtasks[third..<(third * 2)]),
                Array(subtasks[(third * 2)...])
            ]
        }
        
        return phases.isEmpty ? [subtasks] : phases
    }
    
    private func identifyTaskComponents(_ task: AITask) -> [String] {
        var components: [String] = []
        
        let description = task.description.lowercased()
        
        // Common task components
        if description.contains("данн") || description.contains("информац") {
            components.append("Данные")
        }
        if description.contains("интерфейс") || description.contains("ui") {
            components.append("Интерфейс")
        }
        if description.contains("логик") || description.contains("алгоритм") {
            components.append("Логика")
        }
        if description.contains("тест") || description.contains("проверк") {
            components.append("Тестирование")
        }
        if description.contains("документ") || description.contains("отчет") {
            components.append("Документация")
        }
        
        return components.isEmpty ? ["Основная функциональность"] : components
    }
    
    private func identifyTaskPatterns(_ task: AITask) -> [String] {
        var patterns: [String] = []
        
        let description = task.description.lowercased()
        
        if description.contains("создать") || description.contains("разработать") {
            patterns.append("Создание")
        }
        if description.contains("анализ") || description.contains("исследов") {
            patterns.append("Анализ")
        }
        if description.contains("оптимиз") || description.contains("улучш") {
            patterns.append("Оптимизация")
        }
        if description.contains("интеграц") || description.contains("подключ") {
            patterns.append("Интеграция")
        }
        
        return patterns.isEmpty ? ["Стандартная задача"] : patterns
    }
    
    private func assessTaskComplexity(_ task: AITask) -> String {
        var score = 0
        
        // Description length
        if task.description.count > 100 { score += 1 }
        if task.description.count > 300 { score += 2 }
        
        // Number of parameters
        score += min(task.parameters.count, 3)
        
        // Task type complexity
        switch task.type {
        case .coordination, .optimization: score += 3
        case .planning, .analysis: score += 2
        case .execution: score += 1
        default: break
        }
        
        // Context complexity
        if !task.context.isEmpty {
            score += task.context.count > 200 ? 2 : 1
        }
        
        switch score {
        case 0...2: return "Простая"
        case 3...5: return "Средняя"
        case 6...8: return "Сложная"
        default: return "Очень сложная"
        }
    }
    
    private func estimateDecompositionDepth(_ task: AITask) -> Int {
        let complexity = assessTaskComplexity(task)
        
        switch complexity {
        case "Простая": return 1
        case "Средняя": return 2
        case "Сложная": return 3
        default: return 4
        }
    }
    
    private func customizeSubtasks(_ subtasks: [String], for task: AITask) -> [String] {
        return subtasks.map { subtask in
            // Replace generic terms with task-specific ones
            var customized = subtask
            
            if !task.title.isEmpty {
                customized = customized.replacingOccurrences(of: "задачи", with: "'\(task.title)'")
            }
            
            // Add context-specific details
            if !task.context.isEmpty && task.context.count < 50 {
                customized += " (с учетом: \(task.context))"
            }
            
            return customized
        }
    }
    
    private func formatDecompositionResult(task: AITask, subtasks: [String], sequence: String) -> String {
        var result = "РЕЗУЛЬТАТ ДЕКОМПОЗИЦИИ\n"
        result += "========================\n\n"
        
        result += "ИСХОДНАЯ ЗАДАЧА: \(task.title)\n"
        result += "ОПИСАНИЕ: \(task.description)\n\n"
        
        result += "ПОДЗАДАЧИ (\(subtasks.count)):\n"
        for (index, subtask) in subtasks.enumerated() {
            result += "\(index + 1). \(subtask)\n"
        }
        result += "\n"
        
        result += sequence
        
        return result
    }
    
    private func calculateDecompositionConfidence(task: AITask, subtasks: [String]) -> Float {
        var confidence: Float = 0.8 // Base confidence
        
        // Adjust based on number of subtasks (sweet spot is 3-7)
        let subtaskCount = subtasks.count
        if subtaskCount >= 3 && subtaskCount <= 7 {
            confidence += 0.1
        } else if subtaskCount > 10 {
            confidence -= 0.1
        }
        
        // Check for similar past decompositions
        let similarDecompositions = findSimilarDecompositions(task)
        if !similarDecompositions.isEmpty {
            let avgConfidence = similarDecompositions.map { $0.confidence }.reduce(0, +) / Float(similarDecompositions.count)
            confidence += avgConfidence * 0.1
        }
        
        // Adjust based on task complexity
        let complexity = assessTaskComplexity(task)
        switch complexity {
        case "Простая": confidence += 0.1
        case "Очень сложная": confidence -= 0.2
        default: break
        }
        
        return min(confidence, 1.0)
    }
    
    private func findSimilarDecompositions(_ task: AITask) -> [LearningEntry] {
        return memoryContext.learningHistory.filter { entry in
            entry.task.lowercased().contains("декомпозиция") &&
            (entry.task.lowercased().contains(task.title.lowercased()) ||
             task.title.lowercased().contains(entry.task.lowercased()))
        }
    }
    
    private func getRelevantDecompositionPatterns(for task: AITask) -> String {
        let similarDecompositions = findSimilarDecompositions(task)
        
        if similarDecompositions.isEmpty {
            return "Нет предыдущего опыта декомпозиции для подобных задач."
        }
        
        let recentDecompositions = similarDecompositions.suffix(3)
        return "Релевантный опыт декомпозиции:\n" + recentDecompositions.map {
            "• \($0.task): \($0.outcome) (уверенность: \(Int($0.confidence * 100))%)"
        }.joined(separator: "\n")
    }
    
    private func updateMemoryWithDecomposition(task: AITask, result: AITaskResult, subtasks: [String]) {
        let learningEntry = LearningEntry(
            task: "Декомпозиция: \(task.title)",
            outcome: "Разбито на \(subtasks.count) подзадач",
            feedback: result.success ? "Успешная декомпозиция" : "Проблемы с декомпозицией",
            confidence: result.confidence
        )
        
        memoryContext.addLearning(learningEntry)
        
        // Update preferences
        if result.success {
            memoryContext.updatePreference(key: "optimal_subtask_count", value: subtasks.count)
            memoryContext.updatePreference(key: "successful_decomposition_pattern", value: task.type.rawValue)
        }
    }
}
