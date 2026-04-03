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
                    do {
                        let summary = try await APIService.shared.getSpendingSummary(month: monthStr)
                        return (idx, summary)
                    } catch {
                        print("⚠️ [CashflowAPICharts] get-spending-summary failed for \(monthStr): \(error)")
                        return (idx, nil)
                    }
                }
            }
            var dict: [Int: APISpendingSummary] = [:]
            for await (idx, s) in group {
                if let s { dict[idx] = s }
            }
            if dict.isEmpty {
                print("⚠️ [CashflowAPICharts] No monthly summaries loaded for \(year) through month \(throughMonth)")
            } else {
                let loadedMonths = dict.keys.sorted().map { String($0 + 1) }.joined(separator: ",")
                print("✅ [CashflowAPICharts] Loaded monthly summaries for months: \(loadedMonths)")
            }
            return dict
        }
    }

    /// 每月储蓄优先使用手动 check-in；若无手动值，再回退到 summary 推导值。
    static func savingsMonthlyAmountsByYear(summaries: [Int: APISpendingSummary], year: Int) -> [Int: [Double?]] {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        for m in 0..<12 {
            guard let s = summaries[m] else { continue }
            let fallback = max(0, s.totalIncome - s.totalSpending)
            trend[m] = s.savings.actual ?? s.savings.estimated ?? fallback
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
            title: "Total Spending",
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
            let active = s.activeIncome ?? inc
            let passive = s.passiveIncome ?? 0
            trend[m] = inc
            let denom = max(inc, 0.0001)
            monthly[m] = TotalIncomeMonthData(
                total: inc,
                activeAmount: active,
                passiveAmount: passive,
                activePercentage: active / denom * 100,
                passivePercentage: passive / denom * 100
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
            let active = s.activeIncome ?? s.totalIncome
            trend[m] = active > 0 ? active : nil
            let sources: [IncomeDetailSource]
            if let apiSources = s.incomeActiveSources, !apiSources.isEmpty {
                sources = apiSources.enumerated().map { i, src in
                    IncomeDetailSource(
                        id: "active-\(year)-\(m)-\(i)",
                        name: src.name,
                        account: "Linked accounts",
                        amount: src.amount,
                        percentage: src.percentage,
                        colorHex: "#34D399",
                        type: .active
                    )
                }
            } else if active > 0 {
                sources = [IncomeDetailSource(
                    id: "active-\(year)-\(m)",
                    name: "Recorded income",
                    account: "Linked accounts",
                    amount: active,
                    percentage: 100,
                    colorHex: "#34D399",
                    type: .active
                )]
            } else {
                sources = []
            }
            monthly[m] = IncomeMonthData(total: active, sources: sources)
        }
        return IncomeDetailData(
            title: "Active Income",
            accentColor: "#34D399",
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }

    static func passiveIncomeDetail(summaries: [Int: APISpendingSummary], year: Int) -> IncomeDetailData {
        var trend: [Double?] = Array(repeating: nil, count: 12)
        var monthly: [Int: IncomeMonthData] = [:]
        for m in 0..<12 {
            guard let s = summaries[m] else { continue }
            let passive = s.passiveIncome ?? 0
            trend[m] = passive > 0 ? passive : nil
            let sources: [IncomeDetailSource]
            if let apiSources = s.incomePassiveSources, !apiSources.isEmpty {
                sources = apiSources.enumerated().map { i, src in
                    IncomeDetailSource(
                        id: "passive-\(year)-\(m)-\(i)",
                        name: src.name,
                        account: "Linked accounts",
                        amount: src.amount,
                        percentage: src.percentage,
                        colorHex: "#A78BFA",
                        type: .passive
                    )
                }
            } else {
                sources = []
            }
            monthly[m] = IncomeMonthData(total: passive, sources: sources)
        }
        return IncomeDetailData(
            title: "Passive Income",
            accentColor: "#A78BFA",
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }
}
