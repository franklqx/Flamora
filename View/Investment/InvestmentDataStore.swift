//
//  InvestmentDataStore.swift
//  Meridian
//

import Foundation
import SwiftUI
import Combine

struct InvestmentAccountGroup: Identifiable {
    let account: Account
    let holdings: [Holding]
    let holdingsValue: Double
    let cashValue: Double

    var id: String { account.id }
}

@MainActor
final class InvestmentDataStore: ObservableObject {
    @Published var apiNetWorth: APINetWorthSummary? = nil
    @Published var apiHoldingsPayload: APIInvestmentHoldingsPayload? = nil
    @Published var portfolioHistoryCache: [String: [PortfolioDataPoint]] = [:]
    @Published var loadError = false

    func restoreFromCache() {
        if apiNetWorth == nil {
            apiNetWorth = TabContentCache.shared.investmentNetWorth
        }
        if apiHoldingsPayload == nil {
            apiHoldingsPayload = TabContentCache.shared.investmentHoldings
        }
        if portfolioHistoryCache.isEmpty {
            portfolioHistoryCache = TabContentCache.shared.portfolioHistory
        }
    }

    func load(plaidManager: PlaidManager, force: Bool = false) async {
        loadError = false
        guard plaidManager.hasLinkedBank else {
            apiNetWorth = nil
            apiHoldingsPayload = nil
            portfolioHistoryCache = [:]
            TabContentCache.shared.setInvestmentNetWorth(nil)
            TabContentCache.shared.setInvestmentHoldings(nil)
            TabContentCache.shared.setPortfolioHistory([:])
            return
        }

        if !force,
           apiNetWorth != nil,
           apiHoldingsPayload != nil,
           !portfolioHistoryCache.isEmpty {
            return
        }

        let netWorth = await fetchNetWorth()
        if netWorth == nil { loadError = true }
        apiNetWorth = netWorth
        TabContentCache.shared.setInvestmentNetWorth(netWorth)

        async let holdingsTask = fetchHoldingsPayload()
        async let historyTask = fetchAllPortfolioHistory()
        let (holdings, history) = await (holdingsTask, historyTask)

        apiHoldingsPayload = holdings
        portfolioHistoryCache = history
        TabContentCache.shared.setInvestmentHoldings(holdings)
        TabContentCache.shared.setPortfolioHistory(history)
    }

    var portfolioBalanceDisplay: Double {
        if let summary = apiHoldingsPayload?.summary {
            let total = summary.totalAccountValue ?? summary.totalValue
            if total > 0 { return total }
        }
        return apiNetWorth?.breakdown.investmentTotal ?? 0
    }

    var displayAllocation: Allocation {
        guard let payload = apiHoldingsPayload else {
            return InvestmentAllocationBuilder.zeroAllocation
        }
        return InvestmentAllocationBuilder.allocation(from: payload)
    }

    var computedAccounts: [Account] {
        if let holdings = apiHoldingsPayload, let accounts = holdings.accounts, !accounts.isEmpty {
            return accounts
                .map { Account.fromInvestmentAccount($0) }
                .sorted { $0.balance > $1.balance }
        }
        guard let accounts = apiNetWorth?.accounts, !accounts.isEmpty else { return [] }
        return accounts
            .filter { $0.type == "investment" }
            .map { Account.fromNetWorthAccount($0) }
            .sorted { $0.balance > $1.balance }
    }

    var cashBankAccounts: [Account] {
        computedAccounts.filter { $0.accountType == .bank }
    }

    var totalGainLoss: Double? {
        apiHoldingsPayload?.summary.totalGainLoss ?? apiNetWorth?.growthAmount
    }

    var totalGainLossPct: Double? {
        apiHoldingsPayload?.summary.totalGainLossPct ?? apiNetWorth?.growthPercentage
    }

    var todayChange: Double? {
        apiHoldingsPayload?.summary.todayChange
    }

    var todayChangePct: Double? {
        apiHoldingsPayload?.summary.todayChangePct
    }

    var cashValue: Double {
        apiHoldingsPayload?.summary.uninvestedCashValue ?? 0
    }

    var cashPercentage: Double? {
        let total = portfolioBalanceDisplay
        guard total > 0 else { return nil }
        return (cashValue / total) * 100
    }

    var accountGroups: [InvestmentAccountGroup] {
        let holdingsByAccount = Dictionary(grouping: apiHoldingsPayload?.holdings ?? []) { row in
            row.plaidAccountId ?? ""
        }
        let accountBreakdown = Dictionary(uniqueKeysWithValues: (apiHoldingsPayload?.accounts ?? []).map { ($0.id, $0) })

        return computedAccounts.map { account in
            let rows = holdingsByAccount[account.id] ?? []
            let holdings = rows
                .map { InvestmentAllocationBuilder.holding(from: $0) }
                .sorted { $0.totalValue > $1.totalValue }
            let breakdown = accountBreakdown[account.id]
            return InvestmentAccountGroup(
                account: account,
                holdings: holdings,
                holdingsValue: breakdown?.holdingsValue ?? holdings.reduce(0) { $0 + $1.totalValue },
                cashValue: breakdown?.uninvestedCashValue ?? 0
            )
        }
    }

    func history(for range: PortfolioTimeRange) -> [PortfolioDataPoint] {
        portfolioHistoryCache[range.key] ?? []
    }

    private func fetchHoldingsPayload() async -> APIInvestmentHoldingsPayload? {
        try? await APIService.shared.getInvestmentHoldings()
    }

    private func fetchNetWorth() async -> APINetWorthSummary? {
        do {
            return try await APIService.shared.getNetWorthSummary()
        } catch {
            print("❌ [InvestmentDataStore] getNetWorthSummary decode/network: \(error)")
            return nil
        }
    }

    private func fetchAllPortfolioHistory() async -> [String: [PortfolioDataPoint]] {
        let ranges: [PortfolioTimeRange] = [.oneWeek, .oneMonth, .threeMonths, .ytd, .all]
        var result: [String: [PortfolioDataPoint]] = [:]

        await withTaskGroup(of: (String, [PortfolioDataPoint]).self) { group in
            for range in ranges {
                group.addTask {
                    let points = (try? await APIService.shared.getPortfolioHistory(range: range.key))?.points
                        .map { PortfolioDataPoint(date: parseInvestmentDate($0.date), value: $0.value) } ?? []
                    return (range.key, points)
                }
            }

            for await (range, points) in group {
                result[range] = points
            }
        }

        return result
    }
}

private extension PortfolioTimeRange {
    nonisolated var key: String {
        switch self {
        case .oneWeek: return "1w"
        case .oneMonth: return "1m"
        case .threeMonths: return "3m"
        case .ytd: return "ytd"
        case .all: return "all"
        }
    }
}

private nonisolated func parseInvestmentDate(_ value: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value) ?? Date()
}
