//
//  TickRuler.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import SwiftUI

/// The ruler strip that recurs across the references — a row of hairlines with every fifth
/// one taller, and an optional marker showing progress through the night.
///
/// Drawn with `Canvas` rather than a stack of shapes: one draw call instead of ~60 views.
struct TickRuler: View {
    /// 0…1, or nil for no marker.
    var progress: Double?
    var height: CGFloat = 28

    private let spacing: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let count = Int(size.width / spacing)
            for index in 0...count {
                let x = CGFloat(index) * spacing
                let isMajor = index % 5 == 0
                let tickHeight = isMajor ? size.height : size.height * 0.45
                let rect = CGRect(x: x, y: size.height - tickHeight, width: 1, height: tickHeight)
                context.fill(Path(rect), with: .color(Theme.line))
            }

            if let progress {
                let x = size.width * min(max(progress, 0), 1)
                let rect = CGRect(x: x - 1, y: 0, width: 2, height: size.height)
                context.fill(Path(rect), with: .color(Theme.accent))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
