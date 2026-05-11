//
//  TabContentCache.swift
//  Flamora app
//
//  跨 Tab 切换时保留上次拉取的摘要数据，避免子视图销毁后重进出现「先空后闪」。
//  断连银行时清空。
//

import Foundation

extension Notification.Name {
    static let savingsCheckInDidPersist = Notification.Name("SavingsCheckInDidPersist")
    /// 任意入口完成交易分类写入后广播，供 CashflowView 等刷新 summary / 缓存。
    static let transactionClassificationDidPersist = Notification.Name("TransactionClassificationDidPersist")
    /// Budget Setup 全屏流程关闭（完成或取消）后广播，供 Journey / Hero 拉取最新 `setupStage`。
    static let budgetSetupFlowDidDismiss = Notification.Name("BudgetSetupFlowDidDismiss")
    /// Plaid Link 成功完成时广播，触发一次性 toast。userInfo: ["institutionName": String?]
    static let plaidLinkDidSucceed = Notification.Name("PlaidLinkDidSucceed")
}

final class TabContentCache {
    static let shared = TabContentCache()

    /// Home Tab 上次成功的净资产摘要。
    private(set) var homeNetWorthSummary: APINetWorthSummary?

    /// Home Tab 上次成功的净资产趋势。
    private(set) var homeNetWorthHistory: [NetWorthRange: [NetWorthPoint]]?

    /// Home Tab 上次成功的报告入口数据。
    private(set) var homeMonthlyReport: ReportSnapshot?
    private(set) var homeIssueZeroReport: ReportSnapshot?
    private(set) var homeAnnualReport: ReportSnapshot?

    /// Investment Tab 上次成功的 `get-net-worth-summary`；断连或未加载时为 nil。
    private(set) var investmentNetWorth: APINetWorthSummary?

    /// 按时间范围缓存的投资历史曲线（Journey 与 Investment 共用）。
    private(set) var portfolioHistory: [String: [PortfolioDataPoint]] = [:]

    /// 上次成功的持仓数据（Journey 资产分配与 Investment 共用）。
    private(set) var investmentHoldings: APIInvestmentHoldingsPayload?

    /// Cash Flow Tab 上次成功的月度预算；nil 时为空预算。
    private(set) var cashflowBudget: APIMonthlyBudget?

    /// Cash Flow Tab 上次成功的当年月度储蓄序列（Journey 与 Cashflow 共用）。
    private(set) var cashflowSavingsByYear: [Int: [Double?]]?

    /// Cash Flow Tab 上次成功的总支出详情数据。
    private(set) var cashflowSpendingTotalDetail: TotalSpendingDetailData?

    /// Cash Flow Tab 上次成功的 Needs 支出详情数据。
    private(set) var cashflowNeedsDetail: SpendingDetailData?

    /// Cash Flow Tab 上次成功的 Wants 支出详情数据。
    private(set) var cashflowWantsDetail: SpendingDetailData?

    /// Cash Flow 展开层上次成功的当年逐月支出 summary；用于避免 overlay 重新打开时的空白闪烁。
    private(set) var cashflowMonthlySummaries: [Int: APISpendingSummary]?

    /// `cashflowMonthlySummaries` 对应的日历年。session 跨过 1 月 1 日时缓存的「当年」会
    /// 突然变成「去年」；读取方需对比此值与当前年份并丢弃过期数据。
    private(set) var cashflowMonthlySummariesYear: Int?

    /// Cash Flow 上次成功拉到的账户列表（来自 net worth summary 全量 accounts）。
    private(set) var cashflowAccounts: [APIAccount]?

    /// Cash Flow 首页最近活动缓存。
    private(set) var cashflowRecentTransactions: [Transaction]?

    /// Cash / Debt 账户详情缓存。
    private(set) var cashAccountTransactions: [String: [Transaction]] = [:]
    private(set) var cashAccountHistory: [String: [BalanceSnapshot]] = [:]

    /// Investment 账户详情缓存。
    private(set) var investmentAccountTransactions: [String: [Transaction]] = [:]
    private(set) var investmentAccountHistory: [String: [BalanceSnapshot]] = [:]

    private init() {
        hydrateFromDisk()
    }

    // MARK: - Disk persistence
    //
    // We persist a snapshot of the API-shaped cache fields to a JSON file in
    // the user's Documents directory. On cold launch, hydrate populates the
    // shared cache before any view's `.task` runs — so the Home / Cashflow /
    // Investment tabs render last-known-good values instantly while a fresh
    // fetch runs in the background.
    //
    // Only `Codable` API payloads are persisted. Derived detail builders
    // (SpendingDetailData, NetWorthPoint history) rebuild cheaply from those
    // payloads — keeping the snapshot Codable-only avoids a fragile Codable
    // conformance sprawl across UI models.

    private static let cacheFilename = "flamora_tab_cache.v1.json"

    private static let cacheURL: URL? = {
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return nil }
        return docs.appendingPathComponent(cacheFilename)
    }()

    private struct PersistedSnapshot: Codable {
        let homeNetWorthSummary: APINetWorthSummary?
        let investmentNetWorth: APINetWorthSummary?
        let investmentHoldings: APIInvestmentHoldingsPayload?
        let cashflowBudget: APIMonthlyBudget?
        let cashflowMonthlySummaries: [Int: APISpendingSummary]?
        let cashflowMonthlySummariesYear: Int?
        let cashflowSavingsByYear: [Int: [Double?]]?
        let cashflowAccounts: [APIAccount]?
        let homeMonthlyReport: ReportSnapshot?
        let homeIssueZeroReport: ReportSnapshot?
        let homeAnnualReport: ReportSnapshot?
    }

    private func hydrateFromDisk() {
        guard let url = Self.cacheURL,
              let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(PersistedSnapshot.self, from: data)
        else { return }
        homeNetWorthSummary = snap.homeNetWorthSummary
        investmentNetWorth = snap.investmentNetWorth
        investmentHoldings = snap.investmentHoldings
        cashflowBudget = snap.cashflowBudget
        cashflowMonthlySummaries = snap.cashflowMonthlySummaries
        cashflowMonthlySummariesYear = snap.cashflowMonthlySummariesYear
        cashflowSavingsByYear = snap.cashflowSavingsByYear
        cashflowAccounts = snap.cashflowAccounts
        homeMonthlyReport = snap.homeMonthlyReport
        homeIssueZeroReport = snap.homeIssueZeroReport
        homeAnnualReport = snap.homeAnnualReport
    }

    /// Persist the current snapshot in the background. Coalesces rapid writes
    /// via a debounce token — when 5 setters fire in a single frame, we only
    /// write once. Encoding happens off the main thread.
    private var pendingPersistToken: UUID?

    private func schedulePersist() {
        let token = UUID()
        pendingPersistToken = token
        let snapshot = PersistedSnapshot(
            homeNetWorthSummary: homeNetWorthSummary,
            investmentNetWorth: investmentNetWorth,
            investmentHoldings: investmentHoldings,
            cashflowBudget: cashflowBudget,
            cashflowMonthlySummaries: cashflowMonthlySummaries,
            cashflowMonthlySummariesYear: cashflowMonthlySummariesYear,
            cashflowSavingsByYear: cashflowSavingsByYear,
            cashflowAccounts: cashflowAccounts,
            homeMonthlyReport: homeMonthlyReport,
            homeIssueZeroReport: homeIssueZeroReport,
            homeAnnualReport: homeAnnualReport
        )
        // 80ms debounce: any further setter call within the window cancels this
        // write (newer token replaces ours), so we only hit disk for the final
        // state in a burst.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.pendingPersistToken == token else { return }
            guard let url = Self.cacheURL else { return }
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    func setHomeNetWorth(summary: APINetWorthSummary?, history: [NetWorthRange: [NetWorthPoint]]?) {
        homeNetWorthSummary = summary
        homeNetWorthHistory = history
        schedulePersist()
    }

    func setHomeReports(monthly: ReportSnapshot?, issueZero: ReportSnapshot?, annual: ReportSnapshot?) {
        homeMonthlyReport = monthly
        homeIssueZeroReport = issueZero
        homeAnnualReport = annual
        schedulePersist()
    }

    func setInvestmentNetWorth(_ value: APINetWorthSummary?) {
        investmentNetWorth = value
        schedulePersist()
    }

    func setPortfolioHistory(_ value: [String: [PortfolioDataPoint]]) {
        portfolioHistory = value
    }

    func setInvestmentHoldings(_ value: APIInvestmentHoldingsPayload?) {
        investmentHoldings = value
        schedulePersist()
    }

    func setCashflowBudget(_ value: APIMonthlyBudget?) {
        cashflowBudget = value
        schedulePersist()
    }

    func setCashflowSavingsByYear(_ value: [Int: [Double?]]?) {
        cashflowSavingsByYear = value
        schedulePersist()
    }

    func setCashflowMonthlySummaries(_ value: [Int: APISpendingSummary]?, year: Int? = nil) {
        cashflowMonthlySummaries = value
        cashflowMonthlySummariesYear = (value == nil) ? nil : year
        schedulePersist()
    }

    func setCashflowAccounts(_ value: [APIAccount]?) {
        cashflowAccounts = value
        schedulePersist()
    }

    func setCashflowRecentTransactions(_ value: [Transaction]?) {
        cashflowRecentTransactions = value
    }

    func setCashflowSpendingDetails(
        total: TotalSpendingDetailData?,
        needs: SpendingDetailData?,
        wants: SpendingDetailData?
    ) {
        cashflowSpendingTotalDetail = total
        cashflowNeedsDetail = needs
        cashflowWantsDetail = wants
    }

    func cashAccountTransactions(for accountId: String) -> [Transaction]? {
        cashAccountTransactions[accountId]
    }

    func setCashAccountTransactions(_ value: [Transaction], for accountId: String) {
        cashAccountTransactions[accountId] = value
    }

    func cashAccountHistory(for accountId: String, range: AccountHistoryRange) -> [BalanceSnapshot]? {
        cashAccountHistory["\(accountId)::\(range.rawValue)"]
    }

    func setCashAccountHistory(_ value: [BalanceSnapshot], for accountId: String, range: AccountHistoryRange) {
        cashAccountHistory["\(accountId)::\(range.rawValue)"] = value
    }

    func investmentAccountTransactions(for accountId: String) -> [Transaction]? {
        investmentAccountTransactions[accountId]
    }

    func setInvestmentAccountTransactions(_ value: [Transaction], for accountId: String) {
        investmentAccountTransactions[accountId] = value
    }

    func investmentAccountHistory(for accountId: String, range: AccountHistoryRange) -> [BalanceSnapshot]? {
        investmentAccountHistory["\(accountId)::\(range.rawValue)"]
    }

    func setInvestmentAccountHistory(_ value: [BalanceSnapshot], for accountId: String, range: AccountHistoryRange) {
        investmentAccountHistory["\(accountId)::\(range.rawValue)"] = value
    }

    /// Clear LIVE data tied to the now-removed bank connection. Historical
    /// artifacts (savings check-ins, generated reports, the committed budget)
    /// are preserved per the plan-snapshot model — disconnect pauses tracking
    /// rather than resetting the user's progress.
    func clearAfterBankDisconnect() {
        // Live: balances, accounts, transactions
        homeNetWorthSummary = nil
        homeNetWorthHistory = nil
        investmentNetWorth = nil
        portfolioHistory = [:]
        investmentHoldings = nil
        cashflowSpendingTotalDetail = nil
        cashflowNeedsDetail = nil
        cashflowWantsDetail = nil
        cashflowMonthlySummaries = nil
        cashflowMonthlySummariesYear = nil
        cashflowAccounts = nil
        cashflowRecentTransactions = nil
        cashAccountTransactions = [:]
        cashAccountHistory = [:]
        investmentAccountTransactions = [:]
        investmentAccountHistory = [:]
        // Preserved on purpose:
        //   • cashflowSavingsByYear — manual savings check-in history
        //   • cashflowBudget — committed plan numbers (user can still review)
        //   • homeMonthlyReport / homeIssueZeroReport / homeAnnualReport —
        //     past reports are historical artifacts, not live data
        schedulePersist()
    }
}
