//
//  Theme.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import SwiftUI

enum Theme {

    // MARK: - Colour

    static let background = Color(red: 0.09, green: 0.086, blue: 0.078)
    static let ink = Color(red: 0.937, green: 0.925, blue: 0.894)
    static let muted = Color(red: 0.937, green: 0.925, blue: 0.894).opacity(0.42)
    static let line = Color(red: 0.937, green: 0.925, blue: 0.894).opacity(0.16)
    static let accent = Color(red: 0.984, green: 0.827, blue: 0.216)

    // MARK: - Type

    static let clock = Font.system(size: 80, weight: .medium, design: .monospaced)

    static let label = Font.system(size: 11, weight: .medium, design: .monospaced)

    static let body = Font.system(size: 15, weight: .medium, design: .monospaced)

    static let readout = Font.system(size: 10, weight: .regular, design: .monospaced)
}

extension View {
    func tracked(_ color: Color = Theme.muted) -> some View {
        self.font(Theme.label)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
