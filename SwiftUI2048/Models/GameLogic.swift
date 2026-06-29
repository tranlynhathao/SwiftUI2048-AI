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

        var symbol: String {
            switch self {
            case .up: return "↑"
            case .right: return "→"
            case .down: return "↓"
            case .left: return "←"
            }
        }
    }

    /// AI pacing presets. `delay` is the gap between moves; turbo runs as fast
    /// as the search allows (still one move at a time, never overlapping).
    enum AISpeed: String, CaseIterable, Identifiable {
        case slow, normal, fast, turbo
        var id: String { rawValue }
        var delay: TimeInterval {
            switch self {
            case .slow: return 0.5
            case .normal: return 0.2
            case .fast: return 0.08
            case .turbo: return 0.0
            }
        }
        var label: String {
            switch self {
            case .slow: return "Slow"
            case .normal: return "Normal"
            case .fast: return "Fast"
            case .turbo: return "Turbo"
            }
        }
    }

    /// High-level status for the UI.
    enum AIStatus {
        case manual, running, thinking, gameOver

        var label: String {
            switch self {
            case .manual: return "Manual"
            case .running: return "Running"
            case .thinking: return "Thinking…"
            case .gameOver: return "Game Over"
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

    // MARK: - Score / stats model

    @Published fileprivate(set) var score: Int = 0
    @Published fileprivate(set) var bestScore: Int = 0
    @Published fileprivate(set) var moveCount: Int = 0
    @Published fileprivate(set) var maxTile: Int = 0
    /// True once no move can change the board.
    @Published fileprivate(set) var isGameOver: Bool = false
    /// Latches true when a 2048 tile is reached (play continues).
    @Published fileprivate(set) var hasWon: Bool = false
    /// The most recent move chosen by the AI (nil for manual moves / fresh game).
    @Published fileprivate(set) var lastAIDirection: Direction?

    private let bestScoreKey = "com.swiftui2048.bestScore"
    private(set) var gameStartDate = Date()
    private(set) var gameEndDate: Date?

    /// Duration of the current (or finished) game.
    var elapsed: TimeInterval {
        (gameEndDate ?? Date()).timeIntervalSince(gameStartDate)
    }

    var movesPerSecond: Double {
        let t = elapsed
        return t > 0 ? Double(moveCount) / t : 0
    }

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

    @Published var aiSpeed: AISpeed = .normal {
        didSet {
            aiMoveDelay = aiSpeed.delay
            objectWillChange.send(self)
        }
    }

    /// Search depth / strength. Changing it rebuilds the AI instance.
    @Published var aiDepth: Int = 1 {
        didSet {
            guard aiDepth != oldValue else { return }
#if os(macOS)
            rebuildAI()
#endif
            objectWillChange.send(self)
        }
    }

    var status: AIStatus {
        if isGameOver { return .gameOver }
        if isAIThinking { return .thinking }
        if isAIModeEnabled { return .running }
        return .manual
    }

    fileprivate var _globalID = 0
    fileprivate var newGlobalID: Int {
        _globalID += 1
        return _globalID
    }

    // MARK: - AI state

    /// True while a search is in flight; guards against overlapping AI calls.
    @Published private(set) var isAIThinking = false
    /// Delay between AI moves (seconds), derived from `aiSpeed`.
    private(set) var aiMoveDelay: TimeInterval = AISpeed.normal.delay

#if os(macOS)
    // The C++ AI bridge is only wired into the macOS target. Other targets
    // compile without the bridge.
    private var aiPlayer: AIPlayer? = AIPlayer(depth: 1)
    /// Background queue so the (potentially slow) C++ search never blocks the UI.
    private let aiQueue = DispatchQueue(label: "com.swiftui2048.ai", qos: .userInitiated)
    /// True when a delayed step is already queued (prevents double scheduling).
    private var aiStepPending = false
#endif

    init() {
        bestScore = UserDefaults.standard.integer(forKey: bestScoreKey)
        newGame()
    }

    deinit {
        isAIModeEnabled = false
    }

    func newGame() {
        // Pause the AI loop while we reset, then resume if it was on.
        let wasAIEnabled = isAIModeEnabled
        isAIModeEnabled = false

        _blockMatrix = BlockMatrixType()
        resetLastGestureDirection()
        score = 0
        moveCount = 0
        isGameOver = false
        hasWon = false
        lastAIDirection = nil
        gameStartDate = Date()
        gameEndDate = nil
        generateNewBlocks(count: 2) // Start with 2 blocks
        maxTile = currentMaxTile()

        objectWillChange.send(self)

        if wasAIEnabled {
            isAIModeEnabled = true
        }
    }

    func resetLastGestureDirection() {
        lastGestureDirection = .up
    }

    func resetBestScore() {
        bestScore = 0
        UserDefaults.standard.set(0, forKey: bestScoreKey)
        objectWillChange.send(self)
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

    private func currentMaxTile() -> Int {
        valueGrid().flatMap { $0 }.max() ?? 0
    }

    // MARK: - Moves

    /// Apply a move. A new tile is spawned only when the board actually changed,
    /// and the score increases by the value of each merged tile.
    func move(_ direction: Direction) {
        defer {
            objectWillChange.send(self)
        }

        guard !isGameOver else { return }

        lastGestureDirection = direction

        // Snapshot before mutating so we can detect a real change robustly.
        let before = valueGrid()
        var gainedScore = 0

        let axis = direction == .left || direction == .right
        for row in 0..<4 {
            var compactRow = [IdentifiedBlock]()
            for col in 0..<4 {
                // Transpose if necessary.
                if let block = _blockMatrix[axis ? (col, row) : (row, col)] {
                    compactRow.append(block)
                }
            }

            gainedScore += merge(blocks: &compactRow, reverse: direction == .down || direction == .right)

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
            score += gainedScore
            moveCount += 1
            if score > bestScore {
                bestScore = score
                UserDefaults.standard.set(bestScore, forKey: bestScoreKey)
            }
            generateNewBlocks(count: 1) // Add 1 block after a real move
        }

        maxTile = currentMaxTile()
        if maxTile >= 2048 { hasWon = true }

        // Update game-over state after the board settles.
        isGameOver = !anyMovePossible()
        if isGameOver { gameEndDate = Date() }
    }

    /// Slide+merge one line. Returns the score gained (sum of merged tile values).
    @discardableResult
    fileprivate func merge(blocks: inout [IdentifiedBlock], reverse: Bool) -> Int {
        if reverse {
            blocks = blocks.reversed()
        }

        var gained = 0
        blocks = blocks
            .map { (false, $0) }
            .reduce([(Bool, IdentifiedBlock)]()) { acc, item in
                if acc.last?.0 == false && acc.last?.1.number == item.1.number {
                    var accPrefix = Array(acc.dropLast())
                    var mergedBlock = item.1
                    mergedBlock.number *= 2
                    gained += mergedBlock.number
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
        return gained
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
        // Pacing is driven by the isAIModeEnabled guard inside the scheduled
        // block and the completion handler; any in-flight search finishes, then
        // the loop simply stops rescheduling.
    }

    /// Perform a single AI move on demand (used by the "Step" control). Works
    /// whether the AI loop is running or paused; it never overlaps a search.
    func stepAI() {
#if os(macOS)
        computeAndApply()
#endif
    }

#if os(macOS)
    private func rebuildAI() {
        // Safe even if a search is in flight: the in-flight closure retains the
        // old AIPlayer instance until it completes.
        aiPlayer = AIPlayer(depth: aiDepth)
    }

    /// Schedule the next AI step after the configured delay.
    private func scheduleNextAIStep() {
        guard isAIModeEnabled, !aiStepPending else { return }
        aiStepPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + aiMoveDelay) { [weak self] in
            guard let self = self else { return }
            self.aiStepPending = false
            guard self.isAIModeEnabled else { return }
            self.computeAndApply()
        }
    }

    /// Run the search off the main thread, then apply on the main thread.
    /// The isAIThinking guard guarantees a single search at a time.
    private func computeAndApply() {
        guard let ai = aiPlayer, !isAIThinking, !isGameOver else { return }

        isAIThinking = true
        objectWillChange.send(self)
        // BlockMatrix is a value type; this copy is a safe cross-thread snapshot.
        let snapshot = _blockMatrix!

        aiQueue.async { [weak self] in
            let direction = ai.bestMove(forMatrix: snapshot)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAIThinking = false

                if let direction = direction {
                    self.lastAIDirection = direction
                    self.move(direction)
                } else {
                    // No legal move: game over.
                    self.isGameOver = true
                    self.gameEndDate = Date()
                    self.isAIModeEnabled = false
                }

                // Continue the loop as long as the AI is enabled and the game
                // is live — regardless of whether this was an auto or manual step.
                if self.isAIModeEnabled && !self.isGameOver {
                    self.scheduleNextAIStep()
                }
                self.objectWillChange.send(self)
            }
        }
    }
#endif
}
