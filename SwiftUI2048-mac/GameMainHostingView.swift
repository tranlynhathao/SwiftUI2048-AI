//
//  Swift_2048_AIApp.swift
//  Swift_2048_AI
//
//  Created by Trần Lý Nhật Hào on 2/5/25.
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

        withTransaction(Transaction(animation: .spring())) {
            switch event.keyCode {
            case 125:
                self.gameLogic.move(.down)
                return
            case 123:
                self.gameLogic.move(.left)
                return
            case 124:
                self.gameLogic.move(.right)
                return
            case 126:
                self.gameLogic.move(.up)
                return
            default:
                return
            }
        }
    }

    func newGame() {
        withTransaction(Transaction(animation: .spring())) {
            gameLogic.newGame()
        }
    }

}
