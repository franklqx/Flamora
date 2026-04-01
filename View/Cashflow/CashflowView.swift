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
    /// 与 `transaction.accountId` 匹配，供交易详情 Sheet 展示账户行。
    @State private var linkedAccounts: [Account] = []
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
            budgetLimit: apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
        )
    }

    private var hasBudget: Bool {
        budgetSetupCompleted
        && (apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget) > 0
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
                            isConnected:     plaidManager.hasLinkedBank
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        SavingsTargetCard(
                            currentAmount: $currentSavings,
                            targetAmount: apiBudget.savingsBudget,
                            isConnected: plaidManager.hasLinkedBank,
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

                        transactionsSection
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
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
        .fullScreenCover(isPresented: $showSavingsSummary) {
            SavingsTargetDetailView2(
                savingsRatioPercent: apiBudget.savingsRatio,
                savingsBudgetTarget: apiBudget.savingsBudget,
                monthlyAmountsByYear: cashflowSavingsByYear ?? CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()
            )
        }
        .fullScreenCover(isPresented: $showTotalIncomeDetail) {
            TotalIncomeDetailView(
                data: cashflowTotalIncomeDetail ?? .empty,
                initialSelectedMonth: currentMonthIndex
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
                wantsDetailData: cashflowWantsDetail ?? .emptyWants
            )
        }
        .fullScreenCover(isPresented: $showNeedsSpendingDetail) {
            SpendingAnalysisDetailView(data: cashflowNeedsDetail ?? .emptyNeeds)
        }
        .fullScreenCover(isPresented: $showWantsSpendingDetail) {
            SpendingAnalysisDetailView(data: cashflowWantsDetail ?? .emptyWants)
        }
        .sheet(isPresented: $showSavingsInput) {
            SavingsInputSheet(amount: $currentSavings)
                .ignoresSafeArea(.container, edges: .bottom)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(AppColors.backgroundPrimary)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction, linkedAccounts: linkedAccounts) { updated in
                updateTransaction(updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.backgroundPrimary)
        }
        .fullScreenCover(isPresented: $showAllTransactions) {
            AllTransactionsView(transactions: $allTransactions, linkedAccounts: linkedAccounts, onUpdate: updateTransaction)
        }
    }
}

// MARK: - Data Loading

private extension CashflowView {
    func loadCashflowData() async {
        let monthStr = apiMonthString(from: Date())

        if !plaidManager.hasLinkedBank {
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
            linkedAccounts = []
            return
        }

        if let b = await fetchBudget(month: monthStr) {
            apiBudget = b
            FlamoraStorageKey.migrateBudgetSetupIfNeeded(budget: b, hasLinkedBank: true)
            currentSavings = b.savingsActual ?? 0
            needsTotal = b.needsSpent ?? 0
            wantsTotal = b.wantsSpent ?? 0
            totalSpend = (b.needsSpent ?? 0) + (b.wantsSpent ?? 0)
        }

        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)

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
            cashflowSpendingTotalDetail = CashflowAPICharts.totalSpendingDetail(summaries: summaries, year: year)
            cashflowNeedsDetail = CashflowAPICharts.needsSpendingDetail(summaries: summaries, year: year)
            cashflowWantsDetail = CashflowAPICharts.wantsSpendingDetail(summaries: summaries, year: year)
            cashflowTotalIncomeDetail = CashflowAPICharts.totalIncomeDetail(summaries: summaries, year: year)
            cashflowActiveIncomeDetail = CashflowAPICharts.activeIncomeDetail(summaries: summaries, year: year)
            cashflowPassiveIncomeDetail = CashflowAPICharts.passiveIncomeDetail(summaries: summaries, year: year)
            cashflowSavingsByYear = CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
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

        if let nw = try? await APIService.shared.getNetWorthSummary() {
            linkedAccounts = nw.accounts.map { Account.fromNetWorthAccount($0) }
        } else {
            linkedAccounts = []
        }
    }

    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }

    func apiMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

// MARK: - Transactions

private extension CashflowView {
    var transactionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
            HStack {
                Text("TRANSACTIONS")
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(0.6)

                Spacer()

                if plaidManager.hasLinkedBank {
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

            if plaidManager.hasLinkedBank {
                ForEach(allTransactions.sorted {
                    if $0.date != $1.date { return $0.date > $1.date }
                    return ($0.time ?? "") > ($1.time ?? "")
                }.prefix(5)) { transaction in
                    TransactionRow(transaction: transaction) {
                        selectedTransaction = transaction
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
            } else {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary.opacity(0.45))
                    Text("Connect accounts to see your transactions")
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

    func updateTransaction(_ updated: Transaction) {
        guard let index = allTransactions.firstIndex(where: { $0.id == updated.id }) else { return }
        let old = allTransactions[index]

        // Adjust running totals when category changes (category is derived from subcategory)
        if old.category != updated.category {
            if old.category == "needs"      { needsTotal -= old.amount }
            else if old.category == "wants" { wantsTotal -= old.amount }
            else                            { totalSpend += updated.amount }

            if updated.category == "needs"      { needsTotal += updated.amount }
            else if updated.category == "wants" { wantsTotal += updated.amount }
            else                                { totalSpend -= updated.amount }
        }

        allTransactions[index] = updated
    }
}

// TransactionRow is defined in TransactionRow.swift

#Preview {
    CashflowView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
