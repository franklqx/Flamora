//
//  CashflowView.swift
//  Flamora app
//
//  Saving / Cash Flow summary page
//

import SwiftUI

/// Journey 等入口打开与 Cash Flow 相同的二级全屏页时使用（由 MainTabView 直接 present，不切 Tab）
enum CashflowJourneyDestination: Equatable, Identifiable {
    case totalSpending
    case savingsOverview

    var id: String {
        switch self {
        case .totalSpending: return "totalSpending"
        case .savingsOverview: return "savingsOverview"
        }
    }
}

struct CashflowView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager
    @AppStorage(FlamoraStorageKey.budgetSetupCompleted) private var budgetSetupCompleted: Bool = false

    @State private var loadError = false
    @State private var apiBudget = APIMonthlyBudget.empty
    /// 当月收入（来自 `get-spending-summary.total_income`；active/passive 尚无拆分时与 total 对齐）。
    @State private var incomeMonthDisplay = Income(total: 0, active: 0, passive: 0, sources: [])
    /// 本年累计收入（多个月 `get-spending-summary` 汇总）；无银行连接时为 nil。
    @State private var incomeYearDisplay: Income?
    @State private var currentSavings: Double = 0
    @State private var activeSavingsTargetMonthly: Double?
    @State private var needsTotal: Double = 0
    @State private var wantsTotal: Double = 0
    @State private var totalSpend: Double = 0
    @State private var allTransactions: [Transaction] = TabContentCache.shared.cashflowRecentTransactions ?? []
    /// 与 `transaction.accountId` 匹配，供交易详情 Sheet 展示账户行。
    @State private var linkedAccounts: [Account] = []
    /// Cash 页账户列表：depository + credit，来自 get-net-worth-summary.accounts。
    @State private var cashAccountsList: [APIAccount] = TabContentCache.shared.cashflowAccounts?
        .filter { $0.type == "depository" || $0.type == "credit" } ?? []
    @State private var showTrustBridge = false
    @State private var showTotalSpendingDetail = false
    @State private var showNeedsSpendingDetail = false
    @State private var showWantsSpendingDetail = false
    @State private var showMonthSwitcher = false
    @State private var availableBudgetMonths: [Date] = []
    @State private var displayBudgetMonth: Date = Date()

    /// 已连接银行时由多月份 `get-spending-summary` 构建；未连接或拉取失败时为 nil，详情页使用空数据（非 Mock）。
    @State private var cashflowSpendingTotalDetail: TotalSpendingDetailData?
    @State private var cashflowNeedsDetail: SpendingDetailData?
    @State private var cashflowWantsDetail: SpendingDetailData?
    @State private var cashflowTotalIncomeDetail: TotalIncomeDetailData?
    /// 已连接且拉到 summary 时为当年各月储蓄序列；否则 nil → 储蓄全屏用当年全 nil 序列。
    @State private var cashflowSavingsByYear: [Int: [Double?]]?

    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date()) - 1
    }

    /// 当前展示月份对应的 (year, monthIndex0..11)。
    /// 显示历史月份时用它代替 `currentMonthIndex`，避免类目/全屏初始月份永远落在系统当月。
    private var displayMonthYear: Int {
        Calendar.current.component(.year, from: displayBudgetMonth)
    }
    private var displayMonthIndex: Int {
        Calendar.current.component(.month, from: displayBudgetMonth) - 1
    }
    private var isShowingCurrentMonth: Bool {
        Calendar.current.isDate(displayBudgetMonth, equalTo: Date(), toGranularity: .month)
    }

    private var spendingForDisplay: Spending {
        Spending(
            total: totalSpend,
            needs: needsTotal,
            wants: wantsTotal,
            budgetLimit: apiBudget.needsBudget + apiBudget.wantsBudget
        )
    }

    private var hasBudget: Bool {
        plaidManager.hasLinkedBank && budgetSetupCompleted
    }

    private var isCashflowUnlocked: Bool {
        plaidManager.hasLinkedBank
    }

    private var actualSavingsRate: Double? {
        let income = incomeMonthDisplay.total
        guard income > 0 else { return nil }
        return (income - totalSpend) / income
    }

    private var incomePlaceholderMessage: String {
        plaidManager.hasLinkedBank
            ? "Complete budget setup to unlock income"
            : "Connect accounts to see income"
    }

    var body: some View {
        connectedView
    }

    var connectedView: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        BudgetCard(
                            spending: spendingForDisplay,
                            apiBudget: apiBudget,
                            isConnected: plaidManager.hasLinkedBank,
                            hasBudget: hasBudget,
                            onSetupBudget: { plaidManager.openBudgetSetup(mode: .fresh) },
                            onCardTapped: { showTotalSpendingDetail = true },
                            onNeedsTapped: { showNeedsSpendingDetail = true },
                            onWantsTapped: { showWantsSpendingDetail = true },
                            onAdjustOverallPlan: { plaidManager.openBudgetSetup(mode: .editPlan) },
                            onEditCategoryBudgets: { plaidManager.openBudgetSetup(mode: .editCategories) },
                            displayMonth: displayBudgetMonth,
                            onMonthLabelTapped: {
                                Task { await loadAvailableBudgetMonthsIfNeeded() }
                                showMonthSwitcher = true
                            }
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        cashAccountsSection
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .alert("Bank Connection Failed", isPresented: Binding(
            get: { plaidManager.linkError != nil },
            set: { if !$0 { plaidManager.linkError = nil } }
        )) {
            Button("Try Again") { Task { await plaidManager.startLinkFlow() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(plaidManager.linkError ?? "")
        }
        .onAppear {
            restoreFromCache()
        }
        .task {
            await loadCashflowData()
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await loadCashflowData(force: true) }
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadCashflowData(force: true) }
        }
        .onChange(of: budgetSetupCompleted) { _, _ in
            Task { await loadCashflowData(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            Task { await loadCashflowData(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionClassificationDidPersist)) { _ in
            Task { await loadCashflowData(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetSetupFlowDidDismiss)) { _ in
            // Setup 流程可能创建新月份的 monthly_budget，需要让月份选择器列表重新探测一次，
            // 否则 `availableBudgetMonths` 会一直停留在第一次打开 sheet 时的快照。
            availableBudgetMonths = []
            Task { await loadCashflowData(force: true) }
        }
        .fullScreenCover(isPresented: $showTotalSpendingDetail) {
            TotalSpendingAnalysisDetailView(
                data: cashflowSpendingTotalDetail ?? .empty,
                needsDetailData: cashflowNeedsDetail ?? .emptyNeeds,
                wantsDetailData: cashflowWantsDetail ?? .emptyWants,
                initialSelectedMonth: displayMonthIndex,
                initialSelectedYear: displayMonthYear,
                categoryBudgets: apiBudget.categoryBudgets,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: { tx in try await persistTransactionClassification(tx) }
            )
        }
        .fullScreenCover(isPresented: $showNeedsSpendingDetail) {
            SpendingAnalysisDetailView(
                data: cashflowNeedsDetail ?? .emptyNeeds,
                flamoraCategory: "needs",
                initialSelectedMonth: displayMonthIndex,
                initialSelectedYear: displayMonthYear,
                categoryBudgets: apiBudget.categoryBudgets,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: { tx in try await persistTransactionClassification(tx) }
            )
        }
        .fullScreenCover(isPresented: $showWantsSpendingDetail) {
            SpendingAnalysisDetailView(
                data: cashflowWantsDetail ?? .emptyWants,
                flamoraCategory: "wants",
                initialSelectedMonth: displayMonthIndex,
                initialSelectedYear: displayMonthYear,
                categoryBudgets: apiBudget.categoryBudgets,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: { tx in try await persistTransactionClassification(tx) }
            )
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
        .sheet(isPresented: $showMonthSwitcher) {
            BudgetMonthSwitcherSheet(
                months: availableBudgetMonths,
                selected: displayBudgetMonth
            ) { picked in
                Task { await switchToBudgetMonth(picked) }
            }
        }
    }
}

// MARK: - Data Loading

private extension CashflowView {

    func restoreFromCache() {
        let cache = TabContentCache.shared
        if let b = cache.cashflowBudget, apiBudget.budgetId.isEmpty {
            apiBudget = b
            currentSavings = b.savingsActual ?? currentSavings
        }
        // 与 Journey「储蓄」全屏共用 TabContentCache；从主页返回 Cashflow 时始终用缓存覆盖，避免双入口不同步。
        if let savings = cache.cashflowSavingsByYear {
            cashflowSavingsByYear = savings
            if let monthVal = currentSavingsForCurrentMonth(from: savings) {
                currentSavings = monthVal
            }
        }
        if let total = cache.cashflowSpendingTotalDetail, cashflowSpendingTotalDetail == nil {
            cashflowSpendingTotalDetail = total
        }
        if let needs = cache.cashflowNeedsDetail, cashflowNeedsDetail == nil {
            cashflowNeedsDetail = needs
        }
        if let wants = cache.cashflowWantsDetail, cashflowWantsDetail == nil {
            cashflowWantsDetail = wants
        }
        // 跨过新年凌晨时缓存里的「当年」会变成上一年；此处对比当前日历年再决定是否复用。
        let currentYear = Calendar.current.component(.year, from: Date())
        if let summaries = cache.cashflowMonthlySummaries,
           cache.cashflowMonthlySummariesYear == currentYear {
            applyMonthlySummaries(summaries)
        }
        if let accounts = cache.cashflowAccounts {
            linkedAccounts = accounts.map { Account.fromNetWorthAccount($0) }
            cashAccountsList = accounts.filter { $0.type == "depository" || $0.type == "credit" }
        }
        if let recent = cache.cashflowRecentTransactions, allTransactions.isEmpty {
            allTransactions = recent
        }
    }

    func loadCashflowData(force: Bool = false) async {
        loadError = false
        restoreFromCache()
        if !force, hasCachedCashflowData {
            return
        }
        let monthStr = apiMonthString(from: Date())

        // 账户列表独立于 budget setup，只要连接了银行就加载
        if plaidManager.hasLinkedBank {
            if force || TabContentCache.shared.cashflowAccounts == nil {
                do {
                    let nw = try await APIService.shared.getNetWorthSummary()
                    linkedAccounts = nw.accounts.map { Account.fromNetWorthAccount($0) }
                    cashAccountsList = nw.accounts.filter {
                        $0.type == "depository" || $0.type == "credit"
                    }
                    TabContentCache.shared.setCashflowAccounts(nw.accounts)
                } catch {
                    print("❌ [CashflowView] getNetWorthSummary failed: \(error)")
                    loadError = true
                    if linkedAccounts.isEmpty {
                        linkedAccounts = []
                        cashAccountsList = []
                    }
                }
            }
        } else {
            linkedAccounts = []
            cashAccountsList = []
        }

        guard isCashflowUnlocked else {
            apiBudget = .empty
            activeSavingsTargetMonthly = nil
            currentSavings = 0
            needsTotal = 0
            wantsTotal = 0
            totalSpend = 0
            incomeMonthDisplay = Income(total: 0, active: 0, passive: 0, sources: [])
            incomeYearDisplay = nil
            cashflowSpendingTotalDetail = nil
            cashflowNeedsDetail = nil
            cashflowWantsDetail = nil
            cashflowTotalIncomeDetail = nil
            cashflowSavingsByYear = nil
            allTransactions = []
            return
        }

        if force || apiBudget.budgetId.isEmpty {
            if let b = await fetchBudget(month: monthStr) {
                apiBudget = b
                FlamoraStorageKey.migrateBudgetSetupIfNeeded(budget: b, hasLinkedBank: true)
                currentSavings = b.savingsActual ?? 0
                needsTotal = b.needsSpent ?? 0
                wantsTotal = b.wantsSpent ?? 0
                totalSpend = (b.needsSpent ?? 0) + (b.wantsSpent ?? 0)
                TabContentCache.shared.setCashflowBudget(b)
            }
        }

        await refreshActiveSavingsTarget()

        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())

        let cache = TabContentCache.shared
        if !force,
           let cachedSummaries = cache.cashflowMonthlySummaries,
           !cachedSummaries.isEmpty,
           cache.cashflowMonthlySummariesYear == year {
            applyMonthlySummaries(cachedSummaries)
        } else {
            let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
            if summaries.isEmpty {
                print("⚠️ [CashflowView] No detail summaries loaded for \(year)-01...\(year)-\(String(format: "%02d", through))")
            } else if summaries[through - 1] == nil {
                let available = summaries.keys.sorted().map { String(format: "%02d", $0 + 1) }.joined(separator: ",")
                print("⚠️ [CashflowView] Current month summary missing for month \(through). Available months: \(available)")
            }

            applyMonthlySummaries(summaries)
        }

        if force || allTransactions.isEmpty {
            if let tx = try? await APIService.shared.getTransactions(page: 1, limit: 20) {
                allTransactions = tx.transactions.map { Transaction(from: $0) }
                TabContentCache.shared.setCashflowRecentTransactions(allTransactions)
            }
        }
    }

    private var hasCachedCashflowData: Bool {
        let hasPrimaryData = apiBudget.budgetId.isEmpty == false
            || TabContentCache.shared.cashflowMonthlySummaries != nil
        let hasAccounts = !plaidManager.hasLinkedBank || TabContentCache.shared.cashflowAccounts != nil
        return hasPrimaryData && hasAccounts
    }

    private func applyMonthlySummaries(_ summaries: [Int: APISpendingSummary]) {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())

        if let cur = summaries[through - 1] {
            needsTotal = cur.needs.total
            wantsTotal = cur.wants.total
            totalSpend = cur.totalSpending
            let inc = cur.totalIncome
            let monthSources = CashflowAPICharts.incomeSources(from: cur)
            incomeMonthDisplay = Income(total: inc, active: inc, passive: 0, sources: monthSources)
            let ytd = summaries.values.reduce(0) { $0 + $1.totalIncome }
            incomeYearDisplay = Income(total: ytd, active: ytd, passive: 0, sources: [])
        } else {
            incomeMonthDisplay = Income(total: 0, active: 0, passive: 0, sources: [])
            incomeYearDisplay = nil
        }

        if !summaries.isEmpty {
            let total = CashflowAPICharts.totalSpendingDetail(summaries: summaries, year: year)
            let needs = CashflowAPICharts.needsSpendingDetail(summaries: summaries, year: year)
            let wants = CashflowAPICharts.wantsSpendingDetail(summaries: summaries, year: year)
            let savings = CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
            cashflowSpendingTotalDetail = total
            cashflowNeedsDetail = needs
            cashflowWantsDetail = wants
            cashflowTotalIncomeDetail = CashflowAPICharts.totalIncomeDetail(summaries: summaries, year: year)
            cashflowSavingsByYear = savings
            currentSavings = currentSavingsForCurrentMonth(from: savings) ?? currentSavings
            TabContentCache.shared.setCashflowSavingsByYear(savings)
            TabContentCache.shared.setCashflowSpendingDetails(total: total, needs: needs, wants: wants)
            TabContentCache.shared.setCashflowMonthlySummaries(summaries, year: year)
        } else {
            cashflowSpendingTotalDetail = nil
            cashflowNeedsDetail = nil
            cashflowWantsDetail = nil
            cashflowTotalIncomeDetail = nil
            cashflowSavingsByYear = nil
            TabContentCache.shared.setCashflowMonthlySummaries(nil)
        }
    }

    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }

    private func refreshActiveSavingsTarget() async {
        guard budgetSetupCompleted else {
            activeSavingsTargetMonthly = nil
            return
        }
        do {
            let goal = try await APIService.shared.getActiveFireGoal()
            activeSavingsTargetMonthly = goal.savingsTargetMonthly
        } catch {
            print("⚠️ [CashflowView] getActiveFireGoal savings target failed: \(error)")
            activeSavingsTargetMonthly = nil
        }
    }

    func applySavingsCheckIn(_ updated: [Int: [Double?]]) {
        cashflowSavingsByYear = updated
        if let monthValue = currentSavingsForCurrentMonth(from: updated) {
            currentSavings = monthValue
        } else {
            currentSavings = 0
        }
        TabContentCache.shared.setCashflowSavingsByYear(updated)
    }

    func syncMainCardSavingsToSeries() {
        let currentYear = Calendar.current.component(.year, from: Date())
        var updated = cashflowSavingsByYear ?? CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()
        var yearData = updated[currentYear] ?? Array(repeating: nil, count: 12)
        while yearData.count < 12 { yearData.append(nil) }
        yearData[currentMonthIndex] = currentSavings > 0 ? currentSavings : nil
        updated[currentYear] = yearData
        applySavingsCheckIn(updated)
    }

    @MainActor
    func persistCurrentMonthSavings(amount: Double) async {
        let normalizedAmount = amount > 0 ? amount : nil
        do {
            let budget = try await APIService.shared.saveSavingsCheckIn(
                month: apiMonthString(from: Date()),
                savingsActual: normalizedAmount
            )
            apiBudget = budget
            TabContentCache.shared.setCashflowBudget(budget)
            NotificationCenter.default.post(name: .savingsCheckInDidPersist, object: nil)
        } catch {
            print("❌ [CashflowView] Failed to persist current month savings: \(error)")
        }
    }

    func currentSavingsForCurrentMonth(from data: [Int: [Double?]]) -> Double? {
        let currentYear = Calendar.current.component(.year, from: Date())
        let monthIndex = currentMonthIndex
        guard let yearData = data[currentYear], monthIndex < yearData.count else { return nil }
        return yearData[monthIndex] ?? nil
    }

    func apiMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    /// Probe the last 12 months and remember which ones have a saved
    /// `monthly_budget` record. Short-circuits when the list is already populated;
    /// pass `force: true` to refetch (e.g. after a budget setup completes and
    /// creates a new month record).
    /// 12 个月份的探测请求并行发出，避免月份选择器首次打开时串行 12 次网络往返。
    @MainActor
    func loadAvailableBudgetMonthsIfNeeded(force: Bool = false) async {
        if !force, !availableBudgetMonths.isEmpty { return }
        let calendar = Calendar.current
        let today = Date()
        let monthStarts: [Date] = (0..<12).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: today) else { return nil }
            return calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
        }

        let found: [Date] = await withTaskGroup(of: (Int, Date?).self) { group in
            for (index, firstOfMonth) in monthStarts.enumerated() {
                let monthStr = apiMonthString(from: firstOfMonth)
                group.addTask {
                    if let budget = try? await APIService.shared.getMonthlyBudget(month: monthStr),
                       !budget.budgetId.isEmpty {
                        return (index, firstOfMonth)
                    }
                    return (index, nil)
                }
            }
            var byIndex: [Int: Date] = [:]
            for await (index, date) in group {
                if let date { byIndex[index] = date }
            }
            // 保持与 monthStarts 相同的「最近优先」顺序（offset 0 = 当月，offset 11 = 11 个月前）。
            return byIndex.keys.sorted().compactMap { byIndex[$0] }
        }
        availableBudgetMonths = found
    }

    /// Switch the BudgetCard to a historical month. Refetches that month's
    /// monthly_budget, applies its spent totals to the card, and lazy-fetches
    /// the per-month spending detail (needs / wants / total) when the picked
    /// month isn't already cached — typically the case for cross-year picks
    /// since the bulk loader only covers the current year.
    /// Returning to the current month falls back to the standard
    /// `loadCashflowData` path so live data resumes.
    @MainActor
    func switchToBudgetMonth(_ month: Date) async {
        let calendar = Calendar.current
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        displayBudgetMonth = firstOfMonth

        if calendar.isDate(firstOfMonth, equalTo: Date(), toGranularity: .month) {
            await loadCashflowData(force: true)
            return
        }

        let monthStr = apiMonthString(from: firstOfMonth)
        if let budget = try? await APIService.shared.getMonthlyBudget(month: monthStr) {
            apiBudget = budget
            currentSavings = budget.savingsActual ?? 0
            // 历史月的实际花费来自后端基于该月 transactions 的实时计算（见 get-monthly-budget edge function）。
            needsTotal = budget.needsSpent ?? 0
            wantsTotal = budget.wantsSpent ?? 0
            totalSpend = needsTotal + wantsTotal
        }

        await ensureSpendingDetailLoaded(year: displayMonthYear, monthIndex: displayMonthIndex)
    }

    /// 如果指定 year/monthIndex 在 4 个 detail 字典里都已经有数据，直接返回；否则调
    /// `get-spending-summary` 拉一次并 merge。仅在切换到历史月时调用。
    @MainActor
    private func ensureSpendingDetailLoaded(year: Int, monthIndex: Int) async {
        let totalHas = cashflowSpendingTotalDetail?.monthlyDataByYear[year]?[monthIndex] != nil
        let needsHas = cashflowNeedsDetail?.monthlyDataByYear[year]?[monthIndex] != nil
        let wantsHas = cashflowWantsDetail?.monthlyDataByYear[year]?[monthIndex] != nil
        if totalHas && needsHas && wantsHas { return }

        guard let summary = await CashflowAPICharts.fetchSingleMonthSummary(
            year: year, monthIndex: monthIndex
        ) else { return }

        let merged = CashflowAPICharts.mergedDetails(
            summary: summary,
            year: year,
            monthIndex: monthIndex,
            existingTotal: cashflowSpendingTotalDetail,
            existingNeeds: cashflowNeedsDetail,
            existingWants: cashflowWantsDetail,
            existingSavings: cashflowSavingsByYear
        )
        cashflowSpendingTotalDetail = merged.total
        cashflowNeedsDetail = merged.needs
        cashflowWantsDetail = merged.wants
        cashflowSavingsByYear = merged.savings
        TabContentCache.shared.setCashflowSpendingDetails(
            total: merged.total, needs: merged.needs, wants: merged.wants
        )
        TabContentCache.shared.setCashflowSavingsByYear(merged.savings)
    }
}

// MARK: - Cash Accounts

private extension CashflowView {
    var cashAccountsSection: some View {
        Group {
            if plaidManager.hasLinkedBank && !cashAccountsList.isEmpty {
                let depository = cashAccountsList.filter { $0.type == "depository" }
                let credit     = cashAccountsList.filter { $0.type == "credit" }
                CashAccountsCard(
                    cashAccounts: depository,
                    creditAccounts: credit,
                    lastSyncedAt: nil,
                    onAddAccount: {
                        if plaidManager.shouldShowTrustBridge() {
                            showTrustBridge = true
                        } else {
                            Task { await plaidManager.startLinkFlow() }
                        }
                    }
                )
                .padding(.horizontal, AppSpacing.screenPadding)
            } else if !plaidManager.hasLinkedBank {
                EmptyStateView(
                    icon: "building.columns",
                    title: "Connect your first account",
                    message: "Link a checking account to see balances, transactions, and budget progress in one place.",
                    actionTitle: "Connect bank account",
                    action: {
                        if plaidManager.shouldShowTrustBridge() {
                            showTrustBridge = true
                        } else {
                            Task { await plaidManager.startLinkFlow() }
                        }
                    }
                )
                .background(
                    LinearGradient(
                        colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.glassCard))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.glassCard)
                        .stroke(AppColors.glassCardBorder, lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }
}

// MARK: - Transactions

private extension CashflowView {
    @MainActor
    func persistTransactionClassification(_ updated: Transaction) async throws {
        let response = try await APIService.shared.updateTransactionClassification(
            transactionId: updated.id,
            category: updated.category,
            subcategory: updated.subcategory
        )
        updateTransaction(Transaction(from: response))
        Task { await loadCashflowData(force: true) }
    }

    func updateTransaction(_ updated: Transaction) {
        let old = allTransactions.first(where: { $0.id == updated.id })

        // Adjust running totals when category changes (category is derived from subcategory)
        if let old, old.category != updated.category {
            if old.category == "needs"      { needsTotal -= old.amount }
            else if old.category == "wants" { wantsTotal -= old.amount }
            else                            { totalSpend += updated.amount }

            if updated.category == "needs"      { needsTotal += updated.amount }
            else if updated.category == "wants" { wantsTotal += updated.amount }
            else                                { totalSpend -= updated.amount }
        }

        if let old {
            applyTransactionToDetailModels(old: old, updated: updated)
        }

        if let index = allTransactions.firstIndex(where: { $0.id == updated.id }) {
            allTransactions[index] = updated
        } else {
            allTransactions.insert(updated, at: 0)
        }
        TabContentCache.shared.setCashflowRecentTransactions(allTransactions)

        // Do not hide the row after classification — user expects the transaction to stay visible in place.
    }

    func applyTransactionToDetailModels(old: Transaction, updated: Transaction) {
        cashflowNeedsDetail = updateSpendingDetail(
            cashflowNeedsDetail,
            bucket: "needs",
            removing: old.category == "needs" ? old : nil,
            adding: updated.category == "needs" ? updated : nil
        )

        cashflowWantsDetail = updateSpendingDetail(
            cashflowWantsDetail,
            bucket: "wants",
            removing: old.category == "wants" ? old : nil,
            adding: updated.category == "wants" ? updated : nil
        )

        cashflowSpendingTotalDetail = updateTotalSpendingDetail(
            cashflowSpendingTotalDetail,
            old: old,
            updated: updated
        )

        if let total = cashflowSpendingTotalDetail,
           let needs = cashflowNeedsDetail,
           let wants = cashflowWantsDetail {
            TabContentCache.shared.setCashflowSpendingDetails(total: total, needs: needs, wants: wants)
        }
    }

    func updateSpendingDetail(
        _ data: SpendingDetailData?,
        bucket: String,
        removing oldTx: Transaction?,
        adding newTx: Transaction?
    ) -> SpendingDetailData? {
        guard let data else { return nil }
        var result = data
        if let oldTx {
            let (y, m) = monthYearComponents(from: oldTx.date)
            result = applySpendingDetailMonthMutation(
                result,
                bucket: bucket,
                year: y,
                monthIndex: m,
                removeTx: oldTx,
                addTx: nil
            )
        }
        if let newTx {
            let (y, m) = monthYearComponents(from: newTx.date)
            result = applySpendingDetailMonthMutation(
                result,
                bucket: bucket,
                year: y,
                monthIndex: m,
                removeTx: nil,
                addTx: newTx
            )
        }
        return result
    }

    func updateTotalSpendingDetail(
        _ data: TotalSpendingDetailData?,
        old: Transaction,
        updated: Transaction
    ) -> TotalSpendingDetailData? {
        guard let data else { return nil }
        let (yOld, mOld) = monthYearComponents(from: old.date)
        let (yNew, mNew) = monthYearComponents(from: updated.date)

        let deltaNeedsOld = old.category == "needs" ? -old.amount : 0.0
        let deltaWantsOld = old.category == "wants" ? -old.amount : 0.0
        var result = applyTotalSpendingMonthAdjust(
            data,
            year: yOld,
            monthIndex: mOld,
            deltaNeeds: deltaNeedsOld,
            deltaWants: deltaWantsOld
        )

        let deltaNeedsNew = updated.category == "needs" ? updated.amount : 0.0
        let deltaWantsNew = updated.category == "wants" ? updated.amount : 0.0
        result = applyTotalSpendingMonthAdjust(
            result,
            year: yNew,
            monthIndex: mNew,
            deltaNeeds: deltaNeedsNew,
            deltaWants: deltaWantsNew
        )
        return result
    }

    /// `Transaction.date`: `YYYY-MM-DD` 或当年 `MM-DD`。
    private func monthYearComponents(from dateString: String) -> (year: Int, monthIndex: Int) {
        let cal = Calendar.current
        let defaultYear = cal.component(.year, from: Date())
        let defaultMonth = cal.component(.month, from: Date()) - 1
        let parts = dateString.split(separator: "-").map { String($0) }
        if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), m >= 1, m <= 12 {
            return (y, m - 1)
        }
        if parts.count == 2, let m = Int(parts[0]), m >= 1, m <= 12 {
            return (defaultYear, m - 1)
        }
        return (defaultYear, defaultMonth)
    }

    private func applySpendingDetailMonthMutation(
        _ data: SpendingDetailData,
        bucket: String,
        year: Int,
        monthIndex: Int,
        removeTx: Transaction?,
        addTx: Transaction?
    ) -> SpendingDetailData {
        var trendsByYear = data.trendsByYear
        var monthlyDataByYear = data.monthlyDataByYear
        var yearlyTrend = trendsByYear[year] ?? Array(repeating: nil, count: 12)
        var monthlyData = monthlyDataByYear[year] ?? [:]
        let current = monthlyData[monthIndex] ?? SpendingDetailMonthData(total: 0, categories: [])

        var total = current.total
        var categoryAmounts = Dictionary(uniqueKeysWithValues: current.categories.map { ($0.name, $0.amount) })

        if let oldTx = removeTx {
            let name = oldTx.subcategory ?? "uncategorized"
            let nextAmount = max(0, (categoryAmounts[name] ?? 0) - oldTx.amount)
            if nextAmount <= 0.005 {
                categoryAmounts.removeValue(forKey: name)
            } else {
                categoryAmounts[name] = nextAmount
            }
            total = max(0, total - oldTx.amount)
        }

        if let newTx = addTx {
            let name = newTx.subcategory ?? "uncategorized"
            categoryAmounts[name] = (categoryAmounts[name] ?? 0) + newTx.amount
            total += newTx.amount
        }

        let categories = categoryAmounts
            .sorted { $0.value > $1.value }
            .map { name, amount in
                SpendingDetailCategory(
                    id: "\(bucket)-\(year)-\(monthIndex)-\(name)",
                    icon: TransactionCategoryCatalog.icon(forStoredSubcategory: name) ?? "tag.fill",
                    name: name,
                    amount: amount,
                    percentage: total > 0 ? (amount / total) * 100 : 0
                )
            }

        monthlyData[monthIndex] = SpendingDetailMonthData(total: total, categories: categories)
        yearlyTrend[monthIndex] = total
        trendsByYear[year] = yearlyTrend
        monthlyDataByYear[year] = monthlyData

        return SpendingDetailData(
            title: data.title,
            accentColor: data.accentColor,
            trendsByYear: trendsByYear,
            monthlyDataByYear: monthlyDataByYear
        )
    }

    private func applyTotalSpendingMonthAdjust(
        _ data: TotalSpendingDetailData,
        year: Int,
        monthIndex: Int,
        deltaNeeds: Double,
        deltaWants: Double
    ) -> TotalSpendingDetailData {
        var trendsByYear = data.trendsByYear
        var monthlyDataByYear = data.monthlyDataByYear
        var yearlyTrend = trendsByYear[year] ?? Array(repeating: nil, count: 12)
        var monthlyData = monthlyDataByYear[year] ?? [:]
        let prior = monthlyData[monthIndex] ?? TotalSpendingMonthData(
            total: 0,
            needsAmount: 0,
            wantsAmount: 0,
            needsPercentage: 0,
            wantsPercentage: 0
        )

        let needsAmount = max(0, prior.needsAmount + deltaNeeds)
        let wantsAmount = max(0, prior.wantsAmount + deltaWants)
        let total = needsAmount + wantsAmount
        let current = TotalSpendingMonthData(
            total: total,
            needsAmount: needsAmount,
            wantsAmount: wantsAmount,
            needsPercentage: total > 0 ? (needsAmount / total) * 100 : 0,
            wantsPercentage: total > 0 ? (wantsAmount / total) * 100 : 0
        )

        monthlyData[monthIndex] = current
        yearlyTrend[monthIndex] = total
        trendsByYear[year] = yearlyTrend
        monthlyDataByYear[year] = monthlyData

        return TotalSpendingDetailData(
            title: data.title,
            trendsByYear: trendsByYear,
            monthlyDataByYear: monthlyDataByYear
        )
    }

}

// TransactionRow is defined in TransactionRow.swift

#Preview {
    CashflowView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
