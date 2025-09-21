
//
//  TouchGridOverlayView.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import SwiftUI

struct TouchGridOverlayView: View {
    @StateObject private var touchGridSystem = TouchGridSystem.shared
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            if touchGridSystem.isGridVisible {
                // Grid lines
                gridLinesView
                
                // Highlighted cells
                highlightedCellsView
                
                // Selected cell
                selectedCellView
                
                // Grid info overlay
                gridInfoView
            }
        }
        .allowsHitTesting(false) // Allow touches to pass through
        .animation(.easeInOut(duration: 0.3), value: touchGridSystem.isGridVisible)
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Grid Lines
    
    private var gridLinesView: some View {
        Canvas { context, size in
            let path = touchGridSystem.getGridOverlayPath()
            
            context.stroke(
                path,
                with: .color(Color(touchGridSystem.configuration.gridColor).opacity(touchGridSystem.configuration.opacity)),
                lineWidth: 1.0
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Highlighted Cells
    
    private var highlightedCellsView: some View {
        ZStack {
            ForEach(Array(touchGridSystem.highlightedCells), id: \.self) { coordinate in
                if let path = touchGridSystem.getHighlightPath(for: coordinate) {
                    Path(path.cgPath)
                        .fill(Color(touchGridSystem.configuration.highlightColor).opacity(0.3))
                        .overlay(
                            Path(path.cgPath)
                                .stroke(Color(touchGridSystem.configuration.highlightColor), lineWidth: 2)
                        )
                        .animation(.easeInOut(duration: 0.5), value: touchGridSystem.highlightedCells)
                }
            }
        }
    }
    
    // MARK: - Selected Cell
    
    private var selectedCellView: some View {
        Group {
            if let selectedCell = touchGridSystem.selectedCell,
               let path = touchGridSystem.getHighlightPath(for: selectedCell) {
                
                Path(path.cgPath)
                    .fill(Color.blue.opacity(0.4))
                    .overlay(
                        Path(path.cgPath)
                            .stroke(Color.blue, lineWidth: 3)
                            .scaleEffect(1.0 + sin(animationOffset) * 0.05)
                    )
                    .overlay(
                        // Cell coordinate label
                        Text(selectedCell.description)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(4)
                            .position(
                                x: CGFloat(selectedCell.x) * (UIScreen.main.bounds.width / touchGridSystem.gridSize.width) + (UIScreen.main.bounds.width / touchGridSystem.gridSize.width) / 2,
                                y: CGFloat(selectedCell.y) * (UIScreen.main.bounds.height / touchGridSystem.gridSize.height) + (UIScreen.main.bounds.height / touchGridSystem.gridSize.height) / 2
                            )
                    )
                    .animation(.easeInOut(duration: 0.3), value: touchGridSystem.selectedCell)
            }
        }
    }
    
    // MARK: - Grid Info
    
    private var gridInfoView: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Touch Grid")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(Int(touchGridSystem.gridSize.width))×\(Int(touchGridSystem.gridSize.height))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let selectedCell = touchGridSystem.selectedCell {
                        Text("Selected: \(selectedCell.description)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if !touchGridSystem.highlightedCells.isEmpty {
                        Text("Highlighted: \(touchGridSystem.highlightedCells.count)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding(.trailing, 16)
            }
            
            Spacer()
        }
        .padding(.top, 50) // Account for status bar and notch
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            animationOffset = .pi * 2
        }
    }
}

// MARK: - Grid Control View

struct GridControlView: View {
    @StateObject private var touchGridSystem = TouchGridSystem.shared
    @State private var showingGridSettings = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Grid toggle button
            Button(action: {
                touchGridSystem.toggleGrid()
            }) {
                HStack {
                    Image(systemName: touchGridSystem.isGridVisible ? "grid" : "grid.circle")
                    Text(touchGridSystem.isGridVisible ? "Hide Grid" : "Show Grid")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(touchGridSystem.isGridVisible ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Grid settings button
            Button(action: {
                showingGridSettings = true
            }) {
                Image(systemName: "gear")
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
            }
            
            // Grid info
            if touchGridSystem.isGridVisible {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(touchGridSystem.gridSize.width))×\(Int(touchGridSystem.gridSize.height)) Grid")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if let selectedCell = touchGridSystem.selectedCell {
                        Text("Selected: \(selectedCell.description)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingGridSettings) {
            GridSettingsView()
        }
    }
}

// MARK: - Grid Settings View

struct GridSettingsView: View {
    @StateObject private var touchGridSystem = TouchGridSystem.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var gridColumns: Double = 10
    @State private var gridRows: Double = 18
    @State private var gridOpacity: Double = 0.3
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Grid Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Columns: \(Int(gridColumns))")
                        Slider(value: $gridColumns, in: 5...20, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rows: \(Int(gridRows))")
                        Slider(value: $gridRows, in: 10...30, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Opacity: \(Int(gridOpacity * 100))%")
                        Slider(value: $gridOpacity, in: 0.1...1.0, step: 0.1)
                    }
                }
                
                Section(header: Text("Grid Statistics")) {
                    let stats = touchGridSystem.getGridStatistics()
                    
                    HStack {
                        Text("Total Cells")
                        Spacer()
                        Text("\(stats.totalCells)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Cell Size")
                        Spacer()
                        Text("\(Int(stats.cellSize.width))×\(Int(stats.cellSize.height)) pts")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Screen Coverage")
                        Spacer()
                        Text("100%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button("Reset to Default") {
                        gridColumns = 10
                        gridRows = 18
                        gridOpacity = 0.3
                        applySettings()
                    }
                    
                    Button("Clear Selection") {
                        touchGridSystem.clearSelection()
                    }
                }
            }
            .navigationTitle("Grid Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Apply") {
                    applySettings()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        gridColumns = touchGridSystem.gridSize.width
        gridRows = touchGridSystem.gridSize.height
        gridOpacity = Double(touchGridSystem.configuration.opacity)
    }
    
    private func applySettings() {
        var newConfig = touchGridSystem.configuration
        newConfig.columns = Int(gridColumns)
        newConfig.rows = Int(gridRows)
        newConfig.opacity = CGFloat(gridOpacity)
        
        touchGridSystem.configuration = newConfig
    }
}

// MARK: - Preview

struct TouchGridOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()
            
            TouchGridOverlayView()
            
            VStack {
                Spacer()
                GridControlView()
                    .padding()
            }
        }
        .onAppear {
            TouchGridSystem.shared.showGrid()
            TouchGridSystem.shared.selectCell(at: GridCoordinate(x: 5, y: 9))
        }
    }
}
