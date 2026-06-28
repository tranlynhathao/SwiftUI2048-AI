//
//  AIPlayer.swift
//  SwiftUI2048_AI
//
//  Swift wrapper for the C++ AI, reached through the C bridge declared in
//  cpp/AIBridge.h and exposed to Swift via SwiftUI2048-Bridging-Header.h.
//
//  The C functions (AI_Init, AI_Release, AI_GetBestMove, AI_ApplyMove,
//  AI_IsMoveLegal) are imported automatically from the bridging header.
//  Do NOT redeclare them here.
//

import Foundation

/// Canonical board-encoding contract between Swift and the C++ AI.
///
/// The C++ engine stores the board as a 64-bit value, one 4-bit nibble per
/// cell, nibble value = rank (0 = empty, 1 = 2, 2 = 4, 3 = 8, ...).
/// The C++ move tables slide "left" toward the high nibble of a row and "up"
/// toward the high row. To make C++ direction i correspond spatially to
/// `GameLogic.Direction` i, Swift cell (row, col) maps to nibble
/// index `(3 - row) * 4 + (3 - col)`. This is verified by the orientation
/// self-test (see `AIBridgeSelfTest`) and the standalone CLI test in scripts/.
enum AIBoard {

    static let size = 4

    /// Nibble index (0...15) for a Swift grid cell.
    @inline(__always)
    static func nibbleIndex(row: Int, col: Int) -> Int {
        return (3 - row) * 4 + (3 - col)
    }

    /// Integer-safe rank for a tile face value. Returns nil if the value is
    /// not a positive power of two within the encodable range.
    static func rank(forValue value: Int) -> Int? {
        guard value > 0, (value & (value - 1)) == 0 else { return nil } // power of two
        let r = value.trailingZeroBitCount // 2 -> 1, 4 -> 2, 8 -> 3, ...
        guard r >= 1 && r < 16 else { return nil }
        return r
    }

    /// Encode a value grid (0 = empty) into the C++ board representation.
    static func encode(grid: [[Int]]) -> UInt64 {
        var board: UInt64 = 0
        for row in 0..<size {
            for col in 0..<size {
                let value = grid[row][col]
                guard value > 0, let r = rank(forValue: value) else { continue }
                let shift = UInt64(nibbleIndex(row: row, col: col) * 4)
                board |= UInt64(r) << shift
            }
        }
        return board
    }

    /// Decode the C++ board representation back into a value grid (0 = empty).
    static func decode(board: UInt64) -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: size), count: size)
        for row in 0..<size {
            for col in 0..<size {
                let shift = UInt64(nibbleIndex(row: row, col: col) * 4)
                let r = Int((board >> shift) & 0xf)
                grid[row][col] = r == 0 ? 0 : (1 << r)
            }
        }
        return grid
    }

    /// Encode the live block matrix into the C++ board representation.
    static func encode(matrix: BlockMatrix<IdentifiedBlock>) -> UInt64 {
        var board: UInt64 = 0
        for row in 0..<size {
            for col in 0..<size {
                guard let block = matrix[(col, row)], block.number > 0,
                      let r = rank(forValue: block.number) else { continue }
                let shift = UInt64(nibbleIndex(row: row, col: col) * 4)
                board |= UInt64(r) << shift
            }
        }
        return board
    }
}

final class AIPlayer {

    private var aiInstance: UnsafeMutableRawPointer?
    private let searchDepth: Int

    /// Direction codes as defined by the C++ engine and AIBridge.h.
    enum Direction: Int {
        case up = 0
        case right = 1
        case down = 2
        case left = 3

        func toGameLogicDirection() -> GameLogic.Direction {
            switch self {
            case .up: return .up
            case .right: return .right
            case .down: return .down
            case .left: return .left
            }
        }
    }

    init(depth: Int = 1) {
        self.searchDepth = max(1, depth)
        self.aiInstance = AI_Init(Int32(self.searchDepth))
    }

    deinit {
        if let ai = aiInstance {
            AI_Release(ai)
            aiInstance = nil
        }
    }

    /// Compute the best move for the current board, or nil if no move changes
    /// the board (game over). Safe against a null handle and a -1 result.
    func bestMove(forMatrix matrix: BlockMatrix<IdentifiedBlock>) -> GameLogic.Direction? {
        guard let ai = aiInstance else { return nil }

        let board = AIBoard.encode(matrix: matrix)
        let moveInt = Int(AI_GetBestMove(ai, board))

        guard moveInt >= 0, moveInt <= 3, let dir = Direction(rawValue: moveInt) else {
            return nil
        }
        return dir.toGameLogicDirection()
    }
}
