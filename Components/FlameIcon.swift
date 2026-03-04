//
//  FlameIcon.swift
//  Flamora app
//
//  Unified flame icon style
//

import SwiftUI

struct FlameIcon: View {
    let size: CGFloat
    let color: Color
    let shadowColor: Color?
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    init(
        size: CGFloat = 20,
        color: Color = .white,
        shadowColor: Color? = nil,
        shadowRadius: CGFloat = 0,
        shadowY: CGFloat = 0
    ) {
        self.size = size
        self.color = color
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
    }

    var body: some View {
        Image("FlameIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
            .shadow(
                color: shadowColor ?? .clear,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        FlameIcon(size: 48, color: .white, shadowColor: .black.opacity(0.5), shadowRadius: 10, shadowY: 6)
    }
}
