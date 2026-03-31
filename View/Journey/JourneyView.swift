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
    @State private var quoteIndex: Int = 0
    @State private var quoteVisible: Bool = true
    private let data = MockData.journeyData
    var onFireTapped: (() -> Void)? = nil
    var onInvestmentTapped: (() -> Void)? = nil
    var onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    let bottomPadding: CGFloat

    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

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
                            gainAmount: netWorthSummary.growthAmount ?? 0,
                            gainPercentage: netWorthSummary.growthPercentage ?? 0,
                            isConnected: hasInvestmentAccounts,
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
                                    daysLeft: data.budget.daysLeft,
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
    var hasInvestmentAccounts: Bool {
        netWorthSummary.accounts.contains { $0.type == "investment" }
    }

    var hasBudgetData: Bool {
        plaidManager.hasLinkedBank
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
            print("📍 [Flow] loadData skipped budget fetch — hasLinkedBank=false")
            return
        }

        async let budgetTask = fetchBudget(month: monthStr)
        let (nw, budget, fire) = await (nwTask, budgetTask, fireTask)
        if let nw {
            netWorthSummary = nw
            let hasInv = nw.accounts.contains { $0.type == "investment" }
            print("📍 [Flow] net worth loaded — accounts: \(nw.accounts.count), total: \(nw.totalNetWorth), hasInvestment: \(hasInv)")
        } else {
            print("📍 [Flow] ❌ net worth fetch returned nil")
        }
        if let budget {
            apiBudget = budget
            print("📍 [Flow] budget loaded — selectedPlan=\(budget.selectedPlan ?? "nil"), needs=\(budget.needsBudget), wants=\(budget.wantsBudget), savings=\(budget.savingsBudget)")
        } else {
            print("📍 [Flow] budget fetch returned nil (no budget in DB for \(monthStr))")
        }
        fireGoal = fire
        print("📍 [Flow] hasBudgetData=\(hasBudgetData), hasLinkedBank=\(plaidManager.hasLinkedBank)")
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

#Preview {
    JourneyView(onFireTapped: {})
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
