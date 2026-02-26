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

    private var formattedMonthLabel: String {
        monthHeaderLabel(selectedMonthDate)
    }

    private var selectedMonthDate: Date {
        guard selectedMonthIndex >= 0, selectedMonthIndex < monthDates.count else {
            return Date()
        }
        return monthDates[selectedMonthIndex]
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
                AppBackgroundView()

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            monthSelector

                            IncomeCard(
                                income: data.income,
                                monthLabel: formattedMonthLabel,
                                onCardTapped: { showTotalIncomeDetail = true },
                                onActiveTapped: { showActiveIncomeDetail = true },
                                onPassiveTapped: { showPassiveIncomeDetail = true }
                            )
                                .padding(.horizontal, AppSpacing.screenPadding)

                            sectionTitle("Monthly Savings")
                                .padding(.horizontal, AppSpacing.screenPadding)

                            SavingsTargetCard(
                                currentAmount: $currentSavings,
                                targetAmount: apiBudget.savingsBudget,
                                onAdd: { showSavingsInput = true },
                                onCardTap: { showSavingsSummary = true }
                            )
                            .padding(.horizontal, AppSpacing.screenPadding)

                            sectionTitle("Monthly Budget Spend")
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
                        .padding(.top, TopHeaderBar.height)
                        .padding(.bottom, AppSpacing.tabBarReserve)
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

    // async let + try? 组合会触发 Swift runtime crash (swift_task_dealloc)
    // 将 try? 包裹在独立函数中避免此问题
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

// MARK: - Header
private extension CashflowView {
    var monthSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(monthDates.indices, id: \.self) { index in
                        let isSelected = index == selectedMonthIndex
                        Text(monthPillLabel(monthDates[index]))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isSelected ? .white : Color(hex: "#6B7280"))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color(hex: "#121212") : Color.clear)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color(hex: "#222222") : Color.clear, lineWidth: 1)
                                    )
                            )
                            .id(index)
                            .onTapGesture {
                                selectedMonthIndex = index
                            }
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
            .onAppear {
                scrollToCurrentMonth(using: proxy, animated: false)
            }
            .onChange(of: selectedMonthIndex) { _, _ in
                scrollToCurrentMonth(using: proxy, animated: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sections
private extension CashflowView {
    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Month Helpers
private extension CashflowView {
    static let monthPillFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter
    }()

    static let monthHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    func monthPillLabel(_ date: Date) -> String {
        Self.monthPillFormatter.string(from: date)
    }

    func monthHeaderLabel(_ date: Date) -> String {
        Self.monthHeaderFormatter.string(from: date)
    }

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

    func scrollToCurrentMonth(using proxy: ScrollViewProxy, animated: Bool) {
        guard selectedMonthIndex >= 0, selectedMonthIndex < monthDates.count else { return }
        if animated {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                proxy.scrollTo(selectedMonthIndex, anchor: .center)
            }
        } else {
            proxy.scrollTo(selectedMonthIndex, anchor: .center)
        }
    }
}

// MARK: - To Review
private extension CashflowView {
    var toReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("To Review")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(reviewCount) Left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#9CA3AF"))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color(hex: "#1A1A1A"))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.screenPadding)

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

    enum ReviewCategory {
        case needs
        case wants
    }

    func classify(_ transaction: Transaction, as category: ReviewCategory) {
        if let index = reviewTransactions.firstIndex(where: { $0.id == transaction.id }) {
            reviewTransactions.remove(at: index)
            reviewCount = max(reviewCount - 1, 0)

            totalSpend += transaction.amount
            switch category {
            case .needs:
                needsTotal += transaction.amount
            case .wants:
                wantsTotal += transaction.amount
            }
        }
    }
}

// MARK: - Transaction Card
private struct TransactionCard: View {
    let transaction: Transaction
    let onNeeds: () -> Void
    let onWants: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchant)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(formattedDate(transaction.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#6B7280"))
                }

                Spacer()

                Text(formattedAmount(transaction.amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 12) {
                Button(action: onNeeds) {
                    HStack {
                        Text("Needs")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#0F172A"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#A78BFA"))
                    .clipShape(Capsule())
                }

                Button(action: onWants) {
                    HStack {
                        Text("Wants")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#0F172A"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#93C5FD"))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
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
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Cashflow 初始状态 CTA

private struct CashflowCTAView: View {
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xl)

                    // Hero icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(hex: "#93C5FD").opacity(0.15), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#60A5FA"), Color(hex: "#A78BFA")],
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
                            .foregroundColor(Color(hex: "#9CA3AF"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 12) {
                        ForEach(features, id: \.0) { icon, text in
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#60A5FA"))
                                    .frame(width: 24)
                                Text(text)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#121212"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#222222"), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Spacer(minLength: AppSpacing.xl)

                    Button(action: {
                        Task {
                            if !subscriptionManager.isPremium {
                                await subscriptionManager.checkStatus()
                            }
                            if subscriptionManager.isPremium {
                                await plaidManager.startLinkFlow()
                            } else {
                                subscriptionManager.showPaywall = true
                            }
                        }
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
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(plaidManager.isConnecting)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.bottom, 120)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom, AppSpacing.tabBarReserve)
                .padding(.top, TopHeaderBar.height + AppSpacing.lg)
            }
        }
    }

    private let features: [(String, String)] = [
        ("list.bullet.rectangle", "Auto transaction categorization"),
        ("chart.bar.fill", "Monthly needs vs wants breakdown"),
        ("arrow.up.arrow.down", "To Review — flag unusual spending"),
        ("banknote", "Savings goal tracking")
    ]
}

#Preview {
    CashflowView()
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
