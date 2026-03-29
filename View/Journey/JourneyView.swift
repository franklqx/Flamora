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
    var onInvestmentTapped: (() -> Void)? = nil
    var onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    let bottomPadding: CGFloat

    init(
        bottomPadding: CGFloat = 0,
        onFireTapped: (() -> Void)? = nil,
        onInvestmentTapped: (() -> Void)? = nil,
        onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    ) {
        self.bottomPadding = bottomPadding
        self.onFireTapped = onFireTapped
        self.onInvestmentTapped = onInvestmentTapped
        self.onOpenCashflowDestination = onOpenCashflowDestination
    }

    var body: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        PortfolioCard(
                            portfolioBalance: netWorthSummary.totalNetWorth,
                            gainAmount: netWorthSummary.growthAmount,
                            gainPercentage: netWorthSummary.growthPercentage
                        )

                        if quoteVisible {
                            dailyQuoteCard
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Plan")
                                .font(.h4)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.screenPadding)

                            VStack(spacing: AppSpacing.cardGap) {
                                BudgetPlanCard(apiBudget: apiBudget, daysLeft: data.budget.daysLeft) {
                                    onOpenCashflowDestination?(.totalSpending)
                                }
                                SavingsRateCard(apiBudget: apiBudget) {
                                    onOpenCashflowDestination?(.savingsOverview)
                                }
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
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("DAILY QUOTE")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)

                Text(dailyQuotes[quoteIndex])
                    .font(.quoteBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(0..<dailyQuotes.count, id: \.self) { i in
                            Capsule()
                                .fill(i == quoteIndex ? AppColors.textPrimary : AppColors.overlayWhiteForegroundSoft)
                                .frame(width: i == quoteIndex ? 20 : 6, height: 3)
                                .animation(.easeInOut(duration: 0.2), value: quoteIndex)
                        }
                    }
                    Text("\(quoteIndex + 1)/\(dailyQuotes.count)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.cardPadding)
            .background(
                GeometryReader { geo in
                    ZStack {
                        Image("AppBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height * 4.0)
                            .offset(y: -geo.size.height * 3.0)
                        LinearGradient(
                            colors: [AppColors.overlayBlackSoft, AppColors.overlayBlackMid],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.dailyQuoteAccent.opacity(0.20), lineWidth: 0.75)
                    .allowsHitTesting(false)
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    quoteIndex = (quoteIndex + 1) % dailyQuotes.count
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.smallLabel)
                    .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.sm + 2)
            .padding(.trailing, AppSpacing.sm + 2)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
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
}

#Preview {
    JourneyView(onFireTapped: {})
}
