//
//  Grain.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import SwiftUI

struct Grain: View {
    private let opacity = 0.09

    var body: some View {
        if let texture = UIImage(named: "grain") {
            Image(uiImage: texture)
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
    }
}

extension View {
    func grainyBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
            .overlay(Grain())
    }
}
