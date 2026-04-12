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

    private init() {}

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

    func setCashflowSpendingDetails(
        total: TotalSpendingDetailData?,
        needs: SpendingDetailData?,
        wants: SpendingDetailData?
    ) {
        cashflowSpendingTotalDetail = total
        cashflowNeedsDetail = needs
        cashflowWantsDetail = wants
    }

    func clearAfterBankDisconnect() {
        investmentNetWorth = nil
        portfolioHistory = [:]
        investmentHoldings = nil
        cashflowBudget = nil
        cashflowSavingsByYear = nil
        cashflowSpendingTotalDetail = nil
        cashflowNeedsDetail = nil
        cashflowWantsDetail = nil
        cashflowMonthlySummaries = nil
    }
}
