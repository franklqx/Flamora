//
//  FlameTogglePill.swift
//  Flamora app
//
//  Unified flame toggle pill
//

import SwiftUI

struct FlameTogglePill: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .fill(
                        isOn
                        ? LinearGradient(
                            colors: [
                                Color(hex: "#A78BFA"),
                                Color(hex: "#F9A8D4"),
                                Color(hex: "#FCD34D")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [
                                Color(hex: "#121212"),
                                Color(hex: "#121212")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "#222222"), lineWidth: 1)
                    )
                    .frame(width: 80, height: 46)

                HStack {
                    if isOn { Spacer() }

                    Circle()
                        .fill(.white)
                        .frame(width: 34, height: 34)
                        .overlay(
                            FlameIcon(size: 22, color: .black)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 6, y: 3)

                    if !isOn { Spacer() }
                }
                .padding(.horizontal, 6)
                .frame(width: 80, height: 46)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            FlameTogglePill(isOn: false, action: {})
            FlameTogglePill(isOn: true, action: {})
        }
    }
}
