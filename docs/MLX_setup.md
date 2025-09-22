
# MLX и Qwen2-VL Настройка для IOSeiros

## Обзор

Этот документ описывает настройку MLX (Machine Learning eXtended) фреймворка от Apple для запуска модели Qwen2-VL в проекте IOSeiros. MLX оптимизирован для Apple Silicon и обеспечивает высокую производительность для задач машинного обучения.

## Системные Требования

### Для MLX (Рекомендуется)
- **Процессор**: Apple Silicon (M1, M2, M3, M4 или новее)
- **ОС**: macOS 13.5 (Ventura) или новее
- **Python**: 3.9 или новее
- **RAM**: Минимум 16GB, рекомендуется 32GB+
- **Свободное место**: 5-50GB (в зависимости от модели)

### Для Fallback режима (Все платформы)
- **ОС**: Windows, macOS, Linux
- **Python**: 3.8 или новее
- **RAM**: Минимум 4GB
- **Свободное место**: 1GB

## Установка

### 1. Клонирование репозитория

```bash
git clone https://github.com/ricobiz/IOSeiros.git
cd IOSeiros
```

### 2. Создание виртуального окружения

```bash
python -m venv .venv
source .venv/bin/activate  # macOS/Linux
# или
.venv\Scripts\activate     # Windows
```

### 3. Установка зависимостей

```bash
pip install -r requirements.txt
```

**Примечание**: MLX пакеты (`mlx`, `mlx-lm`, `mlx-vlm`) автоматически устанавливаются только на Apple Silicon. На других платформах используется fallback режим.

## Доступные Модели Qwen2-VL

### qwen2-vl-2b-4bit (Рекомендуется для начала)
- **Размер**: ~1.2GB
- **RAM**: Минимум 8GB, рекомендуется 16GB
- **Описание**: Компактная модель с 4-bit квантизацией, идеальна для тестирования

### qwen2-vl-7b-4bit (Сбалансированная)
- **Размер**: ~4.2GB
- **RAM**: Минимум 16GB, рекомендуется 32GB
- **Описание**: Хорошее соотношение производительности и размера

### qwen2-vl-7b-bf16 (Высокое качество)
- **Размер**: ~14GB
- **RAM**: Минимум 32GB, рекомендуется 64GB
- **Описание**: Высокое качество с bf16 точностью

### qwen2-vl-72b-4bit (Максимальная производительность)
- **Размер**: ~42GB
- **RAM**: Минимум 64GB, рекомендуется 128GB
- **Описание**: Самая мощная модель с 72B параметрами

## Запуск Сервера

### Автоматический режим (рекомендуется)

```bash
python qwen2vl_enhanced_server.py
```

Сервер автоматически:
- Определит платформу
- Выберет подходящий backend (MLX или Mock)
- Загрузит рекомендуемую модель
- Запустится на `http://localhost:8888`

### Ручная настройка

```bash
# Указать конкретную модель
python qwen2vl_enhanced_server.py --model qwen2-vl-2b-4bit

# Изменить порт
python qwen2vl_enhanced_server.py --port 9999

# Режим отладки
python qwen2vl_enhanced_server.py --debug
```

## API Endpoints

### GET /health
Проверка состояния сервера
```json
{
  "status": "healthy",
  "model_loaded": true,
  "backend": "mlx",
  "platform": "Darwin",
  "mlx_compatible": true
}
```

### GET /platform
Информация о платформе
```json
{
  "platform": "Darwin",
  "machine": "arm64",
  "mlx_compatible": true,
  "macos_version": "14.0",
  "total_ram_gb": 32
}
```

### GET /models
Список доступных моделей
```json
{
  "backend": "mlx",
  "available_models": {
    "qwen2-vl-2b-4bit": {
      "name": "Qwen2-VL-2B-4bit",
      "size_gb": 1.2,
      "description": "Compact model for testing"
    }
  },
  "recommended": "qwen2-vl-2b-4bit"
}
```

### POST /analyze
Анализ изображения
```json
{
  "image": "base64_encoded_image",
  "prompt": "Describe this screen",
  "task_type": "general"
}
```

Ответ:
```json
{
  "success": true,
  "response": "This is a mobile interface with...",
  "confidence": 0.85,
  "processing_time": 1.2,
  "backend": "mlx"
}
```

## Типы Задач (task_type)

- **general**: Общий анализ изображения
- **findElement**: Поиск UI элементов
- **clickElement**: Поиск кликабельных элементов
- **extractText**: Извлечение текста (OCR)
- **describeScreen**: Описание экрана
- **findButton**: Поиск кнопок
- **findTextField**: Поиск текстовых полей

## Тестирование

### Проверка платформы

```bash
python mlx_loader.py
```

### Тест mock процессора

```bash
python mock_fallback.py
```

### Интеграционный тест

```bash
python -c "
import requests
import base64
from PIL import Image
import io

# Создать тестовое изображение
img = Image.new('RGB', (100, 100), 'white')
buffer = io.BytesIO()
img.save(buffer, format='PNG')
img_b64 = base64.b64encode(buffer.getvalue()).decode()

# Отправить запрос
response = requests.post('http://localhost:8888/analyze', json={
    'image': img_b64,
    'prompt': 'Describe this image',
    'task_type': 'general'
})

print(response.json())
"
```

## Интеграция с iOS

### Swift код для отправки изображений

```swift
import Foundation
import UIKit

class Qwen2VLClient {
    private let baseURL = "http://localhost:8888"
    
    func analyzeImage(_ image: UIImage, prompt: String, taskType: String = "general") async throws -> AnalysisResult {
        guard let imageData = image.pngData() else {
            throw ClientError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let request = AnalysisRequest(
            image: base64Image,
            prompt: prompt,
            task_type: taskType
        )
        
        let url = URL(string: "\(baseURL)/analyze")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        return try JSONDecoder().decode(AnalysisResult.self, from: data)
    }
}

struct AnalysisRequest: Codable {
    let image: String
    let prompt: String
    let task_type: String
}

struct AnalysisResult: Codable {
    let success: Bool
    let response: String
    let confidence: Double
    let processing_time: Double
    let backend: String
}
```

## Производительность

### Ожидаемые времена обработки

| Модель | Apple M1 | Apple M2 | Apple M3 |
|--------|----------|----------|----------|
| 2B-4bit | 0.5-1.5s | 0.3-1.0s | 0.2-0.8s |
| 7B-4bit | 1.0-3.0s | 0.8-2.5s | 0.6-2.0s |
| 7B-bf16 | 2.0-5.0s | 1.5-4.0s | 1.2-3.5s |

### Оптимизация

1. **Используйте квантизованные модели** (4-bit) для лучшей скорости
2. **Кэшируйте модель** - загружайте один раз при старте
3. **Batch обработка** для множественных запросов
4. **Мониторинг памяти** - следите за использованием RAM

## Устранение Неполадок

### MLX не устанавливается

```bash
# Проверить платформу
python -c "import platform; print(platform.system(), platform.machine())"

# Обновить pip
pip install --upgrade pip

# Установить MLX вручную
pip install mlx mlx-lm mlx-vlm
```

### Модель не загружается

1. Проверьте доступную память: `python -c "import psutil; print(f'{psutil.virtual_memory().available // (1024**3)}GB available')"`
2. Попробуйте меньшую модель: `qwen2-vl-2b-4bit`
3. Проверьте интернет соединение для загрузки модели

### Медленная работа

1. Убедитесь, что используется Apple Silicon
2. Закройте другие приложения для освобождения памяти
3. Используйте квантизованные модели (4-bit)

### Fallback режим

Если MLX недоступен, сервер автоматически переключится на mock режим:
- Симулирует ответы модели
- Подходит для тестирования интеграции
- Работает на любой платформе

## Мониторинг

### Статистика сервера

```bash
curl http://localhost:8888/stats
```

### Логи

Сервер выводит подробные логи:
- ✅ Успешные операции
- ❌ Ошибки
- ⚠️ Предупреждения
- 🔄 Процессы загрузки

## Безопасность

1. **Локальный запуск**: Сервер по умолчанию доступен только локально
2. **Нет внешних API**: Все обработки происходят локально
3. **Приватные данные**: Изображения не отправляются в облако

## Дальнейшее Развитие

- [ ] Поддержка видео анализа
- [ ] Batch обработка изображений
- [ ] Fine-tuning для специфических задач
- [ ] Интеграция с Core ML
- [ ] Поддержка streaming ответов

## Поддержка

Для вопросов и проблем:
1. Проверьте логи сервера
2. Используйте endpoint `/health` для диагностики
3. Создайте issue в репозитории с подробным описанием

---

*Документ обновлен: Сентябрь 2025*
