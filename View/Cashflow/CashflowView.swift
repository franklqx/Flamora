//
//  CashflowView.swift
//  Flamora app
//
//  Saving / Cash Flow summary page
//

import SwiftUI

struct CashflowView: View {
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private let data = MockData.cashflowData
    @State private var apiBudget = MockData.apiMonthlyBudget
    @State private var selectedMonthIndex = 0
    @State private var monthDates: [Date] = []
    @State private var hasInitializedMonths = false
    @State private var currentSavings: Double = MockData.apiMonthlyBudget.savingsActual
    @State private var needsTotal: Double = MockData.apiMonthlyBudget.needsSpent
    @State private var wantsTotal: Double = MockData.apiMonthlyBudget.wantsSpent
    @State private var totalSpend: Double = MockData.apiMonthlyBudget.needsSpent + MockData.apiMonthlyBudget.wantsSpent
    @State private var reviewTransactions: [Transaction] = MockData.cashflowData.toReview.transactions
    @State private var reviewCount: Int = MockData.cashflowData.toReview.count
    @State private var showSavingsInput = false
    @State private var showSavingsSummary = false
    @State private var showTotalIncomeDetail = false
    @State private var showActiveIncomeDetail = false
    @State private var showPassiveIncomeDetail = false
    @State private var showTotalSpendingDetail = false
    @State private var showNeedsSpendingDetail = false
    @State private var showWantsSpendingDetail = false

    private var spendingForDisplay: Spending {
        Spending(
            total: totalSpend,
            needs: needsTotal,
            wants: wantsTotal,
            budgetLimit: apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
        )
    }

    var body: some View {
        if plaidManager.hasLinkedBank {
            connectedView
        } else {
            CashflowCTAView()
        }
    }

    var connectedView: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            IncomeCard(
                                income: data.income,
                                monthDates: monthDates,
                                selectedMonthIndex: selectedMonthIndex,
                                onMonthSelected: { idx in selectedMonthIndex = idx },
                                onCardTapped: { showTotalIncomeDetail = true },
                                onActiveTapped: { showActiveIncomeDetail = true },
                                onPassiveTapped: { showPassiveIncomeDetail = true }
                            )
                            .padding(.horizontal, AppSpacing.screenPadding)

                            SavingsTargetCard(
                                currentAmount: $currentSavings,
                                targetAmount: apiBudget.savingsBudget,
                                onAdd: { showSavingsInput = true },
                                onCardTap: { showSavingsSummary = true }
                            )
                            .padding(.horizontal, AppSpacing.screenPadding)

                            BudgetCard(
                                spending: spendingForDisplay,
                                onCardTapped: { showTotalSpendingDetail = true },
                                onNeedsTapped: { showNeedsSpendingDetail = true },
                                onWantsTapped: { showWantsSpendingDetail = true }
                            )
                            .padding(.horizontal, AppSpacing.screenPadding)

                            toReviewSection
                        }
                        .frame(minHeight: proxy.size.height, alignment: .top)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.lg)
                    }
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            initializeMonths()
        }
        .task {
            await loadCashflowData()
        }
        .fullScreenCover(isPresented: $showSavingsSummary) {
            SavingsTargetDetailView2()
        }
        .fullScreenCover(isPresented: $showTotalIncomeDetail) {
            TotalIncomeDetailView(data: MockData.totalIncomeDetail)
        }
        .fullScreenCover(isPresented: $showActiveIncomeDetail) {
            IncomeDetailView(data: MockData.activeIncomeDetail)
        }
        .fullScreenCover(isPresented: $showPassiveIncomeDetail) {
            IncomeDetailView(data: MockData.passiveIncomeDetail)
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
    }
}

// MARK: - Data Loading

private extension CashflowView {
    func loadCashflowData() async {
        let monthStr = apiMonthString(from: Date())
        async let budgetTask = fetchBudget(month: monthStr)
        async let txTask = fetchTransactions()
        let (budget, txResponse) = await (budgetTask, txTask)
        if let b = budget {
            apiBudget = b
            currentSavings = b.savingsActual
            needsTotal = b.needsSpent
            wantsTotal = b.wantsSpent
            totalSpend = b.needsSpent + b.wantsSpent
        }
        if let tx = txResponse {
            reviewTransactions = tx.transactions.map {
                Transaction(id: $0.id, merchant: $0.merchant, amount: $0.amount, date: $0.date, pendingClassification: $0.pendingReview)
            }
            reviewCount = reviewTransactions.count
        }
    }

    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }
    private func fetchTransactions() async -> APITransactionsResponse? {
        try? await APIService.shared.getTransactions(page: 1, limit: 20, pendingReview: true)
    }

    func apiMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

// MARK: - Month Helpers

private extension CashflowView {
    func initializeMonths() {
        guard !hasInitializedMonths else { return }
        let calendar = Calendar.current
        let now = Date()
        let base = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let offsets = -5...6
        monthDates = offsets.compactMap { calendar.date(byAdding: .month, value: $0, to: base) }
        selectedMonthIndex = 5
        hasInitializedMonths = true
    }
}

// MARK: - To Review

private extension CashflowView {
    var toReviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TO REVIEW")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.6)

                Spacer()

                Text("\(reviewCount) LEFT")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(0.4)
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            if reviewTransactions.isEmpty {
                Text("All transactions reviewed")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(reviewTransactions, id: \.id) { transaction in
                    TransactionCard(
                        transaction: transaction,
                        onNeeds: { classify(transaction, as: .needs) },
                        onWants: { classify(transaction, as: .wants) }
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
            }
        }
        .padding(.top, 4)
    }

    enum ReviewCategory { case needs; case wants }

    func classify(_ transaction: Transaction, as category: ReviewCategory) {
        if let index = reviewTransactions.firstIndex(where: { $0.id == transaction.id }) {
            reviewTransactions.remove(at: index)
            reviewCount = max(reviewCount - 1, 0)
            totalSpend += transaction.amount
            switch category {
            case .needs: needsTotal += transaction.amount
            case .wants: wantsTotal += transaction.amount
            }
        }
    }
}

// MARK: - Transaction Card (line style per reference)

private struct TransactionCard: View {
    let transaction: Transaction
    let onNeeds: () -> Void
    let onWants: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                Image(systemName: "bag")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }

            // Merchant + date
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(formattedDate(transaction.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            // Amount + category badge
            VStack(alignment: .trailing, spacing: 6) {
                Text(formattedAmount(transaction.amount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    categoryButton(title: "Needs", action: onNeeds)
                    categoryButton(title: "Wants", action: onWants)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private func categoryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(Color.clear)
                .overlay(
                    Capsule()
                        .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: " ")
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: -amount)) ?? "$0.00"
    }
}

// MARK: - Cashflow CTA

private struct CashflowCTAView: View {
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xl)

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [AppColors.accentBlue.opacity(0.15), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        Image(systemName: "creditcard")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accentBlueBright, AppColors.accentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text("Track Your\nCashflow")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Connect your accounts to automatically\ntrack spending, savings, and budgets.")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 12) {
                        ForEach(features, id: \.0) { icon, text in
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.accentBlueBright)
                                    .frame(width: 24)
                                Text(text)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Spacer(minLength: AppSpacing.xl)

                    Button(action: {
                        Task { await plaidManager.startLinkFlow() }
                    }) {
                        HStack(spacing: 8) {
                            if plaidManager.isConnecting {
                                ProgressView().tint(.black)
                            } else {
                                Text("Connect to Accounts")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
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
                    .disabled(plaidManager.isConnecting)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.bottom, 120)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            }
        }
    }

    private let features: [(String, String)] = [
        ("list.bullet.rectangle", "Auto transaction categorization"),
        ("chart.bar", "Monthly needs vs wants breakdown"),
        ("arrow.up.arrow.down", "To Review — flag unusual spending"),
        ("banknote", "Savings goal tracking")
    ]
}

#Preview {
    CashflowView()
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
