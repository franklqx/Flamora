//
//  InvestmentView.swift
//  Flamora app
//
//  Investment overview page
//

import SwiftUI

struct InvestmentView: View {
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private let data = MockData.investmentData
    @State private var apiNetWorth: APINetWorthSummary? = nil

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
                            portfolioBalance: apiNetWorth?.totalNetWorth ?? 85240.0,
                            gainAmount: apiNetWorth?.growthAmount ?? 3240.0,
                            gainPercentage: apiNetWorth?.growthPercentage ?? 3.95,
                            isConnected: plaidManager.hasLinkedBank,
                            onConnectTapped: {
                                Task { await plaidManager.startLinkFlow() }
                            }
                        )

                        AssetAllocationCard(
                            allocation: data.allocation,
                            isConnected: plaidManager.hasLinkedBank
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
        .task {
            await loadInvestmentData()
        }
    }
}

// MARK: - Data Loading & Computed Data
private extension InvestmentView {
    func loadInvestmentData() async {
        apiNetWorth = await fetchNetWorth()
    }

    // async let + try? 组合会触发 Swift runtime crash (swift_task_dealloc)
    // 将 try? 包裹在独立函数中避免此问题
    private func fetchNetWorth() async -> APINetWorthSummary? {
        try? await APIService.shared.getNetWorthSummary()
    }

    var computedAccounts: [Account] {
        guard let nw = apiNetWorth, !nw.accounts.isEmpty else { return MockData.allAccounts }
        return nw.accounts.map {
            Account(
                id: $0.accountId,
                institution: $0.institution,
                accountType: accountTypeFromAPI($0.type),
                balance: $0.balance,
                connected: true,
                logoUrl: $0.logoUrl
            )
        }
    }

    private func accountTypeFromAPI(_ type: String) -> AccountType {
        let t = type.lowercased()
        if t.contains("crypto") { return .crypto }
        if t.contains("cash") || t.contains("checking") || t.contains("savings") || t == "bank" {
            return .bank
        }
        return .brokerage
    }
}

#Preview {
    InvestmentView()
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
