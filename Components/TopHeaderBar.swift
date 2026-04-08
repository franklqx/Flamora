//
//  TopHeaderBar.swift
//  Flamora app
//
//  顶部导航栏 - 页面标题风格
//

import SwiftUI

struct TopHeaderBar: View {
    let onNotificationTapped: () -> Void
    let isVisible: Bool
    static let height: CGFloat = 60

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: AppSpacing.sm) {
                FlameIcon(
                    size: 18,
                    color: AppColors.textPrimary
                )

                Text("Flamora")
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer()

            Button(action: onNotificationTapped) {
                Circle()
                    .fill(AppColors.overlayWhiteMid)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "bell")
                            .font(.figureSecondarySemibold)
                            .foregroundStyle(AppColors.textPrimary)
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.overlayWhiteStroke, lineWidth: 0.75)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .frame(height: isVisible ? nil : 0)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack {
            TopHeaderBar(
                onNotificationTapped: {},
                isVisible: true
            )
            Spacer()
        }
    }
}
