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

    private var bottomPadding: CGFloat { 0 }

    var body: some View {
        JourneyView(
            bottomPadding: bottomPadding,
            onFireTapped: onFireTapped,
            onInvestmentTapped: onInvestmentTapped,
            onOpenCashflowDestination: onOpenCashflowDestination
        )
    }
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
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text(value)
                .font(.h4)
                .foregroundStyle(AppColors.textPrimary)
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
