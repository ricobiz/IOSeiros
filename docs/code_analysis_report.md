# Отчет анализа кода Eiros Agent

## Сводка

| Метрика | Значение |
|---------|----------|
| Проанализировано файлов | 70 |
| Всего проблем | 81 |
| Критические | 0 |
| Высокий приоритет | 5 |
| Средний приоритет | 4 |
| Низкий приоритет | 72 |

## Метрики кода

| Метрика | Значение |
|---------|----------|
| Строки кода | 14057 |
| Функции | 701 |
| Классы | 83 |
| Сложность | 2335 |
| Комментарии | 880 |

## Проблемы по типам

- **Error Handling**: 1
- **Security**: 5
- **Code Quality**: 37
- **Code Style**: 35
- **Force Unwrapping**: 3

## Рекомендации

### Проблемы высокого приоритета (High)
Исправьте проблемы высокого приоритета в ближайшее время
Количество проблем: 5

### Безопасная работа с опционалами (Medium)
Замените принудительное извлечение на безопасные методы (guard, if let)
Количество проблем: 3

### Снижение сложности кода (Medium)
Рефакторинг сложных функций для улучшения читаемости

## Детальные проблемы

### code_analysis.py

- 🟡 **Error Handling** (Medium): Использование голого except может скрывать ошибки
- 🟠 **Security** (High): Использование eval() может быть небезопасным
- 🟠 **Security** (High): Использование exec() может быть небезопасным

### analyze_architecture.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: networkx
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: yaml

### eiros_agent/vision/manager.py

- 🔵 **Code Style** (Low): Строка 67 превышает 120 символов (124 символов)
- 🔵 **Code Style** (Low): Строка 107 превышает 120 символов (146 символов)
- 🔵 **Code Style** (Low): Строка 149 превышает 120 символов (145 символов)
- 🔵 **Code Style** (Low): Строка 172 превышает 120 символов (181 символов)
- 🔵 **Code Style** (Low): Строка 201 превышает 120 символов (227 символов)
- 🔵 **Code Style** (Low): Строка 230 превышает 120 символов (153 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: numpy

### eiros_agent/vision/screen_capture.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: numpy

### eiros_agent/vision/object_detector.py

- 🔵 **Code Style** (Low): Строка 73 превышает 120 символов (124 символов)
- 🔵 **Code Style** (Low): Строка 93 превышает 120 символов (134 символов)
- 🔵 **Code Style** (Low): Строка 262 превышает 120 символов (126 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: numpy

### eiros_agent/vision/image_analyzer.py

- 🔵 **Code Style** (Low): Строка 281 превышает 120 символов (133 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio

### eiros_agent/ocr/engines.py

- 🔵 **Code Style** (Low): Строка 32 превышает 120 символов (132 символов)
- 🔵 **Code Style** (Low): Строка 81 превышает 120 символов (132 символов)
- 🔵 **Code Style** (Low): Строка 177 превышает 120 символов (132 символов)
- 🔵 **Code Style** (Low): Строка 262 превышает 120 символов (132 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: Path

### eiros_agent/ocr/manager.py

- 🔵 **Code Style** (Low): Строка 81 превышает 120 символов (143 символов)
- 🔵 **Code Style** (Low): Строка 115 превышает 120 символов (121 символов)
- 🔵 **Code Style** (Low): Строка 137 превышает 120 символов (162 символов)
- 🔵 **Code Style** (Low): Строка 164 превышает 120 символов (188 символов)
- 🔵 **Code Style** (Low): Строка 190 превышает 120 символов (146 символов)
- 🔵 **Code Style** (Low): Строка 225 превышает 120 символов (141 символов)
- 🔵 **Code Style** (Low): Строка 283 превышает 120 символов (123 символов)
- 🔵 **Code Style** (Low): Строка 374 превышает 120 символов (123 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: numpy

### eiros_agent/ocr/preprocessor.py

- 🔵 **Code Style** (Low): Строка 35 превышает 120 символов (138 символов)
- 🔵 **Code Style** (Low): Строка 57 превышает 120 символов (125 символов)
- 🔵 **Code Style** (Low): Строка 287 превышает 120 символов (126 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: numpy

### eiros_agent/ocr/postprocessor.py

- 🔵 **Code Style** (Low): Строка 258 превышает 120 символов (122 символов)

### eiros_agent/web_automation/form_handler.py

- 🔵 **Code Style** (Low): Строка 52 превышает 120 символов (129 символов)
- 🔵 **Code Style** (Low): Строка 106 превышает 120 символов (133 символов)

### eiros_agent/web_automation/manager.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio

### eiros_agent/web_automation/browser_controller.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio

### eiros_agent/web_automation/navigation.py

- 🔵 **Code Style** (Low): Строка 162 превышает 120 символов (128 символов)
- 🔵 **Code Style** (Low): Строка 197 превышает 120 символов (159 символов)
- 🔵 **Code Style** (Low): Строка 238 превышает 120 символов (135 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: urljoin

### eiros_agent/utils/image_utils.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: numpy

### eiros_agent/utils/file_utils.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: os

### eiros_agent/core/agent.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: Path

### eiros_agent/core/control_room_integration.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio

### eiros_agent/control_room/backend/api/rest_api.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio

### eiros_agent/control_room/backend/monitoring/metrics_collector.py

- 🔵 **Code Style** (Low): Строка 165 превышает 120 символов (133 символов)

### eiros_agent/control_room/backend/monitoring/system_monitor.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: asyncio

### eiros_agent/control_room/backend/websocket/websocket_server.py

- 🔵 **Code Style** (Low): Строка 361 превышает 120 символов (124 символов)

### eiros_agent/scheduler/task_manager.py

- 🟠 **Security** (High): Использование eval() может быть небезопасным

### eiros_agent/scheduler/scheduler.py

- 🔵 **Code Style** (Low): Строка 159 превышает 120 символов (126 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: TimeTrigger

### eiros_agent/scheduler/triggers.py

- 🟠 **Security** (High): Использование eval() может быть небезопасным

### eiros_agent/scheduler/macro_engine.py

- 🔵 **Code Style** (Low): Строка 61 превышает 120 символов (126 символов)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: yaml
- 🟠 **Security** (High): Использование eval() может быть небезопасным

### EirosAgent/Views/BrowserView.swift

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: WebKit

### EirosAgent/Managers/ScreenCaptureManager.swift

- 🔵 **Code Quality** (Low): Функция содержит 140 строк (рекомендуется < 50)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: Combine

### EirosAgent/Managers/VisionManager.swift

- 🔵 **Code Quality** (Low): Функция содержит 253 строк (рекомендуется < 50)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: AVFoundation

### EirosAgent/Managers/EnhancedLLMManager.swift

- 🟡 **Force Unwrapping** (Medium): Найдено 6 принудительных извлечений опционалов
- 🔵 **Code Quality** (Low): Функция содержит 392 строк (рекомендуется < 50)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: Combine

### EirosAgent/Managers/LLMManager.swift

- 🟡 **Force Unwrapping** (Medium): Найдено 3 принудительных извлечений опционалов
- 🔵 **Code Quality** (Low): Функция содержит 124 строк (рекомендуется < 50)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: Combine

### EirosAgent/Managers/WebViewManager.swift

- 🟡 **Force Unwrapping** (Medium): Найдено 3 принудительных извлечений опционалов
- 🔵 **Code Quality** (Low): Функция содержит 206 строк (рекомендуется < 50)
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: WebKit
- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: Combine

### examples/basic_usage.py

- 🔵 **Code Quality** (Low): Возможно неиспользуемый импорт: Path

