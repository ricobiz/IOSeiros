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
        
        // Configure any additional settings
        configureVisionFramework()
    }
    
    private func configureVisionFramework() {
        // Any global Vision framework configuration can go here
        // For example, setting up default recognition languages or performance settings
    }
}
