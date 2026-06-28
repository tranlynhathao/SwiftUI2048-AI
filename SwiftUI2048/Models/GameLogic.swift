//
//  GameLogic.swift
//  SwiftUI2048_AI
//
//  Created by Trần Lý Nhật Hào on 12/5/25.
//

import Foundation
import SwiftUI
import Combine

final class GameLogic : ObservableObject {

    enum Direction {
        case left
        case right
        case up
        case down

        /// Direction code understood by the C++ AI / AIBridge (0=up,1=right,2=down,3=left).
        var aiCode: Int {
            switch self {
            case .up: return 0
            case .right: return 1
            case .down: return 2
            case .left: return 3
            }
        }
    }

    typealias BlockMatrixType = BlockMatrix<IdentifiedBlock>

    let objectWillChange = PassthroughSubject<GameLogic, Never>()

    fileprivate var _blockMatrix: BlockMatrixType!
    var blockMatrix: BlockMatrixType {
        return _blockMatrix
    }

    @Published fileprivate(set) var lastGestureDirection: Direction = .up

    /// True once no move can change the board.
    @Published fileprivate(set) var isGameOver: Bool = false

    @Published var isAIModeEnabled: Bool = false {
        didSet {
            guard isAIModeEnabled != oldValue else { return }
            if isAIModeEnabled {
                startAIPlaying()
            } else {
                stopAIPlaying()
            }
        }
    }

    fileprivate var _globalID = 0
    fileprivate var newGlobalID: Int {
        _globalID += 1
        return _globalID
    }

    // MARK: - AI state

    /// True while a search is in flight; guards against overlapping AI calls.
    private(set) var isAIThinking = false
    /// Delay between AI moves (seconds). Adjustable from the UI.
    var aiMoveDelay: TimeInterval = 0.25

#if os(macOS)
    // The C++ AI bridge is only wired into the macOS target. On other targets
    // (iOS / Mac Catalyst) the AI is compile-guarded out; see the report.
    private let aiPlayer: AIPlayer? = AIPlayer(depth: 1)
    /// Background queue so the (potentially slow) C++ search never blocks the UI.
    private let aiQueue = DispatchQueue(label: "com.swiftui2048.ai", qos: .userInitiated)
#endif

    init() {
        newGame()
    }

    deinit {
        isAIModeEnabled = false
    }

    func newGame() {
        let wasAIEnabled = isAIModeEnabled
        // Pause the AI loop while we reset.
        isAIModeEnabled = false

        _blockMatrix = BlockMatrixType()
        resetLastGestureDirection()
        isGameOver = false
        generateNewBlocks(count: 2) // Start with 2 blocks

        objectWillChange.send(self)

        if wasAIEnabled {
            isAIModeEnabled = true
        }
    }

    func resetLastGestureDirection() {
        lastGestureDirection = .up
    }

    // MARK: - Board snapshot helpers

    /// Current board as a plain value grid (row-major, 0 = empty).
    private func valueGrid() -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: 4), count: 4)
        for row in 0..<4 {
            for col in 0..<4 {
                if let block = _blockMatrix[(col, row)] {
                    grid[row][col] = block.number
                }
            }
        }
        return grid
    }

    // MARK: - Moves

    /// Apply a move. A new tile is spawned only when the board actually changed.
    func move(_ direction: Direction) {
        defer {
            objectWillChange.send(self)
        }

        lastGestureDirection = direction

        // Snapshot before mutating so we can detect a real change robustly.
        let before = valueGrid()

        let axis = direction == .left || direction == .right
        for row in 0..<4 {
            var compactRow = [IdentifiedBlock]()
            for col in 0..<4 {
                // Transpose if necessary.
                if let block = _blockMatrix[axis ? (col, row) : (row, col)] {
                    compactRow.append(block)
                }
            }

            merge(blocks: &compactRow, reverse: direction == .down || direction == .right)

            var newRow = [IdentifiedBlock?]()
            compactRow.forEach { newRow.append($0) }
            if compactRow.count < 4 {
                for _ in 0..<(4 - compactRow.count) {
                    if direction == .left || direction == .up {
                        newRow.append(nil)
                    } else {
                        newRow.insert(nil, at: 0)
                    }
                }
            }

            newRow.enumerated().forEach {
                _blockMatrix.place($1, to: axis ? ($0, row) : (row, $0))
            }
        }

        let moved = valueGrid() != before
        if moved {
            generateNewBlocks(count: 1) // Add 1 block after a real move
        }

        // Update game-over state after the board settles.
        isGameOver = !anyMovePossible()
    }

    fileprivate func merge(blocks: inout [IdentifiedBlock], reverse: Bool) {
        if reverse {
            blocks = blocks.reversed()
        }

        blocks = blocks
            .map { (false, $0) }
            .reduce([(Bool, IdentifiedBlock)]()) { acc, item in
                if acc.last?.0 == false && acc.last?.1.number == item.1.number {
                    var accPrefix = Array(acc.dropLast())
                    var mergedBlock = item.1
                    mergedBlock.number *= 2
                    accPrefix.append((true, mergedBlock))
                    return accPrefix
                } else {
                    var accTmp = acc
                    accTmp.append((false, item.1))
                    return accTmp
                }
            }
            .map { $0.1 }

        if reverse {
            blocks = blocks.reversed()
        }
    }

    @discardableResult fileprivate func generateNewBlocks(count: Int = 1) -> Bool {
        var blankLocations = [BlockMatrixType.Index]()
        for rowIndex in 0..<4 {
            for colIndex in 0..<4 {
                let index = (colIndex, rowIndex)
                if _blockMatrix[index] == nil {
                    blankLocations.append(index)
                }
            }
        }

        guard blankLocations.count >= count else {
            return false
        }

        // Don't forget to sync data.
        defer {
            objectWillChange.send(self)
        }

        // Place blocks (usually 1 after a move, 2 at game start)
        for _ in 0..<count {
            guard !blankLocations.isEmpty else { break }
            let placeLocIndex = Int.random(in: 0..<blankLocations.count)
            let location = blankLocations[placeLocIndex]
            // 90% chance of 2, 10% chance of 4
            let value = Int.random(in: 0..<10) == 0 ? 4 : 2
            _blockMatrix.place(IdentifiedBlock(id: newGlobalID, number: value), to: location)
            blankLocations.remove(at: placeLocIndex)
        }

        return true
    }

    /// True if any of the four directions would change the current board.
    private func anyMovePossible() -> Bool {
        let grid = valueGrid()
        let directions: [Direction] = [.up, .right, .down, .left]
        return directions.contains { GameLogic.transform(grid: grid, direction: $0).changed }
    }

    // MARK: - Pure reference slide/merge (standard 2048)

    /// Pure standard-2048 slide+merge on a value grid (0 = empty), no spawning.
    /// Used for no-op/game-over checks and for the orientation equivalence test.
    static func transform(grid: [[Int]], direction: Direction) -> (grid: [[Int]], changed: Bool) {
        func slideMerge(_ line: [Int]) -> [Int] {
            let tiles = line.filter { $0 != 0 }
            var result = [Int]()
            var i = 0
            while i < tiles.count {
                if i + 1 < tiles.count && tiles[i] == tiles[i + 1] {
                    result.append(tiles[i] * 2)
                    i += 2
                } else {
                    result.append(tiles[i])
                    i += 1
                }
            }
            while result.count < 4 { result.append(0) }
            return result
        }

        var g = grid
        switch direction {
        case .left:
            for r in 0..<4 { g[r] = slideMerge(g[r]) }
        case .right:
            for r in 0..<4 { g[r] = Array(slideMerge(Array(g[r].reversed())).reversed()) }
        case .up:
            for c in 0..<4 {
                let col = (0..<4).map { g[$0][c] }
                let merged = slideMerge(col)
                for r in 0..<4 { g[r][c] = merged[r] }
            }
        case .down:
            for c in 0..<4 {
                let col = (0..<4).map { g[$0][c] }
                let merged = Array(slideMerge(Array(col.reversed())).reversed())
                for r in 0..<4 { g[r][c] = merged[r] }
            }
        }
        return (g, g != grid)
    }

    // MARK: - AI control

    private func startAIPlaying() {
#if os(macOS)
        guard aiPlayer != nil, !isGameOver else { return }
        scheduleNextAIStep()
#endif
    }

    private func stopAIPlaying() {
        // Nothing to invalidate: pacing is driven by isAIModeEnabled guards.
    }

    /// Perform a single AI move on demand (used by the "Step" control).
    func stepAI() {
#if os(macOS)
        guard aiPlayer != nil, !isAIThinking, !isGameOver else { return }
        computeAndApply(continueRunning: false)
#endif
    }

#if os(macOS)
    /// Schedule the next AI step after the configured delay.
    private func scheduleNextAIStep() {
        guard isAIModeEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + aiMoveDelay) { [weak self] in
            guard let self = self, self.isAIModeEnabled else { return }
            self.computeAndApply(continueRunning: true)
        }
    }

    /// Run the search off the main thread, then apply on the main thread.
    private func computeAndApply(continueRunning: Bool) {
        guard let ai = aiPlayer, !isAIThinking, !isGameOver else { return }

        isAIThinking = true
        // BlockMatrix is a value type; this copy is a safe cross-thread snapshot.
        let snapshot = _blockMatrix!

        aiQueue.async { [weak self] in
            let direction = ai.bestMove(forMatrix: snapshot)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAIThinking = false

                if let direction = direction {
                    self.move(direction)
                } else {
                    // No legal move: game over.
                    self.isGameOver = true
                    self.isAIModeEnabled = false
                    self.objectWillChange.send(self)
                }

                if continueRunning && self.isAIModeEnabled && !self.isGameOver {
                    self.scheduleNextAIStep()
                }
            }
        }
    }
#endif
}
