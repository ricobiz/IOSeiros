#!/usr/bin/env python3
"""
Script to download and test Qwen2-VL-2B MLX model
"""

import os
import sys
from pathlib import Path
from mlx_vlm import load, generate
from mlx_vlm.utils import load_config
import requests
from PIL import Image
import io

def download_model():
    """Download the MLX quantized Qwen2-VL-2B model"""
    model_path = "mlx-community/Qwen2-VL-2B-4bit"
    print(f"Loading model: {model_path}")
    
    try:
        # Load the model and processor
        model, processor = load(model_path)
        print("✅ Model loaded successfully!")
        return model, processor, model_path
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return None, None, None

def test_model_with_image(model, processor, image_url=None):
    """Test the model with a sample image"""
    if model is None or processor is None:
        print("❌ Model not loaded, cannot test")
        return
    
    try:
        # Use a sample image URL if none provided
        if image_url is None:
            image_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/9/93/Placeholder-No-Insignia.svg/192px-Placeholder-No-Insignia.svg.png"
        
        print(f"Downloading test image from: {image_url}")
        response = requests.get(image_url)
        image = Image.open(io.BytesIO(response.content))
        
        # Test prompt
        prompt = "Describe what you see in this image."
        
        print("🔄 Generating response...")
        response = generate(model, processor, image, prompt, verbose=False)
        
        print("✅ Model test successful!")
        print(f"Response: {response}")
        
        return response
        
    except Exception as e:
        print(f"❌ Error testing model: {e}")
        return None

def save_model_info(model_path, target_dir):
    """Save model information for iOS integration"""
    info = {
        "model_name": "Qwen2-VL-2B-4bit",
        "model_path": model_path,
        "framework": "MLX",
        "quantization": "4-bit",
        "capabilities": ["image_analysis", "text_generation", "vision_language"],
        "input_types": ["image", "text"],
        "output_type": "text"
    }
    
    info_file = Path(target_dir) / "model_info.json"
    import json
    with open(info_file, 'w') as f:
        json.dump(info, f, indent=2)
    
    print(f"✅ Model info saved to: {info_file}")

def main():
    print("🚀 Starting Qwen2-VL-2B MLX model download and test...")
    
    # Set target directory
    target_dir = Path("EirosAgent/Models/MLX")
    target_dir.mkdir(parents=True, exist_ok=True)
    
    # Download and load model
    model, processor, model_path = download_model()
    
    if model is not None:
        # Test the model
        test_model_with_image(model, processor)
        
        # Save model information
        save_model_info(model_path, target_dir)
        
        print("✅ Setup complete! Model is ready for iOS integration.")
    else:
        print("❌ Setup failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
