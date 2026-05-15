//
//  InvestmentView.swift
//  Meridian
//
//  Investment overview page
//

import SwiftUI

struct InvestmentView: View {
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(InvestmentHeroData.self) private var heroData

    @State private var apiNetWorth: APINetWorthSummary? = nil
    /// 来自 `get-investment-holdings`；断连或未拉取成功时为 nil。
    @State private var apiHoldingsPayload: APIInvestmentHoldingsPayload?
    /// 按时间范围缓存的真实历史曲线；Hero 层读取 InvestmentHeroData，此处保留供 loadInvestmentData 使用。
    @State private var portfolioHistoryCache: [String: [PortfolioDataPoint]] = [:]
    @State private var loadError = false
    @State private var showTrustBridge = false
    @State private var setupState: HomeSetupStateResponse? = HomeSetupStateCache.load()
    @State private var isMarkingExplicitZero = false
    @State private var showExplicitZeroConfirm = false

    var body: some View {
        connectedView
    }

    var connectedView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                if loadError {
                    ErrorBanner(
                        message: "Couldn't load portfolio data.",
                        onRetry: { Task { await loadInvestmentData() } }
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                if showSetupBanner {
                    setupBanner
                        .padding(.horizontal, AppSpacing.screenPadding)
                }

                AssetAllocationCard(
                    allocation: displayAllocation,
                    isConnected: plaidManager.hasLinkedBank,
                    holdingsPayload: apiHoldingsPayload,
                    cashBankAccounts: cashBankAccounts
                )
                .padding(.horizontal, AppSpacing.screenPadding)

                AccountsCard(
                    accounts: computedAccounts,
                    isConnected: plaidManager.hasLinkedBank,
                    onAddAccount: handleAddAccount
                )
                .padding(.horizontal, AppSpacing.screenPadding)
            }
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)
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
        .alert("Skip investment portfolio?", isPresented: $showExplicitZeroConfirm) {
            Button("Add Investment Account") { handleAddAccount() }
            Button("Continue with $0") { Task { await markStartingPortfolioExplicitZero() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll start your FIRE progress from $0 for now. You can add investment accounts later and your progress will update automatically.")
        }
        .onAppear {
            if apiNetWorth == nil {
                apiNetWorth = TabContentCache.shared.investmentNetWorth
            }
            if portfolioHistoryCache.isEmpty {
                portfolioHistoryCache = TabContentCache.shared.portfolioHistory
            }
            if apiHoldingsPayload == nil {
                apiHoldingsPayload = TabContentCache.shared.investmentHoldings
            }
            // 从缓存恢复 Hero 层数据（避免 Tab 切回时图表空白）
            if heroData.balance == 0, !portfolioHistoryCache.isEmpty {
                heroData.balance        = portfolioBalanceDisplay
                heroData.gainAmount     = apiHoldingsPayload?.summary.totalGainLoss ?? apiNetWorth?.growthAmount ?? 0
                heroData.gainPercentage = apiHoldingsPayload?.summary.totalGainLossPct ?? apiNetWorth?.growthPercentage ?? 0
                heroData.historyCache   = portfolioHistoryCache
            }
        }
        .task {
            await loadInvestmentData()
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadInvestmentData(force: true) }
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await refreshSetupState() }
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
    }
}

// MARK: - Data Loading & Computed Data
private extension InvestmentView {
    /// Investment Tab 主数字：账户总值（含未投资现金）→ 净资产投资合计 → 0。
    /// 不允许 fallback 到 totalNetWorth（totalNetWorth 混入 depository，语义错误）。
    var portfolioBalanceDisplay: Double {
        if let h = apiHoldingsPayload {
            let accountValue = h.summary.totalAccountValue ?? h.summary.totalValue
            if accountValue > 0 { return accountValue }
        }
        guard let nw = apiNetWorth else { return 0 }
        return nw.breakdown.investmentTotal ?? 0
    }

    /// 未连接：零占位；已连接：用 `get-investment-holdings` 聚合；拉取失败：零占位。
    var displayAllocation: Allocation {
        guard plaidManager.hasLinkedBank else {
            return InvestmentAllocationBuilder.zeroAllocation
        }
        guard let p = apiHoldingsPayload else {
            return InvestmentAllocationBuilder.zeroAllocation
        }
        return InvestmentAllocationBuilder.allocation(from: p)
    }

    var cashBankAccounts: [Account] {
        computedAccounts.filter { $0.accountType == .bank }
    }

    func loadInvestmentData(force: Bool = false) async {
        loadError = false
        await refreshSetupState()
        guard plaidManager.hasLinkedBank else {
            apiNetWorth = nil
            apiHoldingsPayload = nil
            portfolioHistoryCache = [:]
            TabContentCache.shared.setInvestmentNetWorth(nil)
            heroData.balance = 0
            heroData.gainAmount = 0
            heroData.gainPercentage = 0
            heroData.historyCache = [:]
            return
        }
        if !force,
           apiNetWorth != nil,
           apiHoldingsPayload != nil,
           !portfolioHistoryCache.isEmpty {
            return
        }
        let nw = await fetchNetWorth()
        if nw == nil { loadError = true }
        apiNetWorth = nw
        TabContentCache.shared.setInvestmentNetWorth(nw)
        async let holdingsTask = fetchHoldingsPayload()
        async let historyTask  = fetchAllPortfolioHistory()
        let (h, hist) = await (holdingsTask, historyTask)
        apiHoldingsPayload    = h
        portfolioHistoryCache = hist
        TabContentCache.shared.setPortfolioHistory(hist)
        TabContentCache.shared.setInvestmentHoldings(h)
        // 同步到 Hero 层
        heroData.balance       = portfolioBalanceDisplay
        heroData.gainAmount    = h?.summary.totalGainLoss ?? nw?.growthAmount ?? 0
        heroData.gainPercentage = h?.summary.totalGainLossPct ?? nw?.growthPercentage ?? 0
        heroData.historyCache  = hist
    }

    private func fetchAllPortfolioHistory() async -> [String: [PortfolioDataPoint]] {
        let ranges = ["1w", "1m", "3m", "ytd", "all"]
        var result: [String: [PortfolioDataPoint]] = [:]
        await withTaskGroup(of: (String, [PortfolioDataPoint]).self) { group in
            for r in ranges {
                group.addTask {
                    let pts = (try? await APIService.shared.getPortfolioHistory(range: r))?.points
                        .map { PortfolioDataPoint(date: parseDate($0.date), value: $0.value) } ?? []
                    return (r, pts)
                }
            }
            for await (r, pts) in group {
                result[r] = pts
            }
        }
        return result
    }

    private func rangeKey(_ range: PortfolioTimeRange) -> String {
        switch range {
        case .oneWeek:      return "1w"
        case .oneMonth:     return "1m"
        case .threeMonths:  return "3m"
        case .ytd:          return "ytd"
        case .all:          return "all"
        }
    }

    private func fetchHoldingsPayload() async -> APIInvestmentHoldingsPayload? {
        try? await APIService.shared.getInvestmentHoldings()
    }

    // async let + try? 组合会触发 Swift runtime crash (swift_task_dealloc)
    // 将 try? 包裹在独立函数中避免此问题
    private func fetchNetWorth() async -> APINetWorthSummary? {
        do {
            return try await APIService.shared.getNetWorthSummary()
        } catch {
            print("❌ [InvestmentView] getNetWorthSummary decode/network: \(error)")
            return nil
        }
    }

    /// Investment 页账户列表：优先来自 `get-investment-holdings.accounts`（与 Portfolio/Allocation 同一数据链）。
    /// 回退：从 `get-net-worth-summary.accounts` 过滤 investment 类型（降级，无 name/mask）。
    var computedAccounts: [Account] {
        if let h = apiHoldingsPayload, let accs = h.accounts, !accs.isEmpty {
            return accs
                .map { Account.fromInvestmentAccount($0) }
                .sorted { $0.balance > $1.balance }
        }
        guard let nw = apiNetWorth, !nw.accounts.isEmpty else { return [] }
        return nw.accounts
            .filter { $0.type == "investment" }
            .map { Account.fromNetWorthAccount($0) }
            .sorted { $0.balance > $1.balance }
    }

    func handleAddAccount() {
        if plaidManager.shouldShowTrustBridge() {
            showTrustBridge = true
        } else {
            Task { await plaidManager.startLinkFlow() }
        }
    }

    func refreshSetupState() async {
        if let latest = await APIService.shared.getSetupStatePersistingCache() {
            setupState = latest
        }
    }

    func markStartingPortfolioExplicitZero() async {
        guard !isMarkingExplicitZero else { return }
        isMarkingExplicitZero = true
        defer { isMarkingExplicitZero = false }
        do {
            _ = try await APIService.shared.updateUserProfile(
                startingPortfolioBalance: 0,
                startingPortfolioSource: "explicit_zero"
            )
            await refreshSetupState()
        } catch {
            print("❌ [InvestmentView] markStartingPortfolioExplicitZero failed: \(error)")
        }
    }
}

// MARK: - Setup banner

private extension InvestmentView {
    /// Show the "Add investment portfolio" banner when the backend says the
    /// portfolio setup step is still incomplete. After Plaid link succeeds or
    /// the user picks "Continue with $0", `portfolioComplete` flips true and
    /// the banner disappears — Home then advances to "Set monthly plan".
    var showSetupBanner: Bool {
        setupState?.portfolioComplete == false
    }

    var setupBanner: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.h4)
                    .foregroundStyle(AppColors.accentGreenDeep)
                Text("Add your investment portfolio")
                    .font(.h4)
                    .foregroundStyle(AppColors.inkPrimary)
            }

            Text("Brokerage and retirement balances let your FIRE progress reflect reality.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: AppSpacing.sm) {
                Button(action: handleAddAccount) {
                    Text("Add investment portfolio")
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(AppColors.ctaWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.inkPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
                .disabled(isMarkingExplicitZero)

                Button {
                    showExplicitZeroConfirm = true
                } label: {
                    Text(isMarkingExplicitZero ? "Saving…" : "I don't have one")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .disabled(isMarkingExplicitZero)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            LinearGradient(
                colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }
}

private nonisolated func parseDate(_ str: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: str) ?? Date()
}

#Preview {
    InvestmentView()
        .environment(PlaidManager.shared)
}
