//
//  BudgetPlanCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetPlanCard: View {
    let apiBudget: APIMonthlyBudget
    let daysLeft: Int
    var onSetupBudget: (() -> Void)? = nil
    var action: (() -> Void)? = nil

    @Environment(PlaidManager.self) private var plaidManager
    @AppStorage(FlamoraStorageKey.budgetSetupCompleted) private var budgetSetupCompleted: Bool = false

    private static let setupSteps: [(String, String)] = [
        ("link", "Link\nAccounts"),
        ("cpu", "AI\nAnalysis"),
        ("target", "Set\nGoal"),
        ("chart.bar.fill", "Optimize\nBudget"),
    ]

    private static let progressBarHeight: CGFloat = (AppSpacing.sm + AppSpacing.xs) / 2

    // MARK: - Computed

    private var hasLinkedBank: Bool { plaidManager.hasLinkedBank }

    private var hasBudget: Bool {
        budgetSetupCompleted
        && hasLinkedBank
        && (apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget) > 0
        && apiBudget.selectedPlan != nil
    }

    private var spent: Double {
        (apiBudget.needsSpent ?? 0) + (apiBudget.wantsSpent ?? 0)
    }
    private var limit: Double {
        apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
    }
    private var remaining: Double { limit - spent }
    private var spentPercent: Int {
        limit > 0 ? Int((spent / limit * 100).rounded()) : 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if !hasBudget {
                setupContent
            } else {
                connectedContent
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack {
            Text("BUDGET")
                .font(.cardHeader)
                .foregroundColor(AppColors.textTertiary)
                .tracking(AppTypography.Tracking.cardHeader)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                Text(currentMonthLabel)
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                if hasLinkedBank && hasBudget {
                    Image(systemName: "chevron.right")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            if hasLinkedBank && hasBudget { action?() }
        }
    }

    // MARK: - State 1: 无预算（Build Your Plan）

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Build Your Plan")
                    .font(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Let AI analyze your spending and create a personalized budget to accelerate your FIRE journey.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(Self.setupSteps, id: \.0) { icon, label in
                    VStack(spacing: AppSpacing.xs) {
                        ZStack {
                            Circle()
                                .fill(AppColors.surfaceElevated)
                                .frame(width: AppSpacing.xxl + AppSpacing.xs, height: AppSpacing.xxl + AppSpacing.xs)
                            Image(systemName: icon)
                                .font(.categoryRowIcon)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Button(action: { onSetupBudget?() }) {
                Text("Start Setup")
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textInverse)
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
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
    }

    // MARK: - State 3: 有预算（原有样式）

    private var connectedContent: some View {
        Button(action: { action?() }) {
            VStack(spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs / 2) {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                            Text(formatCurrency(remaining))
                                .font(.cardFigurePrimary)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("left")
                                .font(.inlineLabel)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Text("\(formatCurrency(spent)) spent this month")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: AppSpacing.xs / 2) {
                        Text("\(daysLeft)")
                            .font(.h3)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("days left")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                HStack(spacing: AppSpacing.xs) {
                    GeometryReader { geo in
                        let w = max(geo.size.width, 1)
                        let safeLimit = max(limit, 1)
                        let nRatio = min(max((apiBudget.needsSpent ?? 0) / safeLimit, 0), 1)
                        let wRatio = min(max((apiBudget.wantsSpent ?? 0) / safeLimit, 0), 1)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.progressTrack)
                                .frame(height: Self.progressBarHeight)
                            HStack(spacing: 0) {
                                Rectangle().fill(AppColors.chartBlue).frame(width: w * CGFloat(nRatio))
                                Rectangle().fill(AppColors.chartAmber).frame(width: w * CGFloat(wRatio))
                            }
                            .clipShape(Capsule())
                            .frame(height: Self.progressBarHeight)
                        }
                    }
                    .frame(height: Self.progressBarHeight)
                    .frame(maxWidth: .infinity)

                    Text("\(spentPercent)%")
                        .font(.inlineFigureBold)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.cardPadding)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: AppSpacing.cardPadding) {
            BudgetPlanCard(
                apiBudget: MockData.apiMonthlyBudget,
                daysLeft: MockData.journeyData.budget.daysLeft
            )
        }
        .padding(.top, AppSpacing.xl + AppSpacing.sm)
    }
}
