//
//  Palette.swift
//  SwiftUI2048_AI
//
//  Shared color palette for the native UI (macOS + iOS). Extracted from
//  GameView so theme constants live in one place under Native/Shared/Theme.
//

import SwiftUI

enum Palette {
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
