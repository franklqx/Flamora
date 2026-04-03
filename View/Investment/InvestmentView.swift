//
//  InvestmentView.swift
//  Flamora app
//
//  Investment overview page
//

import SwiftUI

struct InvestmentView: View {
    @Environment(PlaidManager.self) private var plaidManager

    @State private var apiNetWorth: APINetWorthSummary? = nil
    /// 来自 `get-investment-holdings`；断连或未拉取成功时为 nil。
    @State private var apiHoldingsPayload: APIInvestmentHoldingsPayload?
    /// 按时间范围缓存的真实历史曲线；nil 时 PortfolioCard 回退 mock。
    @State private var portfolioHistoryCache: [String: [PortfolioDataPoint]] = [:]

    var body: some View {
        connectedView
    }

    var connectedView: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        PortfolioCard(
                            portfolioBalance: portfolioBalanceDisplay,
                            gainAmount: apiHoldingsPayload?.summary.totalGainLoss ?? apiNetWorth?.growthAmount ?? 0,
                            gainPercentage: apiHoldingsPayload?.summary.totalGainLossPct ?? apiNetWorth?.growthPercentage ?? 0,
                            realChartData: { range in portfolioHistoryCache[rangeKey(range)] },
                            isConnected: plaidManager.hasLinkedBank,
                            onConnectTapped: {
                                Task { await plaidManager.startLinkFlow() }
                            }
                        )

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
                            onAddAccount: { Task { await plaidManager.startLinkFlow() } },
                            lastSyncedAt: apiNetWorth?.lastSyncedAt
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
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
        }
        .task {
            await loadInvestmentData()
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadInvestmentData() }
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

    func loadInvestmentData() async {
        guard plaidManager.hasLinkedBank else {
            apiNetWorth = nil
            apiHoldingsPayload = nil
            portfolioHistoryCache = [:]
            TabContentCache.shared.setInvestmentNetWorth(nil)
            return
        }
        let nw = await fetchNetWorth()
        apiNetWorth = nw
        TabContentCache.shared.setInvestmentNetWorth(nw)
        async let holdingsTask = fetchHoldingsPayload()
        async let historyTask  = fetchAllPortfolioHistory()
        let (h, hist) = await (holdingsTask, historyTask)
        apiHoldingsPayload    = h
        portfolioHistoryCache = hist
        TabContentCache.shared.setPortfolioHistory(hist)
        TabContentCache.shared.setInvestmentHoldings(h)
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
}

private func parseDate(_ str: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: str) ?? Date()
}

#Preview {
    InvestmentView()
        .environment(PlaidManager.shared)
}
