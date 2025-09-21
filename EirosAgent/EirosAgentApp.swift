//
//  EirosAgentApp.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

@main
struct EirosAgentApp: App {
    
    init() {
        // Initialize enhanced managers
        setupEnhancedManagers()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Load the enhanced LLM model on app launch
                    Task {
                        await EnhancedLLMManager.shared.loadModel()
                    }
                }
        }
    }
    
    private func setupEnhancedManagers() {
        // Initialize singletons to ensure proper setup
        _ = VisionManager.shared
        _ = ScreenCaptureManager.shared
        _ = EnhancedLLMManager.shared
        _ = TouchGridSystem.shared
        _ = Qwen2VLManager.shared
        _ = OpenRouterManager.shared
        _ = AutomationController.shared
        
        // Configure any additional settings
        configureVisionFramework()
        configureAutomationSystem()
    }
    
    private func configureVisionFramework() {
        // Any global Vision framework configuration can go here
        // For example, setting up default recognition languages or performance settings
    }
    
    private func configureAutomationSystem() {
        // Configure TouchGridSystem
        TouchGridSystem.shared.isEnabled = true
        
        // Set default automation mode
        AutomationController.shared.setAutomationMode(.hybrid)
        
        // Load Qwen2VL model if available
        Task {
            if Qwen2VLManager.shared.isAvailable {
                await Qwen2VLManager.shared.loadModel()
            }
        }
        
        print("Automation system configured successfully")
    }
}
