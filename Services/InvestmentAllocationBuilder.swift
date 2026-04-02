//
//  InvestmentAllocationBuilder.swift
//  Flamora app
//
//  将 `get-investment-holdings` 的 `type_breakdown` 映射为 AssetAllocation 卡片使用的 Allocation。
//

import Foundation

enum InvestmentAllocationBuilder {
    /// 无持仓或加载失败时用于已连接状态，避免再显示 Mock 假数据。
    static let zeroAllocation = Allocation(
        stocks: AssetClass(percent: 0, amount: 0),
        bonds: AssetClass(percent: 0, amount: 0),
        cash: AssetClass(percent: 0, amount: 0),
        other: AssetClass(percent: 0, amount: 0)
    )

    static func allocation(from payload: APIInvestmentHoldingsPayload) -> Allocation {
        let total = payload.summary.totalValue
        let rows = payload.typeBreakdown
        guard total > 0, !rows.isEmpty else {
            return zeroAllocation
        }
        var stocks = 0.0
        var crypto = 0.0
        var cash = 0.0
        var other = 0.0
        for row in rows {
            switch bucket(for: row.type) {
            case .stocks: stocks += row.value
            case .crypto: crypto += row.value
            case .cash: cash += row.value
            case .other: other += row.value
            }
        }
        let sum = stocks + crypto + cash + other
        let denom = sum > 0 ? sum : total
        func pct(_ amount: Double) -> Int {
            Int((amount / denom * 100).rounded())
        }
        return Allocation(
            stocks: AssetClass(percent: pct(stocks), amount: stocks),
            bonds: AssetClass(percent: pct(crypto), amount: crypto),
            cash: AssetClass(percent: pct(cash), amount: cash),
            other: AssetClass(percent: pct(other), amount: other)
        )
    }

    private enum Bucket { case stocks, crypto, cash, other }

    /// 将 Plaid securities.type 映射到「股票 / Crypto / 现金 / 其他」四块（与 AssetAllocationCard 文案一致）。
    private static func bucket(for apiType: String) -> Bucket {
        let t = apiType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Crypto
        if t.contains("crypto") || t == "digital asset" { return .crypto }
        // Cash / 货币市场
        if t == "cash" || t == "cash equivalent" || t.contains("money market") || t.contains("currency") { return .cash }
        // 股票类
        if t == "equity" || t == "etf" || t == "mutual fund" || t == "derivative"
            || t == "fund" || t == "common stock" || t == "stock" || t == "reit" { return .stocks }
        // 债券 / 固收 — 单独归入 other（UI 当前四档为 Stocks/Crypto/Cash/Other，无 Bonds 档）
        if t.contains("bond") || t.contains("fixed income") || t.contains("treasury")
            || t.contains("note") || t == "loan" { return .other }
        return .other
    }

    /// 与 `AssetAllocationDetailView` 中 `AllocDetailItem.id`（stocks / crypto / cash / other）对齐。
    static func allocationDetailBucketId(for apiType: String?) -> String {
        guard let t = apiType?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return "other"
        }
        switch bucket(for: t) {
        case .stocks: return "stocks"
        case .crypto: return "crypto"
        case .cash: return "cash"
        case .other: return "other"
        }
    }

    static func holding(from row: APIInvestmentHoldingRow) -> Holding {
        let rawTicker = row.ticker?.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbol: String
        if let rawTicker, !rawTicker.isEmpty {
            symbol = rawTicker
        } else {
            symbol = String(row.name.prefix(4)).uppercased()
        }
        return Holding(
            id: row.id,
            accountId: row.plaidAccountId ?? "",
            symbol: symbol,
            name: row.name,
            shares: row.quantity ?? 0,
            totalValue: row.value ?? 0,
            logoUrl: nil
        )
    }

    static func holdings(for detailItemId: String, payload: APIInvestmentHoldingsPayload?) -> [Holding] {
        guard let payload else { return [] }
        return payload.holdings
            .filter { allocationDetailBucketId(for: $0.type) == detailItemId }
            .map { holding(from: $0) }
            .sorted { $0.totalValue > $1.totalValue }
    }
}
