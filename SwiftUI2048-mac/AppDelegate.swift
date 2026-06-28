//
//  AppDelegate.swift
//  SwiftUI2048_AI-mac
//
//  Created by Trần Lý Nhật Hào on 12/5/25.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
#if DEBUG
        // Verify the Swift <-> C++ board encoding / direction mapping at launch.
        AIBridgeSelfTest.runAndLog()

        // Optional headless autoplay smoke test exercising the real GameLogic
        // AI loop (off-main search + main-thread apply). Enable with:
        //   AI_HEADLESS_TEST=1 ./<app binary>
        if ProcessInfo.processInfo.environment["AI_HEADLESS_TEST"] != nil {
            runHeadlessAITest()
            return
        }
#endif

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("Main Window")

        window.contentView = GameMainHostingView()

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    @objc func newGame(_ sender: Any?) {
        (window.contentView as? GameMainHostingView)?.newGame()
    }

#if DEBUG
    private var headlessGame: GameLogic?

    /// Drives the real GameLogic AI loop for a few seconds and logs progress,
    /// proving the in-app integrated autoplay path works and stays responsive.
    private func runHeadlessAITest() {
        let game = GameLogic()
        game.aiMoveDelay = 0.02
        headlessGame = game
        game.isAIModeEnabled = true
        NSLog("HeadlessAITest: started")

        func maxTile() -> Int {
            game.blockMatrix.flatten.map { $0.item.number }.max() ?? 0
        }

        // Sample a few times to confirm the main thread keeps running (not frozen)
        // while the background search produces moves.
        for i in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                NSLog("HeadlessAITest: t=%.1fs maxTile=%d gameOver=%@ thinking=%@",
                      Double(i) * 0.6, maxTile(),
                      game.isGameOver ? "true" : "false",
                      game.isAIThinking ? "true" : "false")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            NSLog("HeadlessAITest: DONE maxTile=%d", maxTile())
            NSApplication.shared.terminate(nil)
        }
    }
#endif

}

