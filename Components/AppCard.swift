//
//  AppCard.swift
//  Flamora app
//
//  统一卡片样式修饰符 - 所有页面共用
//

import SwiftUI

// MARK: - View Modifier
struct AppCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.lg

    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.cardPadding)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
            )
            // Top-edge highlight (simulates overhead lighting)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.cardTopHighlight, Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: AppColors.cardShadow, radius: 16, x: 0, y: 8)
    }
}

extension View {
    /// 应用统一的深色卡片样式
    func appCard(cornerRadius: CGFloat = AppRadius.lg) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Standalone Card Container (optional)
struct AppCard<Content: View>: View {
    var cornerRadius: CGFloat = AppRadius.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .appCard(cornerRadius: cornerRadius)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            Text("A sample card")
                .foregroundStyle(.white)
                .appCard()

            AppCard {
                VStack(alignment: .leading) {
                    Text("Another card")
                        .foregroundStyle(.white)
                    Text("With subtitle")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
    }
}
