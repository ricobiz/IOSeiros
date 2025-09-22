#!/usr/bin/env python3
"""
Code Analysis для Eiros Agent
Анализирует код на ошибки, проблемы безопасности и качество
"""

import os
import re
import json
from collections import defaultdict, Counter

class EirosCodeAnalyzer:
    def __init__(self, project_path):
        self.project_path = project_path
        self.issues = []
        self.metrics = defaultdict(int)
        self.file_analysis = {}
        
    def analyze_swift_file(self, file_path):
        """Анализирует Swift файл"""
        issues = []
        metrics = {
            'lines_of_code': 0,
            'functions': 0,
            'classes': 0,
            'complexity': 0,
            'comments': 0
        }
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
                
            metrics['lines_of_code'] = len([line for line in lines if line.strip()])
            
            # Подсчет функций и классов
            metrics['functions'] = len(re.findall(r'func\s+\w+', content))
            metrics['classes'] = len(re.findall(r'class\s+\w+', content))
            metrics['comments'] = len(re.findall(r'//.*|/\*.*?\*/', content, re.DOTALL))
            
            # Анализ сложности (упрощенный)
            complexity_keywords = ['if', 'else', 'for', 'while', 'switch', 'case', 'guard']
            for keyword in complexity_keywords:
                metrics['complexity'] += len(re.findall(rf'\b{keyword}\b', content))
            
            # Поиск потенциальных проблем
            
            # 1. Отсутствие обработки ошибок
            if 'try!' in content:
                issues.append({
                    'type': 'Error Handling',
                    'severity': 'High',
                    'message': 'Использование try! может привести к крашу приложения',
                    'line': self.find_line_number(content, 'try!')
                })
            
            # 2. Принудительное извлечение опционалов
            force_unwraps = re.findall(r'\w+!(?!\s*=)', content)
            if force_unwraps:
                issues.append({
                    'type': 'Force Unwrapping',
                    'severity': 'Medium',
                    'message': f'Найдено {len(force_unwraps)} принудительных извлечений опционалов',
                    'details': force_unwraps[:5]  # Показываем первые 5
                })
            
            # 3. Длинные функции
            functions = re.findall(r'func\s+\w+.*?\{(.*?)\n\}', content, re.DOTALL)
            for func in functions:
                func_lines = len(func.split('\n'))
                if func_lines > 50:
                    issues.append({
                        'type': 'Code Quality',
                        'severity': 'Low',
                        'message': f'Функция содержит {func_lines} строк (рекомендуется < 50)'
                    })
            
            # 4. Отсутствие документации
            public_funcs = re.findall(r'public\s+func\s+\w+', content)
            documented_funcs = re.findall(r'///.*\n\s*public\s+func', content)
            if len(public_funcs) > len(documented_funcs):
                issues.append({
                    'type': 'Documentation',
                    'severity': 'Low',
                    'message': f'{len(public_funcs) - len(documented_funcs)} публичных функций без документации'
                })
            
            # 5. Проблемы безопасности
            if 'http://' in content:
                issues.append({
                    'type': 'Security',
                    'severity': 'High',
                    'message': 'Обнаружены HTTP соединения (следует использовать HTTPS)'
                })
            
            if re.search(r'password.*=.*".*"', content, re.IGNORECASE):
                issues.append({
                    'type': 'Security',
                    'severity': 'Critical',
                    'message': 'Возможно хранение пароля в открытом виде'
                })
            
            # 6. Неиспользуемые импорты
            imports = re.findall(r'import\s+(\w+)', content)
            for imp in imports:
                if imp not in ['Foundation', 'UIKit', 'SwiftUI'] and content.count(imp) == 1:
                    issues.append({
                        'type': 'Code Quality',
                        'severity': 'Low',
                        'message': f'Возможно неиспользуемый импорт: {imp}'
                    })
            
            # 7. TODO и FIXME
            todos = re.findall(r'//\s*(TODO|FIXME|XXX|HACK).*', content)
            for todo in todos:
                issues.append({
                    'type': 'TODO/FIXME',
                    'severity': 'Low',
                    'message': todo.strip()
                })
            
        except Exception as e:
            issues.append({
                'type': 'Parse Error',
                'severity': 'High',
                'message': f'Ошибка анализа файла: {str(e)}'
            })
        
        return issues, metrics
    
    def analyze_python_file(self, file_path):
        """Анализирует Python файл"""
        issues = []
        metrics = {
            'lines_of_code': 0,
            'functions': 0,
            'classes': 0,
            'complexity': 0,
            'comments': 0
        }
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
            
            metrics['lines_of_code'] = len([line for line in lines if line.strip()])
            metrics['functions'] = len(re.findall(r'def\s+\w+', content))
            metrics['classes'] = len(re.findall(r'class\s+\w+', content))
            metrics['comments'] = len(re.findall(r'#.*', content))
            
            # Анализ сложности
            complexity_keywords = ['if', 'elif', 'else', 'for', 'while', 'try', 'except', 'with']
            for keyword in complexity_keywords:
                metrics['complexity'] += len(re.findall(rf'\b{keyword}\b', content))
            
            # Поиск проблем
            
            # 1. Отсутствие обработки исключений
            if 'except:' in content:
                issues.append({
                    'type': 'Error Handling',
                    'severity': 'Medium',
                    'message': 'Использование голого except может скрывать ошибки'
                })
            
            # 2. Длинные строки
            for i, line in enumerate(lines, 1):
                if len(line) > 120:
                    issues.append({
                        'type': 'Code Style',
                        'severity': 'Low',
                        'message': f'Строка {i} превышает 120 символов ({len(line)} символов)'
                    })
            
            # 3. Неиспользуемые импорты
            imports = re.findall(r'import\s+(\w+)', content)
            for imp in imports:
                if content.count(imp) == 1:
                    issues.append({
                        'type': 'Code Quality',
                        'severity': 'Low',
                        'message': f'Возможно неиспользуемый импорт: {imp}'
                    })
            
            # 4. Проблемы безопасности
            if 'eval(' in content:
                issues.append({
                    'type': 'Security',
                    'severity': 'High',
                    'message': 'Использование eval() может быть небезопасным'
                })
            
            if 'exec(' in content:
                issues.append({
                    'type': 'Security',
                    'severity': 'High',
                    'message': 'Использование exec() может быть небезопасным'
                })
            
        except Exception as e:
            issues.append({
                'type': 'Parse Error',
                'severity': 'High',
                'message': f'Ошибка анализа файла: {str(e)}'
            })
        
        return issues, metrics
    
    def find_line_number(self, content, search_text):
        """Находит номер строки с текстом"""
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            if search_text in line:
                return i
        return None
    
    def analyze_project(self):
        """Анализирует весь проект"""
        print("🔍 Анализ кода проекта...")
        
        total_metrics = defaultdict(int)
        all_issues = []
        
        # Анализ Swift файлов
        for root, dirs, files in os.walk(self.project_path):
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            
            for file in files:
                file_path = os.path.join(root, file)
                relative_path = os.path.relpath(file_path, self.project_path)
                
                if file.endswith('.swift'):
                    print(f"  📱 Анализ Swift: {relative_path}")
                    issues, metrics = self.analyze_swift_file(file_path)
                    
                elif file.endswith('.py'):
                    print(f"  🐍 Анализ Python: {relative_path}")
                    issues, metrics = self.analyze_python_file(file_path)
                    
                else:
                    continue
                
                # Добавляем путь к файлу в каждую проблему
                for issue in issues:
                    issue['file'] = relative_path
                
                all_issues.extend(issues)
                self.file_analysis[relative_path] = {
                    'issues': issues,
                    'metrics': metrics
                }
                
                # Суммируем метрики
                for key, value in metrics.items():
                    total_metrics[key] += value
        
        self.issues = all_issues
        self.metrics = total_metrics
        
        return self.generate_analysis_report()
    
    def generate_analysis_report(self):
        """Генерирует отчет анализа"""
        # Группируем проблемы по типу и серьезности
        issues_by_type = defaultdict(list)
        issues_by_severity = defaultdict(list)
        
        for issue in self.issues:
            issues_by_type[issue['type']].append(issue)
            issues_by_severity[issue['severity']].append(issue)
        
        # Создаем отчет
        report = {
            'summary': {
                'total_files_analyzed': len(self.file_analysis),
                'total_issues': len(self.issues),
                'critical_issues': len(issues_by_severity['Critical']),
                'high_issues': len(issues_by_severity['High']),
                'medium_issues': len(issues_by_severity['Medium']),
                'low_issues': len(issues_by_severity['Low'])
            },
            'metrics': dict(self.metrics),
            'issues_by_type': {k: len(v) for k, v in issues_by_type.items()},
            'issues_by_severity': {k: len(v) for k, v in issues_by_severity.items()},
            'detailed_issues': self.issues,
            'file_analysis': self.file_analysis,
            'recommendations': self.generate_recommendations(issues_by_type, issues_by_severity)
        }
        
        return report
    
    def generate_recommendations(self, issues_by_type, issues_by_severity):
        """Генерирует рекомендации по улучшению кода"""
        recommendations = []
        
        if issues_by_severity['Critical']:
            recommendations.append({
                'priority': 'Critical',
                'title': 'Критические проблемы безопасности',
                'description': 'Немедленно исправьте критические проблемы безопасности',
                'count': len(issues_by_severity['Critical'])
            })
        
        if issues_by_severity['High']:
            recommendations.append({
                'priority': 'High',
                'title': 'Проблемы высокого приоритета',
                'description': 'Исправьте проблемы высокого приоритета в ближайшее время',
                'count': len(issues_by_severity['High'])
            })
        
        if 'Force Unwrapping' in issues_by_type:
            recommendations.append({
                'priority': 'Medium',
                'title': 'Безопасная работа с опционалами',
                'description': 'Замените принудительное извлечение на безопасные методы (guard, if let)',
                'count': len(issues_by_type['Force Unwrapping'])
            })
        
        if 'Documentation' in issues_by_type:
            recommendations.append({
                'priority': 'Low',
                'title': 'Улучшение документации',
                'description': 'Добавьте документацию к публичным функциям и классам',
                'count': len(issues_by_type['Documentation'])
            })
        
        if self.metrics['complexity'] > 100:
            recommendations.append({
                'priority': 'Medium',
                'title': 'Снижение сложности кода',
                'description': 'Рефакторинг сложных функций для улучшения читаемости',
                'complexity': self.metrics['complexity']
            })
        
        return recommendations
    
    def save_analysis_report(self, report):
        """Сохраняет отчет анализа"""
        os.makedirs('docs', exist_ok=True)
        
        # Сохраняем JSON отчет
        with open('docs/code_analysis_report.json', 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        # Создаем Markdown отчет
        markdown_report = self.generate_markdown_report(report)
        with open('docs/code_analysis_report.md', 'w', encoding='utf-8') as f:
            f.write(markdown_report)
        
        print("✅ Отчет анализа кода сохранен в docs/")
    
    def generate_markdown_report(self, report):
        """Генерирует Markdown отчет"""
        md = f"""# Отчет анализа кода Eiros Agent

## Сводка

| Метрика | Значение |
|---------|----------|
| Проанализировано файлов | {report['summary']['total_files_analyzed']} |
| Всего проблем | {report['summary']['total_issues']} |
| Критические | {report['summary']['critical_issues']} |
| Высокий приоритет | {report['summary']['high_issues']} |
| Средний приоритет | {report['summary']['medium_issues']} |
| Низкий приоритет | {report['summary']['low_issues']} |

## Метрики кода

| Метрика | Значение |
|---------|----------|
| Строки кода | {report['metrics']['lines_of_code']} |
| Функции | {report['metrics']['functions']} |
| Классы | {report['metrics']['classes']} |
| Сложность | {report['metrics']['complexity']} |
| Комментарии | {report['metrics']['comments']} |

## Проблемы по типам

"""
        
        for issue_type, count in report['issues_by_type'].items():
            md += f"- **{issue_type}**: {count}\n"
        
        md += "\n## Рекомендации\n\n"
        
        for rec in report['recommendations']:
            md += f"### {rec['title']} ({rec['priority']})\n"
            md += f"{rec['description']}\n"
            if 'count' in rec:
                md += f"Количество проблем: {rec['count']}\n"
            md += "\n"
        
        md += "## Детальные проблемы\n\n"
        
        # Группируем проблемы по файлам
        issues_by_file = defaultdict(list)
        for issue in report['detailed_issues']:
            issues_by_file[issue['file']].append(issue)
        
        for file_path, issues in issues_by_file.items():
            md += f"### {file_path}\n\n"
            for issue in issues:
                severity_emoji = {
                    'Critical': '🔴',
                    'High': '🟠', 
                    'Medium': '🟡',
                    'Low': '🔵'
                }.get(issue['severity'], '⚪')
                
                md += f"- {severity_emoji} **{issue['type']}** ({issue['severity']}): {issue['message']}\n"
            md += "\n"
        
        return md

if __name__ == "__main__":
    analyzer = EirosCodeAnalyzer('.')
    report = analyzer.analyze_project()
    analyzer.save_analysis_report(report)
    
    print(f"\n📊 Анализ завершен!")
    print(f"📁 Проанализировано файлов: {report['summary']['total_files_analyzed']}")
    print(f"⚠️  Найдено проблем: {report['summary']['total_issues']}")
    print(f"🔴 Критические: {report['summary']['critical_issues']}")
    print(f"🟠 Высокий приоритет: {report['summary']['high_issues']}")
    print(f"🟡 Средний приоритет: {report['summary']['medium_issues']}")
    print(f"🔵 Низкий приоритет: {report['summary']['low_issues']}")
