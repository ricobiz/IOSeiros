
"""
Tests for web automation functionality
"""
import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock
from eiros_agent.web_automation import WebAutomationManager, JSInjector, FormHandler


class TestJSInjector:
    """Test JavaScript injection functionality"""
    
    @pytest.fixture
    def js_injector(self):
        """Create test JS injector"""
        config = {
            "injection_timeout": 5000,
            "max_retries": 3,
            "enable_stealth": True
        }
        return JSInjector(config)
    
    @pytest.mark.asyncio
    async def test_js_injector_initialization(self, js_injector):
        """Test JS injector initialization"""
        await js_injector.initialize()
        assert js_injector is not None
    
    def test_available_templates(self, js_injector):
        """Test getting available script templates"""
        templates = js_injector.get_available_templates()
        
        assert "extract_links" in templates
        assert "extract_images" in templates
        assert "scroll_to_bottom" in templates
        assert "stealth_mode" in templates
    
    def test_add_template(self, js_injector):
        """Test adding custom script template"""
        custom_script = "return document.title;"
        js_injector.add_template("get_title", custom_script)
        
        templates = js_injector.get_available_templates()
        assert "get_title" in templates
        assert js_injector.script_templates["get_title"] == custom_script
    
    @pytest.mark.asyncio
    async def test_execute_script_with_mock_page(self, js_injector):
        """Test script execution with mock page"""
        await js_injector.initialize()
        
        # Mock page
        mock_page = Mock()
        mock_page.evaluate = AsyncMock(return_value="Test Title")
        
        # Test template execution
        result = await js_injector.execute_script(mock_page, "return document.title;")
        
        assert result == "Test Title"
        mock_page.evaluate.assert_called_once()


class TestFormHandler:
    """Test form handling functionality"""
    
    @pytest.fixture
    def form_handler(self):
        """Create test form handler"""
        config = {
            "auto_fill": True,
            "validation": True,
            "submit_delay": 1000
        }
        return FormHandler(config)
    
    @pytest.mark.asyncio
    async def test_form_handler_initialization(self, form_handler):
        """Test form handler initialization"""
        await form_handler.initialize()
        assert form_handler is not None
        assert form_handler.auto_fill is True
        assert form_handler.validation is True
        assert form_handler.submit_delay == 1000
    
    def test_field_handlers(self, form_handler):
        """Test field handler registration"""
        assert "text" in form_handler.field_handlers
        assert "email" in form_handler.field_handlers
        assert "password" in form_handler.field_handlers
        assert "select" in form_handler.field_handlers
        assert "checkbox" in form_handler.field_handlers
        assert "radio" in form_handler.field_handlers
        assert "file" in form_handler.field_handlers


class TestWebAutomationManager:
    """Test web automation manager"""
    
    @pytest.fixture
    def web_manager(self):
        """Create test web automation manager"""
        config = {
            "browser": {
                "type": "chromium",
                "headless": True,
                "timeout": 30000
            },
            "javascript": {
                "enable_stealth": True
            },
            "forms": {
                "auto_fill": True
            }
        }
        return WebAutomationManager(config)
    
    def test_web_manager_initialization(self, web_manager):
        """Test web manager initialization"""
        assert web_manager is not None
        assert not web_manager.is_initialized
        assert web_manager.browser_controller is not None
        assert web_manager.js_injector is not None
        assert web_manager.form_handler is not None
        assert web_manager.navigation_manager is not None
    
    def test_web_manager_config(self, web_manager):
        """Test web manager configuration"""
        assert web_manager.config["browser"]["type"] == "chromium"
        assert web_manager.config["browser"]["headless"] is True
        assert web_manager.config["javascript"]["enable_stealth"] is True
        assert web_manager.config["forms"]["auto_fill"] is True
    
    def test_get_status(self, web_manager):
        """Test getting web manager status"""
        status = web_manager.get_status()
        
        assert "initialized" in status
        assert "browser_type" in status
        assert "active_pages" in status
        assert "page_ids" in status
        
        assert status["initialized"] == web_manager.is_initialized
        assert status["browser_type"] == "chromium"
        assert status["active_pages"] == 0
        assert status["page_ids"] == []
    
    @pytest.mark.asyncio
    async def test_execute_task_structure(self, web_manager):
        """Test task execution structure"""
        # Mock initialization
        web_manager.is_initialized = True
        web_manager.context = Mock()
        web_manager.context.new_page = AsyncMock()
        
        mock_page = Mock()
        mock_page.set_default_timeout = Mock()
        web_manager.context.new_page.return_value = mock_page
        
        # Mock step execution
        with patch.object(web_manager, '_execute_step') as mock_execute:
            mock_execute.return_value = {"result": "success"}
            
            task_config = {
                "name": "test_task",
                "steps": [
                    {
                        "name": "test_step",
                        "action": "navigate",
                        "params": {"url": "https://example.com"}
                    }
                ]
            }
            
            result = await web_manager.execute_task(task_config)
            
            assert result["task_name"] == "test_task"
            assert result["status"] == "success"
            assert "results" in result
            assert "test_step" in result["results"]
            
            mock_execute.assert_called_once()


@pytest.mark.asyncio
async def test_web_automation_integration():
    """Integration test for web automation components"""
    config = {
        "browser": {"type": "chromium", "headless": True},
        "javascript": {"enable_stealth": False},
        "forms": {"auto_fill": True}
    }
    
    web_manager = WebAutomationManager(config)
    
    # Test component creation
    assert web_manager.browser_controller is not None
    assert web_manager.js_injector is not None
    assert web_manager.form_handler is not None
    assert web_manager.navigation_manager is not None
    
    # Test status
    status = web_manager.get_status()
    assert status["initialized"] is False
    assert status["browser_type"] == "chromium"


if __name__ == "__main__":
    pytest.main([__file__])
