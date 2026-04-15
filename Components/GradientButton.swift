//
//  GradientButton.swift
//  Flamora app
//
//  渐变按钮组件 - 全局统一使用
//

import SwiftUI

struct GradientButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.statRowSemibold)
                    .foregroundColor(.black)

                if let icon {
                    Image(systemName: icon)
                        .font(.figureSecondarySemibold)
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: AppColors.gradientFire,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .shadow(
                color: AppColors.gradientStart.opacity(0.35),
                radius: 14,
                y: 6
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 20) {
            GradientButton(title: "Enter simulator") {}
            GradientButton(title: "Launch simulation", icon: "arrow.right") {}
        }
        .padding()
    }
}
