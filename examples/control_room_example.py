
"""
Example usage of EirosAgent with Control Room
"""
import asyncio
import yaml
from pathlib import Path

from eiros_agent.core.control_room_integration import EirosAgentWithControlRoom


async def main():
    """Main example function"""
    print("🤖 Starting EirosAgent with Control Room...")
    
    # Initialize agent with Control Room
    agent = EirosAgentWithControlRoom("config/control_room_config.yaml")
    
    try:
        # Initialize all components
        await agent.initialize()
        
        print(f"✅ EirosAgent with Control Room initialized successfully!")
        print(f"🌐 Control Room web interface: {agent.get_control_room_url()}")
        print(f"📊 WebSocket server: ws://localhost:8765")
        
        # Send a welcome notification
        await agent.send_control_room_notification(
            "Welcome to Control Room",
            "EirosAgent Control Room is now running and ready for use!",
            "success"
        )
        
        # Get system status
        status = agent.get_status()
        print(f"📈 System Status:")
        print(f"  - Agent initialized: {status['initialized']}")
        print(f"  - Control Room running: {status.get('control_room', {}).get('running', False)}")
        print(f"  - Active sessions: {status.get('control_room', {}).get('active_sessions', 0)}")
        
        # Example: Capture and analyze screen
        print("\n🖥️  Capturing and analyzing screen...")
        screen_result = await agent.capture_and_analyze_screen()
        
        if screen_result:
            ocr_text = screen_result.get('ocr_result', {}).get('text', '')
            print(f"📝 OCR extracted {len(ocr_text)} characters")
            
            # Send notification about screen capture
            await agent.send_control_room_notification(
                "Screen Analysis Complete",
                f"Successfully captured and analyzed screen. Extracted {len(ocr_text)} characters.",
                "info"
            )
        
        # Example: Execute a simple web automation task
        print("\n🌐 Executing web automation task...")
        web_task = {
            "name": "example_navigation",
            "steps": [
                {
                    "name": "navigate",
                    "action": "navigate",
                    "params": {"url": "https://httpbin.org/get"}
                }
            ]
        }
        
        web_result = await agent.automate_web_task(web_task)
        print(f"🔧 Web automation result: {web_result.get('status', 'unknown')}")
        
        # Example: Execute a macro (if available)
        macro_path = Path("config/macros/example_macro.yaml")
        if macro_path.exists():
            print(f"\n📋 Executing macro: {macro_path}")
            macro_result = await agent.execute_macro(str(macro_path))
            print(f"⚙️  Macro execution result: {macro_result.get('status', 'unknown')}")
        
        print("\n🎯 Control Room Features Available:")
        print("  - Real-time system monitoring")
        print("  - Task management and execution")
        print("  - Live notifications and alerts")
        print("  - Performance metrics and analytics")
        print("  - WebSocket real-time communication")
        print("  - RESTful API endpoints")
        print("  - User profiles and settings")
        
        print(f"\n🚀 Control Room is running! Open {agent.get_control_room_url()} in your browser")
        print("Press Ctrl+C to stop...")
        
        # Keep running until interrupted
        try:
            while True:
                await asyncio.sleep(10)
                
                # Send periodic status update
                await agent.send_control_room_notification(
                    "System Heartbeat",
                    "EirosAgent is running normally",
                    "info"
                )
                
        except KeyboardInterrupt:
            print("\n⏹️  Stopping EirosAgent...")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        await agent.send_control_room_notification(
            "System Error",
            f"An error occurred: {str(e)}",
            "error"
        )
        
    finally:
        # Shutdown gracefully
        await agent.shutdown()
        print("✅ EirosAgent with Control Room stopped")


if __name__ == "__main__":
    asyncio.run(main())
