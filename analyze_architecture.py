#!/usr/bin/env python3
"""
Eiros Agent iOS App Architecture Analyzer
Анализирует структуру приложения и создает визуализации
"""

import os
import re
import json
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import networkx as nx
from collections import defaultdict, Counter
import yaml

class EirosArchitectureAnalyzer:
    def __init__(self, project_path):
        self.project_path = project_path
        self.swift_files = []
        self.python_files = []
        self.components = defaultdict(list)
        self.dependencies = defaultdict(set)
        self.issues = []
        
    def scan_files(self):
        """Сканирует все файлы проекта"""
        for root, dirs, files in os.walk(self.project_path):
            # Пропускаем .git и другие служебные папки
            dirs[:] = [d for d in dirs if not d.startswith('.') and d != '__pycache__']
            
            for file in files:
                file_path = os.path.join(root, file)
                if file.endswith('.swift'):
                    self.swift_files.append(file_path)
                elif file.endswith('.py'):
                    self.python_files.append(file_path)
    
    def analyze_swift_files(self):
        """Анализирует Swift файлы"""
        for file_path in self.swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Извлекаем классы и структуры
                classes = re.findall(r'class\s+(\w+)', content)
                structs = re.findall(r'struct\s+(\w+)', content)
                protocols = re.findall(r'protocol\s+(\w+)', content)
                
                # Извлекаем импорты
                imports = re.findall(r'import\s+(\w+)', content)
                
                # Определяем тип компонента по пути
                relative_path = os.path.relpath(file_path, self.project_path)
                if 'Views' in relative_path:
                    component_type = 'View'
                elif 'Managers' in relative_path:
                    component_type = 'Manager'
                elif 'Models' in relative_path:
                    component_type = 'Model'
                else:
                    component_type = 'Core'
                
                # Сохраняем информацию о компонентах
                for cls in classes:
                    self.components[component_type].append({
                        'name': cls,
                        'file': relative_path,
                        'type': 'class',
                        'imports': imports
                    })
                
                for struct in structs:
                    self.components[component_type].append({
                        'name': struct,
                        'file': relative_path,
                        'type': 'struct',
                        'imports': imports
                    })
                
                # Ищем потенциальные проблемы
                if 'TODO' in content or 'FIXME' in content:
                    todos = re.findall(r'//\s*(TODO|FIXME).*', content)
                    for todo in todos:
                        self.issues.append({
                            'file': relative_path,
                            'type': 'TODO/FIXME',
                            'description': todo
                        })
                
                # Проверяем на потенциальные проблемы безопасности
                if 'http://' in content:
                    self.issues.append({
                        'file': relative_path,
                        'type': 'Security',
                        'description': 'HTTP connection detected (should use HTTPS)'
                    })
                
            except Exception as e:
                self.issues.append({
                    'file': file_path,
                    'type': 'Parse Error',
                    'description': str(e)
                })
    
    def analyze_python_files(self):
        """Анализирует Python файлы"""
        for file_path in self.python_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Извлекаем классы
                classes = re.findall(r'class\s+(\w+)', content)
                functions = re.findall(r'def\s+(\w+)', content)
                
                relative_path = os.path.relpath(file_path, self.project_path)
                
                # Определяем тип компонента
                if 'control_room' in relative_path:
                    component_type = 'Control Room'
                elif 'vision' in relative_path:
                    component_type = 'Vision'
                elif 'web_automation' in relative_path:
                    component_type = 'Web Automation'
                elif 'ocr' in relative_path:
                    component_type = 'OCR'
                else:
                    component_type = 'Backend'
                
                for cls in classes:
                    self.components[component_type].append({
                        'name': cls,
                        'file': relative_path,
                        'type': 'class'
                    })
                    
            except Exception as e:
                self.issues.append({
                    'file': file_path,
                    'type': 'Parse Error',
                    'description': str(e)
                })
    
    def generate_architecture_diagram(self):
        """Создает диаграмму архитектуры"""
        plt.figure(figsize=(16, 12))
        
        # Цвета для разных типов компонентов
        colors = {
            'View': '#FF6B6B',
            'Manager': '#4ECDC4', 
            'Model': '#45B7D1',
            'Core': '#96CEB4',
            'Control Room': '#FFEAA7',
            'Vision': '#DDA0DD',
            'Web Automation': '#98D8C8',
            'OCR': '#F7DC6F',
            'Backend': '#BB8FCE'
        }
        
        # Позиции для компонентов
        positions = {
            'View': (0.2, 0.8),
            'Manager': (0.5, 0.6),
            'Model': (0.8, 0.8),
            'Core': (0.5, 0.9),
            'Control Room': (0.1, 0.4),
            'Vision': (0.3, 0.2),
            'Web Automation': (0.7, 0.2),
            'OCR': (0.9, 0.4),
            'Backend': (0.5, 0.1)
        }
        
        ax = plt.gca()
        
        # Рисуем компоненты
        for comp_type, components in self.components.items():
            if components and comp_type in positions:
                x, y = positions[comp_type]
                
                # Создаем прямоугольник для группы компонентов
                rect = FancyBboxPatch(
                    (x-0.08, y-0.06), 0.16, 0.12,
                    boxstyle="round,pad=0.01",
                    facecolor=colors.get(comp_type, '#CCCCCC'),
                    edgecolor='black',
                    alpha=0.7
                )
                ax.add_patch(rect)
                
                # Добавляем текст
                plt.text(x, y+0.02, comp_type, ha='center', va='center', 
                        fontsize=10, fontweight='bold')
                plt.text(x, y-0.02, f'({len(components)})', ha='center', va='center', 
                        fontsize=8)
        
        # Рисуем связи между компонентами
        connections = [
            ('Core', 'View'),
            ('Core', 'Manager'),
            ('Manager', 'Model'),
            ('Manager', 'Vision'),
            ('Manager', 'Web Automation'),
            ('Control Room', 'Backend'),
            ('Vision', 'OCR'),
            ('Web Automation', 'Backend')
        ]
        
        for start, end in connections:
            if start in positions and end in positions:
                x1, y1 = positions[start]
                x2, y2 = positions[end]
                plt.arrow(x1, y1, x2-x1, y2-y1, head_width=0.02, head_length=0.02,
                         fc='gray', ec='gray', alpha=0.6)
        
        plt.xlim(0, 1)
        plt.ylim(0, 1)
        plt.title('Eiros Agent - Архитектура приложения', fontsize=16, fontweight='bold')
        plt.axis('off')
        
        # Добавляем легенду
        legend_elements = [mpatches.Patch(color=color, label=comp_type) 
                          for comp_type, color in colors.items() 
                          if comp_type in self.components and self.components[comp_type]]
        plt.legend(handles=legend_elements, loc='upper right', bbox_to_anchor=(1.15, 1))
        
        plt.tight_layout()
        plt.savefig('docs/architecture_diagram.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_component_stats(self):
        """Генерирует статистику компонентов"""
        stats = {}
        for comp_type, components in self.components.items():
            stats[comp_type] = {
                'count': len(components),
                'files': list(set([comp['file'] for comp in components]))
            }
        return stats
    
    def run_analysis(self):
        """Запускает полный анализ"""
        print("🔍 Сканирование файлов...")
        self.scan_files()
        
        print(f"📱 Найдено Swift файлов: {len(self.swift_files)}")
        print(f"🐍 Найдено Python файлов: {len(self.python_files)}")
        
        print("🔍 Анализ Swift кода...")
        self.analyze_swift_files()
        
        print("🔍 Анализ Python кода...")
        self.analyze_python_files()
        
        print("📊 Создание диаграммы архитектуры...")
        os.makedirs('docs', exist_ok=True)
        self.generate_architecture_diagram()
        
        print("📈 Генерация статистики...")
        stats = self.generate_component_stats()
        
        return {
            'components': dict(self.components),
            'stats': stats,
            'issues': self.issues,
            'swift_files_count': len(self.swift_files),
            'python_files_count': len(self.python_files)
        }

if __name__ == "__main__":
    analyzer = EirosArchitectureAnalyzer('.')
    results = analyzer.run_analysis()
    
    # Сохраняем результаты
    with open('docs/analysis_results.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print("✅ Анализ завершен! Результаты сохранены в docs/")
