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

    private init() {}

    func setHomeNetWorth(summary: APINetWorthSummary?, history: [NetWorthRange: [NetWorthPoint]]?) {
        homeNetWorthSummary = summary
        homeNetWorthHistory = history
    }

    func setHomeReports(monthly: ReportSnapshot?, issueZero: ReportSnapshot?, annual: ReportSnapshot?) {
        homeMonthlyReport = monthly
        homeIssueZeroReport = issueZero
        homeAnnualReport = annual
    }

    func setInvestmentNetWorth(_ value: APINetWorthSummary?) {
        investmentNetWorth = value
    }

    func setPortfolioHistory(_ value: [String: [PortfolioDataPoint]]) {
        portfolioHistory = value
    }

    func setInvestmentHoldings(_ value: APIInvestmentHoldingsPayload?) {
        investmentHoldings = value
    }

    func setCashflowBudget(_ value: APIMonthlyBudget?) {
        cashflowBudget = value
    }

    func setCashflowSavingsByYear(_ value: [Int: [Double?]]?) {
        cashflowSavingsByYear = value
    }

    func setCashflowMonthlySummaries(_ value: [Int: APISpendingSummary]?) {
        cashflowMonthlySummaries = value
    }

    func setCashflowAccounts(_ value: [APIAccount]?) {
        cashflowAccounts = value
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

    func clearAfterBankDisconnect() {
        homeNetWorthSummary = nil
        homeNetWorthHistory = nil
        homeMonthlyReport = nil
        homeIssueZeroReport = nil
        homeAnnualReport = nil
        investmentNetWorth = nil
        portfolioHistory = [:]
        investmentHoldings = nil
        cashflowBudget = nil
        cashflowSavingsByYear = nil
        cashflowSpendingTotalDetail = nil
        cashflowNeedsDetail = nil
        cashflowWantsDetail = nil
        cashflowMonthlySummaries = nil
        cashflowAccounts = nil
        cashflowRecentTransactions = nil
        cashAccountTransactions = [:]
        cashAccountHistory = [:]
        investmentAccountTransactions = [:]
        investmentAccountHistory = [:]
    }
}
