//
//  FreedomProjectionCalculator.swift
//  Flamora app
//
//  纯计算层 - 无 SwiftUI 依赖，可单独测试
//  输入 OnboardingData，输出 RoadmapMetrics 和 RoadmapUserCase
//

import Foundation

// MARK: - User Case Classification

enum RoadmapUserCase: String {
    case A  // 存不下钱 (savingsRate <= 0)
    case B  // 已经很近 (freedomAge <= currentAge + 5)
    case C  // 有储蓄但未投资 (investment == 0 && savingsRate > 0)
    case D  // 非常遥远 (freedomAge > 65)
    case E  // 正常情况
}

// MARK: - Roadmap Metrics

struct RoadmapMetrics {
    // 输入镜像（供显示用）
    let currentAge: Int
    let targetAmount: Double
    let savingsRate: Double
    let monthlyInvestable: Double
    let existingInvestment: Double
    let retirementMonthlySpend: Double
    let currencySymbol: String

    // 基础 FIRE 计算
    let yearsToFire: Int
    let freedomAge: Int

    // 时间线进度 (0.0 - 1.0)
    let passiveIncomeMonthly: Double
    let timelineProgress: Double

    // 优化建议
    let extraMonthlyInvestRecommendation: Double
    let optimizedYearsToFire: Int
    let optimizedFreedomAge: Int
    let yearsEarlier: Int

    // 延迟代价
    let delayedFreedomAge: Int
    let delayCostYears: Int

    // Case D：10 年增长估算
    let tenYearGrowth: Double

    // 用户分类
    let userCase: RoadmapUserCase
}

// MARK: - Calculator

struct FreedomProjectionCalculator {

    /// 从 OnboardingData 计算完整 RoadmapMetrics
    static func compute(from data: OnboardingData) -> RoadmapMetrics {
        let currentAge = Int(data.age)
        let monthlyIncome  = max(0, Double(data.monthlyIncome)   ?? 0)
        let monthlyExpenses = max(0, Double(data.monthlyExpenses) ?? 0)
        let existingInvestment = max(0, Double(data.currentNetWorth) ?? 0)

        // 退休月支出：优先用 targetMonthlySpend（由 LifestyleView 写入），否则 fallback
        let retirementMonthlySpend: Double = data.targetMonthlySpend > 0
            ? data.targetMonthlySpend
            : monthlyExpenses

        // FIRE 目标金额 (4% 规则)
        let targetAmount = retirementMonthlySpend * 12.0 * 25.0

        let monthlyInvestable = max(0, monthlyIncome - monthlyExpenses)
        let savingsRate = monthlyIncome > 0
            ? ((monthlyIncome - monthlyExpenses) / monthlyIncome) * 100.0
            : 0.0

        // 基础 FIRE 年数
        let yearsToFire = computeYearsToFire(
            principal: existingInvestment,
            monthlyContribution: monthlyInvestable,
            target: targetAmount
        )
        let freedomAge = currentAge + yearsToFire

        // 时间线进度：被动收入 / 目标月支出
        let passiveIncomeMonthly = existingInvestment * 0.04 / 12.0
        let timelineProgress = retirementMonthlySpend > 0
            ? min(1.0, passiveIncomeMonthly / retirementMonthlySpend)
            : 0.0

        // 额外投入建议（按收入区间）
        let extraRec = extraMonthlyRecommendation(monthlyIncome: monthlyIncome)

        // 优化后 FIRE
        let optimizedMonthly = monthlyInvestable + extraRec
        let optimizedYearsToFire = computeYearsToFire(
            principal: existingInvestment,
            monthlyContribution: optimizedMonthly,
            target: targetAmount
        )
        let optimizedFreedomAge = currentAge + optimizedYearsToFire
        let yearsEarlier = max(0, freedomAge - optimizedFreedomAge)

        // 延迟 1 年代价：投资继续增长但不新增储蓄 1 年
        let principalAfterDelay = existingInvestment * 1.07
        let delayedYears = 1 + computeYearsToFire(
            principal: principalAfterDelay,
            monthlyContribution: monthlyInvestable,
            target: targetAmount
        )
        let delayedFreedomAge = currentAge + min(delayedYears, 99)
        let delayCostYears = max(0, delayedFreedomAge - freedomAge)

        // Case D：仅用额外建议投入的 10 年增长（从零开始）
        let tenYearGrowth = compute10YearGrowth(monthlyContribution: extraRec)

        // 决策树（优先级严格按照产品规格）
        let userCase: RoadmapUserCase
        if savingsRate <= 0 {
            userCase = .A
        } else if freedomAge <= currentAge + 5 {
            userCase = .B
        } else if existingInvestment == 0 && savingsRate > 0 {
            userCase = .C
        } else if freedomAge > 65 {
            userCase = .D
        } else {
            userCase = .E
        }

        return RoadmapMetrics(
            currentAge: currentAge,
            targetAmount: targetAmount,
            savingsRate: savingsRate,
            monthlyInvestable: monthlyInvestable,
            existingInvestment: existingInvestment,
            retirementMonthlySpend: retirementMonthlySpend,
            currencySymbol: data.currencySymbol,
            yearsToFire: yearsToFire,
            freedomAge: freedomAge,
            passiveIncomeMonthly: passiveIncomeMonthly,
            timelineProgress: timelineProgress,
            extraMonthlyInvestRecommendation: extraRec,
            optimizedYearsToFire: optimizedYearsToFire,
            optimizedFreedomAge: optimizedFreedomAge,
            yearsEarlier: yearsEarlier,
            delayedFreedomAge: delayedFreedomAge,
            delayCostYears: delayCostYears,
            tenYearGrowth: tenYearGrowth,
            userCase: userCase
        )
    }

    // MARK: - Private Helpers

    /// 考虑复利（7% 年化）计算达到目标需要多少年
    static func computeYearsToFire(
        principal: Double,
        monthlyContribution: Double,
        target: Double,
        annualReturn: Double = 0.07
    ) -> Int {
        guard target > 0 else { return 0 }
        if principal >= target { return 0 }
        if monthlyContribution <= 0 { return 99 }

        var accumulated = principal
        var years = 0
        let annualContribution = monthlyContribution * 12.0

        while accumulated < target && years < 99 {
            accumulated = accumulated * (1.0 + annualReturn) + annualContribution
            years += 1
        }
        return years
    }

    /// 按收入区间返回建议额外投入金额
    static func extraMonthlyRecommendation(monthlyIncome: Double) -> Double {
        switch monthlyIncome {
        case ..<3_000:          return 100
        case 3_000..<6_000:    return 200
        case 6_000..<10_000:   return 300
        case 10_000..<20_000:  return 500
        default:                return 1_000
        }
    }

    /// 从零开始按建议金额投入 10 年的复利增长总额
    static func compute10YearGrowth(
        monthlyContribution: Double,
        annualReturn: Double = 0.07
    ) -> Double {
        var accumulated = 0.0
        let annualContribution = monthlyContribution * 12.0
        for _ in 1...10 {
            accumulated = accumulated * (1.0 + annualReturn) + annualContribution
        }
        return accumulated
    }

    /// 格式化货币金额（K/M 简写）
    static func formatAmount(_ value: Double, symbol: String) -> String {
        if value >= 1_000_000 {
            return "\(symbol)\(String(format: "%.1fM", value / 1_000_000))"
        } else if value >= 1_000 {
            return "\(symbol)\(String(format: "%.0fK", value / 1_000))"
        }
        return "\(symbol)\(Int(value))"
    }
}
