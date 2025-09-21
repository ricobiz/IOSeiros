
"""
Tests for core EirosAgent functionality
"""
import pytest
import asyncio
from unittest.mock import Mock, patch
from eiros_agent.core import EirosAgent, Config
from eiros_agent.core.exceptions import EirosAgentError


class TestConfig:
    """Test configuration management"""
    
    def test_config_initialization(self):
        """Test config initialization"""
        config = Config()
        assert config.app is not None
        assert config.web_automation is not None
        assert config.ocr is not None
        assert config.scheduler is not None
        assert config.vision is not None
        assert config.logging is not None
    
    def test_config_get_value(self):
        """Test getting configuration values"""
        config = Config()
        
        # Test existing value
        log_level = config.get("logging.level", "DEBUG")
        assert log_level in ["INFO", "DEBUG", "WARNING", "ERROR"]
        
        # Test non-existing value with default
        non_existing = config.get("non.existing.key", "default_value")
        assert non_existing == "default_value"
    
    def test_config_update_value(self):
        """Test updating configuration values"""
        config = Config()
        
        # Update value
        config.update("test.key", "test_value")
        
        # Verify update
        assert config.get("test.key") == "test_value"


class TestEirosAgent:
    """Test main EirosAgent class"""
    
    @pytest.fixture
    async def agent(self):
        """Create test agent"""
        agent = EirosAgent()
        yield agent
        if agent.is_initialized:
            await agent.shutdown()
    
    @pytest.mark.asyncio
    async def test_agent_initialization(self, agent):
        """Test agent initialization"""
        assert not agent.is_initialized
        
        # Mock subsystem initialization
        with patch.object(agent, 'web_automation') as mock_web, \
             patch.object(agent, 'ocr_manager') as mock_ocr, \
             patch.object(agent, 'vision_manager') as mock_vision, \
             patch.object(agent, 'scheduler') as mock_scheduler:
            
            # Mock initialize methods
            mock_web.initialize = Mock(return_value=asyncio.coroutine(lambda: None)())
            mock_ocr.initialize = Mock(return_value=asyncio.coroutine(lambda: None)())
            mock_vision.initialize = Mock(return_value=asyncio.coroutine(lambda: None)())
            mock_scheduler.initialize = Mock(return_value=asyncio.coroutine(lambda: None)())
            
            await agent.initialize()
            
            assert agent.is_initialized
            mock_web.initialize.assert_called_once()
            mock_ocr.initialize.assert_called_once()
            mock_vision.initialize.assert_called_once()
            mock_scheduler.initialize.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_agent_shutdown(self, agent):
        """Test agent shutdown"""
        # Mock initialization
        agent.is_initialized = True
        agent.web_automation = Mock()
        agent.ocr_manager = Mock()
        agent.vision_manager = Mock()
        agent.scheduler = Mock()
        
        # Mock shutdown methods
        agent.web_automation.shutdown = Mock(return_value=asyncio.coroutine(lambda: None)())
        agent.ocr_manager.shutdown = Mock(return_value=asyncio.coroutine(lambda: None)())
        agent.vision_manager.shutdown = Mock(return_value=asyncio.coroutine(lambda: None)())
        agent.scheduler.shutdown = Mock(return_value=asyncio.coroutine(lambda: None)())
        
        await agent.shutdown()
        
        assert not agent.is_initialized
        agent.web_automation.shutdown.assert_called_once()
        agent.ocr_manager.shutdown.assert_called_once()
        agent.vision_manager.shutdown.assert_called_once()
        agent.scheduler.shutdown.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_agent_not_initialized_error(self, agent):
        """Test error when agent not initialized"""
        with pytest.raises(EirosAgentError, match="Agent not initialized"):
            await agent.execute_macro("test_macro.yaml")
    
    def test_agent_status(self, agent):
        """Test getting agent status"""
        status = agent.get_status()
        
        assert "initialized" in status
        assert status["initialized"] == agent.is_initialized
        assert "web_automation" in status
        assert "ocr_manager" in status
        assert "scheduler" in status
        assert "vision_manager" in status


@pytest.mark.asyncio
async def test_agent_integration():
    """Integration test for agent components"""
    agent = EirosAgent()
    
    try:
        # Test that agent can be created and basic operations work
        assert agent is not None
        assert not agent.is_initialized
        
        # Test status before initialization
        status = agent.get_status()
        assert status["initialized"] is False
        
    finally:
        if agent.is_initialized:
            await agent.shutdown()


if __name__ == "__main__":
    pytest.main([__file__])
