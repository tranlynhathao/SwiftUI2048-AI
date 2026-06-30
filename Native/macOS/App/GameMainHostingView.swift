//
//  GameMainHostingView.swift
//  SwiftUI2048_AI-mac
//
//  Created by Trần Lý Nhật Hào on 12/5/25.
//

import SwiftUI

struct GameViewWrapper : View {

    fileprivate let gameLogic: GameLogic

    var body: some View {
        GameView()
            .environmentObject(gameLogic)
    }

}

class GameMainHostingView: NSHostingView<GameViewWrapper> {

    fileprivate var gameLogic: GameLogic!

    init() {
        gameLogic = GameLogic()
        super.init(rootView: GameViewWrapper(gameLogic: gameLogic))
    }

    @objc required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(rootView: GameViewWrapper) {
        fatalError("init(rootView:) should not be called directly")
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else {
            return
        }

        // Command-key combos (Cmd-N etc.) are handled by the menu/responder
        // chain — don't intercept them here.
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }

        // Non-arrow shortcuts that work regardless of game state.
        switch event.keyCode {
        case 49: // Space — Start/Pause AI
            gameLogic.isAIModeEnabled.toggle()
            return
        case 1: // S — Step once
            gameLogic.stepAI()
            return
        case 45: // N — New Game
            newGame()
            return
        case 24, 69: // = / + (and keypad +) — faster
            cycleSpeed(faster: true)
            return
        case 27, 78: // - (and keypad -) — slower
            cycleSpeed(faster: false)
            return
        default:
            break
        }

        // Arrow keys: manual play. Ignored once the game is over.
        guard !gameLogic.isGameOver else { return }

        withTransaction(Transaction(animation: .spring())) {
            switch event.keyCode {
            case 125:
                self.gameLogic.move(.down)
            case 123:
                self.gameLogic.move(.left)
            case 124:
                self.gameLogic.move(.right)
            case 126:
                self.gameLogic.move(.up)
            default:
                super.keyDown(with: event)
            }
        }
    }

    private func cycleSpeed(faster: Bool) {
        let all = GameLogic.AISpeed.allCases
        guard let idx = all.firstIndex(of: gameLogic.aiSpeed) else { return }
        let next = faster ? min(idx + 1, all.count - 1) : max(idx - 1, 0)
        gameLogic.aiSpeed = all[next]
    }

    func newGame() {
        withTransaction(Transaction(animation: .spring())) {
            gameLogic.newGame()
        }
    }

}
