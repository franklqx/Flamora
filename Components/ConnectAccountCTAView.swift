//
//  ConnectAccountCTAView.swift
//  Flamora app
//
//  Shared "connect bank / Plaid" CTA for Journey, Cashflow, and Investment tabs.
//  两步引导：Step 1 Link Account（激活）→ Step 2 Set Up Budget（锁定）
//

import SwiftUI

struct ConnectAccountCTAView: View {
    let icon: String
    let glowColor: Color
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let features: [(String, String)]   // 保留参数，供调用方兼容，内部不再展示
    let buttonLabel: String
    let bottomPadding: CGFloat

    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    Spacer().frame(height: AppSpacing.xl)

                    // MARK: Icon
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [glowColor.opacity(0.18), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: AppSpacing.xxl + AppSpacing.xl
                            ))
                            .frame(width: AppSpacing.xl * 5, height: AppSpacing.xl * 5)

                        Image(systemName: icon)
                            .font(.currencyHero)
                            .foregroundStyle(LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }

                    // MARK: Title + Subtitle
                    VStack(spacing: AppSpacing.sm) {
                        Text(title)
                            .font(.h1)
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(subtitle)
                            .font(.supportingText)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(AppSpacing.xs)
                    }

                    // MARK: 两步引导
                    VStack(spacing: 0) {
                        // Step 1 — 激活
                        stepCard(
                            stepNumber: "1",
                            stepTitle: "Link Your Accounts",
                            stepDescription: "Connect your bank and investment accounts via Plaid. Takes about 2 minutes.",
                            isActive: true
                        )

                        // 连接线
                        HStack {
                            Spacer().frame(width: AppSpacing.cardPadding + AppSpacing.md)
                            Rectangle()
                                .fill(AppColors.surfaceBorder)
                                .frame(width: 1.5, height: AppSpacing.lg + AppSpacing.xs)
                            Spacer()
                        }

                        // Step 2 — 锁定
                        stepCard(
                            stepNumber: "2",
                            stepTitle: "Set Up Your Budget",
                            stepDescription: "AI analyzes your spending to build a personalized FIRE plan.",
                            isActive: false
                        )
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Spacer(minLength: AppSpacing.lg)

                    // MARK: CTA Button
                    Button(action: { Task { await plaidManager.startLinkFlow() } }) {
                        HStack(spacing: AppSpacing.sm) {
                            if plaidManager.isConnecting {
                                ProgressView().tint(AppColors.textInverse)
                            } else {
                                Text(buttonLabel)
                                    .font(.statRowSemibold)
                                    .foregroundColor(AppColors.textInverse)
                                Image(systemName: "arrow.right")
                                    .font(.figureSecondarySemibold)
                                    .foregroundColor(AppColors.textInverse)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: AppColors.gradientFlamePill,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }
                    .disabled(plaidManager.isConnecting)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.bottom, bottomPadding + AppSpacing.lg)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.top, AppSpacing.lg)
            }
        }
    }

    // MARK: - Step Card

    @ViewBuilder
    private func stepCard(
        stepNumber: String,
        stepTitle: String,
        stepDescription: String,
        isActive: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {

            // 步骤圆圈
            ZStack {
                Circle()
                    .fill(
                        isActive
                            ? AnyShapeStyle(LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(AppColors.surfaceInput)
                    )
                    .frame(width: AppSpacing.xl, height: AppSpacing.xl)

                if isActive {
                    Text(stepNumber)
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.textInverse)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            // 文字
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(stepTitle)
                    .font(.bodySemibold)
                    .foregroundStyle(
                        isActive ? AppColors.textPrimary : AppColors.textTertiary
                    )

                Text(stepDescription)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(
            isActive
                ? AppColors.surface
                : AppColors.surface.opacity(0.4)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(
                    isActive ? glowColor.opacity(0.5) : AppColors.surfaceBorder,
                    lineWidth: isActive ? 1.0 : 0.75
                )
        )
    }
}
