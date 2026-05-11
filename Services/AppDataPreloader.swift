//
//  AppDataPreloader.swift
//  Flamora app
//
//  Fires off the main-tab data fetches in parallel right after auth, so by
//  the time the user lands on (or taps into) any tab the cache is warm.
//  Without this, each tab's `.task` blocks on its own RTT chain on first open,
//  producing the "blank → spinner → content" flash the user reported.
//
//  Idempotent and silent: nothing here forces UI — it just warms
//  `TabContentCache`. Views that read from the cache get instant data; views
//  that need a refresh still fire their own fetches.
//

import Foundation

@MainActor
enum AppDataPreloader {

    /// One-shot preload triggered after auth + onboarding completion.
    /// Safe to call multiple times — concurrent calls are deduped via a flag.
    static func warmAllTabs() {
        guard !isWarming else { return }
        isWarming = true

        // Bail early if the user isn't authenticated yet — the API calls
        // would 401 and we'd waste a request budget on every cold launch.
        guard SupabaseManager.shared.isAuthenticated else {
            isWarming = false
            return
        }

        Task {
            // Run everything in parallel via async let so total wall time =
            // slowest single call, not sum of all calls. Each task swallows
            // errors so a single failure doesn't cascade.
            async let netWorth: Void = warmNetWorth()
            async let holdings: Void = warmInvestmentHoldings()
            async let budget: Void = warmCurrentMonthBudget()
            async let summaries: Void = warmMonthlySummaries()

            _ = await (netWorth, holdings, budget, summaries)

            isWarming = false
        }
    }

    /// Re-warm after a Plaid Link success — the cache from prior empty state
    /// would otherwise persist until the user manually pulls to refresh.
    static func warmAfterBankLink() {
        // Same surface as cold-launch warming; reuse the path.
        warmAllTabs()
    }

    // MARK: - Internal

    private static var isWarming = false

    private static func warmNetWorth() async {
        guard let summary = try? await APIService.shared.getNetWorthSummary() else { return }
        TabContentCache.shared.setHomeNetWorth(summary: summary, history: nil)
        TabContentCache.shared.setInvestmentNetWorth(summary)
        // APINetWorthSummary.accounts is non-optional. Cache for Cashflow row.
        TabContentCache.shared.setCashflowAccounts(summary.accounts)
    }

    private static func warmInvestmentHoldings() async {
        guard let payload = try? await APIService.shared.getInvestmentHoldings() else { return }
        TabContentCache.shared.setInvestmentHoldings(payload)
    }

    private static func warmCurrentMonthBudget() async {
        let now = Date()
        let cal = Calendar.current
        let monthStr = String(
            format: "%04d-%02d",
            cal.component(.year, from: now),
            cal.component(.month, from: now)
        )
        guard let budget = try? await APIService.shared.getMonthlyBudget(month: monthStr) else { return }
        TabContentCache.shared.setCashflowBudget(budget)
    }

    private static func warmMonthlySummaries() async {
        let cal = Calendar.current
        let now = Date()
        let year = cal.component(.year, from: now)
        let through = cal.component(.month, from: now)
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
        guard !summaries.isEmpty else { return }
        TabContentCache.shared.setCashflowMonthlySummaries(summaries, year: year)
    }
}
