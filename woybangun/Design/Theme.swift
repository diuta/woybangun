//
//  Theme.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import SwiftUI

/// The app's visual language: warm dark, grainy, oversized numerals, one yellow accent.
///
/// Plain static values rather than an injected `@Observable` theme — there is only one
/// palette, so there is nothing to observe. If a light mode is ever added, this becomes an
/// instance type and moves into `@Environment`.
enum Theme {

    // MARK: - Colour
    // Warm near-black rather than pure black, and cream rather than pure white. Neutral greys
    // read as cold and clinical; the references are all warm.

    static let background = Color(red: 0.09, green: 0.086, blue: 0.078)
    /// Cards and raised surfaces, a step up from the background.
    static let surface = Color(red: 0.145, green: 0.137, blue: 0.125)
    /// Primary text.
    static let ink = Color(red: 0.937, green: 0.925, blue: 0.894)
    /// Secondary text, and the muted half of the split time display.
    static let muted = Color(red: 0.937, green: 0.925, blue: 0.894).opacity(0.42)
    /// Hairlines and tick marks.
    static let line = Color(red: 0.937, green: 0.925, blue: 0.894).opacity(0.16)
    /// The single accent, from the yellow pill in the first reference.
    static let accent = Color(red: 0.984, green: 0.827, blue: 0.216)

    // MARK: - Type
    // Monospaced throughout: it is what makes digits feel mechanical, and it stops the time
    // from reflowing as the numbers change.

    /// The hero clock.
    static func clock(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// Small uppercase labels. Pair with `.tracked()`.
    static let label = Font.system(size: 11, weight: .medium, design: .monospaced)

    /// Buttons and body copy.
    static let body = Font.system(size: 15, weight: .medium, design: .monospaced)

    static let readout = Font.system(size: 10, weight: .regular, design: .monospaced)
}

extension View {
    /// Uppercase, letterspaced, muted — the small-caps label style used throughout.
    func tracked(_ color: Color = Theme.muted) -> some View {
        self.font(Theme.label)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
