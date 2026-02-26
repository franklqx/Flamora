//
//  JourneyView.swift
//  Flamora app
//
//  Journey 主页面 - 使用 MockData API 模型
//

import SwiftUI

struct JourneyView: View {
    @State private var netWorthSummary = MockData.apiNetWorthSummary
    @State private var apiBudget = MockData.apiMonthlyBudget
    @State private var fireGoal: APIFireGoal? = nil
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
                                fireProgressCard
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
        .task { await loadData() }
    }
}

// MARK: - Subviews
private extension JourneyView {
    @ViewBuilder
    var fireProgressCard: some View {
        if let goal = fireGoal {
            let progress = min(goal.progressPercentage / 100.0, 1.0)
            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FIRE Progress")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Retire at age \(goal.targetRetirementAge)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#6B7280"))
                    }
                    Spacer()
                    Text("\(Int(goal.progressPercentage))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                ProgressBar(progress: progress, color: Color(hex: "#F97316"))
                HStack {
                    Text(formatCurrency(goal.currentNetWorth))
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Goal: \(formatCurrency(goal.fireNumber))")
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
    }

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
                    Text("Sustainable Income")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("CAPACITY REPORT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#93C5FD"))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Spacer()

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#9CA3AF"))
                    .help("4% safe withdrawal rate: a common annual withdrawal guideline for portfolio sustainability.")
            }

            ProgressBar(
                progress: progress,
                color: Color(hex: "#93C5FD")
            )

            HStack {
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

                Spacer()

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
        let savings = data.savingsRate
        let values = savings.monthlySavings
        let hasSavingsData = values.contains { $0 > 0 }

        return VStack(spacing: AppSpacing.sm) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings Streak")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    if hasSavingsData {
                        Text(formatCurrency(savings.savedThisMonth))
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(.white)

                        Text("Saved This Month")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    } else {
                        Text("Record Your First Saving")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#9FB2CC"))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    savingsStreakBars(values: values, hasData: hasSavingsData)
                }
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

    func savingsStreakBars(values: [Double], hasData: Bool) -> some View {
        let barValues = values.isEmpty ? Array(repeating: 0.0, count: 6) : values
        let maxValue = max(barValues.max() ?? 1, 1)
        let palette = [
            Color(hex: "#2B3342"),
            Color(hex: "#3B4861"),
            Color(hex: "#55698E"),
            Color(hex: "#728BC0"),
            Color(hex: "#95A3E2"),
            Color(hex: "#B5B7FA")
        ]

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(barValues.enumerated()), id: \.offset) { index, value in
                let normalized = hasData ? max(value / maxValue, 0) : 0
                let height = hasData ? (18 + CGFloat(normalized) * 48) : 42

                Capsule()
                    .fill(hasData ? palette[min(index, palette.count - 1)] : Color(hex: "#323845"))
                    .frame(width: 8, height: height)
                    .opacity(hasData ? 1 : 0.55)
            }
        }
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
    func loadData() async {
        let monthStr = currentMonthString
        async let nwTask = fetchNetWorth()
        async let budgetTask = fetchBudget(month: monthStr)
        async let fireTask = fetchFireGoal()
        let (nw, budget, fire) = await (nwTask, budgetTask, fireTask)
        if let nw { netWorthSummary = nw }
        if let budget { apiBudget = budget }
        fireGoal = fire
    }

    // async let + try? 组合会触发 Swift runtime crash (swift_task_dealloc)
    // 将 try? 包裹在独立函数中避免此问题
    private func fetchNetWorth() async -> APINetWorthSummary? {
        try? await APIService.shared.getNetWorthSummary()
    }
    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }
    private func fetchFireGoal() async -> APIFireGoal? {
        try? await APIService.shared.getActiveFireGoal()
    }

    var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    JourneyView(onFireTapped: {})
}
