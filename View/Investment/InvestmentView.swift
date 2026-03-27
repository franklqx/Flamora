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
            InvestmentCTAView()
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
                            portfolioBalance: 85240.0,
                            gainAmount: 3240.0,
                            gainPercentage: 3.95
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

// MARK: - Investment 初始状态 CTA

private struct InvestmentCTAView: View {
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
                                    colors: [AppColors.accentGreen.opacity(0.15), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accentGreenDeep, AppColors.chartBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text("Track Your\nInvestments")
                            .font(.h1)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Connect your brokerage and bank accounts\nto see your full portfolio in one place.")
                            .font(.supportingText)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 12) {
                        ForEach(features, id: \.0) { icon, text in
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.bodyRegular)
                                    .foregroundColor(AppColors.accentGreen)
                                    .frame(width: 24)
                                Text(text)
                                    .font(.inlineLabel)
                                    .foregroundStyle(.white)
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
                        Task {
                            await plaidManager.startLinkFlow()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if plaidManager.isConnecting {
                                ProgressView().tint(.black)
                            } else {
                                Text("Connect to Accounts")
                                    .font(.statRowSemibold)
                                    .foregroundColor(.black)
                                Image(systemName: "arrow.right")
                                    .font(.figureSecondarySemibold)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: AppColors.gradientFire,
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
        ("chart.line.uptrend.xyaxis", "Live portfolio performance"),
        ("building.columns.fill", "All accounts in one view"),
        ("chart.pie", "Asset allocation breakdown"),
        ("arrow.up.right", "Net worth growth tracking")
    ]
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
