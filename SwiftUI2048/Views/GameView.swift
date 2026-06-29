//
//  GameView.swift
//  SwiftUI2048_AI
//
//  Created by Trần Lý Nhật Hào on 12/5/25.
//

import SwiftUI

extension Edge {

    static func from(_ from: GameLogic.Direction) -> Self {
        switch from {
        case .down:
            return .top
        case .up:
            return .bottom
        case .left:
            return .trailing
        case .right:
            return .leading
        }
    }

}

private enum Palette {
    static let background = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let cardBackground = Color(red: 0.74, green: 0.68, blue: 0.63)
    static let cardText = Color.white
    static let title = Color(red: 0.47, green: 0.43, blue: 0.40)
    static let subtitle = Color(red: 0.60, green: 0.56, blue: 0.52)
    static let accent = Color(red: 0.20, green: 0.60, blue: 0.90)
    static let neutralButton = Color(red: 0.56, green: 0.52, blue: 0.48)
    static let warn = Color(red: 0.78, green: 0.30, blue: 0.30)
    static let win = Color(red: 0.92, green: 0.69, blue: 0.20)

    // Segmented control (matches the web demo for clear contrast).
    static let segTrack = Color(red: 0.85, green: 0.81, blue: 0.75)        // beige track
    static let segActiveFill = Color.white                                 // elevated selected pill
    static let segText = Color(red: 0.44, green: 0.40, blue: 0.36)         // dark taupe (inactive)
    static let segTextActive = Color(red: 0.29, green: 0.26, blue: 0.23)   // darker (selected)
    static let segLabel = Color(red: 0.45, green: 0.41, blue: 0.37)        // SPEED / DEPTH labels
}

/// Custom segmented control with a visible track, an elevated white selected
/// pill, and dark readable text — replaces the washed-out native
/// `SegmentedPickerStyle` on macOS.
private struct SegmentedPill<T: Hashable>: View {
    let options: [(value: T, label: String)]
    let selection: T
    var enabled: Bool = true
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options.indices, id: \.self) { i in
                let opt = options[i]
                let isSelected = opt.value == selection
                Button(action: { onSelect(opt.value) }) {
                    Text(opt.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? Palette.segTextActive : Palette.segText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Palette.segActiveFill : Color.clear)
                                .shadow(color: isSelected ? Color.black.opacity(0.14) : .clear,
                                        radius: 1.5, x: 0, y: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.segTrack))
        .opacity(enabled ? 1.0 : 0.55)
        .allowsHitTesting(enabled)
    }
}

struct GameView : View {

    @State var ignoreGesture = false
    @EnvironmentObject var gameLogic: GameLogic

    var gestureEnabled: Bool {
#if os(macOS) || targetEnvironment(macCatalyst)
        return false
#else
        return true
#endif
    }

    var gesture: some Gesture {
        let threshold: CGFloat = 44
        let drag = DragGesture()
            .onChanged { v in
                guard !self.ignoreGesture else { return }
                guard abs(v.translation.width) > threshold ||
                    abs(v.translation.height) > threshold else { return }

                withTransaction(Transaction(animation: .spring())) {
                    self.ignoreGesture = true
                    if v.translation.width > threshold {
                        self.gameLogic.move(.right)
                    } else if v.translation.width < -threshold {
                        self.gameLogic.move(.left)
                    } else if v.translation.height > threshold {
                        self.gameLogic.move(.down)
                    } else if v.translation.height < -threshold {
                        self.gameLogic.move(.up)
                    }
                }
            }
            .onEnded { _ in self.ignoreGesture = false }
        return drag
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("2048")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(Palette.title)
                Text("AI")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(Palette.accent)
                if gameLogic.hasWon {
                    Text("🏆 2048")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Palette.win))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            HStack {
                Text("C++ Expectimax Autoplay")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Palette.subtitle)
                Spacer()
            }
        }
    }

    // MARK: - Score cards

    private func scoreCard(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.white.opacity(0.85))
            Text(value)
                .font(.system(size: 19, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(highlight ? Palette.accent : Palette.cardBackground))
    }

    private var scoreCards: some View {
        HStack(spacing: 8) {
            scoreCard("Score", "\(gameLogic.score)")
            scoreCard("Best", "\(gameLogic.bestScore)")
            scoreCard("Moves", "\(gameLogic.moveCount)")
            scoreCard("Max Tile", gameLogic.maxTile > 0 ? "\(gameLogic.maxTile)" : "—",
                      highlight: gameLogic.maxTile >= 2048)
        }
    }

    // MARK: - Controls

    private func pill(_ title: String, color: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 64)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7).fill(color))
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.45)
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                pill("New Game", color: Palette.neutralButton) { gameLogic.newGame() }

#if os(macOS)
                pill(gameLogic.isAIModeEnabled ? "Pause" : "Start AI",
                     color: gameLogic.isAIModeEnabled ? Palette.warn : Palette.accent,
                     enabled: !gameLogic.isGameOver) {
                    gameLogic.isAIModeEnabled.toggle()
                }

                pill("Step", color: Palette.neutralButton,
                     enabled: !gameLogic.isAIThinking && !gameLogic.isGameOver) {
                    gameLogic.stepAI()
                }
#endif
                Spacer()
            }

#if os(macOS)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SPEED")
                        .font(.system(size: 10, weight: .heavy)).tracking(0.8)
                        .foregroundColor(Palette.segLabel)
                    SegmentedPill(
                        options: GameLogic.AISpeed.allCases.map { ($0, $0.label) },
                        selection: gameLogic.aiSpeed
                    ) { gameLogic.aiSpeed = $0 }
                    .frame(width: 248)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("DEPTH")
                        .font(.system(size: 10, weight: .heavy)).tracking(0.8)
                        .foregroundColor(Palette.segLabel)
                    SegmentedPill(
                        options: [(1, "1"), (2, "2"), (3, "3")],
                        selection: gameLogic.aiDepth
                    ) { gameLogic.aiDepth = $0 }
                    .frame(width: 120)
                }
                Spacer()
            }
#endif
        }
    }

    // MARK: - Status

    private var statusColor: Color {
        switch gameLogic.status {
        case .manual: return Palette.subtitle
        case .running: return Palette.accent
        case .thinking: return Palette.win
        case .gameOver: return Palette.warn
        }
    }

    private var statusText: String {
        switch gameLogic.status {
        case .manual:
            return "AI: Manual"
        case .running:
            return "AI: Running · \(gameLogic.aiSpeed.label) · Depth \(gameLogic.aiDepth)"
        case .thinking:
            return "AI: Thinking… · Depth \(gameLogic.aiDepth)"
        case .gameOver:
            return "Game Over"
        }
    }

    private var statusLine: some View {
        HStack(spacing: 7) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.title)
            if let dir = gameLogic.lastAIDirection {
                Text("· last \(dir.symbol)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Palette.subtitle)
            }
            Spacer()
        }
    }

    // MARK: - Board

    private var board: some View {
        BlockGridView(matrix: gameLogic.blockMatrix,
                      blockEnterEdge: .from(gameLogic.lastGestureDirection))
            .frame(width: 320, height: 320)
    }

    // MARK: - Game over overlay

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).edgesIgnoringSafeArea(.all)
            VStack(spacing: 12) {
                Text("Game Over")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                VStack(spacing: 6) {
                    overlayStat("Score", "\(gameLogic.score)")
                    overlayStat("Best", "\(gameLogic.bestScore)")
                    overlayStat("Max Tile", "\(gameLogic.maxTile)")
                    overlayStat("Moves", "\(gameLogic.moveCount)")
                    overlayStat("Time", formatTime(gameLogic.elapsed))
                    if gameLogic.movesPerSecond > 0 {
                        overlayStat("Moves/s", String(format: "%.1f", gameLogic.movesPerSecond))
                    }
                }
                pill("New Game", color: Palette.accent) { gameLogic.newGame() }
                    .padding(.top, 4)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cardBackground))
            .shadow(radius: 20)
        }
        .transition(.opacity)
    }

    private func overlayStat(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 30)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        }
        .frame(width: 180)
    }

    // MARK: - Composition

    var content: some View {
        ZStack {
            Palette.background.edgesIgnoringSafeArea(.all)

            VStack(spacing: 14) {
                header
                scoreCards
                board
                controls
                statusLine
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: 460)

            if gameLogic.isGameOver {
                gameOverOverlay
            }
        }
        .animation(.easeInOut(duration: 0.2), value: gameLogic.isGameOver)
    }

    var body: AnyView {
        return gestureEnabled ? (
            content.gesture(gesture, including: .all)>*
        ) : content>*
    }

}

#if DEBUG
struct GameView_Previews : PreviewProvider {

    static var previews: some View {
        GameView()
            .environmentObject(GameLogic())
            .frame(width: 460, height: 680)
    }

}
#endif
