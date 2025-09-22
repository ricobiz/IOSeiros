#!/usr/bin/env python3
"""
UI Mockups Generator для Eiros Agent
Создает визуальные мокапы всех экранов приложения
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, Circle
import os

class EirosUIMockupGenerator:
    def __init__(self):
        self.screen_width = 375  # iPhone screen width
        self.screen_height = 812  # iPhone screen height
        self.colors = {
            'primary': '#007AFF',
            'secondary': '#5856D6', 
            'success': '#34C759',
            'warning': '#FF9500',
            'danger': '#FF3B30',
            'background': '#F2F2F7',
            'surface': '#FFFFFF',
            'text': '#000000',
            'text_secondary': '#8E8E93'
        }
    
    def create_base_screen(self, title):
        """Создает базовый экран iPhone"""
        fig, ax = plt.subplots(figsize=(6, 12))
        
        # Фон экрана
        screen_bg = FancyBboxPatch(
            (0, 0), self.screen_width, self.screen_height,
            boxstyle="round,pad=20",
            facecolor=self.colors['background'],
            edgecolor='black',
            linewidth=2
        )
        ax.add_patch(screen_bg)
        
        # Status bar
        status_bar = patches.Rectangle(
            (20, self.screen_height - 60), self.screen_width - 40, 40,
            facecolor=self.colors['surface'], alpha=0.9
        )
        ax.add_patch(status_bar)
        
        # Navigation bar
        nav_bar = patches.Rectangle(
            (20, self.screen_height - 120), self.screen_width - 40, 60,
            facecolor=self.colors['primary'], alpha=0.9
        )
        ax.add_patch(nav_bar)
        
        # Title
        ax.text(self.screen_width/2, self.screen_height - 90, title,
                ha='center', va='center', fontsize=16, fontweight='bold',
                color='white')
        
        return fig, ax
    
    def add_button(self, ax, x, y, width, height, text, color='primary'):
        """Добавляет кнопку"""
        button = FancyBboxPatch(
            (x, y), width, height,
            boxstyle="round,pad=5",
            facecolor=self.colors[color],
            edgecolor=self.colors[color],
            alpha=0.8
        )
        ax.add_patch(button)
        
        ax.text(x + width/2, y + height/2, text,
                ha='center', va='center', fontsize=10, fontweight='bold',
                color='white')
    
    def add_text_field(self, ax, x, y, width, height, placeholder=""):
        """Добавляет текстовое поле"""
        field = FancyBboxPatch(
            (x, y), width, height,
            boxstyle="round,pad=3",
            facecolor=self.colors['surface'],
            edgecolor=self.colors['text_secondary'],
            linewidth=1
        )
        ax.add_patch(field)
        
        if placeholder:
            ax.text(x + 10, y + height/2, placeholder,
                    ha='left', va='center', fontsize=9,
                    color=self.colors['text_secondary'])
    
    def add_card(self, ax, x, y, width, height, title="", content=""):
        """Добавляет карточку"""
        card = FancyBboxPatch(
            (x, y), width, height,
            boxstyle="round,pad=8",
            facecolor=self.colors['surface'],
            edgecolor=self.colors['text_secondary'],
            linewidth=1,
            alpha=0.9
        )
        ax.add_patch(card)
        
        if title:
            ax.text(x + 15, y + height - 20, title,
                    ha='left', va='center', fontsize=11, fontweight='bold',
                    color=self.colors['text'])
        
        if content:
            ax.text(x + 15, y + height/2, content,
                    ha='left', va='center', fontsize=9,
                    color=self.colors['text_secondary'])
    
    def generate_main_screen(self):
        """Генерирует главный экран"""
        fig, ax = self.create_base_screen("Eiros Agent")
        
        # Welcome section
        self.add_card(ax, 30, 600, 315, 80, 
                     "Добро пожаловать!", 
                     "Ваш ИИ-помощник для автоматизации")
        
        # Main action buttons
        self.add_button(ax, 30, 500, 315, 50, "🌐 Открыть браузер", 'primary')
        self.add_button(ax, 30, 430, 315, 50, "🤖 Роли ИИ", 'secondary')
        self.add_button(ax, 30, 360, 315, 50, "⚡ Автоматизация", 'success')
        self.add_button(ax, 30, 290, 315, 50, "👁️ Анализ экрана", 'warning')
        
        # Recent activity
        self.add_card(ax, 30, 150, 315, 120,
                     "Последняя активность",
                     "• Автоматизация веб-формы\n• Анализ изображения\n• Планирование задач")
        
        # Settings button
        self.add_button(ax, 30, 80, 315, 40, "⚙️ Настройки", 'text_secondary')
        
        ax.set_xlim(0, self.screen_width)
        ax.set_ylim(0, self.screen_height)
        ax.set_aspect('equal')
        ax.axis('off')
        
        plt.tight_layout()
        plt.savefig('docs/ui_mockups/main_screen.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_browser_screen(self):
        """Генерирует экран браузера"""
        fig, ax = self.create_base_screen("Браузер")
        
        # URL bar
        self.add_text_field(ax, 30, 650, 315, 40, "https://example.com")
        
        # Browser controls
        self.add_button(ax, 30, 600, 60, 35, "←", 'text_secondary')
        self.add_button(ax, 100, 600, 60, 35, "→", 'text_secondary')
        self.add_button(ax, 170, 600, 60, 35, "⟳", 'text_secondary')
        self.add_button(ax, 285, 600, 60, 35, "⋯", 'text_secondary')
        
        # Web content area
        web_content = patches.Rectangle(
            (30, 200), 315, 380,
            facecolor='white', edgecolor=self.colors['text_secondary']
        )
        ax.add_patch(web_content)
        
        ax.text(187.5, 390, "Веб-контент",
                ha='center', va='center', fontsize=12,
                color=self.colors['text_secondary'])
        
        # Automation controls
        self.add_card(ax, 30, 120, 315, 60,
                     "Автоматизация",
                     "Активные скрипты: 2")
        
        self.add_button(ax, 30, 60, 100, 40, "Запись", 'danger')
        self.add_button(ax, 140, 60, 100, 40, "Воспроизведение", 'success')
        self.add_button(ax, 250, 60, 95, 40, "Стоп", 'text_secondary')
        
        ax.set_xlim(0, self.screen_width)
        ax.set_ylim(0, self.screen_height)
        ax.set_aspect('equal')
        ax.axis('off')
        
        plt.tight_layout()
        plt.savefig('docs/ui_mockups/browser_screen.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_ai_roles_screen(self):
        """Генерирует экран ролей ИИ"""
        fig, ax = self.create_base_screen("Роли ИИ")
        
        # Role cards
        roles = [
            ("🧠 Планировщик", "Создает стратегии и планы", 'primary'),
            ("🔧 Декомпозитор", "Разбивает задачи на части", 'secondary'),
            ("🎭 Оркестратор", "Координирует выполнение", 'success')
        ]
        
        y_pos = 580
        for role_name, role_desc, color in roles:
            self.add_card(ax, 30, y_pos, 315, 80, role_name, role_desc)
            
            # Status indicator
            status_circle = Circle((320, y_pos + 40), 8, 
                                 facecolor=self.colors[color], alpha=0.8)
            ax.add_patch(status_circle)
            
            y_pos -= 100
        
        # Current task
        self.add_card(ax, 30, 250, 315, 100,
                     "Текущая задача",
                     "Анализ веб-страницы\nСтатус: В процессе\nПрогресс: 65%")
        
        # Control buttons
        self.add_button(ax, 30, 180, 100, 40, "Пауза", 'warning')
        self.add_button(ax, 140, 180, 100, 40, "Остановить", 'danger')
        self.add_button(ax, 250, 180, 95, 40, "Настройки", 'text_secondary')
        
        # Role switching
        self.add_card(ax, 30, 80, 315, 80,
                     "Переключение ролей",
                     "Автоматическое переключение: ВКЛ")
        
        ax.set_xlim(0, self.screen_width)
        ax.set_ylim(0, self.screen_height)
        ax.set_aspect('equal')
        ax.axis('off')
        
        plt.tight_layout()
        plt.savefig('docs/ui_mockups/ai_roles_screen.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_automation_screen(self):
        """Генерирует экран автоматизации"""
        fig, ax = self.create_base_screen("Автоматизация")
        
        # Quick actions
        self.add_button(ax, 30, 650, 150, 50, "📝 Новый скрипт", 'primary')
        self.add_button(ax, 195, 650, 150, 50, "📂 Библиотека", 'secondary')
        
        # Active scripts
        self.add_card(ax, 30, 550, 315, 80,
                     "Активные скрипты",
                     "Заполнение форм: Запущен\nПарсинг данных: Ожидание")
        
        # Script templates
        templates = [
            "🌐 Веб-автоматизация",
            "📱 UI-тестирование", 
            "📊 Сбор данных",
            "🔄 Повторяющиеся задачи"
        ]
        
        y_pos = 450
        for i, template in enumerate(templates):
            self.add_button(ax, 30, y_pos, 315, 40, template, 'surface')
            y_pos -= 50
        
        # Execution controls
        self.add_card(ax, 30, 120, 315, 60,
                     "Управление выполнением",
                     "Очередь: 3 задачи | Выполнено: 12")
        
        self.add_button(ax, 30, 60, 100, 40, "Запустить", 'success')
        self.add_button(ax, 140, 60, 100, 40, "Пауза", 'warning')
        self.add_button(ax, 250, 60, 95, 40, "Очистить", 'danger')
        
        ax.set_xlim(0, self.screen_width)
        ax.set_ylim(0, self.screen_height)
        ax.set_aspect('equal')
        ax.axis('off')
        
        plt.tight_layout()
        plt.savefig('docs/ui_mockups/automation_screen.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_settings_screen(self):
        """Генерирует экран настроек"""
        fig, ax = self.create_base_screen("Настройки")
        
        # Settings sections
        sections = [
            ("🤖 ИИ и модели", "OpenRouter, Qwen2-VL-2B"),
            ("🔐 Безопасность", "Биометрия, пароли"),
            ("🌐 Сеть", "Прокси, таймауты"),
            ("📱 Интерфейс", "Тема, язык"),
            ("🔔 Уведомления", "Push, звуки"),
            ("💾 Данные", "Кэш, история"),
            ("ℹ️ О приложении", "Версия, лицензии")
        ]
        
        y_pos = 650
        for section_name, section_desc in sections:
            self.add_card(ax, 30, y_pos, 315, 60, section_name, section_desc)
            
            # Arrow indicator
            ax.text(330, y_pos + 30, "›",
                    ha='center', va='center', fontsize=16,
                    color=self.colors['text_secondary'])
            
            y_pos -= 80
        
        ax.set_xlim(0, self.screen_width)
        ax.set_ylim(0, self.screen_height)
        ax.set_aspect('equal')
        ax.axis('off')
        
        plt.tight_layout()
        plt.savefig('docs/ui_mockups/settings_screen.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_vision_analysis_screen(self):
        """Генерирует экран анализа изображений"""
        fig, ax = self.create_base_screen("Анализ экрана")
        
        # Camera/screenshot area
        camera_area = patches.Rectangle(
            (30, 450), 315, 200,
            facecolor='black', edgecolor=self.colors['text_secondary']
        )
        ax.add_patch(camera_area)
        
        ax.text(187.5, 550, "📷 Предварительный просмотр",
                ha='center', va='center', fontsize=12, color='white')
        
        # Capture controls
        self.add_button(ax, 30, 390, 100, 40, "📸 Снимок", 'primary')
        self.add_button(ax, 140, 390, 100, 40, "🎥 Запись", 'danger')
        self.add_button(ax, 250, 390, 95, 40, "📁 Галерея", 'secondary')
        
        # Analysis results
        self.add_card(ax, 30, 280, 315, 90,
                     "Результаты анализа",
                     "Обнаружено: 3 кнопки, 2 текстовых поля\nТекст: 'Войти в систему'\nДействия: Доступны")
        
        # AI insights
        self.add_card(ax, 30, 170, 315, 90,
                     "ИИ рекомендации",
                     "• Заполнить форму автоматически\n• Создать скрипт для входа\n• Сохранить как шаблон")
        
        # Action buttons
        self.add_button(ax, 30, 110, 150, 40, "Автоматизировать", 'success')
        self.add_button(ax, 195, 110, 150, 40, "Экспорт данных", 'warning')
        
        # OCR toggle
        self.add_card(ax, 30, 50, 315, 40,
                     "OCR: Включен | Точность: 94%", "")
        
        ax.set_xlim(0, self.screen_width)
        ax.set_ylim(0, self.screen_height)
        ax.set_aspect('equal')
        ax.axis('off')
        
        plt.tight_layout()
        plt.savefig('docs/ui_mockups/vision_analysis_screen.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_all_mockups(self):
        """Генерирует все мокапы"""
        os.makedirs('docs/ui_mockups', exist_ok=True)
        
        print("🎨 Создание мокапов UI...")
        
        print("  📱 Главный экран...")
        self.generate_main_screen()
        
        print("  🌐 Экран браузера...")
        self.generate_browser_screen()
        
        print("  🤖 Экран ролей ИИ...")
        self.generate_ai_roles_screen()
        
        print("  ⚡ Экран автоматизации...")
        self.generate_automation_screen()
        
        print("  ⚙️ Экран настроек...")
        self.generate_settings_screen()
        
        print("  👁️ Экран анализа...")
        self.generate_vision_analysis_screen()
        
        print("✅ Все мокапы созданы!")

if __name__ == "__main__":
    generator = EirosUIMockupGenerator()
    generator.generate_all_mockups()
