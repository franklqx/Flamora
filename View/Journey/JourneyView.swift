//
//  JourneyView.swift
//  Flamora app
//
//  Journey 主页面 - 使用 MockData API 模型
//

import SwiftUI

struct JourneyView: View {
    private let netWorthSummary = MockData.apiNetWorthSummary
    private let apiBudget = MockData.apiMonthlyBudget
    private let fireGoal = MockData.apiFireGoal
    private let userProfile = MockData.apiUserProfile
    private let data = MockData.journeyData // for passiveIncome & savingsRate (no API equivalent yet)
    var onFireTapped: (() -> Void)? = nil
    let bottomPadding: CGFloat

    init(bottomPadding: CGFloat = AppSpacing.tabBarReserve, onFireTapped: (() -> Void)? = nil) {
        self.bottomPadding = bottomPadding
        self.onFireTapped = onFireTapped
    }

    var body: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        NetWorthCard(
                            totalNetWorth: netWorthSummary.totalNetWorth,
                            growthAmount: netWorthSummary.growthAmount,
                            growthPercentage: netWorthSummary.growthPercentage
                        )

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Plan")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, AppSpacing.screenPadding)

                            VStack(spacing: AppSpacing.cardGap) {
                                budgetCard
                                passiveIncomeCard
                                savingsRateCard
                                aiInsightsCard
                            }
                        }

                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.bottom, bottomPadding)
                    .padding(.top, AppSpacing.lg)
                }
            }
        }
        .animation(nil, value: bottomPadding)
    }
}

// MARK: - Subviews
private extension JourneyView {
    var budgetCard: some View {
        let totalSpent = apiBudget.needsSpent + apiBudget.wantsSpent
        let totalBudget = apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
        let spentPercent = totalBudget > 0 ? Int(totalSpent / totalBudget * 100) : 0
        let progress = Double(spentPercent) / 100.0

        return VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(apiBudget.month)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B7280"))
                }

                Spacer()

                Text("\(spentPercent)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            ProgressBar(
                progress: progress,
                color: Color(hex: "#A78BFA")
            )

            HStack {
                Text("\(formatCurrency(totalSpent)) spent")
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                Spacer()

                Text("Limit: \(formatCurrency(totalBudget))")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var passiveIncomeCard: some View {
        let income = data.passiveIncome
        let progress = Double(income.percent) / 100.0

        return VStack(spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Passive Income")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("CAPACITY REPORT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#93C5FD"))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("PROJECTED")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#6B7280"))

                        Text(formatCurrency(income.projected))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Circle()
                            .fill(Color(hex: "#93C5FD"))
                            .frame(width: 6, height: 6)
                    }

                    HStack(spacing: 4) {
                        Text("TARGET")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#6B7280"))

                        Text(formatCurrency(income.target))
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#6B7280"))

                        Circle()
                            .fill(Color(hex: "#4B5563"))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            ProgressBar(
                progress: progress,
                color: Color(hex: "#93C5FD")
            )

            Text("Based on 4% safe withdrawal rate")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#6B7280"))
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var savingsRateCard: some View {
        let currentPercent = Int(apiBudget.savingsRatio)
        let targetPercent = Int(fireGoal.requiredSavingsRate)
        let savings = data.savingsRate

        return VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings Rate")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Target: \(targetPercent)% of income")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B7280"))
                }

                Spacer()

                Text("\(currentPercent)%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: AppSpacing.lg) {
                ForEach(savings.months, id: \.month) { monthStatus in
                    MonthIndicator(
                        month: monthStatus.month,
                        status: statusFromString(monthStatus.status)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var aiInsightsCard: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: 48, height: 48)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA"), Color(hex: "#EC4899")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Insights")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text("Evaluate your spending patterns")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#9CA3AF"))
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1D4ED8"),
                            Color(hex: "#7C3AED"),
                            Color(hex: "#DB2777")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Helpers
private extension JourneyView {
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func statusFromString(_ statusString: String) -> MonthIndicator.Status {
        switch statusString.lowercased() {
        case "success":
            return .success
        case "failed":
            return .failed
        default:
            return .pending
        }
    }
}

#Preview {
    JourneyView(onFireTapped: {})
}
