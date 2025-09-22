# План тестирования Eiros Agent iOS

**Проект:** Eiros Agent iOS  
**Версия:** 1.0.0  
**Дата создания:** 2025-09-22

## Обзор тестирования

| Категория | Количество тестов |
|-----------|-------------------|
| Unit тесты | 5 |
| Интеграционные тесты | 4 |
| UI тесты | 6 |
| Тесты производительности | 4 |
| Тесты безопасности | 4 |

## Unit тесты

### test_llm_initialization
**Компонент:** LLMManager  
**Описание:** Проверка инициализации LLM менеджера  
**Приоритет:** High  
**Ожидаемый результат:** Менеджер создается успешно

```swift

func testLLMManagerInitialization() {
    let manager = LLMManager()
    XCTAssertNotNil(manager)
    XCTAssertEqual(manager.isInitialized, false)
}
```

### test_image_analysis
**Компонент:** VisionManager  
**Описание:** Проверка анализа изображений  
**Приоритет:** High  
**Ожидаемый результат:** Изображение анализируется корректно

```swift

func testImageAnalysis() {
    let manager = VisionManager()
    let testImage = UIImage(named: "test_image")!
    
    let expectation = XCTestExpectation(description: "Image analysis")
    
    manager.analyzeImage(testImage) { result in
        XCTAssertNotNil(result)
        XCTAssertTrue(result.confidence > 0.5)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10.0)
}
```

### test_javascript_injection
**Компонент:** WebViewManager  
**Описание:** Проверка внедрения JavaScript  
**Приоритет:** Medium  
**Ожидаемый результат:** JavaScript выполняется успешно

```swift

func testJavaScriptInjection() {
    let manager = WebViewManager()
    let testScript = "document.title"
    
    let expectation = XCTestExpectation(description: "JS injection")
    
    manager.injectJavaScript(testScript) { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

### test_screen_capture
**Компонент:** ScreenCaptureManager  
**Описание:** Проверка захвата экрана  
**Приоритет:** High  
**Ожидаемый результат:** Скриншот создается успешно

```swift

func testScreenCapture() {
    let manager = ScreenCaptureManager()
    
    let expectation = XCTestExpectation(description: "Screen capture")
    
    manager.captureScreen { image in
        XCTAssertNotNil(image)
        XCTAssertTrue(image.size.width > 0)
        XCTAssertTrue(image.size.height > 0)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 3.0)
}
```

### test_message_creation
**Компонент:** ChatMessage  
**Описание:** Проверка создания сообщений чата  
**Приоритет:** Low  
**Ожидаемый результат:** Сообщение создается с корректными данными

```swift

func testChatMessageCreation() {
    let message = ChatMessage(
        id: UUID(),
        content: "Test message",
        isUser: true,
        timestamp: Date()
    )
    
    XCTAssertEqual(message.content, "Test message")
    XCTAssertTrue(message.isUser)
    XCTAssertNotNil(message.timestamp)
}
```

## Интеграционные тесты

### test_llm_vision_integration
**Описание:** Интеграция LLM и Vision компонентов  
**Компоненты:** LLMManager, VisionManager  
**Приоритет:** High

**Сценарий:**

1. Захватить скриншот экрана
2. Передать изображение в VisionManager для анализа
3. Отправить результаты анализа в LLMManager
4. Получить текстовое описание от LLM
5. Проверить корректность результата


**Ожидаемый результат:** LLM корректно обрабатывает результаты анализа изображений

### test_web_automation_flow
**Описание:** Полный цикл веб-автоматизации  
**Компоненты:** WebViewManager, VisionManager, LLMManager  
**Приоритет:** High

**Сценарий:**

1. Загрузить веб-страницу в WebView
2. Сделать скриншот страницы
3. Проанализировать элементы через Vision
4. Получить инструкции от LLM
5. Выполнить автоматизированные действия
6. Проверить результат


**Ожидаемый результат:** Автоматизация веб-страницы выполняется успешно

### test_ai_roles_switching
**Описание:** Переключение между ролями ИИ  
**Компоненты:** AIRoleManager, LLMManager  
**Приоритет:** Medium

**Сценарий:**

1. Инициализировать роль Планировщика
2. Создать план задач
3. Переключиться на роль Декомпозитора
4. Разбить задачи на подзадачи
5. Переключиться на роль Оркестратора
6. Координировать выполнение


**Ожидаемый результат:** Роли переключаются корректно и выполняют свои функции

### test_control_room_communication
**Описание:** Связь с Control Room бэкендом  
**Компоненты:** ControlRoomManager, WebSocket  
**Приоритет:** High

**Сценарий:**

1. Установить WebSocket соединение
2. Отправить команду в Control Room
3. Получить ответ от бэкенда
4. Обработать результат в iOS приложении
5. Обновить UI


**Ожидаемый результат:** Связь с бэкендом работает стабильно

## UI тесты

### test_main_screen_navigation
**Экран:** MainScreen  
**Описание:** Навигация с главного экрана  
**Приоритет:** High

**Шаги:**
1. Запустить приложение
2. Проверить отображение главного экрана
3. Нажать кнопку 'Открыть браузер'
4. Проверить переход на экран браузера
5. Вернуться на главный экран
6. Нажать кнопку 'Роли ИИ'
7. Проверить переход на экран ролей

**Ожидаемый результат:** Навигация работает корректно

### test_browser_functionality
**Экран:** BrowserView  
**Описание:** Функциональность браузера  
**Приоритет:** High

**Шаги:**
1. Открыть экран браузера
2. Ввести URL в адресную строку
3. Нажать кнопку перехода
4. Проверить загрузку страницы
5. Использовать кнопки навигации (назад/вперед)
6. Проверить работу кнопки обновления

**Ожидаемый результат:** Браузер загружает страницы и навигация работает

### test_ai_roles_interface
**Экран:** AIRolesView  
**Описание:** Интерфейс ролей ИИ  
**Приоритет:** Medium

**Шаги:**
1. Открыть экран ролей ИИ
2. Проверить отображение всех ролей
3. Выбрать роль Планировщика
4. Проверить активацию роли
5. Переключиться на роль Декомпозитора
6. Проверить смену активной роли

**Ожидаемый результат:** Роли отображаются и переключаются корректно

### test_automation_controls
**Экран:** AutomationView  
**Описание:** Элементы управления автоматизацией  
**Приоритет:** High

**Шаги:**
1. Открыть экран автоматизации
2. Нажать кнопку 'Новый скрипт'
3. Проверить открытие редактора
4. Создать простой скрипт
5. Сохранить скрипт
6. Запустить выполнение
7. Проверить статус выполнения

**Ожидаемый результат:** Создание и выполнение скриптов работает

### test_vision_analysis_ui
**Экран:** VisionAnalysisView  
**Описание:** Интерфейс анализа изображений  
**Приоритет:** High

**Шаги:**
1. Открыть экран анализа
2. Нажать кнопку 'Снимок'
3. Проверить захват изображения
4. Дождаться результатов анализа
5. Проверить отображение результатов
6. Нажать кнопку 'Автоматизировать'

**Ожидаемый результат:** Анализ изображений и отображение результатов работает

### test_settings_configuration
**Экран:** SettingsView  
**Описание:** Настройки приложения  
**Приоритет:** Medium

**Шаги:**
1. Открыть экран настроек
2. Проверить отображение всех секций
3. Открыть настройки ИИ
4. Изменить модель LLM
5. Сохранить изменения
6. Проверить применение настроек

**Ожидаемый результат:** Настройки сохраняются и применяются

## Тестовое окружение

### Поддерживаемые версии iOS
- iOS 15.0+
- iOS 16.0+
- iOS 17.0+

### Устройства для тестирования
- iPhone 12
- iPhone 13
- iPhone 14
- iPhone 15
- iPad

### Симуляторы
- iPhone 14 Simulator
- iPad Pro Simulator

## Тестовые данные

### Тестовые изображения
- test_screenshot.png
- test_webpage.png
- test_form.png

### Тестовые URL
- https://example.com
- https://httpbin.org/forms/post

### Тестовые скрипты
- login_automation.js
- form_filling.js
