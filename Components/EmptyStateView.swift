//
//  EmptyStateView.swift
//  Meridian
//
//  Inline empty-state placeholder for cards / sections with no data yet.
//  Designed to be dropped INSIDE an existing card (which provides its own
//  header + chrome). Caller wraps with card background as needed.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppColors.inkSoft)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(AppColors.inkPrimary.opacity(0.06))
                )

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.ctaWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .fill(AppColors.ctaBlack)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint(actionTitle ?? "")
    }
}

#Preview("With action") {
    ZStack {
        AppColors.shellBg1.ignoresSafeArea()
        VStack {
            Spacer()
            EmptyStateView(
                icon: "chart.line.uptrend.xyaxis",
                title: "Track your portfolio",
                message: "Connect your brokerage to see allocation, growth, and FIRE impact in real time.",
                actionTitle: "Connect investment account",
                action: {}
            )
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.glassCard))
            .padding(AppSpacing.screenPadding)
            Spacer()
        }
    }
}

#Preview("No action") {
    ZStack {
        AppColors.shellBg1.ignoresSafeArea()
        VStack {
            Spacer()
            EmptyStateView(
                icon: "bell",
                title: "Insights coming soon",
                message: "We're watching your accounts. The first monthly insight unlocks after 30 days of activity."
            )
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.glassCard))
            .padding(AppSpacing.screenPadding)
            Spacer()
        }
    }
}
