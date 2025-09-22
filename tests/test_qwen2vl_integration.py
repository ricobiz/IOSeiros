#!/usr/bin/env python3
"""
Tests for Qwen2VL Integration
"""

import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock
from PIL import Image
import numpy as np

# Import the modules to test
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from eiros_agent.vision.qwen2vl_analyzer import Qwen2VLAnalyzer
from eiros_agent.vision.manager import VisionManager
from eiros_agent.core.exceptions import VisionError


class TestQwen2VLAnalyzer:
    """Test cases for Qwen2VLAnalyzer"""
    
    @pytest.fixture
    def config(self):
        """Test configuration"""
        return {
            "model_name": "Qwen/Qwen2-VL-7B-Instruct",
            "max_tokens": 1024,
            "temperature": 0.1,
            "enable_scene_description": True,
            "enable_object_analysis": True,
            "enable_text_extraction": True,
            "enable_ui_analysis": True,
            "enable_reasoning": True
        }
    
    @pytest.fixture
    def sample_image(self):
        """Create a sample image for testing"""
        return Image.new('RGB', (100, 100), color='red')
    
    @pytest.fixture
    def analyzer(self, config):
        """Create analyzer instance"""
        return Qwen2VLAnalyzer(config)
    
    def test_analyzer_initialization(self, config):
        """Test analyzer initialization"""
        analyzer = Qwen2VLAnalyzer(config)
        
        assert analyzer.model_name == "Qwen/Qwen2-VL-7B-Instruct"
        assert analyzer.max_tokens == 1024
        assert analyzer.temperature == 0.1
        assert analyzer.enable_scene_description is True
        assert analyzer.is_initialized is False
    
    @pytest.mark.asyncio
    async def test_analyzer_initialize_shutdown(self, analyzer):
        """Test analyzer initialization and shutdown"""
        # Test initialization
        await analyzer.initialize()
        assert analyzer.is_initialized is True
        
        # Test shutdown
        await analyzer.shutdown()
        assert analyzer.is_initialized is False
    
    @pytest.mark.asyncio
    async def test_image_to_base64(self, analyzer, sample_image):
        """Test image to base64 conversion"""
        await analyzer.initialize()
        
        base64_str = await analyzer._image_to_base64(sample_image)
        
        assert isinstance(base64_str, str)
        assert len(base64_str) > 0
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_generate_prompts(self, analyzer):
        """Test prompt generation for different analysis types"""
        await analyzer.initialize()
        
        analysis_types = ["comprehensive", "scene", "objects", "text", "ui", "reasoning"]
        
        for analysis_type in analysis_types:
            prompt = await analyzer._generate_prompt(analysis_type)
            assert isinstance(prompt, str)
            assert len(prompt) > 0
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_analyze_image_mock(self, analyzer, sample_image):
        """Test image analysis with mocked response"""
        await analyzer.initialize()
        
        # Mock the analysis method
        with patch.object(analyzer, '_analyze_with_local_model', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = {
                "analysis": "Mock analysis result",
                "confidence": 0.95,
                "processing_time": 1.0,
                "model_version": "test_version"
            }
            
            result = await analyzer.analyze_image(sample_image, analysis_type="comprehensive")
            
            assert result["analysis_type"] == "comprehensive"
            assert result["confidence"] == 0.95
            assert result["content"] == "Mock analysis result"
            assert "model_info" in result
            
            mock_analyze.assert_called_once()
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_scene_description(self, analyzer, sample_image):
        """Test scene description functionality"""
        await analyzer.initialize()
        
        with patch.object(analyzer, 'analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = {"content": "Mock scene description"}
            
            result = await analyzer.describe_scene(sample_image, detail_level="detailed")
            
            mock_analyze.assert_called_once()
            args, kwargs = mock_analyze.call_args
            assert kwargs["analysis_type"] == "scene"
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_object_analysis(self, analyzer, sample_image):
        """Test object analysis functionality"""
        await analyzer.initialize()
        
        with patch.object(analyzer, 'analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = {"content": "Mock object analysis"}
            
            result = await analyzer.analyze_objects(sample_image, focus_objects=["car", "person"])
            
            mock_analyze.assert_called_once()
            args, kwargs = mock_analyze.call_args
            assert kwargs["analysis_type"] == "objects"
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_text_extraction(self, analyzer, sample_image):
        """Test text extraction functionality"""
        await analyzer.initialize()
        
        with patch.object(analyzer, 'analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = {"content": "Mock text extraction"}
            
            result = await analyzer.extract_text(sample_image, language="en")
            
            mock_analyze.assert_called_once()
            args, kwargs = mock_analyze.call_args
            assert kwargs["analysis_type"] == "text"
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_ui_analysis(self, analyzer, sample_image):
        """Test UI analysis functionality"""
        await analyzer.initialize()
        
        with patch.object(analyzer, 'analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = {"content": "Mock UI analysis"}
            
            result = await analyzer.analyze_ui_elements(sample_image, ui_type="mobile")
            
            mock_analyze.assert_called_once()
            args, kwargs = mock_analyze.call_args
            assert kwargs["analysis_type"] == "ui"
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_visual_reasoning(self, analyzer, sample_image):
        """Test visual reasoning functionality"""
        await analyzer.initialize()
        
        with patch.object(analyzer, 'analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = {"content": "Mock reasoning result"}
            
            question = "What color is this image?"
            result = await analyzer.visual_reasoning(sample_image, question)
            
            mock_analyze.assert_called_once()
            args, kwargs = mock_analyze.call_args
            assert kwargs["analysis_type"] == "reasoning"
            assert question in kwargs["prompt"]
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_batch_analysis(self, analyzer):
        """Test batch analysis functionality"""
        await analyzer.initialize()
        
        # Create multiple test images
        images = [
            Image.new('RGB', (50, 50), color='red'),
            Image.new('RGB', (50, 50), color='blue'),
            Image.new('RGB', (50, 50), color='green')
        ]
        
        with patch.object(analyzer, 'analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = {"content": "Mock analysis"}
            
            results = await analyzer.batch_analyze(images, analysis_type="scene")
            
            assert len(results) == 3
            assert mock_analyze.call_count == 3
        
        await analyzer.shutdown()
    
    @pytest.mark.asyncio
    async def test_error_handling(self, analyzer, sample_image):
        """Test error handling"""
        # Test without initialization
        with pytest.raises(VisionError):
            await analyzer.analyze_image(sample_image)
        
        # Test with initialization
        await analyzer.initialize()
        
        # Mock an error in analysis
        with patch.object(analyzer, '_analyze_with_local_model', side_effect=Exception("Mock error")):
            with pytest.raises(VisionError):
                await analyzer.analyze_image(sample_image)
        
        await analyzer.shutdown()
    
    def test_get_status(self, analyzer):
        """Test status reporting"""
        status = analyzer.get_status()
        
        assert "initialized" in status
        assert "model_name" in status
        assert "capabilities" in status
        assert "config" in status
        
        assert status["model_name"] == "Qwen/Qwen2-VL-7B-Instruct"
        assert status["capabilities"]["scene_description"] is True


class TestVisionManagerQwen2VLIntegration:
    """Test cases for VisionManager with Qwen2VL integration"""
    
    @pytest.fixture
    def vision_config(self):
        """Vision manager configuration with Qwen2VL"""
        return {
            "screen_capture": {},
            "analysis": {},
            "object_detection": {},
            "qwen2vl": {
                "model_name": "Qwen/Qwen2-VL-7B-Instruct",
                "max_tokens": 512,
                "temperature": 0.1
            }
        }
    
    @pytest.fixture
    def sample_image(self):
        """Create a sample image for testing"""
        return Image.new('RGB', (200, 200), color='blue')
    
    @pytest.mark.asyncio
    async def test_vision_manager_qwen2vl_initialization(self, vision_config):
        """Test VisionManager initialization with Qwen2VL"""
        vision_manager = VisionManager(vision_config)
        
        # Check that Qwen2VL analyzer is created
        assert hasattr(vision_manager, 'qwen2vl_analyzer')
        assert vision_manager.qwen2vl_analyzer is not None
        
        # Mock the initialization of all components
        with patch.multiple(
            vision_manager,
            screen_capture=Mock(),
            image_analyzer=Mock(),
            object_detector=Mock(),
            qwen2vl_analyzer=Mock()
        ):
            # Mock async initialize methods
            vision_manager.screen_capture.initialize = AsyncMock()
            vision_manager.image_analyzer.initialize = AsyncMock()
            vision_manager.object_detector.initialize = AsyncMock()
            vision_manager.qwen2vl_analyzer.initialize = AsyncMock()
            
            await vision_manager.initialize()
            
            # Verify all components were initialized
            vision_manager.screen_capture.initialize.assert_called_once()
            vision_manager.image_analyzer.initialize.assert_called_once()
            vision_manager.object_detector.initialize.assert_called_once()
            vision_manager.qwen2vl_analyzer.initialize.assert_called_once()
            
            assert vision_manager.is_initialized is True
    
    @pytest.mark.asyncio
    async def test_analyze_with_qwen2vl(self, vision_config, sample_image):
        """Test analyze_with_qwen2vl method"""
        vision_manager = VisionManager(vision_config)
        
        # Mock the qwen2vl_analyzer
        vision_manager.qwen2vl_analyzer = Mock()
        vision_manager.qwen2vl_analyzer.analyze_image = AsyncMock(
            return_value={"content": "Mock analysis result"}
        )
        vision_manager.is_initialized = True
        
        result = await vision_manager.analyze_with_qwen2vl(
            image=sample_image,
            prompt="Test prompt",
            analysis_type="comprehensive"
        )
        
        vision_manager.qwen2vl_analyzer.analyze_image.assert_called_once_with(
            sample_image, "Test prompt", "comprehensive"
        )
        assert result["content"] == "Mock analysis result"
    
    @pytest.mark.asyncio
    async def test_describe_screen_with_qwen2vl(self, vision_config):
        """Test describe_screen_with_qwen2vl method"""
        vision_manager = VisionManager(vision_config)
        
        # Mock components
        vision_manager.qwen2vl_analyzer = Mock()
        vision_manager.qwen2vl_analyzer.describe_scene = AsyncMock(
            return_value={"content": "Mock screen description"}
        )
        vision_manager.capture_screen = AsyncMock(
            return_value=Image.new('RGB', (100, 100), color='white')
        )
        vision_manager.is_initialized = True
        
        result = await vision_manager.describe_screen_with_qwen2vl(
            region=None,
            detail_level="detailed"
        )
        
        vision_manager.capture_screen.assert_called_once_with(None)
        vision_manager.qwen2vl_analyzer.describe_scene.assert_called_once()
        assert result["content"] == "Mock screen description"
    
    @pytest.mark.asyncio
    async def test_analyze_ui_with_qwen2vl(self, vision_config, sample_image):
        """Test analyze_ui_with_qwen2vl method"""
        vision_manager = VisionManager(vision_config)
        
        # Mock the qwen2vl_analyzer
        vision_manager.qwen2vl_analyzer = Mock()
        vision_manager.qwen2vl_analyzer.analyze_ui_elements = AsyncMock(
            return_value={"content": "Mock UI analysis"}
        )
        vision_manager.is_initialized = True
        
        result = await vision_manager.analyze_ui_with_qwen2vl(
            image=sample_image,
            ui_type="mobile"
        )
        
        vision_manager.qwen2vl_analyzer.analyze_ui_elements.assert_called_once_with(
            sample_image, "mobile"
        )
        assert result["content"] == "Mock UI analysis"
    
    @pytest.mark.asyncio
    async def test_extract_text_with_qwen2vl(self, vision_config, sample_image):
        """Test extract_text_with_qwen2vl method"""
        vision_manager = VisionManager(vision_config)
        
        # Mock the qwen2vl_analyzer
        vision_manager.qwen2vl_analyzer = Mock()
        vision_manager.qwen2vl_analyzer.extract_text = AsyncMock(
            return_value={"content": "Mock text extraction"}
        )
        vision_manager.is_initialized = True
        
        result = await vision_manager.extract_text_with_qwen2vl(
            image=sample_image,
            language="en"
        )
        
        vision_manager.qwen2vl_analyzer.extract_text.assert_called_once_with(
            sample_image, "en"
        )
        assert result["content"] == "Mock text extraction"
    
    @pytest.mark.asyncio
    async def test_visual_reasoning_with_qwen2vl(self, vision_config, sample_image):
        """Test visual_reasoning_with_qwen2vl method"""
        vision_manager = VisionManager(vision_config)
        
        # Mock the qwen2vl_analyzer
        vision_manager.qwen2vl_analyzer = Mock()
        vision_manager.qwen2vl_analyzer.visual_reasoning = AsyncMock(
            return_value={"content": "Mock reasoning result"}
        )
        vision_manager.is_initialized = True
        
        question = "What is in this image?"
        result = await vision_manager.visual_reasoning_with_qwen2vl(
            image=sample_image,
            question=question
        )
        
        vision_manager.qwen2vl_analyzer.visual_reasoning.assert_called_once_with(
            sample_image, question
        )
        assert result["content"] == "Mock reasoning result"
    
    @pytest.mark.asyncio
    async def test_batch_analyze_with_qwen2vl(self, vision_config):
        """Test batch_analyze_with_qwen2vl method"""
        vision_manager = VisionManager(vision_config)
        
        # Create test images
        images = [
            Image.new('RGB', (50, 50), color='red'),
            Image.new('RGB', (50, 50), color='blue')
        ]
        
        # Mock the qwen2vl_analyzer
        vision_manager.qwen2vl_analyzer = Mock()
        vision_manager.qwen2vl_analyzer.batch_analyze = AsyncMock(
            return_value=[{"content": "Result 1"}, {"content": "Result 2"}]
        )
        vision_manager.is_initialized = True
        
        results = await vision_manager.batch_analyze_with_qwen2vl(
            images=images,
            prompts=["Prompt 1", "Prompt 2"],
            analysis_type="scene"
        )
        
        vision_manager.qwen2vl_analyzer.batch_analyze.assert_called_once()
        assert len(results) == 2
        assert results[0]["content"] == "Result 1"
        assert results[1]["content"] == "Result 2"
    
    @pytest.mark.asyncio
    async def test_error_handling_not_initialized(self, vision_config, sample_image):
        """Test error handling when not initialized"""
        vision_manager = VisionManager(vision_config)
        
        with pytest.raises(VisionError, match="Vision system not initialized"):
            await vision_manager.analyze_with_qwen2vl(sample_image)
    
    def test_get_status_includes_qwen2vl(self, vision_config):
        """Test that get_status includes Qwen2VL analyzer status"""
        vision_manager = VisionManager(vision_config)
        
        # Mock all components
        vision_manager.screen_capture = Mock()
        vision_manager.image_analyzer = Mock()
        vision_manager.object_detector = Mock()
        vision_manager.qwen2vl_analyzer = Mock()
        
        # Mock get_status methods
        vision_manager.screen_capture.get_status.return_value = {"status": "ok"}
        vision_manager.image_analyzer.get_status.return_value = {"status": "ok"}
        vision_manager.object_detector.get_status.return_value = {"status": "ok"}
        vision_manager.qwen2vl_analyzer.get_status.return_value = {"status": "ok"}
        
        status = vision_manager.get_status()
        
        assert "qwen2vl_analyzer" in status
        assert status["qwen2vl_analyzer"]["status"] == "ok"


class TestIntegrationScenarios:
    """Integration test scenarios"""
    
    @pytest.mark.asyncio
    async def test_full_workflow(self):
        """Test a complete workflow with Qwen2VL"""
        config = {
            "screen_capture": {},
            "analysis": {},
            "object_detection": {},
            "qwen2vl": {
                "model_name": "Qwen/Qwen2-VL-7B-Instruct",
                "max_tokens": 512,
                "temperature": 0.1
            }
        }
        
        vision_manager = VisionManager(config)
        
        # Mock all components
        with patch.multiple(
            vision_manager,
            screen_capture=Mock(),
            image_analyzer=Mock(),
            object_detector=Mock(),
            qwen2vl_analyzer=Mock()
        ):
            # Setup async mocks
            vision_manager.screen_capture.initialize = AsyncMock()
            vision_manager.image_analyzer.initialize = AsyncMock()
            vision_manager.object_detector.initialize = AsyncMock()
            vision_manager.qwen2vl_analyzer.initialize = AsyncMock()
            
            vision_manager.screen_capture.shutdown = AsyncMock()
            vision_manager.image_analyzer.shutdown = AsyncMock()
            vision_manager.object_detector.shutdown = AsyncMock()
            vision_manager.qwen2vl_analyzer.shutdown = AsyncMock()
            
            vision_manager.capture_screen = AsyncMock(
                return_value=Image.new('RGB', (100, 100), color='white')
            )
            vision_manager.qwen2vl_analyzer.describe_scene = AsyncMock(
                return_value={"content": "A white screen"}
            )
            vision_manager.qwen2vl_analyzer.analyze_ui_elements = AsyncMock(
                return_value={"content": "No UI elements found"}
            )
            
            # Initialize
            await vision_manager.initialize()
            assert vision_manager.is_initialized
            
            # Perform analysis workflow
            screen_description = await vision_manager.describe_screen_with_qwen2vl()
            assert screen_description["content"] == "A white screen"
            
            # Analyze UI
            screenshot = await vision_manager.capture_screen()
            ui_analysis = await vision_manager.analyze_ui_with_qwen2vl(screenshot)
            assert ui_analysis["content"] == "No UI elements found"
            
            # Shutdown
            await vision_manager.shutdown()
            assert not vision_manager.is_initialized


if __name__ == "__main__":
    # Run tests
    pytest.main([__file__, "-v"])
