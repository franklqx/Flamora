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

    private let data = MockData.cashflowData
    @State private var apiBudget = MockData.apiMonthlyBudget
    @State private var currentSavings: Double = MockData.apiMonthlyBudget.savingsActual ?? 0
    @State private var needsTotal: Double = MockData.apiMonthlyBudget.needsSpent ?? 0
    @State private var wantsTotal: Double = MockData.apiMonthlyBudget.wantsSpent ?? 0
    @State private var totalSpend: Double = (MockData.apiMonthlyBudget.needsSpent ?? 0) + (MockData.apiMonthlyBudget.wantsSpent ?? 0)
    @State private var allTransactions: [Transaction] = MockData.allTransactions
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
        (apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget) > 0
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
                            income:          data.income,
                            yearlyIncome:    MockData.yearlyIncome,
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
        .fullScreenCover(isPresented: $showSavingsSummary) {
            SavingsTargetDetailView2()
        }
        .fullScreenCover(isPresented: $showTotalIncomeDetail) {
            TotalIncomeDetailView(data: MockData.totalIncomeDetail, initialSelectedMonth: currentMonthIndex)
        }
        .fullScreenCover(isPresented: $showActiveIncomeDetail) {
            IncomeDetailView(data: MockData.activeIncomeDetail, initialSelectedMonth: currentMonthIndex)
        }
        .fullScreenCover(isPresented: $showPassiveIncomeDetail) {
            IncomeDetailView(data: MockData.passiveIncomeDetail, initialSelectedMonth: currentMonthIndex)
        }
        .fullScreenCover(isPresented: $showTotalSpendingDetail) {
            TotalSpendingAnalysisDetailView(data: MockData.totalSpendingDetail)
        }
        .fullScreenCover(isPresented: $showNeedsSpendingDetail) {
            SpendingAnalysisDetailView(data: MockData.needsSpendingDetail)
        }
        .fullScreenCover(isPresented: $showWantsSpendingDetail) {
            SpendingAnalysisDetailView(data: MockData.wantsSpendingDetail)
        }
        .sheet(isPresented: $showSavingsInput) {
            SavingsInputSheet(amount: $currentSavings)
                .ignoresSafeArea(.container, edges: .bottom)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color.black)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction) { updated in
                updateTransaction(updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(Color.black)
        }
        .fullScreenCover(isPresented: $showAllTransactions) {
            AllTransactionsView(transactions: $allTransactions, onUpdate: updateTransaction)
        }
    }
}

// MARK: - Data Loading

private extension CashflowView {
    func loadCashflowData() async {
        let monthStr = apiMonthString(from: Date())
        if let b = await fetchBudget(month: monthStr) {
            apiBudget = b
            currentSavings = b.savingsActual ?? 0
            needsTotal = b.needsSpent ?? 0
            wantsTotal = b.wantsSpent ?? 0
            totalSpend = (b.needsSpent ?? 0) + (b.wantsSpent ?? 0)
        }
        if let tx = try? await APIService.shared.getTransactions(page: 1, limit: 20) {
            allTransactions = tx.transactions.map {
                Transaction(id: $0.id, merchant: $0.merchant, amount: $0.amount, date: $0.date, time: nil, pendingClassification: $0.pendingReview, subcategory: nil, category: nil, note: nil)
            }
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
