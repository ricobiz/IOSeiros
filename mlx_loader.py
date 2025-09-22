
#!/usr/bin/env python3
"""
MLX Model Loader and Configuration Manager
Handles loading and configuration of Qwen2-VL models with MLX framework
"""

import os
import platform
import logging
from typing import Dict, Any, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)

@dataclass
class ModelConfig:
    """Configuration for Qwen2-VL models"""
    name: str
    model_path: str
    size_gb: float
    min_ram_gb: int
    recommended_ram_gb: int
    quantization: str
    description: str
    max_tokens: int = 2048
    temperature: float = 0.1

# Available Qwen2-VL model configurations
QWEN2VL_MODELS = {
    "qwen2-vl-2b-4bit": ModelConfig(
        name="Qwen2-VL-2B-4bit",
        model_path="mlx-community/Qwen2-VL-2B-4bit",
        size_gb=1.2,
        min_ram_gb=8,
        recommended_ram_gb=16,
        quantization="4-bit",
        description="Compact 2B parameter model with 4-bit quantization, ideal for testing and development"
    ),
    "qwen2-vl-7b-4bit": ModelConfig(
        name="Qwen2-VL-7B-4bit",
        model_path="mlx-community/Qwen2-VL-7B-4bit",
        size_gb=4.2,
        min_ram_gb=16,
        recommended_ram_gb=32,
        quantization="4-bit",
        description="Balanced 7B parameter model with 4-bit quantization, good performance/size ratio"
    ),
    "qwen2-vl-7b-bf16": ModelConfig(
        name="Qwen2-VL-7B-bf16",
        model_path="mlx-community/Qwen2-VL-7B-bf16",
        size_gb=14.0,
        min_ram_gb=32,
        recommended_ram_gb=64,
        quantization="bf16",
        description="High-quality 7B parameter model with bf16 precision, best accuracy"
    ),
    "qwen2-vl-72b-4bit": ModelConfig(
        name="Qwen2-VL-72B-4bit",
        model_path="mlx-community/Qwen2-VL-72B-4bit",
        size_gb=42.0,
        min_ram_gb=64,
        recommended_ram_gb=128,
        quantization="4-bit",
        description="Large 72B parameter model with 4-bit quantization, highest capability"
    )
}

class PlatformDetector:
    """Detect platform capabilities for MLX support"""
    
    @staticmethod
    def is_apple_silicon() -> bool:
        """Check if running on Apple Silicon (M1/M2/M3/M4)"""
        return (
            platform.system() == "Darwin" and 
            platform.machine() == "arm64"
        )
    
    @staticmethod
    def get_macos_version() -> Optional[Tuple[int, int]]:
        """Get macOS version as tuple (major, minor)"""
        if platform.system() != "Darwin":
            return None
        
        try:
            version_str = platform.mac_ver()[0]
            major, minor = map(int, version_str.split('.')[:2])
            return (major, minor)
        except:
            return None
    
    @staticmethod
    def check_mlx_compatibility() -> Dict[str, Any]:
        """Check MLX compatibility and requirements"""
        result = {
            "compatible": False,
            "platform": platform.system(),
            "machine": platform.machine(),
            "python_version": platform.python_version(),
            "issues": []
        }
        
        # Check Apple Silicon
        if not PlatformDetector.is_apple_silicon():
            result["issues"].append("MLX requires Apple Silicon (M1/M2/M3/M4)")
            return result
        
        # Check macOS version
        macos_version = PlatformDetector.get_macos_version()
        if macos_version is None:
            result["issues"].append("Could not determine macOS version")
            return result
        
        major, minor = macos_version
        if major < 13 or (major == 13 and minor < 5):
            result["issues"].append(f"MLX requires macOS 13.5+, found {major}.{minor}")
            return result
        
        # Check Python version
        python_version = tuple(map(int, platform.python_version().split('.')[:2]))
        if python_version < (3, 9):
            result["issues"].append(f"MLX requires Python 3.9+, found {platform.python_version()}")
            return result
        
        result["compatible"] = True
        result["macos_version"] = f"{major}.{minor}"
        return result

class MLXModelLoader:
    """MLX Model Loader for Qwen2-VL models"""
    
    def __init__(self):
        self.model = None
        self.processor = None
        self.model_config = None
        self.loaded_model_name = None
        
    def check_mlx_availability(self) -> bool:
        """Check if MLX is available and can be imported"""
        try:
            import mlx.core as mx
            import mlx_vlm
            return True
        except ImportError as e:
            logger.warning(f"MLX not available: {e}")
            return False
    
    def get_available_models(self) -> Dict[str, ModelConfig]:
        """Get list of available models"""
        return QWEN2VL_MODELS.copy()
    
    def recommend_model(self, available_ram_gb: Optional[int] = None) -> str:
        """Recommend best model based on available RAM"""
        if available_ram_gb is None:
            # Try to detect available RAM
            try:
                import psutil
                available_ram_gb = psutil.virtual_memory().total // (1024**3)
            except:
                available_ram_gb = 16  # Default assumption
        
        logger.info(f"Available RAM: {available_ram_gb}GB")
        
        # Find best model that fits in available RAM
        suitable_models = [
            (name, config) for name, config in QWEN2VL_MODELS.items()
            if config.min_ram_gb <= available_ram_gb
        ]
        
        if not suitable_models:
            return "qwen2-vl-2b-4bit"  # Fallback to smallest model
        
        # Sort by model size (descending) and return the largest that fits
        suitable_models.sort(key=lambda x: x[1].size_gb, reverse=True)
        recommended = suitable_models[0][0]
        
        logger.info(f"Recommended model: {recommended}")
        return recommended
    
    async def load_model(self, model_name: str = "auto") -> bool:
        """Load Qwen2-VL model with MLX"""
        try:
            # Check MLX availability
            if not self.check_mlx_availability():
                raise ImportError("MLX not available on this system")
            
            # Auto-select model if needed
            if model_name == "auto":
                model_name = self.recommend_model()
            
            if model_name not in QWEN2VL_MODELS:
                raise ValueError(f"Unknown model: {model_name}")
            
            self.model_config = QWEN2VL_MODELS[model_name]
            logger.info(f"Loading {self.model_config.name}...")
            
            # Import MLX VLM
            from mlx_vlm import load
            
            # Load model and processor
            logger.info(f"Downloading model from {self.model_config.model_path}...")
            self.model, self.processor = load(self.model_config.model_path)
            
            self.loaded_model_name = model_name
            logger.info(f"✅ Successfully loaded {self.model_config.name}")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to load model {model_name}: {e}")
            self.model = None
            self.processor = None
            self.model_config = None
            self.loaded_model_name = None
            return False
    
    def generate_response(self, image, prompt: str, **kwargs) -> str:
        """Generate response using loaded model"""
        if not self.model or not self.processor:
            raise RuntimeError("Model not loaded")
        
        try:
            from mlx_vlm import generate
            
            # Set default parameters
            max_tokens = kwargs.get('max_tokens', self.model_config.max_tokens)
            temperature = kwargs.get('temperature', self.model_config.temperature)
            verbose = kwargs.get('verbose', False)
            
            # Generate response
            response = generate(
                self.model, 
                self.processor, 
                image, 
                prompt,
                max_tokens=max_tokens,
                temp=temperature,
                verbose=verbose
            )
            
            return response
            
        except Exception as e:
            logger.error(f"Generation failed: {e}")
            raise
    
    def get_model_info(self) -> Optional[Dict[str, Any]]:
        """Get information about loaded model"""
        if not self.model_config:
            return None
        
        return {
            "name": self.model_config.name,
            "model_path": self.model_config.model_path,
            "size_gb": self.model_config.size_gb,
            "quantization": self.model_config.quantization,
            "description": self.model_config.description,
            "loaded": self.model is not None,
            "loaded_model_name": self.loaded_model_name
        }
    
    def unload_model(self):
        """Unload model to free memory"""
        self.model = None
        self.processor = None
        self.model_config = None
        self.loaded_model_name = None
        logger.info("Model unloaded")

# Global model loader instance
model_loader = MLXModelLoader()

def get_platform_info() -> Dict[str, Any]:
    """Get comprehensive platform information"""
    detector = PlatformDetector()
    compatibility = detector.check_mlx_compatibility()
    
    info = {
        "platform": platform.system(),
        "machine": platform.machine(),
        "python_version": platform.python_version(),
        "is_apple_silicon": detector.is_apple_silicon(),
        "mlx_compatible": compatibility["compatible"],
        "compatibility_issues": compatibility.get("issues", []),
        "available_models": list(QWEN2VL_MODELS.keys())
    }
    
    # Add macOS version if available
    macos_version = detector.get_macos_version()
    if macos_version:
        info["macos_version"] = f"{macos_version[0]}.{macos_version[1]}"
    
    # Add RAM information if available
    try:
        import psutil
        info["total_ram_gb"] = psutil.virtual_memory().total // (1024**3)
        info["available_ram_gb"] = psutil.virtual_memory().available // (1024**3)
    except:
        pass
    
    return info

if __name__ == "__main__":
    # Test platform detection and model loading
    print("🔍 Platform Detection Results:")
    print("=" * 50)
    
    info = get_platform_info()
    for key, value in info.items():
        print(f"{key}: {value}")
    
    print("\n📋 Available Models:")
    print("=" * 50)
    
    for name, config in QWEN2VL_MODELS.items():
        print(f"{name}:")
        print(f"  Name: {config.name}")
        print(f"  Size: {config.size_gb}GB")
        print(f"  Min RAM: {config.min_ram_gb}GB")
        print(f"  Quantization: {config.quantization}")
        print(f"  Description: {config.description}")
        print()
    
    if info["mlx_compatible"]:
        print("✅ MLX compatible - models can be loaded")
        recommended = model_loader.recommend_model()
        print(f"🎯 Recommended model: {recommended}")
    else:
        print("❌ MLX not compatible - fallback mode required")
        for issue in info["compatibility_issues"]:
            print(f"  • {issue}")
