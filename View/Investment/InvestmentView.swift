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
        if plaidManager.hasLinkedBank {
            connectedView
        } else {
            ConnectAccountCTAView(
                icon: "chart.pie.fill",
                glowColor: AppColors.accentGreen,
                iconGradient: [AppColors.accentGreenDeep, AppColors.chartBlue],
                title: "Track Your\nInvestments",
                subtitle: "Connect your brokerage and bank accounts\nto see your full portfolio in one place.",
                features: [
                    ("chart.line.uptrend.xyaxis", "Live portfolio performance"),
                    ("building.columns.fill", "All accounts in one view"),
                    ("chart.pie", "Asset allocation breakdown"),
                    ("arrow.up.right", "Net worth growth tracking")
                ],
                buttonLabel: "Connect to Accounts",
                bottomPadding: 0
            )
        }
    }

    var connectedView: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 顶部第一张：投资页展示与 Journey 同风格的净资产卡片
                        PortfolioCard(
                            portfolioBalance: apiNetWorth?.totalNetWorth ?? 85240.0,
                            gainAmount: apiNetWorth?.growthAmount ?? 3240.0,
                            gainPercentage: apiNetWorth?.growthPercentage ?? 3.95
                        )

                        AssetAllocationCard(allocation: data.allocation)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        AccountsCard(accounts: computedAccounts)
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
