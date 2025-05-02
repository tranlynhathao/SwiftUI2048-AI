//
//  Swift_2048_AIApp.swift
//  Swift_2048_AI
//
//  Created by Trần Lý Nhật Hào on 2/5/25.
//


import SwiftUI

extension View {

    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }

}

postfix operator >*
postfix func >*<V>(lhs: V) -> AnyView where V: View {
    return lhs.eraseToAnyView()
}

