//
//  RoadmapCopyResolver.swift
//  Flamora app
//
//  A/B/C/D/E 决策树与全页面文案生成器
//  纯 Foundation 层，不依赖 SwiftUI
//

import Foundation

// MARK: - Copy Model

struct RoadmapCopy {
    // 区域 1 — 顶部标题
    let heroLine1: String        // 白色大字（主标题）
    let heroLine2: String        // 品牌高亮色（优化建议）
    let heroLine3: String        // 渐变大字（冲击数字）
    let showFreedomAgeInHero: Bool

    // 区域 2 — KPI 卡片
    let leftCardLabel: String
    let leftCardValue: String
    let leftCardSublabel: String
    let rightCardLabel: String
    let rightCardValue: String
    let rightCardSublabel: String

    // 区域 3 — 时间线
    let showTimeline: Bool
    let timelinePlaceholder: String?  // 仅当 showTimeline == false 时使用

    // 区域 4 — 紧迫感卡片
    let urgencyTitle: String
    let urgencyBody: String

    // 区域 5 — 锁定洞察
    let insightCard1Title: String
    let insightCard2Title: String
    let insightCard3Title: String
}

// MARK: - Resolver

struct RoadmapCopyResolver {

    static func resolve(metrics: RoadmapMetrics) -> RoadmapCopy {
        switch metrics.userCase {
        case .A: return resolveA(metrics: metrics)
        case .B: return resolveB(metrics: metrics)
        case .C: return resolveC(metrics: metrics)
        case .D: return resolveD(metrics: metrics)
        case .E: return resolveE(metrics: metrics)
        }
    }

    // MARK: Case A — 存不下钱 (savingsRate <= 0)

    private static func resolveA(metrics: RoadmapMetrics) -> RoadmapCopy {
        let sym = metrics.currencySymbol
        let target = FreedomProjectionCalculator.formatAmount(metrics.targetAmount, symbol: sym)

        return RoadmapCopy(
            heroLine1: "Let's find your starting point",
            heroLine2: "Most people have hidden savings in their spending.",
            heroLine3: "Users discover \(sym)200–400/month in hidden savings on average.",
            showFreedomAgeInHero: false,
            leftCardLabel: "SAVINGS RATE",
            leftCardValue: "0%",
            leftCardSublabel: "Let's improve this",
            rightCardLabel: "TARGET",
            rightCardValue: target,
            rightCardSublabel: "Freedom number",
            showTimeline: false,
            timelinePlaceholder: "Connect your accounts and we'll map your path",
            urgencyTitle: "The cost of not knowing",
            urgencyBody: "Without tracking, the average person overspends \(sym)300–500/month without realizing it.",
            insightCard1Title: "Find hidden savings in your spending",
            insightCard2Title: "Your personalized budget plan",
            insightCard3Title: "First steps to start investing"
        )
    }

    // MARK: Case B — 已经很近 (freedomAge <= currentAge + 5)

    private static func resolveB(metrics: RoadmapMetrics) -> RoadmapCopy {
        let sym = metrics.currencySymbol
        let progress = Int(metrics.timelineProgress * 100)
        let target = FreedomProjectionCalculator.formatAmount(metrics.targetAmount, symbol: sym)
        let savingsStr = String(format: "%.0f%%", metrics.savingsRate)

        return RoadmapCopy(
            heroLine1: "You can reach freedom at age \(metrics.freedomAge)",
            heroLine2: "You're ahead of 95% of people your age.",
            heroLine3: "You're almost there. Flamora keeps your progress on track.",
            showFreedomAgeInHero: true,
            leftCardLabel: "SAVINGS RATE",
            leftCardValue: savingsStr,
            leftCardSublabel: "Current",
            rightCardLabel: "PROGRESS",
            rightCardValue: "\(progress)%",
            rightCardSublabel: "Almost there",
            showTimeline: true,
            timelinePlaceholder: nil,
            urgencyTitle: "Don't lose momentum",
            urgencyBody: "You're this close. A small slip in spending could push your freedom date back by months.",
            insightCard1Title: "How to protect your progress",
            insightCard2Title: "Optimize your asset allocation",
            insightCard3Title: "Tax-efficient withdrawal strategies"
        )
    }

    // MARK: Case C — 有储蓄但未投资 (investment == 0, savingsRate > 0)

    private static func resolveC(metrics: RoadmapMetrics) -> RoadmapCopy {
        let sym = metrics.currencySymbol
        let extra = FreedomProjectionCalculator.formatAmount(
            metrics.extraMonthlyInvestRecommendation, symbol: sym)
        let target = FreedomProjectionCalculator.formatAmount(metrics.targetAmount, symbol: sym)
        let savingsStr = String(format: "%.0f%%", metrics.savingsRate)
        let costStr = pluralYears(metrics.delayCostYears)

        return RoadmapCopy(
            heroLine1: "You can reach freedom at age \(metrics.freedomAge)",
            heroLine2: "Start investing just \(extra)/month today — free by \(metrics.optimizedFreedomAge)",
            heroLine3: "\(metrics.yearsEarlier) years earlier — just by starting now.",
            showFreedomAgeInHero: true,
            leftCardLabel: "SAVINGS RATE",
            leftCardValue: savingsStr,
            leftCardSublabel: "Current",
            rightCardLabel: "TARGET",
            rightCardValue: target,
            rightCardSublabel: "Freedom number",
            showTimeline: true,
            timelinePlaceholder: nil,
            urgencyTitle: "Every month you wait costs you",
            urgencyBody: "If you delay your plan by just 1 year, your freedom age moves from \(metrics.freedomAge) to \(metrics.delayedFreedomAge). That's \(costStr) extra of working.",
            insightCard1Title: "3 ways to reach freedom faster",
            insightCard2Title: "Your monthly saving plan",
            insightCard3Title: "Spending areas to optimize"
        )
    }

    // MARK: Case D — 非常遥远 (freedomAge > 65)

    private static func resolveD(metrics: RoadmapMetrics) -> RoadmapCopy {
        let sym = metrics.currencySymbol
        let extra = FreedomProjectionCalculator.formatAmount(
            metrics.extraMonthlyInvestRecommendation, symbol: sym)
        let growth = FreedomProjectionCalculator.formatAmount(metrics.tenYearGrowth, symbol: sym)
        let target = FreedomProjectionCalculator.formatAmount(metrics.targetAmount, symbol: sym)
        let savingsStr = String(format: "%.0f%%", metrics.savingsRate)

        return RoadmapCopy(
            heroLine1: "Your journey starts today",
            heroLine2: "By investing just \(extra) more per month, you could build \(growth) in 10 years.",
            heroLine3: "Small changes compound into big results.",
            showFreedomAgeInHero: false,
            leftCardLabel: "SAVINGS RATE",
            leftCardValue: savingsStr,
            leftCardSublabel: "Current",
            rightCardLabel: "TARGET",
            rightCardValue: target,
            rightCardSublabel: "Freedom number",
            showTimeline: true,
            timelinePlaceholder: nil,
            urgencyTitle: "Time is your biggest asset",
            urgencyBody: "The earlier you start, the more compound interest works for you. Even starting 1 year earlier makes a significant difference.",
            insightCard1Title: "3 ways to reach freedom faster",
            insightCard2Title: "Your monthly saving plan",
            insightCard3Title: "Spending areas to optimize"
        )
    }

    // MARK: Case E — 正常情况

    private static func resolveE(metrics: RoadmapMetrics) -> RoadmapCopy {
        let sym = metrics.currencySymbol
        let extra = FreedomProjectionCalculator.formatAmount(
            metrics.extraMonthlyInvestRecommendation, symbol: sym)
        let target = FreedomProjectionCalculator.formatAmount(metrics.targetAmount, symbol: sym)
        let savingsStr = String(format: "%.0f%%", metrics.savingsRate)
        let costStr = pluralYears(metrics.delayCostYears)
        let earlierStr = pluralYears(metrics.yearsEarlier)

        return RoadmapCopy(
            heroLine1: "You can reach freedom at age \(metrics.freedomAge)",
            heroLine2: "Invest just \(extra) more per month — free by \(metrics.optimizedFreedomAge)",
            heroLine3: "That's \(earlierStr) earlier.",
            showFreedomAgeInHero: true,
            leftCardLabel: "SAVINGS RATE",
            leftCardValue: savingsStr,
            leftCardSublabel: "Current",
            rightCardLabel: "TARGET",
            rightCardValue: target,
            rightCardSublabel: "Freedom number",
            showTimeline: true,
            timelinePlaceholder: nil,
            urgencyTitle: "Every month you wait costs you",
            urgencyBody: "If you delay your plan by just 1 year, your freedom age moves from \(metrics.freedomAge) to \(metrics.delayedFreedomAge). That's \(costStr) extra of working.",
            insightCard1Title: "3 ways to reach freedom faster",
            insightCard2Title: "Your monthly saving plan",
            insightCard3Title: "Spending areas to optimize"
        )
    }

    // MARK: - Helpers

    private static func pluralYears(_ n: Int) -> String {
        n == 1 ? "1 year" : "\(n) years"
    }
}
