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
    private let accountsBreakdown = MockData.investmentAccountsBreakdown
    @State private var showAccountsBreakdown = false
    @State private var apiNetWorth: APINetWorthSummary? = nil
    @State private var apiHoldings: APIHoldingsResponse? = nil

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
                    VStack(spacing: 20) {
                        PortfolioCard(portfolio: computedPortfolio)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        sectionHeader(title: "Accounts", actionTitle: "View all") {
                            showAccountsBreakdown = true
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)

                        AccountsCard(accounts: computedAccounts)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        sectionHeader(title: "Asset allocation")
                            .padding(.horizontal, AppSpacing.screenPadding)

                        AssetAllocationCard(allocation: data.allocation)
                            .padding(.horizontal, AppSpacing.screenPadding)
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.bottom, AppSpacing.tabBarReserve)
                }
            }
        }
        .fullScreenCover(isPresented: $showAccountsBreakdown) {
            InvestmentAccountsBreakdownDetailView(data: computedBreakdown)
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
                                    colors: [Color(hex: "#34D399").opacity(0.15), Color.clear],
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
                                    colors: [Color(hex: "#34D399"), Color(hex: "#60A5FA")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text("Track Your\nInvestments")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Connect your brokerage and bank accounts\nto see your full portfolio in one place.")
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
                                    .foregroundColor(Color(hex: "#34D399"))
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
        ("chart.line.uptrend.xyaxis", "Live portfolio performance"),
        ("building.columns.fill", "All accounts in one view"),
        ("chart.pie", "Asset allocation breakdown"),
        ("arrow.up.right", "Net worth growth tracking")
    ]
}

// MARK: - Data Loading & Computed Data
private extension InvestmentView {
    func loadInvestmentData() async {
        async let nwTask = try? await APIService.shared.getNetWorthSummary()
        async let holdingsTask = try? await APIService.shared.getInvestmentHoldings()
        let (nw, holdings) = await (nwTask, holdingsTask)
        apiNetWorth = nw
        apiHoldings = holdings
    }

    var computedPortfolio: Portfolio {
        guard let nw = apiNetWorth else { return data.portfolio }
        return Portfolio(
            totalBalance: nw.totalNetWorth,
            performance: data.portfolio.performance,
            chartData: data.portfolio.chartData
        )
    }

    var computedAccounts: [Account] {
        guard let nw = apiNetWorth, !nw.accounts.isEmpty else { return data.accounts }
        return nw.accounts.map {
            Account(id: $0.accountId, institution: $0.institution, type: $0.type, balance: $0.balance, connected: true)
        }
    }

    var computedBreakdown: InvestmentAccountsBreakdownData {
        guard let h = apiHoldings, !h.holdings.isEmpty else { return accountsBreakdown }
        return InvestmentAccountsBreakdownData(
            title: "Holdings",
            totalAmount: h.totalValue,
            positions: h.holdings.map {
                InvestmentAccountPosition(id: $0.id, symbol: $0.symbol ?? $0.name, institution: $0.institution, amount: $0.value)
            }
        )
    }
}

// MARK: - Header
private extension InvestmentView {
    func sectionHeader(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if let actionTitle {
                if let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#A78BFA"))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#A78BFA"))
                }
            }
        }
    }
}

private struct InvestmentAccountsBreakdownDetailView: View {
    let data: InvestmentAccountsBreakdownData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    allocationsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(data.totalAmount, minFractionDigits: 2, maxFractionDigits: 2))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("across connected accounts")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
    }

    private var allocationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allocations")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(data.positions) { position in
                    InvestmentAccountPositionRow(position: position)
                }
            }
        }
    }

    private func formatCurrency(
        _ value: Double,
        minFractionDigits: Int,
        maxFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct InvestmentAccountPositionRow: View {
    let position: InvestmentAccountPosition

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(position.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text(position.institution.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(Color(hex: "#9CA3AF"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                    )
            }

            Spacer()

            Text(formatCurrency(position.amount))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    InvestmentView()
}
