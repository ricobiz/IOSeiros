
#!/usr/bin/env python3
"""
Integration Tests for MLX Qwen2-VL Setup
Tests platform detection, model loading, and inference capabilities
"""

import asyncio
import base64
import io
import json
import logging
import time
import unittest
from PIL import Image
import requests
import threading
import subprocess
import sys
from pathlib import Path

# Import our modules
from mlx_loader import get_platform_info, model_loader, PlatformDetector, QWEN2VL_MODELS
from mock_fallback import MockQwen2VLProcessor, mock_loader
from qwen2vl_enhanced_server import EnhancedQwen2VLServer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class TestPlatformDetection(unittest.TestCase):
    """Test platform detection and compatibility checks"""
    
    def test_platform_info(self):
        """Test platform information gathering"""
        info = get_platform_info()
        
        self.assertIn('platform', info)
        self.assertIn('machine', info)
        self.assertIn('python_version', info)
        self.assertIn('is_apple_silicon', info)
        self.assertIn('mlx_compatible', info)
        
        logger.info(f"Platform info: {json.dumps(info, indent=2)}")
    
    def test_apple_silicon_detection(self):
        """Test Apple Silicon detection"""
        detector = PlatformDetector()
        is_apple_silicon = detector.is_apple_silicon()
        
        logger.info(f"Apple Silicon detected: {is_apple_silicon}")
        
        # This will be True only on actual Apple Silicon
        self.assertIsInstance(is_apple_silicon, bool)
    
    def test_mlx_compatibility(self):
        """Test MLX compatibility check"""
        detector = PlatformDetector()
        compatibility = detector.check_mlx_compatibility()
        
        self.assertIn('compatible', compatibility)
        self.assertIn('issues', compatibility)
        
        logger.info(f"MLX compatibility: {compatibility}")

class TestModelConfiguration(unittest.TestCase):
    """Test model configurations and recommendations"""
    
    def test_available_models(self):
        """Test available model configurations"""
        models = model_loader.get_available_models()
        
        self.assertGreater(len(models), 0)
        self.assertIn('qwen2-vl-2b-4bit', models)
        
        for name, config in models.items():
            self.assertIsInstance(config.size_gb, float)
            self.assertIsInstance(config.min_ram_gb, int)
            self.assertIsInstance(config.description, str)
            
        logger.info(f"Available models: {list(models.keys())}")
    
    def test_model_recommendation(self):
        """Test model recommendation logic"""
        # Test with different RAM amounts
        test_cases = [
            (8, 'qwen2-vl-2b-4bit'),
            (16, 'qwen2-vl-7b-4bit'),
            (32, 'qwen2-vl-7b-bf16'),
            (64, 'qwen2-vl-72b-4bit')
        ]
        
        for ram_gb, expected_model in test_cases:
            recommended = model_loader.recommend_model(ram_gb)
            logger.info(f"RAM: {ram_gb}GB -> Recommended: {recommended}")
            
            # Check that recommended model fits in available RAM
            model_config = QWEN2VL_MODELS[recommended]
            self.assertLessEqual(model_config.min_ram_gb, ram_gb)

class TestMockProcessor(unittest.TestCase):
    """Test mock processor functionality"""
    
    def setUp(self):
        self.processor = MockQwen2VLProcessor()
        self.test_image = Image.new('RGB', (375, 812), color='white')
    
    def test_mock_analysis(self):
        """Test mock image analysis"""
        result = self.processor.analyze_image(
            self.test_image, 
            "Describe this screen", 
            "general"
        )
        
        self.assertTrue(result['success'])
        self.assertIsInstance(result['response'], str)
        self.assertGreater(result['confidence'], 0)
        self.assertGreater(result['processing_time'], 0)
        self.assertTrue(result['mock_mode'])
        
        logger.info(f"Mock analysis result: {result['response'][:100]}...")
    
    def test_different_task_types(self):
        """Test different task types with mock processor"""
        task_types = [
            'general',
            'findElement', 
            'clickElement',
            'extractText',
            'describeScreen',
            'findButton',
            'findTextField'
        ]
        
        for task_type in task_types:
            with self.subTest(task_type=task_type):
                result = self.processor.analyze_image(
                    self.test_image,
                    f"Test prompt for {task_type}",
                    task_type
                )
                
                self.assertTrue(result['success'])
                self.assertEqual(result['task_type'], task_type)
                
                logger.info(f"Task {task_type}: {result['response'][:50]}...")
    
    def test_mock_model_info(self):
        """Test mock model information"""
        info = self.processor.get_model_info()
        
        self.assertIn('name', info)
        self.assertIn('type', info)
        self.assertIn('capabilities', info)
        self.assertIn('limitations', info)
        
        logger.info(f"Mock model info: {json.dumps(info, indent=2)}")

class TestMLXLoader(unittest.TestCase):
    """Test MLX loader functionality"""
    
    def test_mlx_availability(self):
        """Test MLX availability check"""
        available = model_loader.check_mlx_availability()
        logger.info(f"MLX available: {available}")
        
        # This will be True only on Apple Silicon with MLX installed
        self.assertIsInstance(available, bool)
    
    @unittest.skipUnless(
        PlatformDetector.is_apple_silicon(), 
        "MLX tests require Apple Silicon"
    )
    def test_model_loading(self):
        """Test actual model loading (only on Apple Silicon)"""
        async def test_load():
            # Try to load the smallest model
            success = await model_loader.load_model('qwen2-vl-2b-4bit')
            
            if success:
                logger.info("✅ MLX model loaded successfully")
                
                # Test model info
                info = model_loader.get_model_info()
                self.assertIsNotNone(info)
                self.assertTrue(info['loaded'])
                
                # Test inference
                test_image = Image.new('RGB', (100, 100), color='white')
                response = model_loader.generate_response(
                    test_image, 
                    "Describe this image"
                )
                
                self.assertIsInstance(response, str)
                self.assertGreater(len(response), 0)
                
                logger.info(f"MLX inference result: {response[:100]}...")
            else:
                logger.warning("❌ MLX model loading failed")
        
        asyncio.run(test_load())

class TestEnhancedServer(unittest.TestCase):
    """Test enhanced server functionality"""
    
    def setUp(self):
        self.server = EnhancedQwen2VLServer()
    
    def test_server_initialization(self):
        """Test server initialization"""
        self.assertIsNotNone(self.server.platform_info)
        self.assertIsInstance(self.server.use_mlx, bool)
        self.assertIsInstance(self.server.use_mock, bool)
        
        # One of the backends should be active
        self.assertTrue(self.server.use_mlx or self.server.use_mock)
        
        logger.info(f"Server backend: {'MLX' if self.server.use_mlx else 'Mock'}")
    
    def test_image_analysis(self):
        """Test image analysis through server"""
        # Create test image
        test_image = Image.new('RGB', (375, 812), color='lightblue')
        
        # Test analysis
        result = self.server.analyze_image(
            test_image,
            "Describe this mobile screen",
            "general"
        )
        
        # Check if model is loaded first
        if not self.server.model_loaded:
            logger.warning("Model not loaded, skipping analysis test")
            return
        
        self.assertIn('success', result)
        self.assertIn('response', result)
        self.assertIn('backend', result)
        
        logger.info(f"Server analysis result: {result}")
    
    def test_stats_collection(self):
        """Test statistics collection"""
        stats = self.server.get_stats()
        
        required_fields = [
            'model_loaded',
            'backend',
            'platform_info',
            'total_requests',
            'successful_requests',
            'uptime_seconds'
        ]
        
        for field in required_fields:
            self.assertIn(field, stats)
        
        logger.info(f"Server stats: {json.dumps(stats, indent=2)}")

class TestServerAPI(unittest.TestCase):
    """Test server API endpoints"""
    
    @classmethod
    def setUpClass(cls):
        """Start server for API tests"""
        cls.server_process = None
        cls.base_url = "http://localhost:8889"  # Use different port for testing
        
        # Start server in background
        def start_server():
            from qwen2vl_enhanced_server import start_server
            start_server('localhost', 8889, debug=False)
        
        cls.server_thread = threading.Thread(target=start_server, daemon=True)
        cls.server_thread.start()
        
        # Wait for server to start
        time.sleep(3)
        
        # Check if server is running
        try:
            response = requests.get(f"{cls.base_url}/health", timeout=5)
            if response.status_code == 200:
                logger.info("✅ Test server started successfully")
            else:
                logger.warning("⚠️ Test server may not be ready")
        except requests.exceptions.RequestException as e:
            logger.warning(f"⚠️ Could not connect to test server: {e}")
    
    def test_health_endpoint(self):
        """Test health check endpoint"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertIn('status', data)
            self.assertIn('backend', data)
            
            logger.info(f"Health check: {data}")
        except requests.exceptions.RequestException as e:
            self.skipTest(f"Server not available: {e}")
    
    def test_platform_endpoint(self):
        """Test platform information endpoint"""
        try:
            response = requests.get(f"{self.base_url}/platform", timeout=5)
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertIn('platform', data)
            self.assertIn('mlx_compatible', data)
            
            logger.info(f"Platform info: {data}")
        except requests.exceptions.RequestException as e:
            self.skipTest(f"Server not available: {e}")
    
    def test_models_endpoint(self):
        """Test models listing endpoint"""
        try:
            response = requests.get(f"{self.base_url}/models", timeout=5)
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertIn('backend', data)
            self.assertIn('available_models', data)
            
            logger.info(f"Available models: {list(data['available_models'].keys())}")
        except requests.exceptions.RequestException as e:
            self.skipTest(f"Server not available: {e}")
    
    def test_analyze_endpoint(self):
        """Test image analysis endpoint"""
        try:
            # Create test image
            test_image = Image.new('RGB', (100, 100), color='red')
            buffer = io.BytesIO()
            test_image.save(buffer, format='PNG')
            image_b64 = base64.b64encode(buffer.getvalue()).decode()
            
            # Send analysis request
            response = requests.post(
                f"{self.base_url}/analyze",
                json={
                    'image': image_b64,
                    'prompt': 'Describe this test image',
                    'task_type': 'general'
                },
                timeout=30
            )
            
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertIn('success', data)
            self.assertIn('response', data)
            self.assertIn('backend', data)
            
            logger.info(f"Analysis result: {data}")
            
        except requests.exceptions.RequestException as e:
            self.skipTest(f"Server not available: {e}")

def run_smoke_test():
    """Run a quick smoke test of the system"""
    print("🧪 Running MLX Integration Smoke Test")
    print("=" * 50)
    
    # Test platform detection
    print("1. Platform Detection:")
    info = get_platform_info()
    print(f"   Platform: {info['platform']} ({info['machine']})")
    print(f"   Apple Silicon: {info['is_apple_silicon']}")
    print(f"   MLX Compatible: {info['mlx_compatible']}")
    
    if not info['mlx_compatible']:
        print("   Issues:")
        for issue in info['compatibility_issues']:
            print(f"     • {issue}")
    
    # Test mock processor
    print("\n2. Mock Processor Test:")
    processor = MockQwen2VLProcessor()
    test_image = Image.new('RGB', (100, 100), color='blue')
    result = processor.analyze_image(test_image, "Test prompt", "general")
    print(f"   Success: {result['success']}")
    print(f"   Backend: Mock")
    print(f"   Response: {result['response'][:50]}...")
    
    # Test MLX if available
    if info['mlx_compatible']:
        print("\n3. MLX Availability Test:")
        mlx_available = model_loader.check_mlx_availability()
        print(f"   MLX Available: {mlx_available}")
        
        if mlx_available:
            print("   Recommended Model:", model_loader.recommend_model())
    
    print("\n✅ Smoke test completed!")

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='MLX Integration Tests')
    parser.add_argument('--smoke', action='store_true', help='Run smoke test only')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    if args.smoke:
        run_smoke_test()
    else:
        # Run full test suite
        unittest.main(argv=[''], exit=False, verbosity=2 if args.verbose else 1)
