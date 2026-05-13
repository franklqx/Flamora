//
//  InvestmentAllocationBuilder.swift
//  Meridian
//
//  将 `get-investment-holdings` 的 `type_breakdown` 映射为 AssetAllocation 卡片使用的 Allocation。
//

import Foundation

enum InvestmentAllocationBuilder {
    /// 无持仓或加载失败时用于已连接状态，避免再显示 Mock 假数据。
    static let zeroAllocation = Allocation(
        stocks: AssetClass(percent: 0, amount: 0),
        funds:  AssetClass(percent: 0, amount: 0),
        bonds:  AssetClass(percent: 0, amount: 0),
        cash:   AssetClass(percent: 0, amount: 0),
        crypto: AssetClass(percent: 0, amount: 0),
        other:  AssetClass(percent: 0, amount: 0)
    )

    static func allocation(from payload: APIInvestmentHoldingsPayload) -> Allocation {
        // 分母优先用 total_account_value（账户余额总和，含未投资现金），确保百分比正确
        let totalAccountValue = payload.summary.totalAccountValue ?? payload.summary.totalValue
        guard totalAccountValue > 0 else { return zeroAllocation }

        // 从 type_breakdown 累加各类持仓市值
        var stocks = 0.0
        var funds  = 0.0
        var bonds  = 0.0
        var cash   = 0.0
        var crypto = 0.0
        var other  = 0.0
        for row in payload.typeBreakdown {
            switch bucket(for: row.type) {
            case .stocks: stocks += row.value
            case .funds:  funds  += row.value
            case .bonds:  bonds  += row.value
            case .cash:   cash   += row.value
            case .crypto: crypto += row.value
            case .other:  other  += row.value
            }
        }
        // 将未投资现金（账户余额 - 持仓市值）计入 Cash；仅计 investment portfolio 内部，不混入 depository
        cash += payload.summary.uninvestedCashValue ?? 0

        func pct(_ amount: Double) -> Int {
            Int((amount / totalAccountValue * 100).rounded())
        }
        return Allocation(
            stocks: AssetClass(percent: pct(stocks), amount: stocks),
            funds:  AssetClass(percent: pct(funds),  amount: funds),
            bonds:  AssetClass(percent: pct(bonds),  amount: bonds),
            cash:   AssetClass(percent: pct(cash),   amount: cash),
            crypto: AssetClass(percent: pct(crypto), amount: crypto),
            other:  AssetClass(percent: pct(other),  amount: other)
        )
    }

    private enum Bucket { case stocks, funds, bonds, cash, crypto, other }

    /// Plaid `security.type` → bucket. Plaid's canonical types: `cash`, `cryptocurrency`,
    /// `derivative`, `equity`, `etf`, `fixed income`, `loan`, `mutual fund`, `other`.
    /// We split funds and bonds into their own buckets instead of force-fitting them
    /// into stocks / other.
    private static func bucket(for apiType: String) -> Bucket {
        let t = apiType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Canonical Plaid strings (exact match, fastest path)
        switch t {
        case "cryptocurrency":          return .crypto
        case "cash":                    return .cash
        case "equity":                  return .stocks
        case "etf", "mutual fund":      return .funds
        case "fixed income":            return .bonds
        case "derivative", "loan",
             "other", "":               return .other
        default:                        break
        }

        // Defensive substring match for non-canonical / legacy strings
        if t.contains("crypto") || t == "digital asset" { return .crypto }
        if t == "cash equivalent" || t.contains("money market") || t.contains("currency") { return .cash }
        if t.contains("bond") || t.contains("fixed") || t.contains("treasury") || t.contains("note") { return .bonds }
        if t.contains("etf") || t.contains("fund") { return .funds }
        if t.contains("equity") || t.contains("stock") || t == "reit" { return .stocks }
        return .other
    }

    /// 与 `AssetAllocationDetailView` 中 `AllocDetailItem.id` 对齐。
    static func allocationDetailBucketId(for apiType: String?) -> String {
        guard let t = apiType?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return "other"
        }
        switch bucket(for: t) {
        case .stocks: return "stocks"
        case .funds:  return "funds"
        case .bonds:  return "bonds"
        case .cash:   return "cash"
        case .crypto: return "crypto"
        case .other:  return "other"
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
            name: cleanedSecurityName(row.name),
            shares: row.quantity ?? 0,
            totalValue: row.value ?? 0,
            logoUrl: nil,
            accountName: row.accountName,
            accountMask: row.accountMask
        )
    }

    /// Plaid security names are verbose ("Vanguard Index Funds - Vanguard Total
    /// Stock Market ETF"). Strip the issuer-fund-family prefix so the row title
    /// fits on one line.
    static func cleanedSecurityName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

        // Pattern 1: "Issuer Family - Real Name" → take the part after " - "
        if let dashRange = trimmed.range(of: " - ") {
            let tail = trimmed[dashRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                return stripTrailingSeries(tail)
            }
        }

        return stripTrailingSeries(trimmed)
    }

    /// Drops trailing " Series N" / " Class A/B" noise that Plaid appends.
    /// Example: "Invesco QQQ Trust Series 1" → "Invesco QQQ Trust".
    private static func stripTrailingSeries(_ name: String) -> String {
        let suffixes = [" Series ", " Class "]
        for suffix in suffixes {
            if let range = name.range(of: suffix, options: .backwards) {
                return String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return name
    }

    static func holdings(for detailItemId: String, payload: APIInvestmentHoldingsPayload?) -> [Holding] {
        guard let payload else { return [] }
        return payload.holdings
            .filter { allocationDetailBucketId(for: $0.type) == detailItemId }
            .map { holding(from: $0) }
            .sorted { $0.totalValue > $1.totalValue }
    }
}
