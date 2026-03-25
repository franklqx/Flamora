//
//  JourneyContainerView.swift
//  Flamora app
//
//  Journey 的容器视图
//  SimulatorView 已提升到 MainTabView 作为全局覆盖层
//

import SwiftUI

struct JourneyContainerView: View {
    var onFireTapped: () -> Void = {}
    var onInvestmentTapped: (() -> Void)? = nil
    var onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private var bottomPadding: CGFloat { 0 }

    var body: some View {
        if plaidManager.hasLinkedBank {
            JourneyView(
                bottomPadding: bottomPadding,
                onFireTapped: onFireTapped,
                onInvestmentTapped: onInvestmentTapped,
                onOpenCashflowDestination: onOpenCashflowDestination
            )
        } else {
            JourneyCTAView(bottomPadding: bottomPadding)
        }
    }
}

// MARK: - Journey 初始状态 CTA

private struct JourneyCTAView: View {
    let bottomPadding: CGFloat
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xl)

                    // Hero icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        AppColors.accentPurple.opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accentPurple, AppColors.accentPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text("Build Your\nFIRE Plan")
                            .font(.h1)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Connect your accounts to see your real\nFIRE progress and net worth.")
                            .font(.supportingText)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    // Feature chips
                    VStack(spacing: 12) {
                        ForEach(features, id: \.0) { icon, text in
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.bodyRegular)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppColors.accentPurple, AppColors.accentPink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 24)

                                Text(text)
                                    .font(.inlineLabel)
                                    .foregroundStyle(.white)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Spacer(minLength: AppSpacing.xl)

                    // CTA Button
                    Button(action: {
                        Task {
                            await plaidManager.startLinkFlow()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if plaidManager.isConnecting {
                                ProgressView().tint(.black)
                            } else {
                                Text("Connect Accounts")
                                    .font(.statRowSemibold)
                                    .foregroundColor(.black)
                                Image(systemName: "arrow.right")
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
                    }
                    .disabled(plaidManager.isConnecting)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.bottom, 120)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            }
        }
    }

    private let features: [(String, String)] = [
        ("chart.line.uptrend.xyaxis", "Real-time FIRE progress tracking"),
        ("banknote", "Live net worth from all accounts"),
        ("calendar", "Monthly savings & budget trends"),
        ("sparkles", "AI-powered FIRE insights")
    ]
}

// MARK: - Analysis Card
struct AnalysisCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.detailTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentPurple, AppColors.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(title)
                .font(.supportingText)
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.h4)
                .foregroundStyle(.white)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    JourneyContainerView(onFireTapped: {})
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
