//
//  FunctionalUtils.swift
//  Swift_2048_AI
//
//  Created by Trần Lý Nhật Hào on 2/5/25.
//

func bind<T, U>(_ x: T, _ closure: (T) -> U) -> U {
    return closure(x)
}
