//
//  CashflowDetailEmptyStates.swift
//  Flamora app
//
//  无聚合数据时的空详情（非 Mock 假数），供 Cashflow / Journey / MainTab 运行时回退。
//

import Foundation

enum CashflowDetailEmptyStates {
    /// 当年 12 个月储蓄金额全为 nil（图表空柱）。
    static func savingsMonthlyAmountsEmptyCurrentYear() -> [Int: [Double?]] {
        let y = currentYear
        return [y: twelveNils]
    }

    fileprivate static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    fileprivate static var twelveNils: [Double?] {
        Array(repeating: nil, count: 12)
    }
}

extension IncomeDetailData {
    static var emptyActiveIncome: IncomeDetailData {
        let y = CashflowDetailEmptyStates.currentYear
        return IncomeDetailData(
            title: "Active Income",
            accentColor: "#34D399",
            trendsByYear: [y: CashflowDetailEmptyStates.twelveNils],
            monthlyDataByYear: [y: [:]]
        )
    }

    static var emptyPassiveIncome: IncomeDetailData {
        let y = CashflowDetailEmptyStates.currentYear
        return IncomeDetailData(
            title: "Passive Income",
            accentColor: "#A78BFA",
            trendsByYear: [y: CashflowDetailEmptyStates.twelveNils],
            monthlyDataByYear: [y: [:]]
        )
    }
}

extension TotalIncomeDetailData {
    static var empty: TotalIncomeDetailData {
        let y = CashflowDetailEmptyStates.currentYear
        return TotalIncomeDetailData(
            title: "Total Income",
            trendsByYear: [y: CashflowDetailEmptyStates.twelveNils],
            monthlyDataByYear: [y: [:]]
        )
    }
}

extension SpendingDetailData {
    static var emptyNeeds: SpendingDetailData {
        let y = CashflowDetailEmptyStates.currentYear
        return SpendingDetailData(
            title: "Spending Analysis (Needs)",
            accentColor: "#2563EB",
            trendsByYear: [y: CashflowDetailEmptyStates.twelveNils],
            monthlyDataByYear: [y: [:]]
        )
    }

    static var emptyWants: SpendingDetailData {
        let y = CashflowDetailEmptyStates.currentYear
        return SpendingDetailData(
            title: "Spending Analysis (Wants)",
            accentColor: "#D97706",
            trendsByYear: [y: CashflowDetailEmptyStates.twelveNils],
            monthlyDataByYear: [y: [:]]
        )
    }
}

extension TotalSpendingDetailData {
    static var empty: TotalSpendingDetailData {
        let y = CashflowDetailEmptyStates.currentYear
        return TotalSpendingDetailData(
            title: "Total Spending",
            trendsByYear: [y: CashflowDetailEmptyStates.twelveNils],
            monthlyDataByYear: [y: [:]]
        )
    }
}
