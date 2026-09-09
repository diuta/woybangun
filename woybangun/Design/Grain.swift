//
//  Grain.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import SwiftUI

/// A tiled film-grain overlay.
///
/// The texture is a 128×128 PNG of white pixels with random alpha, tiled rather than scaled so
/// the speckles stay pixel-sized on any screen. `.allowsHitTesting(false)` keeps it from eating
/// taps, and `.overlay` means it sits above content without affecting layout.
struct Grain: View {
    var opacity: Double = 0.09

    var body: some View {
        if let texture = UIImage(named: "grain") {
            Image(uiImage: texture)
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                // Plain alpha, not `.overlay`: overlay blending all but vanishes against a
                // dark ground, which is where this app actually lives.
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
    }
}

extension View {
    /// Paints the warm background and lays grain over the whole screen.
    func grainyBackground(_ opacity: Double = 0.09) -> some View {
        self.background(Theme.background.ignoresSafeArea())
            .overlay(Grain(opacity: opacity))
    }
}
