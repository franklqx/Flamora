//
//  JourneyView.swift
//  Flamora app
//
//  Journey 主页面 - 参考图风格重排
//

import SwiftUI

// MARK: - Daily Quote Data

private let dailyQuotes: [String] = [
    "It's not about being rich\nIt's about being free.",
    "Financial freedom is available to those who learn about it and work for it.",
    "Do not save what is left after spending,\nbut spend what is left after saving."
]

struct JourneyView: View {
    @State private var netWorthSummary = MockData.apiNetWorthSummary
    @State private var apiBudget = MockData.apiMonthlyBudget
    @State private var fireGoal: APIFireGoal? = nil
    @State private var quoteIndex: Int = 0
    @State private var quoteVisible: Bool = true
    private let data = MockData.journeyData
    var onFireTapped: (() -> Void)? = nil
    let bottomPadding: CGFloat

    init(bottomPadding: CGFloat = 0, onFireTapped: (() -> Void)? = nil) {
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

                        if quoteVisible {
                            dailyQuoteCard
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Plan")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, AppSpacing.screenPadding)

                            VStack(spacing: AppSpacing.cardGap) {
                                budgetCard
                                passiveIncomeCard
                                savingsRateCard
                            }
                        }
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.bottom, max(bottomPadding, AppSpacing.lg))
                    .padding(.top, AppSpacing.md)
                }
            }
        }
        .animation(nil, value: bottomPadding)
        .task { await loadData() }
    }
}

// MARK: - Daily Quote

private extension JourneyView {
    var dailyQuoteCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                Text("DAILY QUOTE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.dailyQuoteAccent.opacity(0.75))
                    .tracking(1.2)

                Text(dailyQuotes[quoteIndex])
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(0..<dailyQuotes.count, id: \.self) { i in
                            Capsule()
                                .fill(i == quoteIndex ? Color.white : Color.white.opacity(0.30))
                                .frame(width: i == quoteIndex ? 20 : 6, height: 3)
                                .animation(.easeInOut(duration: 0.2), value: quoteIndex)
                        }
                    }
                    Text("\(quoteIndex + 1)/\(dailyQuotes.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.cardPadding)
            .background(AppColors.dailyQuoteBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.dailyQuoteAccent.opacity(0.20), lineWidth: 0.75)
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    quoteIndex = (quoteIndex + 1) % dailyQuotes.count
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.50))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Plan Cards

private extension JourneyView {
    var budgetCard: some View {
        let totalSpent = apiBudget.needsSpent + apiBudget.wantsSpent
        let totalBudget = apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
        let progress = totalBudget > 0 ? min(totalSpent / totalBudget, 1.0) : 0
        let spentPercent = totalBudget > 0 ? Int(totalSpent / totalBudget * 100) : 0

        return VStack(spacing: 0) {
            cardHeader(title: "BUDGET IN \(apiBudget.month.uppercased())", hasChevron: true)

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)

            VStack(spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatCurrency(totalSpent))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("of \(formatCurrency(totalBudget))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(spentPercent)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                }

                ProgressBar(progress: progress, color: AppColors.progressGreen, height: 4)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var passiveIncomeCard: some View {
        let income = data.passiveIncome
        let progress = Double(income.percent) / 100.0

        return VStack(spacing: 0) {
            cardHeader(title: "SUSTAINABLE INCOME", hasChevron: true)

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)

            VStack(spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatCurrency(income.projected))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("of \(formatCurrency(income.target))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(income.percent)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                }

                ProgressBar(progress: progress, color: AppColors.progressBlue, height: 4)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var savingsRateCard: some View {
        let savings = data.savingsRate
        let values = savings.monthlySavings
        let hasSavingsData = values.contains { $0 > 0 }

        return VStack(spacing: 0) {
            cardHeader(title: "MONTHLY SAVINGS", hasChevron: true)

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    if hasSavingsData {
                        Text(formatCurrency(savings.savedThisMonth))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Saved This Month")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text("Record Your First Saving")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.progressBlue)
                    }
                }
                Spacer()
                savingsStreakBars(values: values, hasData: hasSavingsData)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    func cardHeader(title: String, hasChevron: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.8)
            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, 12)
    }

    func savingsStreakBars(values: [Double], hasData: Bool) -> some View {
        let barValues = values.isEmpty ? Array(repeating: 0.0, count: 6) : values
        let maxValue = max(barValues.max() ?? 1, 1)
        let palette: [Color] = [
            Color(hex: "#2B3342"), Color(hex: "#3B4861"),
            Color(hex: "#55698E"), AppColors.accentPurple.opacity(0.7),
            AppColors.accentPurpleLight.opacity(0.85), AppColors.accentPurpleLight
        ]

        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(barValues.enumerated()), id: \.offset) { index, value in
                let normalized = hasData ? max(value / maxValue, 0) : 0
                let height = hasData ? (14 + CGFloat(normalized) * 44) : 38
                Capsule()
                    .fill(hasData ? palette[min(index, palette.count - 1)] : AppColors.surfaceInput)
                    .frame(width: 7, height: height)
                    .opacity(hasData ? 1 : 0.55)
            }
        }
    }
}

// MARK: - Data Loading

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
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    JourneyView(onFireTapped: {})
}
