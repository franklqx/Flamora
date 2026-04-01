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
                            gainAmount: apiNetWorth?.growthAmount ?? 0,
                            gainPercentage: apiNetWorth?.growthPercentage ?? 0,
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
                            onAddAccount: { Task { await plaidManager.startLinkFlow() } }
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
    /// Investment Tab 主数字优先用净资产里的「投资账户」合计，与持仓 API 一致。
    var portfolioBalanceDisplay: Double {
        guard let nw = apiNetWorth else { return 0 }
        if let inv = nw.breakdown.investmentTotal, inv > 0 {
            return inv
        }
        return nw.totalNetWorth
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
            TabContentCache.shared.setInvestmentNetWorth(nil)
            return
        }
        let nw = await fetchNetWorth()
        apiNetWorth = nw
        TabContentCache.shared.setInvestmentNetWorth(nw)
        apiHoldingsPayload = await fetchHoldingsPayload()
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

    var computedAccounts: [Account] {
        guard let nw = apiNetWorth, !nw.accounts.isEmpty else { return [] }
        return nw.accounts.map { Account.fromNetWorthAccount($0) }
    }
}

#Preview {
    InvestmentView()
        .environment(PlaidManager.shared)
}
