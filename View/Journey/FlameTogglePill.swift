//
//  FlameTogglePill.swift
//  Flamora app
//
//  Fire/Simulator toggle — circular blue-purple style per reference design
//

import SwiftUI

struct FlameTogglePill: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isOn
                        ? LinearGradient(
                            colors: AppColors.gradientFlamePill,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [AppColors.surface, AppColors.surface],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(
                                isOn ? Color.clear : AppColors.surfaceBorder,
                                lineWidth: 0.75
                            )
                    )
                    .shadow(
                        color: isOn ? AppColors.gradientFlamePill[0].opacity(0.45) : .clear,
                        radius: 8, x: 0, y: 4
                    )

                FlameIcon(
                    size: 17,
                    color: isOn ? .white : AppColors.textTertiary
                )
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
