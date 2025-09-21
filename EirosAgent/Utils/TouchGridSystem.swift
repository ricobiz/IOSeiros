
//
//  TouchGridSystem.swift
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

import Foundation
import UIKit

class TouchGridSystem: ObservableObject {
    static let shared = TouchGridSystem()
    
    // MARK: - Published Properties
    @Published var isGridVisible = false
    @Published var gridSize = CGSize(width: 10, height: 18) // 10x18 grid for mobile screens
    @Published var selectedCell: GridCoordinate?
    @Published var highlightedCells: Set<GridCoordinate> = []
    
    // MARK: - Grid Properties
    private var gridCells: [[GridCell]] = []
    private let coordinateMapper = CoordinateMapper.shared
    
    // MARK: - Grid Configuration
    struct GridConfiguration {
        let columns: Int
        let rows: Int
        let cellSpacing: CGFloat
        let highlightColor: UIColor
        let gridColor: UIColor
        let opacity: CGFloat
        
        static let `default` = GridConfiguration(
            columns: 10,
            rows: 18,
            cellSpacing: 2.0,
            highlightColor: .systemBlue,
            gridColor: .systemGray,
            opacity: 0.3
        )
    }
    
    var configuration = GridConfiguration.default {
        didSet {
            gridSize = CGSize(width: configuration.columns, height: configuration.rows)
            setupGrid()
        }
    }
    
    private init() {
        setupGrid()
    }
    
    // MARK: - Grid Setup
    
    private func setupGrid() {
        let screenSize = UIScreen.main.bounds.size
        let cellWidth = screenSize.width / CGFloat(configuration.columns)
        let cellHeight = screenSize.height / CGFloat(configuration.rows)
        
        gridCells = []
        
        for row in 0..<configuration.rows {
            var rowCells: [GridCell] = []
            
            for column in 0..<configuration.columns {
                let frame = CGRect(
                    x: CGFloat(column) * cellWidth,
                    y: CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                
                let cell = GridCell(
                    coordinate: GridCoordinate(x: column, y: row),
                    frame: frame,
                    isInteractable: true
                )
                
                rowCells.append(cell)
            }
            
            gridCells.append(rowCells)
        }
    }
    
    // MARK: - Grid Interaction
    
    func showGrid() {
        isGridVisible = true
    }
    
    func hideGrid() {
        isGridVisible = false
        clearSelection()
    }
    
    func toggleGrid() {
        isGridVisible.toggle()
        if !isGridVisible {
            clearSelection()
        }
    }
    
    func selectCell(at coordinate: GridCoordinate) {
        guard isValidCoordinate(coordinate) else { return }
        
        selectedCell = coordinate
        
        // Highlight surrounding cells for better visibility
        highlightSurroundingCells(around: coordinate)
    }
    
    func selectCell(at point: CGPoint) {
        let coordinate = coordinateMapper.mapToTouchGrid(point, gridSize: gridSize)
        selectCell(at: coordinate)
    }
    
    func clearSelection() {
        selectedCell = nil
        highlightedCells.removeAll()
    }
    
    // MARK: - Grid Queries
    
    func getCell(at coordinate: GridCoordinate) -> GridCell? {
        guard isValidCoordinate(coordinate) else { return nil }
        return gridCells[coordinate.y][coordinate.x]
    }
    
    func getCell(at point: CGPoint) -> GridCell? {
        let coordinate = coordinateMapper.mapToTouchGrid(point, gridSize: gridSize)
        return getCell(at: coordinate)
    }
    
    func getCellCenter(at coordinate: GridCoordinate) -> CGPoint? {
        guard let cell = getCell(at: coordinate) else { return nil }
        return cell.frame.centerPoint
    }
    
    func getCellsInRegion(_ region: CGRect) -> [GridCell] {
        var cellsInRegion: [GridCell] = []
        
        for row in gridCells {
            for cell in row {
                if region.intersects(cell.frame) {
                    cellsInRegion.append(cell)
                }
            }
        }
        
        return cellsInRegion
    }
    
    // MARK: - UI Element Integration
    
    func mapUIElementsToGrid(_ elements: [UIAutomationElement]) -> [GridElementMapping] {
        var mappings: [GridElementMapping] = []
        
        for element in elements {
            let cellsForElement = getCellsInRegion(element.boundingBox)
            
            if !cellsForElement.isEmpty {
                let mapping = GridElementMapping(
                    element: element,
                    gridCells: cellsForElement,
                    primaryCell: findPrimaryCell(for: element.boundingBox)
                )
                mappings.append(mapping)
            }
        }
        
        return mappings
    }
    
    private func findPrimaryCell(for boundingBox: CGRect) -> GridCell? {
        let centerPoint = boundingBox.centerPoint
        return getCell(at: centerPoint)
    }
    
    func highlightElementsOnGrid(_ elements: [UIAutomationElement]) {
        clearSelection()
        
        var cellsToHighlight: Set<GridCoordinate> = []
        
        for element in elements {
            let cellsForElement = getCellsInRegion(element.boundingBox)
            for cell in cellsForElement {
                cellsToHighlight.insert(cell.coordinate)
            }
        }
        
        highlightedCells = cellsToHighlight
    }
    
    // MARK: - Touch Simulation
    
    func simulateTouch(at coordinate: GridCoordinate) -> CGPoint? {
        guard let centerPoint = getCellCenter(at: coordinate) else { return nil }
        
        // Add small random offset for more natural touch simulation
        let offset = CGPoint(
            x: CGFloat.random(in: -5...5),
            y: CGFloat.random(in: -5...5)
        )
        
        let touchPoint = CGPoint(
            x: centerPoint.x + offset.x,
            y: centerPoint.y + offset.y
        ).clampedToScreen
        
        return touchPoint
    }
    
    func simulateSwipe(from startCoordinate: GridCoordinate, to endCoordinate: GridCoordinate) -> (start: CGPoint, end: CGPoint)? {
        guard let startPoint = getCellCenter(at: startCoordinate),
              let endPoint = getCellCenter(at: endCoordinate) else {
            return nil
        }
        
        return (start: startPoint.clampedToScreen, end: endPoint.clampedToScreen)
    }
    
    // MARK: - Grid Visualization
    
    func getGridOverlayPath() -> UIBezierPath {
        let path = UIBezierPath()
        let screenSize = UIScreen.main.bounds.size
        
        // Vertical lines
        for column in 0...configuration.columns {
            let x = CGFloat(column) * (screenSize.width / CGFloat(configuration.columns))
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: screenSize.height))
        }
        
        // Horizontal lines
        for row in 0...configuration.rows {
            let y = CGFloat(row) * (screenSize.height / CGFloat(configuration.rows))
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: screenSize.width, y: y))
        }
        
        return path
    }
    
    func getHighlightPath(for coordinate: GridCoordinate) -> UIBezierPath? {
        guard let cell = getCell(at: coordinate) else { return nil }
        
        let path = UIBezierPath(rect: cell.frame)
        return path
    }
    
    // MARK: - Utility Methods
    
    private func isValidCoordinate(_ coordinate: GridCoordinate) -> Bool {
        return coordinate.x >= 0 && coordinate.x < configuration.columns &&
               coordinate.y >= 0 && coordinate.y < configuration.rows
    }
    
    private func highlightSurroundingCells(around coordinate: GridCoordinate) {
        highlightedCells.removeAll()
        
        // Highlight 3x3 area around selected cell
        for dy in -1...1 {
            for dx in -1...1 {
                let surroundingCoordinate = GridCoordinate(
                    x: coordinate.x + dx,
                    y: coordinate.y + dy
                )
                
                if isValidCoordinate(surroundingCoordinate) {
                    highlightedCells.insert(surroundingCoordinate)
                }
            }
        }
    }
    
    // MARK: - Analytics
    
    func getGridStatistics() -> GridStatistics {
        let totalCells = configuration.columns * configuration.rows
        let interactableCells = gridCells.flatMap { $0 }.filter { $0.isInteractable }.count
        
        return GridStatistics(
            totalCells: totalCells,
            interactableCells: interactableCells,
            gridSize: gridSize,
            cellSize: CGSize(
                width: UIScreen.main.bounds.width / CGFloat(configuration.columns),
                height: UIScreen.main.bounds.height / CGFloat(configuration.rows)
            )
        )
    }
}

// MARK: - Supporting Data Structures

struct GridCell {
    let coordinate: GridCoordinate
    let frame: CGRect
    let isInteractable: Bool
    var metadata: [String: Any] = [:]
    
    var centerPoint: CGPoint {
        return frame.centerPoint
    }
}

struct GridElementMapping {
    let element: UIAutomationElement
    let gridCells: [GridCell]
    let primaryCell: GridCell?
    
    var primaryCoordinate: GridCoordinate? {
        return primaryCell?.coordinate
    }
}

struct GridStatistics {
    let totalCells: Int
    let interactableCells: Int
    let gridSize: CGSize
    let cellSize: CGSize
    
    var interactabilityRatio: Double {
        return Double(interactableCells) / Double(totalCells)
    }
}

// MARK: - Extensions

extension GridCoordinate: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
    static func == (lhs: GridCoordinate, rhs: GridCoordinate) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

extension GridCoordinate {
    /// Returns the distance to another coordinate
    func distance(to other: GridCoordinate) -> Double {
        let dx = Double(other.x - x)
        let dy = Double(other.y - y)
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Returns coordinates in a radius around this coordinate
    func coordinatesInRadius(_ radius: Int) -> [GridCoordinate] {
        var coordinates: [GridCoordinate] = []
        
        for dy in -radius...radius {
            for dx in -radius...radius {
                let coordinate = GridCoordinate(x: x + dx, y: y + dy)
                if coordinate.distance(to: self) <= Double(radius) {
                    coordinates.append(coordinate)
                }
            }
        }
        
        return coordinates
    }
}
