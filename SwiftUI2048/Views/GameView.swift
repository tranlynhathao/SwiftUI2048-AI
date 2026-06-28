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

struct GameView : View {

    @State var ignoreGesture = false
    @EnvironmentObject var gameLogic: GameLogic

    fileprivate struct LayoutTraits {
        let bannerOffset: CGSize
        let showsBanner: Bool
        let containerAlignment: Alignment
    }

    fileprivate func layoutTraits(`for` proxy: GeometryProxy) -> LayoutTraits {
#if os(macOS)
        let landscape = false
#else
        let landscape = proxy.size.width > proxy.size.height
#endif

        return LayoutTraits(
            bannerOffset: landscape
                ? .init(width: 32, height: 0)
                : .init(width: 0, height: 32),
            showsBanner: landscape ? proxy.size.width > 720 : proxy.size.height > 550,
            containerAlignment: landscape ? .leading : .top
        )
    }

    var gestureEnabled: Bool {
        // Existed for future usage.
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
                    abs(v.translation.height) > threshold else {
                    return
                }

                withTransaction(Transaction(animation: .spring())) {
                    self.ignoreGesture = true

                    if v.translation.width > threshold {
                        // Move right
                        self.gameLogic.move(.right)
                    } else if v.translation.width < -threshold {
                        // Move left
                        self.gameLogic.move(.left)
                    } else if v.translation.height > threshold {
                        // Move down
                        self.gameLogic.move(.down)
                    } else if v.translation.height < -threshold {
                        // Move up
                        self.gameLogic.move(.up)
                    }
                }
            }
            .onEnded { _ in
                self.ignoreGesture = false
            }
        return drag
    }

    private func pillBackground(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
    }

    @ViewBuilder
    private var controlBar: some View {
        HStack(spacing: 10) {
            Button(action: { self.gameLogic.newGame() }) {
                Text("New Game")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(pillBackground(Color(red: 0.7, green: 0.7, blue: 0.7)))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())

#if os(macOS)
            Button(action: { self.gameLogic.isAIModeEnabled.toggle() }) {
                Text(self.gameLogic.isAIModeEnabled ? "AI: ON" : "AI: OFF")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                .background(pillBackground(self.gameLogic.isAIModeEnabled
                    ? Color(red: 0.2, green: 0.6, blue: 0.9)
                    : Color(red: 0.7, green: 0.7, blue: 0.7)))
                .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { self.gameLogic.stepAI() }) {
                Text("Step")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(pillBackground(Color(red: 0.55, green: 0.55, blue: 0.6)))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(self.gameLogic.isAIModeEnabled || self.gameLogic.isGameOver)
            .opacity((self.gameLogic.isAIModeEnabled || self.gameLogic.isGameOver) ? 0.5 : 1.0)
#endif

            if self.gameLogic.isGameOver {
                Text("Game Over")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.78, green: 0.30, blue: 0.30))
            }

            Spacer()
        }
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    var content: some View {
        GeometryReader { proxy in
            bind(self.layoutTraits(for: proxy)) { layoutTraits in
                ZStack(alignment: layoutTraits.containerAlignment) {
                    if layoutTraits.showsBanner {
                        Text("2048")
                            .font(Font.system(size: 48).weight(.black))
                            .foregroundColor(Color(red:0.47, green:0.43, blue:0.40, opacity:1.00))
                            .offset(layoutTraits.bannerOffset)
                    }

                    VStack(spacing: 0) {
                        controlBar

                        // Game Board
                        Spacer()
                        ZStack(alignment: .center) {
                            BlockGridView(matrix: self.gameLogic.blockMatrix,
                                          blockEnterEdge: .from(self.gameLogic.lastGestureDirection))
                        }
                        .frame(width: min(proxy.size.width - 40, proxy.size.height - 120),
                               height: min(proxy.size.width - 40, proxy.size.height - 120),
                               alignment: .center)
                        Spacer()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                .background(
                    Rectangle()
                        .fill(Color(red:0.96, green:0.94, blue:0.90, opacity:1.00))
                        .edgesIgnoringSafeArea(.all)
                )
            }
        }
    }

    var body: AnyView {
        return gestureEnabled ? (
            content
                .gesture(gesture, including: .all)>*
        ) : content>*
    }

}

#if DEBUG
struct GameView_Previews : PreviewProvider {

    static var previews: some View {
        GameView()
            .environmentObject(GameLogic())
    }

}
#endif
