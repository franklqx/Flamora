//
//  CashflowDetailBuilders.swift
//  Flamora app
//
//  将多个月份的 `get-spending-summary` 汇总为 Cash Flow 全屏详情页与储蓄年度趋势使用的结构体。
//

import Foundation

enum CashflowAPICharts {
    /// 并行拉取本年至 `throughMonth`（含）的每月 `get-spending-summary`。键为月份索引 0–11（1 月 = 0）。
    static func fetchMonthlySummaries(year: Int, throughMonth: Int) async -> [Int: APISpendingSummary] {
        let cal = Calendar.current
        let now = Date()
        guard cal.component(.year, from: now) == year else { return [:] }
        guard throughMonth >= 1, throughMonth <= 12 else { return [:] }

        return await withTaskGroup(of: (Int, APISpendingSummary?).self) { group in
            for m in 1...throughMonth {
                let monthStr = String(format: "%04d-%02d", year, m)
                let idx = m - 1
                group.addTask {
                    let s = try? await APIService.shared.getSpendingSummary(month: monthStr)
                    return (idx, s)
                }
            }
            var dict: [Int: APISpendingSummary] = [:]
            for await (idx, s) in group {
                if let s { dict[idx] = s }
            }
            return dict
        }
    }

    /// 每月储蓄 ≈ max(0, total_income − total_spending)，与 `get-spending-summary` 基于 transactions 的汇总一致。
    static func savingsMonthlyAmountsByYear(summaries: [Int: APISpendingSummary], year: Int) -> [Int: [Double?]] {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        for m in 0..<12 {
            guard let s = summaries[m] else { continue }
            let net = s.totalIncome - s.totalSpending
            trend[m] = max(0, net)
        }
        return [year: trend]
    }

    static func totalSpendingDetail(summaries: [Int: APISpendingSummary], year: Int) -> TotalSpendingDetailData {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        var monthly: [Int: TotalSpendingMonthData] = [:]
        for m in 0..<12 {
            guard let s = summaries[m] else { continue }
            let total = s.totalSpending
            trend[m] = total
            let n = s.needs.total
            let w = s.wants.total
            let denom = total > 0 ? total : 1
            monthly[m] = TotalSpendingMonthData(
                total: total,
                needsAmount: n,
                wantsAmount: w,
                needsPercentage: n / denom * 100,
                wantsPercentage: w / denom * 100
            )
        }
        return TotalSpendingDetailData(
            title: "Spending Analysis",
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }

    static func needsSpendingDetail(summaries: [Int: APISpendingSummary], year: Int) -> SpendingDetailData {
        spendingBucketDetail(
            title: "Spending Analysis (Needs)",
            accentColor: "#2563EB",
            summaries: summaries,
            year: year,
            bucket: { $0.needs }
        )
    }

    static func wantsSpendingDetail(summaries: [Int: APISpendingSummary], year: Int) -> SpendingDetailData {
        spendingBucketDetail(
            title: "Spending Analysis (Wants)",
            accentColor: "#D97706",
            summaries: summaries,
            year: year,
            bucket: { $0.wants }
        )
    }

    private static func spendingBucketDetail(
        title: String,
        accentColor: String,
        summaries: [Int: APISpendingSummary],
        year: Int,
        bucket: (APISpendingSummary) -> APISpendingCategoryBucket
    ) -> SpendingDetailData {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        var monthly: [Int: SpendingDetailMonthData] = [:]
        for m in 0..<12 {
            guard let s = summaries[m] else { continue }
            let b = bucket(s)
            let total = b.total
            trend[m] = total
            let cats: [SpendingDetailCategory] = b.subcategories.enumerated().map { i, sub in
                SpendingDetailCategory(
                    id: "\(year)-\(m)-\(sub.subcategory)-\(i)",
                    icon: "tag.fill",
                    name: sub.subcategory,
                    amount: sub.amount,
                    percentage: sub.percentage
                )
            }
            monthly[m] = SpendingDetailMonthData(total: total, categories: cats)
        }
        return SpendingDetailData(
            title: title,
            accentColor: accentColor,
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }

    static func totalIncomeDetail(summaries: [Int: APISpendingSummary], year: Int) -> TotalIncomeDetailData {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        var monthly: [Int: TotalIncomeMonthData] = [:]
        for m in 0..<12 {
            guard let s = summaries[m] else { continue }
            let inc = s.totalIncome
            trend[m] = inc
            monthly[m] = TotalIncomeMonthData(
                total: inc,
                activeAmount: inc,
                passiveAmount: 0,
                activePercentage: inc > 0 ? 100 : 0,
                passivePercentage: 0
            )
        }
        return TotalIncomeDetailData(
            title: "Total Income",
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }

    static func activeIncomeDetail(summaries: [Int: APISpendingSummary], year: Int) -> IncomeDetailData {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        var monthly: [Int: IncomeMonthData] = [:]
        for m in 0..<12 {
            guard let s = summaries[m] else { continue }
            let inc = s.totalIncome
            trend[m] = inc
            monthly[m] = IncomeMonthData(
                total: inc,
                sources: [
                    IncomeDetailSource(
                        id: "active-\(year)-\(m)",
                        name: "Recorded income",
                        account: "Linked accounts",
                        amount: inc,
                        percentage: 100,
                        colorHex: "#34D399",
                        type: .active
                    )
                ]
            )
        }
        return IncomeDetailData(
            title: "Active Income",
            accentColor: "#34D399",
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }

    /// 尚无 passive 拆分时：有 summary 的月份显示 0，与「全部记入 Active」一致。
    static func passiveIncomeDetail(summaries: [Int: APISpendingSummary], year: Int) -> IncomeDetailData {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        var monthly: [Int: IncomeMonthData] = [:]
        for m in 0..<12 {
            guard summaries[m] != nil else { continue }
            trend[m] = 0
            monthly[m] = IncomeMonthData(total: 0, sources: [])
        }
        return IncomeDetailData(
            title: "Passive Income",
            accentColor: "#A78BFA",
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }
}
