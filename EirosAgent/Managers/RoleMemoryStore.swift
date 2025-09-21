
//
//  RoleMemoryStore.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import Combine

@MainActor
class RoleMemoryStore: ObservableObject {
    static let shared = RoleMemoryStore()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var lastSaveTime: Date?
    @Published var memorySize: [AIRoleType: Int] = [:]
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let memoryDirectory: URL
    
    private init() {
        // Setup directories
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        memoryDirectory = documentsDirectory.appendingPathComponent("AIRoleMemories")
        
        createMemoryDirectoryIfNeeded()
        loadMemorySizes()
    }
    
    // MARK: - Directory Management
    
    private func createMemoryDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: memoryDirectory.path) {
            try? fileManager.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func getMemoryFileURL(for roleType: AIRoleType) -> URL {
        return memoryDirectory.appendingPathComponent("\(roleType.rawValue)_memory.json")
    }
    
    // MARK: - Memory Operations
    
    func saveMemory(_ memory: RoleMemoryContext, for roleType: AIRoleType) async {
        isLoading = true
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(memory)
            let fileURL = getMemoryFileURL(for: roleType)
            
            try data.write(to: fileURL)
            
            // Update metadata
            lastSaveTime = Date()
            memorySize[roleType] = data.count
            
            print("RoleMemoryStore: Saved memory for \(roleType.displayName) (\(data.count) bytes)")
            
        } catch {
            print("RoleMemoryStore: Failed to save memory for \(roleType.displayName): \(error)")
        }
        
        isLoading = false
    }
    
    func loadMemory(for roleType: AIRoleType) async -> RoleMemoryContext {
        isLoading = true
        
        let fileURL = getMemoryFileURL(for: roleType)
        var memory = RoleMemoryContext()
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                memory = try decoder.decode(RoleMemoryContext.self, from: data)
                memorySize[roleType] = data.count
                
                print("RoleMemoryStore: Loaded memory for \(roleType.displayName) (\(data.count) bytes)")
            } else {
                print("RoleMemoryStore: No existing memory file for \(roleType.displayName), using default")
            }
        } catch {
            print("RoleMemoryStore: Failed to load memory for \(roleType.displayName): \(error)")
            memory = RoleMemoryContext() // Return default on error
        }
        
        isLoading = false
        return memory
    }
    
    func clearMemory(for roleType: AIRoleType) async {
        let fileURL = getMemoryFileURL(for: roleType)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                memorySize[roleType] = 0
                print("RoleMemoryStore: Cleared memory for \(roleType.displayName)")
            }
        } catch {
            print("RoleMemoryStore: Failed to clear memory for \(roleType.displayName): \(error)")
        }
    }
    
    func clearAllMemories() async {
        for roleType in AIRoleType.allCases {
            await clearMemory(for: roleType)
        }
        lastSaveTime = nil
    }
    
    // MARK: - Memory Analytics
    
    func getMemoryStats() -> MemoryStats {
        let totalSize = memorySize.values.reduce(0, +)
        let roleCount = memorySize.filter { $0.value > 0 }.count
        
        return MemoryStats(
            totalSize: totalSize,
            rolesWithMemory: roleCount,
            lastSaveTime: lastSaveTime,
            memoryByRole: memorySize
        )
    }
    
    func getMemoryUsage(for roleType: AIRoleType) -> MemoryUsage {
        let size = memorySize[roleType] ?? 0
        let fileURL = getMemoryFileURL(for: roleType)
        let exists = fileManager.fileExists(atPath: fileURL.path)
        
        var lastModified: Date?
        if exists {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                lastModified = attributes[.modificationDate] as? Date
            } catch {
                print("RoleMemoryStore: Failed to get file attributes: \(error)")
            }
        }
        
        return MemoryUsage(
            roleType: roleType,
            size: size,
            exists: exists,
            lastModified: lastModified
        )
    }
    
    private func loadMemorySizes() {
        for roleType in AIRoleType.allCases {
            let fileURL = getMemoryFileURL(for: roleType)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    if let size = attributes[.size] as? Int {
                        memorySize[roleType] = size
                    }
                } catch {
                    print("RoleMemoryStore: Failed to get size for \(roleType.displayName): \(error)")
                }
            }
        }
    }
    
    // MARK: - Memory Export/Import
    
    func exportMemory(for roleType: AIRoleType) async -> Data? {
        let fileURL = getMemoryFileURL(for: roleType)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                return try Data(contentsOf: fileURL)
            }
        } catch {
            print("RoleMemoryStore: Failed to export memory for \(roleType.displayName): \(error)")
        }
        
        return nil
    }
    
    func importMemory(_ data: Data, for roleType: AIRoleType) async -> Bool {
        do {
            // Validate data by trying to decode it
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            _ = try decoder.decode(RoleMemoryContext.self, from: data)
            
            // If validation passes, save the data
            let fileURL = getMemoryFileURL(for: roleType)
            try data.write(to: fileURL)
            
            memorySize[roleType] = data.count
            lastSaveTime = Date()
            
            print("RoleMemoryStore: Imported memory for \(roleType.displayName)")
            return true
            
        } catch {
            print("RoleMemoryStore: Failed to import memory for \(roleType.displayName): \(error)")
            return false
        }
    }
    
    // MARK: - Memory Backup
    
    func createBackup() async -> URL? {
        let backupURL = documentsDirectory.appendingPathComponent("AIRoleMemories_Backup_\(Date().timeIntervalSince1970).zip")
        
        // For simplicity, we'll create a directory backup instead of zip
        let backupDir = documentsDirectory.appendingPathComponent("AIRoleMemories_Backup_\(Date().timeIntervalSince1970)")
        
        do {
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
            
            for roleType in AIRoleType.allCases {
                let sourceURL = getMemoryFileURL(for: roleType)
                let destURL = backupDir.appendingPathComponent("\(roleType.rawValue)_memory.json")
                
                if fileManager.fileExists(atPath: sourceURL.path) {
                    try fileManager.copyItem(at: sourceURL, to: destURL)
                }
            }
            
            print("RoleMemoryStore: Created backup at \(backupDir.path)")
            return backupDir
            
        } catch {
            print("RoleMemoryStore: Failed to create backup: \(error)")
            return nil
        }
    }
    
    func restoreFromBackup(_ backupURL: URL) async -> Bool {
        do {
            for roleType in AIRoleType.allCases {
                let backupFileURL = backupURL.appendingPathComponent("\(roleType.rawValue)_memory.json")
                let destURL = getMemoryFileURL(for: roleType)
                
                if fileManager.fileExists(atPath: backupFileURL.path) {
                    // Remove existing file if it exists
                    if fileManager.fileExists(atPath: destURL.path) {
                        try fileManager.removeItem(at: destURL)
                    }
                    
                    try fileManager.copyItem(at: backupFileURL, to: destURL)
                }
            }
            
            loadMemorySizes()
            lastSaveTime = Date()
            
            print("RoleMemoryStore: Restored from backup")
            return true
            
        } catch {
            print("RoleMemoryStore: Failed to restore from backup: \(error)")
            return false
        }
    }
}

// MARK: - Supporting Data Models

struct MemoryStats {
    let totalSize: Int
    let rolesWithMemory: Int
    let lastSaveTime: Date?
    let memoryByRole: [AIRoleType: Int]
    
    var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    var formattedLastSaveTime: String {
        guard let lastSaveTime = lastSaveTime else { return "Никогда" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastSaveTime)
    }
}

struct MemoryUsage {
    let roleType: AIRoleType
    let size: Int
    let exists: Bool
    let lastModified: Date?
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var formattedLastModified: String {
        guard let lastModified = lastModified else { return "Неизвестно" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastModified)
    }
}
