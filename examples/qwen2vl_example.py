#!/usr/bin/env python3
"""
Qwen2VL Integration Example
Demonstrates how to use the Qwen2VL analyzer for advanced image analysis
"""

import asyncio
import sys
import os
from pathlib import Path
from PIL import Image
import yaml

# Add the parent directory to the path to import eiros_agent
sys.path.insert(0, str(Path(__file__).parent.parent))

from eiros_agent.vision import VisionManager, Qwen2VLAnalyzer
from eiros_agent.core.exceptions import VisionError


async def load_config():
    """Load configuration from YAML file"""
    config_path = Path(__file__).parent.parent / "config" / "qwen2vl_config.yaml"
    
    if config_path.exists():
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    else:
        # Default configuration
        return {
            "vision": {
                "qwen2vl": {
                    "model_name": "Qwen/Qwen2-VL-7B-Instruct",
                    "max_tokens": 1024,
                    "temperature": 0.1,
                    "enable_scene_description": True,
                    "enable_object_analysis": True,
                    "enable_text_extraction": True,
                    "enable_ui_analysis": True,
                    "enable_reasoning": True
                }
            }
        }


async def example_basic_analysis():
    """Example: Basic image analysis with Qwen2VL"""
    print("\n=== Basic Image Analysis Example ===")
    
    config = await load_config()
    vision_manager = VisionManager(config["vision"])
    
    try:
        await vision_manager.initialize()
        
        # Create a sample image for demonstration
        sample_image = Image.new('RGB', (400, 300), color='lightblue')
        
        # Analyze the image
        result = await vision_manager.analyze_with_qwen2vl(
            image=sample_image,
            prompt="Describe this image in detail",
            analysis_type="comprehensive"
        )
        
        print(f"Analysis Type: {result['analysis_type']}")
        print(f"Model: {result['model_info']['name']}")
        print(f"Confidence: {result['confidence']:.2f}")
        print(f"Content: {result['content']}")
        
    except Exception as e:
        print(f"Error in basic analysis: {e}")
    finally:
        await vision_manager.shutdown()


async def example_screen_description():
    """Example: Screen capture and description"""
    print("\n=== Screen Description Example ===")
    
    config = await load_config()
    vision_manager = VisionManager(config["vision"])
    
    try:
        await vision_manager.initialize()
        
        # Capture and describe screen
        result = await vision_manager.describe_screen_with_qwen2vl(
            region=None,  # Full screen
            detail_level="detailed"
        )
        
        print(f"Screen Description: {result['content']}")
        print(f"Processing Time: {result['model_info']['processing_time']:.2f}s")
        
    except Exception as e:
        print(f"Error in screen description: {e}")
    finally:
        await vision_manager.shutdown()


async def example_ui_analysis():
    """Example: UI element analysis"""
    print("\n=== UI Analysis Example ===")
    
    config = await load_config()
    vision_manager = VisionManager(config["vision"])
    
    try:
        await vision_manager.initialize()
        
        # Create a mock UI image
        ui_image = Image.new('RGB', (300, 500), color='white')
        
        # Analyze UI elements
        result = await vision_manager.analyze_ui_with_qwen2vl(
            image=ui_image,
            ui_type="mobile"
        )
        
        print(f"UI Analysis: {result['content']}")
        if 'ui_elements' in result:
            print(f"Detected UI Elements: {len(result['ui_elements'])}")
            for element in result['ui_elements']:
                print(f"  - {element['element_type']}: {element['text']} at {element['location']}")
        
    except Exception as e:
        print(f"Error in UI analysis: {e}")
    finally:
        await vision_manager.shutdown()


async def example_text_extraction():
    """Example: Text extraction from image"""
    print("\n=== Text Extraction Example ===")
    
    config = await load_config()
    vision_manager = VisionManager(config["vision"])
    
    try:
        await vision_manager.initialize()
        
        # Create a mock image with text
        text_image = Image.new('RGB', (400, 200), color='white')
        
        # Extract text
        result = await vision_manager.extract_text_with_qwen2vl(
            image=text_image,
            language="auto"
        )
        
        print(f"Text Extraction: {result['content']}")
        if 'extracted_text' in result:
            print("Extracted Text Elements:")
            for text_elem in result['extracted_text']:
                print(f"  - '{text_elem['text']}' at {text_elem['location']}")
        
    except Exception as e:
        print(f"Error in text extraction: {e}")
    finally:
        await vision_manager.shutdown()


async def example_visual_reasoning():
    """Example: Visual reasoning with questions"""
    print("\n=== Visual Reasoning Example ===")
    
    config = await load_config()
    vision_manager = VisionManager(config["vision"])
    
    try:
        await vision_manager.initialize()
        
        # Create a sample image
        reasoning_image = Image.new('RGB', (400, 300), color='lightgreen')
        
        # Ask a question about the image
        question = "What color is this image and what might it represent?"
        result = await vision_manager.visual_reasoning_with_qwen2vl(
            image=reasoning_image,
            question=question
        )
        
        print(f"Question: {question}")
        print(f"Answer: {result['content']}")
        print(f"Confidence: {result['confidence']:.2f}")
        
    except Exception as e:
        print(f"Error in visual reasoning: {e}")
    finally:
        await vision_manager.shutdown()


async def example_batch_analysis():
    """Example: Batch analysis of multiple images"""
    print("\n=== Batch Analysis Example ===")
    
    config = await load_config()
    vision_manager = VisionManager(config["vision"])
    
    try:
        await vision_manager.initialize()
        
        # Create multiple sample images
        images = [
            Image.new('RGB', (200, 200), color='red'),
            Image.new('RGB', (200, 200), color='blue'),
            Image.new('RGB', (200, 200), color='green')
        ]
        
        prompts = [
            "Describe this red image",
            "Describe this blue image", 
            "Describe this green image"
        ]
        
        # Batch analyze
        results = await vision_manager.batch_analyze_with_qwen2vl(
            images=images,
            prompts=prompts,
            analysis_type="scene"
        )
        
        print(f"Analyzed {len(results)} images:")
        for i, result in enumerate(results):
            if 'error' not in result:
                print(f"  Image {i+1}: {result['content'][:100]}...")
            else:
                print(f"  Image {i+1}: Error - {result['error']}")
        
    except Exception as e:
        print(f"Error in batch analysis: {e}")
    finally:
        await vision_manager.shutdown()


async def example_standalone_qwen2vl():
    """Example: Using Qwen2VL analyzer directly"""
    print("\n=== Standalone Qwen2VL Analyzer Example ===")
    
    config = await load_config()
    qwen2vl_config = config["vision"]["qwen2vl"]
    
    analyzer = Qwen2VLAnalyzer(qwen2vl_config)
    
    try:
        await analyzer.initialize()
        
        # Create sample image
        sample_image = Image.new('RGB', (300, 300), color='purple')
        
        # Different analysis types
        analyses = [
            ("comprehensive", None),
            ("scene", None),
            ("objects", None),
            ("reasoning", "What can you tell me about this image?")
        ]
        
        for analysis_type, custom_prompt in analyses:
            print(f"\n--- {analysis_type.title()} Analysis ---")
            result = await analyzer.analyze_image(
                image=sample_image,
                prompt=custom_prompt,
                analysis_type=analysis_type
            )
            print(f"Result: {result['content']}")
        
        # Test status
        status = analyzer.get_status()
        print(f"\nAnalyzer Status: {status}")
        
    except Exception as e:
        print(f"Error in standalone analysis: {e}")
    finally:
        await analyzer.shutdown()


async def main():
    """Run all examples"""
    print("Qwen2VL Integration Examples")
    print("=" * 40)
    
    examples = [
        example_basic_analysis,
        example_screen_description,
        example_ui_analysis,
        example_text_extraction,
        example_visual_reasoning,
        example_batch_analysis,
        example_standalone_qwen2vl
    ]
    
    for example_func in examples:
        try:
            await example_func()
        except Exception as e:
            print(f"Example {example_func.__name__} failed: {e}")
        
        print("\n" + "-" * 50)
    
    print("\nAll examples completed!")


if __name__ == "__main__":
    # Run the examples
    asyncio.run(main())
