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
    @State private var netWorthSummary = APINetWorthSummary.empty
    @State private var apiBudget = APIMonthlyBudget.empty
    @State private var fireGoal: APIFireGoal? = nil
    /// 已连接银行时由 `get-spending-summary` 推导的当年各月储蓄，供 `SavingsRateCard` 迷你图；nil 时迷你图为空柱。
    @State private var savingsByYearForChart: [Int: [Double?]]?
    /// 当月 `get-spending-summary`，供 BudgetPlanCard 使用与 CashflowView 同口径的实际支出。
    @State private var currentMonthSummary: APISpendingSummary?
    /// 按时间范围缓存的真实投资历史曲线，供首页 PortfolioCard 使用（与 InvestmentView 共用同一套数据）。
    @State private var portfolioHistoryCache: [String: [PortfolioDataPoint]] = [:]
    @State private var quoteIndex: Int = 0
    @State private var quoteVisible: Bool = true
    var onFireTapped: (() -> Void)? = nil
    var onInvestmentTapped: (() -> Void)? = nil
    var onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    let bottomPadding: CGFloat

    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @AppStorage(FlamoraStorageKey.budgetSetupCompleted) private var budgetSetupCompleted: Bool = false

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
                            portfolioBalance: netWorthSummary.breakdown.investmentTotal ?? 0,
                            gainAmount: netWorthSummary.growthAmount ?? 0,
                            gainPercentage: netWorthSummary.growthPercentage ?? 0,
                            realChartData: plaidManager.hasLinkedBank ? { [portfolioHistoryCache] range in
                                portfolioHistoryCache[journeyRangeKey(range)]
                            } : nil,
                            isConnected: plaidManager.hasLinkedBank,
                            onConnectTapped: {
                                guard subscriptionManager.isPremium else {
                                    subscriptionManager.showPaywall = true
                                    return
                                }
                                Task { await plaidManager.startLinkFlow() }
                            }
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
                                BudgetPlanCard(
                                    apiBudget: apiBudget,
                                    daysLeft: daysLeftInCurrentMonth,
                                    summaryNeedsSpent: currentMonthSummary?.needs.total,
                                    summaryWantsSpent: currentMonthSummary?.wants.total,
                                    onSetupBudget: { plaidManager.showBudgetSetup = true },
                                    action: { onOpenCashflowDestination?(.totalSpending) }
                                )
                                if hasBudgetData {
                                    SavingsRateCard(
                                        apiBudget: apiBudget,
                                        isConnected: true
                                    ) {
                                        onOpenCashflowDestination?(.savingsOverview)
                                    }
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
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            print("📍 [Flow] lastConnectionTime changed")
            Task { await loadData() }
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            print("📍 [Flow] hasLinkedBank changed → \(plaidManager.hasLinkedBank)")
            Task { await loadData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            Task { await loadData() }
        }
    }
}

// MARK: - Calendar helpers

private extension JourneyView {
    /// 当月剩余天数（含今日），替代 MockData 固定值（阶段 0 / 路线图 0.4）。
    var daysLeftInCurrentMonth: Int {
        let cal = Calendar.current
        let now = Date()
        guard let range = cal.range(of: .day, in: .month, for: now) else { return 0 }
        let day = cal.component(.day, from: now)
        return range.count - day + 1
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
    var hasBudgetData: Bool {
        budgetSetupCompleted
        && plaidManager.hasLinkedBank
        && (apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget) > 0
        && apiBudget.selectedPlan != nil
    }

    func loadData() async {
        print("📍 [Flow] loadData started — hasLinkedBank=\(plaidManager.hasLinkedBank)")
        let monthStr = currentMonthString
        async let nwTask = fetchNetWorth()
        async let fireTask = fetchFireGoal()

        guard plaidManager.hasLinkedBank else {
            let (nw, fire) = await (nwTask, fireTask)
            if let nw {
                netWorthSummary = nw
                print("📍 [Flow] net worth loaded (no bank) — accounts: \(nw.accounts.count)")
            } else {
                print("📍 [Flow] ❌ net worth fetch returned nil (no bank)")
            }
            apiBudget = .empty
            fireGoal = fire
            savingsByYearForChart = nil
            currentMonthSummary = nil
            portfolioHistoryCache = [:]
            print("📍 [Flow] loadData skipped budget fetch — hasLinkedBank=false")
            return
        }

        // 优先用缓存填充，避免首帧空白
        if portfolioHistoryCache.isEmpty {
            portfolioHistoryCache = TabContentCache.shared.portfolioHistory
        }
        if savingsByYearForChart == nil {
            savingsByYearForChart = TabContentCache.shared.cashflowSavingsByYear
        }

        async let budgetTask = fetchBudget(month: monthStr)
        async let spendingDataTask = fetchSpendingData()
        async let portfolioHistoryTask = fetchAllPortfolioHistory()
        let (nw, budget, fire, spendingData, portfolioHistory) = await (nwTask, budgetTask, fireTask, spendingDataTask, portfolioHistoryTask)

        if let nw {
            netWorthSummary = nw
            let hasInv = nw.accounts.contains { $0.type == "investment" }
            print("📍 [Flow] net worth loaded — accounts: \(nw.accounts.count), total: \(nw.totalNetWorth), hasInvestment: \(hasInv)")
        } else {
            print("📍 [Flow] ❌ net worth fetch returned nil")
        }
        if let budget {
            apiBudget = budget
            FlamoraStorageKey.migrateBudgetSetupIfNeeded(budget: budget, hasLinkedBank: true)
            print("📍 [Flow] budget loaded — selectedPlan=\(budget.selectedPlan ?? "nil"), needs=\(budget.needsBudget), wants=\(budget.wantsBudget), savings=\(budget.savingsBudget)")
        } else {
            print("📍 [Flow] budget fetch returned nil (no budget in DB for \(monthStr))")
        }
        fireGoal = fire
        savingsByYearForChart = spendingData.savingsByYear
        currentMonthSummary = spendingData.currentMonthSummary
        portfolioHistoryCache = portfolioHistory
        // 写入共享缓存，供 InvestmentView / CashflowView 复用
        TabContentCache.shared.setPortfolioHistory(portfolioHistory)
        if let savings = spendingData.savingsByYear {
            TabContentCache.shared.setCashflowSavingsByYear(savings)
        }
        print("📍 [Flow] hasBudgetData=\(hasBudgetData), hasLinkedBank=\(plaidManager.hasLinkedBank)")
    }

    /// 统一拉取多月 summary，返回储蓄趋势与当月 summary（与 CashflowView 同口径）。
    private func fetchSpendingData() async -> (savingsByYear: [Int: [Double?]]?, currentMonthSummary: APISpendingSummary?) {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
        guard !summaries.isEmpty else { return (nil, nil) }
        let savingsByYear = CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
        let currentSummary = summaries[through - 1]
        return (savingsByYear, currentSummary)
    }

    private func fetchAllPortfolioHistory() async -> [String: [PortfolioDataPoint]] {
        let ranges = ["1w", "1m", "3m", "ytd", "all"]
        var result: [String: [PortfolioDataPoint]] = [:]
        await withTaskGroup(of: (String, [PortfolioDataPoint]).self) { group in
            for r in ranges {
                group.addTask {
                    let pts = (try? await APIService.shared.getPortfolioHistory(range: r))?.points
                        .map { PortfolioDataPoint(date: journeyParseDate($0.date), value: $0.value) } ?? []
                    return (r, pts)
                }
            }
            for await (r, pts) in group { result[r] = pts }
        }
        return result
    }

    private func fetchNetWorth() async -> APINetWorthSummary? {
        do {
            return try await APIService.shared.getNetWorthSummary()
        } catch {
            print("📍 [Flow] ❌ fetchNetWorth error: \(error)")
            return nil
        }
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

// MARK: - Portfolio range helpers (file-private, mirrors InvestmentView)

private func journeyRangeKey(_ range: PortfolioTimeRange) -> String {
    switch range {
    case .oneWeek:     return "1w"
    case .oneMonth:    return "1m"
    case .threeMonths: return "3m"
    case .ytd:         return "ytd"
    case .all:         return "all"
    }
}

private func journeyParseDate(_ str: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: str) ?? Date()
}

#Preview {
    JourneyView(onFireTapped: {})
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
