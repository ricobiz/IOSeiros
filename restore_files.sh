#!/bin/bash

# Список отсутствующих файлов для восстановления
missing_files=(
    "EirosAgent/Managers/Qwen2VLManager.swift"
    "EirosAgent/Managers/AIRoleManager.swift"
    "EirosAgent/Controllers/AutomationController.swift"
    "EirosAgent/Roles/DecomposerRole.swift"
    "EirosAgent/Roles/OrchestratorRole.swift"
    "EirosAgent/Roles/PlannerRole.swift"
    "EirosAgent/Roles/ExecutorRole.swift"
    "EirosAgent/Roles/AnalyzerRole.swift"
    "EirosAgent/Roles/BaseRole.swift"
    "EirosAgent/Views/AIRoleMonitorView.swift"
    "EirosAgent/Views/AutomationPanelView.swift"
    "EirosAgent/Views/RoleSystemView.swift"
    "EirosAgent/Views/TaskExecutionView.swift"
    "EirosAgent/Utils/CoordinateUtils.swift"
    "EirosAgent/Utils/TouchGridUtils.swift"
    "EirosAgent/Utils/ScreenAnalysisUtils.swift"
    "EirosAgent/Models/RoleModels.swift"
    "EirosAgent/Models/TaskModels.swift"
    "EirosAgent/Models/CoordinateModels.swift"
    "EirosAgent/Services/RoleCoordinator.swift"
    "EirosAgent/Services/TaskQueue.swift"
    "EirosAgent/Services/ScreenAnalyzer.swift"
    "EirosAgent/Extensions/UIImage+Analysis.swift"
    "EirosAgent/Extensions/CGPoint+Grid.swift"
    "EirosAgent/Protocols/RoleProtocol.swift"
    "EirosAgent/Protocols/TaskProtocol.swift"
    "EirosAgent/Config/RoleConfig.swift"
    "EirosAgent/Config/AutomationConfig.swift"
    "EirosAgent/Resources/role_prompts.json"
    "EirosAgent/Resources/automation_templates.json"
    "EirosAgent/Tests/RoleSystemTests.swift"
)

# Ветки для поиска файлов
branches=("main" "feature/qwen2vl_integration" "feature/ui-automation-integration" "roles-system")

restored_count=0
recovery_log="/tmp/recovery_log.txt"
echo "=== File Recovery Log ===" > "$recovery_log"
echo "Recovery started at: $(date)" >> "$recovery_log"
echo "" >> "$recovery_log"

for file in "${missing_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Searching for: $file"
        found=false
        
        for branch in "${branches[@]}"; do
            if git cat-file -e "origin/$branch:$file" 2>/dev/null; then
                echo "  Found in branch: $branch"
                
                # Создаем директорию если не существует
                mkdir -p "$(dirname "$file")"
                
                # Восстанавливаем файл
                if git checkout "origin/$branch" -- "$file" 2>/dev/null; then
                    echo "  ✓ Restored: $file from $branch"
                    echo "RESTORED: $file <- origin/$branch" >> "$recovery_log"
                    ((restored_count++))
                    found=true
                    break
                else
                    echo "  ✗ Failed to restore: $file from $branch"
                    echo "FAILED: $file <- origin/$branch (checkout failed)" >> "$recovery_log"
                fi
            fi
        done
        
        if [ "$found" = false ]; then
            echo "  ✗ Not found in any branch: $file"
            echo "NOT_FOUND: $file (searched in all branches)" >> "$recovery_log"
        fi
    else
        echo "Already exists: $file"
        echo "EXISTS: $file (already present)" >> "$recovery_log"
    fi
done

echo ""
echo "Recovery completed!"
echo "Files restored: $restored_count"
echo "Recovery finished at: $(date)" >> "$recovery_log"
echo "Total files restored: $restored_count" >> "$recovery_log"

cat "$recovery_log"
