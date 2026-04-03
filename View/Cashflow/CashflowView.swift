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

    @State private var apiBudget = APIMonthlyBudget.empty
    /// 当月收入（来自 `get-spending-summary.total_income`；active/passive 尚无拆分时与 total 对齐）。
    @State private var incomeMonthDisplay = Income(total: 0, active: 0, passive: 0, sources: [])
    /// 本年累计收入（多个月 `get-spending-summary` 汇总）；无银行连接时为 nil。
    @State private var incomeYearDisplay: Income?
    @State private var currentSavings: Double = 0
    @State private var needsTotal: Double = 0
    @State private var wantsTotal: Double = 0
    @State private var totalSpend: Double = 0
    @State private var allTransactions: [Transaction] = []
    @State private var hiddenReviewedTransactionIDs: Set<String> = []
    /// 与 `transaction.accountId` 匹配，供交易详情 Sheet 展示账户行。
    @State private var linkedAccounts: [Account] = []
    /// Cash 页账户列表：depository + credit，来自 get-net-worth-summary.accounts。
    @State private var cashAccountsList: [APIAccount] = []
    @State private var selectedTransaction: Transaction? = nil
    @State private var showAllTransactions = false
    @State private var showSavingsInput = false
    @State private var showSavingsSummary = false
    @State private var showTotalIncomeDetail = false
    @State private var showActiveIncomeDetail = false
    @State private var showPassiveIncomeDetail = false
    @State private var showTotalSpendingDetail = false
    @State private var showNeedsSpendingDetail = false
    @State private var showWantsSpendingDetail = false

    /// 已连接银行时由多月份 `get-spending-summary` 构建；未连接或拉取失败时为 nil，详情页使用空数据（非 Mock）。
    @State private var cashflowSpendingTotalDetail: TotalSpendingDetailData?
    @State private var cashflowNeedsDetail: SpendingDetailData?
    @State private var cashflowWantsDetail: SpendingDetailData?
    @State private var cashflowTotalIncomeDetail: TotalIncomeDetailData?
    @State private var cashflowActiveIncomeDetail: IncomeDetailData?
    @State private var cashflowPassiveIncomeDetail: IncomeDetailData?
    /// 已连接且拉到 summary 时为当年各月储蓄序列；否则 nil → 储蓄全屏用当年全 nil 序列。
    @State private var cashflowSavingsByYear: [Int: [Double?]]?

    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date()) - 1
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
        budgetSetupCompleted
        && (apiBudget.needsBudget + apiBudget.wantsBudget) > 0
    }

    private var isCashflowUnlocked: Bool {
        plaidManager.hasLinkedBank && budgetSetupCompleted
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
                        IncomeCard(
                            income:          incomeMonthDisplay,
                            yearlyIncome:    incomeYearDisplay,
                            onCardTapped:    { showTotalIncomeDetail = true },
                            onActiveTapped:  { showActiveIncomeDetail = true },
                            onPassiveTapped: { showPassiveIncomeDetail = true },
                            isConnected:     isCashflowUnlocked,
                            placeholderMessage: incomePlaceholderMessage
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        SavingsTargetCard(
                            currentAmount: $currentSavings,
                            targetAmount: apiBudget.savingsBudget,
                            isConnected: plaidManager.hasLinkedBank,
                            hasBudgetSetup: hasBudget,
                            onAdd: { showSavingsInput = true },
                            onCardTap: { showSavingsSummary = true }
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        BudgetCard(
                            spending: spendingForDisplay,
                            apiBudget: apiBudget,
                            isConnected: plaidManager.hasLinkedBank,
                            hasBudget: hasBudget,
                            onSetupBudget: { plaidManager.showBudgetSetup = true },
                            onCardTapped: { showTotalSpendingDetail = true },
                            onNeedsTapped: { showNeedsSpendingDetail = true },
                            onWantsTapped: { showWantsSpendingDetail = true }
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        cashAccountsSection

                        transactionsSection
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .onAppear {
            restoreFromCache()
        }
        .task {
            await loadCashflowData()
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await loadCashflowData() }
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadCashflowData() }
        }
        .onChange(of: budgetSetupCompleted) { _, _ in
            Task { await loadCashflowData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            Task { await loadCashflowData() }
        }
        .fullScreenCover(isPresented: $showSavingsSummary) {
            SavingsTargetDetailView2(
                savingsRatioPercent: apiBudget.savingsRatio,
                savingsBudgetTarget: apiBudget.savingsBudget,
                monthlyAmountsByYear: cashflowSavingsByYear ?? CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear(),
                onMonthlyAmountsChange: { updated in
                    applySavingsCheckIn(updated)
                }
            )
        }
        .fullScreenCover(isPresented: $showTotalIncomeDetail) {
            TotalIncomeDetailView(
                data: cashflowTotalIncomeDetail ?? .empty,
                initialSelectedMonth: currentMonthIndex,
                activeData: cashflowActiveIncomeDetail,
                passiveData: cashflowPassiveIncomeDetail
            )
        }
        .fullScreenCover(isPresented: $showActiveIncomeDetail) {
            IncomeDetailView(
                data: cashflowActiveIncomeDetail ?? .emptyActiveIncome,
                initialSelectedMonth: currentMonthIndex
            )
        }
        .fullScreenCover(isPresented: $showPassiveIncomeDetail) {
            IncomeDetailView(
                data: cashflowPassiveIncomeDetail ?? .emptyPassiveIncome,
                initialSelectedMonth: currentMonthIndex
            )
        }
        .fullScreenCover(isPresented: $showTotalSpendingDetail) {
            TotalSpendingAnalysisDetailView(
                data: cashflowSpendingTotalDetail ?? .empty,
                needsDetailData: cashflowNeedsDetail ?? .emptyNeeds,
                wantsDetailData: cashflowWantsDetail ?? .emptyWants,
                initialSelectedMonth: currentMonthIndex
            )
        }
        .fullScreenCover(isPresented: $showNeedsSpendingDetail) {
            SpendingAnalysisDetailView(
                data: cashflowNeedsDetail ?? .emptyNeeds,
                flamoraCategory: "needs",
                initialSelectedMonth: currentMonthIndex
            )
        }
        .fullScreenCover(isPresented: $showWantsSpendingDetail) {
            SpendingAnalysisDetailView(
                data: cashflowWantsDetail ?? .emptyWants,
                flamoraCategory: "wants",
                initialSelectedMonth: currentMonthIndex
            )
        }
        .sheet(isPresented: $showSavingsInput, onDismiss: syncMainCardSavingsToSeries) {
            SavingsInputSheet(amount: $currentSavings, onSubmit: { amount in
                Task { await persistCurrentMonthSavings(amount: amount) }
            })
                .ignoresSafeArea(.container, edges: .bottom)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(AppColors.backgroundPrimary)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction, linkedAccounts: linkedAccounts) { updated in
                try await persistTransactionClassification(updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.backgroundPrimary)
        }
        .fullScreenCover(isPresented: $showAllTransactions) {
            AllTransactionsView(transactions: $allTransactions, linkedAccounts: linkedAccounts) { updated in
                try await persistTransactionClassification(updated)
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
        if let savings = cache.cashflowSavingsByYear, cashflowSavingsByYear == nil {
            cashflowSavingsByYear = savings
            currentSavings = currentSavingsForCurrentMonth(from: savings) ?? currentSavings
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
    }

    func loadCashflowData() async {
        let monthStr = apiMonthString(from: Date())

        // 账户列表独立于 budget setup，只要连接了银行就加载
        if plaidManager.hasLinkedBank {
            if let nw = try? await APIService.shared.getNetWorthSummary() {
                linkedAccounts = nw.accounts.map { Account.fromNetWorthAccount($0) }
                cashAccountsList = nw.accounts.filter {
                    $0.type == "depository" || $0.type == "credit"
                }
            }
        } else {
            linkedAccounts = []
            cashAccountsList = []
        }

        guard isCashflowUnlocked else {
            apiBudget = .empty
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
            cashflowActiveIncomeDetail = nil
            cashflowPassiveIncomeDetail = nil
            cashflowSavingsByYear = nil
            allTransactions = []
            return
        }

        if let b = await fetchBudget(month: monthStr) {
            apiBudget = b
            FlamoraStorageKey.migrateBudgetSetupIfNeeded(budget: b, hasLinkedBank: true)
            currentSavings = b.savingsActual ?? 0
            needsTotal = b.needsSpent ?? 0
            wantsTotal = b.wantsSpent ?? 0
            totalSpend = (b.needsSpent ?? 0) + (b.wantsSpent ?? 0)
            TabContentCache.shared.setCashflowBudget(b)
        }

        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
        if summaries.isEmpty {
            print("⚠️ [CashflowView] No detail summaries loaded for \(year)-01...\(year)-\(String(format: "%02d", through))")
        } else if summaries[through - 1] == nil {
            let available = summaries.keys.sorted().map { String(format: "%02d", $0 + 1) }.joined(separator: ",")
            print("⚠️ [CashflowView] Current month summary missing for month \(through). Available months: \(available)")
        }

        if let cur = summaries[through - 1] {
            needsTotal = cur.needs.total
            wantsTotal = cur.wants.total
            totalSpend = cur.totalSpending
            let inc = cur.totalIncome
            incomeMonthDisplay = Income(total: inc, active: inc, passive: 0, sources: [])
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
            cashflowActiveIncomeDetail = CashflowAPICharts.activeIncomeDetail(summaries: summaries, year: year)
            cashflowPassiveIncomeDetail = CashflowAPICharts.passiveIncomeDetail(summaries: summaries, year: year)
            cashflowSavingsByYear = savings
            currentSavings = currentSavingsForCurrentMonth(from: savings) ?? currentSavings
            TabContentCache.shared.setCashflowSavingsByYear(savings)
            TabContentCache.shared.setCashflowSpendingDetails(total: total, needs: needs, wants: wants)
        } else {
            cashflowSpendingTotalDetail = nil
            cashflowNeedsDetail = nil
            cashflowWantsDetail = nil
            cashflowTotalIncomeDetail = nil
            cashflowActiveIncomeDetail = nil
            cashflowPassiveIncomeDetail = nil
            cashflowSavingsByYear = nil
        }

        if let tx = try? await APIService.shared.getTransactions(page: 1, limit: 20) {
            allTransactions = tx.transactions.map { Transaction(from: $0) }
        }
    }

    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
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
                    onAddAccount: { Task { await plaidManager.startLinkFlow() } }
                )
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }
}

// MARK: - Transactions

private extension CashflowView {
    var transactionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
            HStack {
                Text("RECENT ACTIVITY")
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(0.6)

                Spacer()

                if isCashflowUnlocked {
                    Button(action: { showAllTransactions = true }) {
                        Text("SEE ALL")
                            .font(.smallLabel)
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(0.4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            if isCashflowUnlocked {
                if recentActivityTransactions.isEmpty {
                    Text("No recent activity yet")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.vertical, AppSpacing.md)
                } else {
                    ForEach(recentActivityTransactions) { transaction in
                        TransactionRow(
                            transaction: transaction,
                            titleOverride: recentActivityTitle(for: transaction)
                        ) {
                            selectedTransaction = transaction
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)
                    }
                }
            } else {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: plaidManager.hasLinkedBank ? "sparkles" : "lock.fill")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary.opacity(0.45))
                    Text(plaidManager.hasLinkedBank
                         ? "Complete Build Your Plan to unlock activity"
                         : "Connect accounts to see recent activity")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.vertical, AppSpacing.md)
            }
        }
        .padding(.top, 4)
    }

    var recentActivityTransactions: [Transaction] {
        let sorted = allTransactions.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return ($0.time ?? "") > ($1.time ?? "")
        }

        let filtered = sorted.filter {
            !hiddenReviewedTransactionIDs.contains($0.id) && !isLowSignalActivity($0)
        }
        if filtered.isEmpty {
            let visible = sorted.filter { !hiddenReviewedTransactionIDs.contains($0.id) }
            return Array(visible.prefix(5))
        }
        return Array(filtered.prefix(5))
    }

    func isLowSignalActivity(_ transaction: Transaction) -> Bool {
        let sub = transaction.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let merchant = transaction.merchant.lowercased()

        if [
            "transfer_out",
            "transfer_in",
            "credit card payment",
            "credit_card_payment",
            "payment",
        ].contains(sub) {
            return true
        }

        if merchant.contains("payment thank you") {
            return true
        }

        return false
    }

    @MainActor
    func persistTransactionClassification(_ updated: Transaction) async throws {
        let response = try await APIService.shared.updateTransactionClassification(
            transactionId: updated.id,
            category: updated.category,
            subcategory: updated.subcategory
        )
        updateTransaction(Transaction(from: response))
        Task { await loadCashflowData() }
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

        if let old,
           old.category != updated.category || old.subcategory != updated.subcategory || (old.pendingClassification && !updated.pendingClassification) {
            withAnimation(.easeInOut(duration: 0.22)) {
                hiddenReviewedTransactionIDs.insert(updated.id)
            }
        }
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
        let year = Calendar.current.component(.year, from: Date())
        let month = currentMonthIndex

        var trendsByYear = data.trendsByYear
        var monthlyDataByYear = data.monthlyDataByYear
        var yearlyTrend = trendsByYear[year] ?? Array(repeating: nil, count: 12)
        var monthlyData = monthlyDataByYear[year] ?? [:]
        let current = monthlyData[month] ?? SpendingDetailMonthData(total: 0, categories: [])

        var total = current.total
        var categoryAmounts = Dictionary(uniqueKeysWithValues: current.categories.map { ($0.name, $0.amount) })

        if let oldTx {
            let name = oldTx.subcategory ?? "uncategorized"
            let nextAmount = max(0, (categoryAmounts[name] ?? 0) - oldTx.amount)
            if nextAmount <= 0.005 {
                categoryAmounts.removeValue(forKey: name)
            } else {
                categoryAmounts[name] = nextAmount
            }
            total = max(0, total - oldTx.amount)
        }

        if let newTx {
            let name = newTx.subcategory ?? "uncategorized"
            categoryAmounts[name] = (categoryAmounts[name] ?? 0) + newTx.amount
            total += newTx.amount
        }

        let categories = categoryAmounts
            .sorted { $0.value > $1.value }
            .map { name, amount in
                SpendingDetailCategory(
                    id: "\(bucket)-\(year)-\(month)-\(name)",
                    icon: TransactionCategoryCatalog.icon(forStoredSubcategory: name) ?? "tag.fill",
                    name: name,
                    amount: amount,
                    percentage: total > 0 ? (amount / total) * 100 : 0
                )
            }

        monthlyData[month] = SpendingDetailMonthData(total: total, categories: categories)
        yearlyTrend[month] = total
        trendsByYear[year] = yearlyTrend
        monthlyDataByYear[year] = monthlyData

        return SpendingDetailData(
            title: data.title,
            accentColor: data.accentColor,
            trendsByYear: trendsByYear,
            monthlyDataByYear: monthlyDataByYear
        )
    }

    func updateTotalSpendingDetail(
        _ data: TotalSpendingDetailData?,
        old: Transaction,
        updated: Transaction
    ) -> TotalSpendingDetailData? {
        guard let data else { return nil }
        let year = Calendar.current.component(.year, from: Date())
        let month = currentMonthIndex

        var trendsByYear = data.trendsByYear
        var monthlyDataByYear = data.monthlyDataByYear
        var yearlyTrend = trendsByYear[year] ?? Array(repeating: nil, count: 12)
        var monthlyData = monthlyDataByYear[year] ?? [:]
        var current = monthlyData[month] ?? TotalSpendingMonthData(
            total: 0,
            needsAmount: 0,
            wantsAmount: 0,
            needsPercentage: 0,
            wantsPercentage: 0
        )

        var needsAmount = current.needsAmount
        var wantsAmount = current.wantsAmount

        if old.category == "needs" { needsAmount = max(0, needsAmount - old.amount) }
        if old.category == "wants" { wantsAmount = max(0, wantsAmount - old.amount) }
        if updated.category == "needs" { needsAmount += updated.amount }
        if updated.category == "wants" { wantsAmount += updated.amount }

        let total = needsAmount + wantsAmount
        current = TotalSpendingMonthData(
            total: total,
            needsAmount: needsAmount,
            wantsAmount: wantsAmount,
            needsPercentage: total > 0 ? (needsAmount / total) * 100 : 0,
            wantsPercentage: total > 0 ? (wantsAmount / total) * 100 : 0
        )

        monthlyData[month] = current
        yearlyTrend[month] = total
        trendsByYear[year] = yearlyTrend
        monthlyDataByYear[year] = monthlyData

        return TotalSpendingDetailData(
            title: data.title,
            trendsByYear: trendsByYear,
            monthlyDataByYear: monthlyDataByYear
        )
    }

    func recentActivityTitle(for transaction: Transaction) -> String {
        var name = transaction.merchant
            .replacingOccurrences(of: #"(?i)^(ach withdrawal|ach deposit|pos debit|debit card purchase|card purchase|online payment|online transfer|withdrawal|purchase authorization)\s*[-:]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\bcheck\s+\d+\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b\d{6,}\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty {
            name = transaction.merchant
        }

        if name.count > 34 {
            name = String(name.prefix(31)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        return name
    }
}

// TransactionRow is defined in TransactionRow.swift

#Preview {
    CashflowView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
