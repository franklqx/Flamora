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

    /// 单月按需补拉。预选月份选择器最多回溯 12 个月，可能跨年；`fetchMonthlySummaries` 只覆盖
    /// "今年 1 月 → 当月"，跨年或缺月时由 `switchToBudgetMonth` 调用本方法补齐。
    static func fetchSingleMonthSummary(year: Int, monthIndex: Int) async -> APISpendingSummary? {
        let month = monthIndex + 1
        guard month >= 1, month <= 12 else { return nil }
        let monthStr = String(format: "%04d-%02d", year, month)
        do {
            return try await APIService.shared.getSpendingSummary(month: monthStr)
        } catch {
            print("⚠️ [CashflowAPICharts] single-month summary failed for \(monthStr): \(error)")
            return nil
        }
    }

    /// 把单月 summary merge 进 4 个 detail 结构（`total` / `needs` / `wants` / `savings`）。
    /// 用于切换到缓存里没有的月份（典型为跨年）。其余月份保持不变。
    static func mergedDetails(
        summary: APISpendingSummary,
        year: Int,
        monthIndex: Int,
        existingTotal: TotalSpendingDetailData?,
        existingNeeds: SpendingDetailData?,
        existingWants: SpendingDetailData?,
        existingSavings: [Int: [Double?]]?
    ) -> (
        total: TotalSpendingDetailData,
        needs: SpendingDetailData,
        wants: SpendingDetailData,
        savings: [Int: [Double?]]
    ) {
        func ensure12(_ arr: [Double?]?) -> [Double?] {
            var copy = arr ?? Array(repeating: nil, count: 12)
            while copy.count < 12 { copy.append(nil) }
            return copy
        }

        // Total
        let totalSpending = summary.totalSpending
        let n = summary.needs.total
        let w = summary.wants.total
        let denom = totalSpending > 0 ? totalSpending : 1
        let totalEntry = TotalSpendingMonthData(
            total: totalSpending,
            needsAmount: n,
            wantsAmount: w,
            needsPercentage: n / denom * 100,
            wantsPercentage: w / denom * 100
        )
        var totalTrendsByYear = existingTotal?.trendsByYear ?? [:]
        var totalMonthlyByYear = existingTotal?.monthlyDataByYear ?? [:]
        var totalTrend = ensure12(totalTrendsByYear[year])
        totalTrend[monthIndex] = totalSpending
        var totalMonthly = totalMonthlyByYear[year] ?? [:]
        totalMonthly[monthIndex] = totalEntry
        totalTrendsByYear[year] = totalTrend
        totalMonthlyByYear[year] = totalMonthly
        let mergedTotal = TotalSpendingDetailData(
            title: existingTotal?.title ?? "Total Spending",
            trendsByYear: totalTrendsByYear,
            monthlyDataByYear: totalMonthlyByYear
        )

        // Needs
        let needsCats = summary.needs.subcategories.enumerated().map { i, sub in
            SpendingDetailCategory(
                id: "\(year)-\(monthIndex)-\(sub.subcategory)-\(i)",
                icon: "tag.fill",
                name: sub.subcategory,
                amount: sub.amount,
                percentage: sub.percentage
            )
        }
        let needsEntry = SpendingDetailMonthData(total: n, categories: needsCats)
        var needsTrendsByYear = existingNeeds?.trendsByYear ?? [:]
        var needsMonthlyByYear = existingNeeds?.monthlyDataByYear ?? [:]
        var needsTrend = ensure12(needsTrendsByYear[year])
        needsTrend[monthIndex] = n
        var needsMonthly = needsMonthlyByYear[year] ?? [:]
        needsMonthly[monthIndex] = needsEntry
        needsTrendsByYear[year] = needsTrend
        needsMonthlyByYear[year] = needsMonthly
        let mergedNeeds = SpendingDetailData(
            title: existingNeeds?.title ?? "Spending Analysis (Needs)",
            accentColor: existingNeeds?.accentColor ?? "#2563EB",
            trendsByYear: needsTrendsByYear,
            monthlyDataByYear: needsMonthlyByYear
        )

        // Wants
        let wantsCats = summary.wants.subcategories.enumerated().map { i, sub in
            SpendingDetailCategory(
                id: "\(year)-\(monthIndex)-\(sub.subcategory)-\(i)",
                icon: "tag.fill",
                name: sub.subcategory,
                amount: sub.amount,
                percentage: sub.percentage
            )
        }
        let wantsEntry = SpendingDetailMonthData(total: w, categories: wantsCats)
        var wantsTrendsByYear = existingWants?.trendsByYear ?? [:]
        var wantsMonthlyByYear = existingWants?.monthlyDataByYear ?? [:]
        var wantsTrend = ensure12(wantsTrendsByYear[year])
        wantsTrend[monthIndex] = w
        var wantsMonthly = wantsMonthlyByYear[year] ?? [:]
        wantsMonthly[monthIndex] = wantsEntry
        wantsTrendsByYear[year] = wantsTrend
        wantsMonthlyByYear[year] = wantsMonthly
        let mergedWants = SpendingDetailData(
            title: existingWants?.title ?? "Spending Analysis (Wants)",
            accentColor: existingWants?.accentColor ?? "#8B5CF6",
            trendsByYear: wantsTrendsByYear,
            monthlyDataByYear: wantsMonthlyByYear
        )

        // Savings (manual check-in 优先；否则 estimated；再否则 income - spending)
        var mergedSavings = existingSavings ?? [:]
        var savingsTrend = ensure12(mergedSavings[year])
        let fallback = max(0, summary.totalIncome - summary.totalSpending)
        savingsTrend[monthIndex] = summary.savings.actual ?? summary.savings.estimated ?? fallback
        mergedSavings[year] = savingsTrend

        return (mergedTotal, mergedNeeds, mergedWants, mergedSavings)
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
            accentColor: "#8B5CF6",
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
            let categories = incomeSourceCategories(from: s, year: year, monthIndex: m, total: inc)
            monthly[m] = TotalIncomeMonthData(
                total: inc,
                activeAmount: active,
                passiveAmount: passive,
                activePercentage: active / denom * 100,
                passivePercentage: passive / denom * 100,
                sourceCategories: categories
            )
        }
        return TotalIncomeDetailData(
            title: "Total Income",
            trendsByYear: [year: trend],
            monthlyDataByYear: [year: monthly]
        )
    }

    /// 合并 `incomeActiveSources` / `incomePassiveSources`；无明细时退回 Active/Passive 或「Recorded income」行。
    private static func incomeSourceCategories(
        from s: APISpendingSummary,
        year: Int,
        monthIndex: Int,
        total: Double
    ) -> [SpendingDetailCategory] {
        struct Row {
            let name: String
            let amount: Double
            let accountName: String?
            let creditDate: String?
        }
        var rows: [Row] = []
        if let a = s.incomeActiveSources {
            for src in a {
                rows.append(Row(name: src.name, amount: src.amount, accountName: src.accountName, creditDate: src.creditDate))
            }
        }
        if let p = s.incomePassiveSources {
            for src in p {
                rows.append(Row(name: src.name, amount: src.amount, accountName: src.accountName, creditDate: src.creditDate))
            }
        }
        if rows.isEmpty {
            let ai = s.activeIncome ?? 0
            let pi = s.passiveIncome ?? 0
            if ai > 0.005 { rows.append(Row(name: "Active income", amount: ai, accountName: nil, creditDate: nil)) }
            if pi > 0.005 { rows.append(Row(name: "Passive income", amount: pi, accountName: nil, creditDate: nil)) }
            if rows.isEmpty && total > 0.005 {
                rows.append(Row(name: "Recorded income", amount: total, accountName: nil, creditDate: nil))
            }
        }
        let denom = max(total, 0.0001)
        return rows.enumerated().map { i, r in
            SpendingDetailCategory(
                id: "income-\(year)-\(monthIndex)-\(i)-\(r.name)",
                icon: TransactionCategoryCatalog.icon(forStoredSubcategory: r.name) ?? "dollarsign.circle.fill",
                name: r.name,
                amount: r.amount,
                percentage: r.amount / denom * 100,
                accountName: r.accountName,
                creditDate: r.creditDate
            )
        }
    }

    /// 主卡 `Income` 圆环分段；行顺序与 `incomeSourceCategories` 一致。
    static func incomeSources(from summary: APISpendingSummary) -> [IncomeSource] {
        var rows: [(name: String, amount: Double, type: String)] = []
        if let a = summary.incomeActiveSources {
            for src in a { rows.append((src.name, src.amount, "active")) }
        }
        if let p = summary.incomePassiveSources {
            for src in p { rows.append((src.name, src.amount, "passive")) }
        }
        if rows.isEmpty {
            let ai = summary.activeIncome ?? 0
            let pi = summary.passiveIncome ?? 0
            if ai > 0.005 { rows.append(("Active income", ai, "active")) }
            if pi > 0.005 { rows.append(("Passive income", pi, "passive")) }
            if rows.isEmpty && summary.totalIncome > 0.005 {
                rows.append(("Recorded income", summary.totalIncome, "active"))
            }
        }
        return rows.enumerated().map { i, r in
            IncomeSource(id: "income-src-\(i)", name: r.name, amount: r.amount, type: r.type)
        }
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
