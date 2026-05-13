//
//  TopHeaderBar.swift
//  Meridian
//
//  顶部导航栏 - 页面标题风格
//

import SwiftUI

struct TopHeaderBar: View {
    let onNotificationTapped: () -> Void
    let onSettingsTapped: () -> Void
    let isVisible: Bool
    static let height: CGFloat = 60

    var body: some View {
        HStack(spacing: 10) {
            // HTML `.brand-mark`: 34pt circle, rgba(255,255,255,0.1) fill, 0.12 stroke
            Circle()
                .fill(AppColors.overlayWhiteMid)
                .overlay(
                    Circle()
                        .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
                )
                .frame(width: 34, height: 34)
                .overlay {
                    FlameIcon(size: 16, color: AppColors.heroTextPrimary)
                }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onNotificationTapped) {
                    Circle()
                        .fill(AppColors.overlayWhiteMid)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "bell")
                                .font(.figureSecondarySemibold)
                                .foregroundStyle(AppColors.heroTextPrimary)
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")
                .accessibilityHint("Open insights and reports")

                Button(action: onSettingsTapped) {
                    Circle()
                        .fill(AppColors.overlayWhiteMid)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "gearshape")
                                .font(.figureSecondarySemibold)
                                .foregroundStyle(AppColors.heroTextPrimary)
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityHint("Open account and app preferences")
            }
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
                onSettingsTapped: {},
                isVisible: true
            )
            Spacer()
        }
    }
}
