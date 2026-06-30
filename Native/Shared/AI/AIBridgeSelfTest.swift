//
//  AIBridgeSelfTest.swift
//  SwiftUI2048_AI
//
//  Debug-only equivalence check for the Swift <-> C++ board encoding and
//  direction mapping. It compares the C++ engine's slide/merge (AI_ApplyMove)
//  against the pure Swift reference (GameLogic.transform) for a set of
//  representative boards across all four directions, plus an encode/decode
//  round-trip. Run automatically at launch in DEBUG builds.
//

import Foundation

enum AIBridgeSelfTest {

    /// Representative boards chosen to expose any mirror/transpose/180° error:
    /// asymmetric placements, merges, triples, and a near-full board.
    private static let boards: [[[Int]]] = [
        [[2, 0, 0, 0],
         [0, 0, 0, 0],
         [0, 0, 0, 0],
         [0, 0, 0, 0]],

        [[2, 4, 8, 16],
         [0, 0, 0, 0],
         [0, 0, 0, 0],
         [0, 0, 0, 0]],

        [[2, 0, 0, 0],
         [4, 0, 0, 0],
         [8, 0, 0, 0],
         [16, 0, 0, 0]],

        [[2, 2, 2, 0],
         [0, 4, 4, 0],
         [8, 0, 8, 0],
         [0, 0, 0, 2]],

        [[2, 4, 2, 4],
         [4, 2, 4, 2],
         [2, 4, 2, 4],
         [4, 2, 4, 0]],

        [[2, 4, 8, 16],
         [32, 64, 128, 256],
         [512, 1024, 2048, 4096],
         [8192, 16384, 32768, 2]],
    ]

    private static let directions: [GameLogic.Direction] = [.up, .right, .down, .left]

    /// Returns (passed, summary lines).
    @discardableResult
    static func run() -> (passed: Bool, report: [String]) {
        var report: [String] = []
        var passed = true

        // 1) encode/decode round-trip.
        for (i, grid) in boards.enumerated() {
            let decoded = AIBoard.decode(board: AIBoard.encode(grid: grid))
            if decoded != grid {
                passed = false
                report.append("ROUND-TRIP FAIL board #\(i): \(decoded) != \(grid)")
            }
        }

        // 2) Move equivalence: C++ AI_ApplyMove vs Swift reference transform.
        for (i, grid) in boards.enumerated() {
            for dir in directions {
                let swiftResult = GameLogic.transform(grid: grid, direction: dir).grid
                let encoded = AIBoard.encode(grid: grid)
                let cppBoard = AI_ApplyMove(encoded, Int32(dir.aiCode))
                let cppResult = AIBoard.decode(board: cppBoard)

                if swiftResult != cppResult {
                    passed = false
                    report.append("MOVE FAIL board #\(i) dir \(dir): swift=\(swiftResult) cpp=\(cppResult)")
                }

                // 3) Legality agreement.
                let swiftChanged = GameLogic.transform(grid: grid, direction: dir).changed
                let cppLegal = AI_IsMoveLegal(encoded, Int32(dir.aiCode)) == 1
                if swiftChanged != cppLegal {
                    passed = false
                    report.append("LEGAL FAIL board #\(i) dir \(dir): swift=\(swiftChanged) cpp=\(cppLegal)")
                }
            }
        }

        report.insert(passed
            ? "AIBridgeSelfTest: PASS (\(boards.count) boards × \(directions.count) directions)"
            : "AIBridgeSelfTest: FAIL", at: 0)
        return (passed, report)
    }

    /// Runs the self-test and logs the result. DEBUG builds only.
    static func runAndLog() {
        let result = run()
        for line in result.report {
            NSLog("%@", line)
            print(line)
        }
        assert(result.passed, "AIBridgeSelfTest failed — see log for the failing board/direction.")
    }
}
