//
//  SuccessToast.swift
//  Flamora app
//
//  Lightweight celebration toast for "Net worth new high", "Goal met for May" etc.
//  Triggered via NotificationCenter so any view can post; rendered by MainTabView
//  as a full-screen overlay (alignment switches per kind: top-slide vs center-scale).
//

import SwiftUI

// MARK: - Notification + Payload

extension Notification.Name {
    /// Post with `userInfo["payload"] = SuccessMomentPayload`. MainTabView listens.
    static let successMomentDidOccur = Notification.Name("SuccessMomentDidOccur")
}

struct SuccessMomentPayload: Equatable {
    enum Kind: Equatable {
        /// Highest net worth ever — top toast, slides from top, animated up-arrow.
        case netWorthHigh
        /// Monthly savings target hit — centered celebration card, scale-in.
        case savingsGoalMet
    }
    let kind: Kind
    let title: String
    let subtitle: String?

    static func netWorthHigh(amount: Double, deltaThisMonth: Double?) -> SuccessMomentPayload {
        let amountText = formatCurrency(amount)
        let subtitle: String? = {
            guard let d = deltaThisMonth, d > 0 else { return amountText }
            return "\(amountText) · up \(formatCurrency(d)) this month"
        }()
        return SuccessMomentPayload(
            kind: .netWorthHigh,
            title: "Net worth new high",
            subtitle: subtitle
        )
    }

    static func savingsGoalMet(monthLabel: String, saved: Double, target: Double) -> SuccessMomentPayload {
        SuccessMomentPayload(
            kind: .savingsGoalMet,
            title: "Goal met for \(monthLabel)",
            subtitle: "\(formatCurrency(saved)) saved · target \(formatCurrency(target))"
        )
    }

    private static func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Toast view

struct SuccessToast: View {
    let payload: SuccessMomentPayload?

    var body: some View {
        Group {
            if let payload {
                switch payload.kind {
                case .netWorthHigh:
                    topToast(payload)
                case .savingsGoalMet:
                    centerCelebration(payload)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: Top toast (compact, slides from top)

    private func topToast(_ payload: SuccessMomentPayload) -> some View {
        HStack(spacing: AppSpacing.sm) {
            netWorthIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(payload.title)
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                    RisingArrow()
                }
                if let subtitle = payload.subtitle {
                    Text(subtitle)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .fill(AppColors.glassCardBg)
                .shadow(color: AppColors.glassCardShadow, radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Center celebration (savings goal met)
    // 较 top toast 更隆重：居中、scale-in、稍大留白、淡色光晕。

    private func centerCelebration(_ payload: SuccessMomentPayload) -> some View {
        VStack(spacing: AppSpacing.md) {
            // 大号 ✓ icon — 品牌渐变（蓝→紫，与 gradientShellAccent 一致），外圈带同色淡光晕
            ZStack {
                Circle()
                    .fill(AppColors.gradientShellAccent.first ?? AppColors.accentBlueBright)
                    .opacity(0.22)
                    .frame(width: 72, height: 72)
                    .blur(radius: 12)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: AppColors.gradientShellAccent,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppColors.ctaWhite)
            }

            VStack(spacing: AppSpacing.xs) {
                Text(payload.title)
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
                if let subtitle = payload.subtitle {
                    Text(subtitle)
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .fill(AppColors.glassCardBg)
                .shadow(color: AppColors.glassCardShadow, radius: 32, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .transition(.scale(scale: 0.88).combined(with: .opacity))
    }

    // MARK: Icons

    private var netWorthIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: AppColors.gradientFire,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            FlameIcon(size: 16, color: .white)
        }
    }
}

// MARK: - Rising arrow (inline trailing accent for "new high")

/// 小箭头持续向上漂浮 + 淡出 → 重启循环。
private struct RisingArrow: View {
    @State private var animating = false

    var body: some View {
        Image(systemName: "arrow.up")
            .font(.footnoteBold)
            .foregroundStyle(AppColors.success)
            .offset(y: animating ? -5 : 1)
            .opacity(animating ? 0.0 : 1.0)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.1)
                    .repeatForever(autoreverses: false)
                ) {
                    animating = true
                }
            }
    }
}

// MARK: - Preview

#Preview("New high (top)") {
    ZStack {
        AppColors.shellBg1.ignoresSafeArea()
        SuccessToast(payload: .netWorthHigh(amount: 123_456, deltaThisMonth: 2_400))
    }
}

#Preview("Goal met (center)") {
    ZStack {
        AppColors.shellBg1.ignoresSafeArea()
        SuccessToast(payload: .savingsGoalMet(monthLabel: "May", saved: 1_200, target: 1_000))
    }
}
