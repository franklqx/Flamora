//
//  ConnectAccountCTAView.swift
//  Flamora app
//
//  Shared “connect bank / Plaid” CTA for Journey, Cashflow, and Investment tabs.
//

import SwiftUI

struct ConnectAccountCTAView: View {
    let icon: String
    let glowColor: Color
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let features: [(String, String)]
    let buttonLabel: String
    let bottomPadding: CGFloat

    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xl)

                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [glowColor.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            ))
                            .frame(width: 160, height: 160)

                        Image(systemName: icon)
                            .font(.currencyHero)
                            .foregroundStyle(LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text(title)
                            .font(.h1)
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(subtitle)
                            .font(.supportingText)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(spacing: AppSpacing.cardGap) {
                        ForEach(features, id: \.0) { icon, text in
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: icon)
                                    .font(.bodyRegular)
                                    .foregroundColor(glowColor)
                                    .frame(width: 24)
                                Text(text)
                                    .font(.inlineLabel)
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Spacer(minLength: AppSpacing.xl)

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
                        .background(LinearGradient(
                            colors: AppColors.gradientFlamePill,
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }
                    .disabled(plaidManager.isConnecting)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.bottom, bottomPadding + AppSpacing.lg)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            }
        }
    }
}
