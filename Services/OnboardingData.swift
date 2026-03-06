//
//  OnboardingData.swift
//  Flamora app
//
//  Onboarding 数据模型 - 收集用户信息
//

import SwiftUI

@Observable
class OnboardingData {
    var email: String = ""
    var userId: String = ""   // 登录/注册成功后立即存入，供后续 API 调用使用
    var userName: String = ""
    var motivations: Set<String> = []
    var age: Double = 28
    var country: String = "United States"
    var currencyCode: String = "USD"
    var currencySymbol: String = "$"
    var monthlyIncome: String = ""
    var monthlyExpenses: String = ""
    var currentNetWorth: String = ""
    var fireType: String = "maintain"
    var targetMonthlySpend: Double = 0
    var selectedPlan: String = ""        // "monthly" or "yearly"
    var plaidConnected: Bool = false
    var painPoint: String = ""           // pain_money_tracking, pain_saving, pain_investing, pain_fire

    var savingsRate: Double {
        let income = Double(monthlyIncome) ?? 0
        let expenses = Double(monthlyExpenses) ?? 0
        guard income > 0 else { return 0 }
        return ((income - expenses) / income) * 100
    }

    var monthlySavings: Double {
        let income = Double(monthlyIncome) ?? 0
        let expenses = Double(monthlyExpenses) ?? 0
        return max(0, income - expenses)
    }

    var fireNumber: Double {
        let expenses = Double(monthlyExpenses) ?? 0
        let multiplier: Double
        switch fireType {
        case "minimalist": multiplier = 0.8
        case "upgrade": multiplier = 1.5
        default: multiplier = 1.0
        }
        return expenses * multiplier * 12 * 25
    }

    var yearsToFire: Int {
        let savings = monthlySavings
        guard savings > 0 else { return 99 }
        let netWorth = Double(currentNetWorth) ?? 0
        let target = fireNumber
        let annualSavings = savings * 12
        // Simple calculation with 7% return
        var years = 0
        var accumulated = netWorth
        while accumulated < target && years < 99 {
            accumulated = accumulated * 1.07 + annualSavings
            years += 1
        }
        return years
    }

    var freedomAge: Int {
        Int(age) + yearsToFire
    }

    // MARK: - V2 Computed Properties

    /// 额外投入建议金额（基于收入）
    var suggestedExtraInvestment: Double {
        let income = Double(monthlyIncome) ?? 0
        if income < 3000 { return 100 }
        if income < 6000 { return 200 }
        if income < 10000 { return 300 }
        if income < 20000 { return 500 }
        return 1000
    }

    /// 优化后的 Freedom Age（额外投入后）
    var optimizedFreedomAge: Int {
        let optimizedMonthlySavings = monthlySavings + suggestedExtraInvestment
        guard optimizedMonthlySavings > 0 else { return freedomAge }
        var accumulated = Double(currentNetWorth) ?? 0
        var years = 0
        let target = fireNumber
        guard target > 0 else { return Int(age) }
        while accumulated < target && years < 100 {
            accumulated = accumulated * 1.07 + optimizedMonthlySavings * 12
            years += 1
        }
        return Int(age) + years
    }

    /// 提前年数
    var yearsSaved: Int {
        return max(0, freedomAge - optimizedFreedomAge)
    }

    /// 延迟1年的代价
    var delayPenalty: Int {
        let currentSavings = monthlySavings
        guard currentSavings > 0 else { return 0 }
        var accumulated = Double(currentNetWorth) ?? 0
        var years = 0
        let target = fireNumber
        guard target > 0 else { return 0 }
        // 第一年不投入，只有复利
        accumulated = accumulated * 1.07
        while accumulated < target && years < 100 {
            accumulated = accumulated * 1.07 + currentSavings * 12
            years += 1
        }
        let delayedAge = Int(age) + 1 + years
        return max(0, delayedAge - freedomAge)
    }

    /// 当前 FIRE 进度百分比
    var fireProgress: Double {
        guard fireNumber > 0 else { return 0 }
        let netWorth = Double(currentNetWorth) ?? 0
        let monthlyPassiveIncome = (netWorth * 0.04) / 12
        let expenses = Double(monthlyExpenses) ?? 0
        let targetMonthly = targetMonthlySpend > 0 ? targetMonthlySpend : expenses
        guard targetMonthly > 0 else { return 0 }
        return min(100, (monthlyPassiveIncome / targetMonthly) * 100)
    }

    var userSituation: UserSituation {
        let netWorth = Double(currentNetWorth) ?? 0
        if savingsRate <= 0 { return .cannotSave }
        if freedomAge <= Int(age) + 5 { return .almostFree }
        if netWorth == 0 && savingsRate > 0 { return .notInvesting }
        if freedomAge > 65 { return .veryFar }
        return .normal
    }
}

// MARK: - User Situation
enum UserSituation {
    case cannotSave       // 储蓄率 <= 0
    case almostFree       // freedom age <= 当前年龄 + 5
    case notInvesting     // 净资产 = 0，储蓄率 > 0
    case veryFar          // freedom age > 65
    case normal           // 正常情况
}

// MARK: - Motivation Options
struct MotivationOption: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let key: String
}

let motivationOptions: [MotivationOption] = [
    MotivationOption(icon: "briefcase", title: "Quit the 9-to-5", subtitle: "Work because you want to, not have to", key: "quit"),
    MotivationOption(icon: "figure.2.and.child.holdinghands", title: "Family First", subtitle: "Be there for every moment that matters", key: "family"),
    MotivationOption(icon: "shield.checkered", title: "Security", subtitle: "Sleep well knowing you're covered", key: "security"),
    MotivationOption(icon: "globe.americas", title: "Adventure", subtitle: "Go anywhere, anytime", key: "adventure"),
    MotivationOption(icon: "paintpalette", title: "Passion", subtitle: "Build what you actually care about", key: "passion"),
]

// MARK: - Challenge Options (Pain Points)
struct ChallengeOption: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let key: String
}

let challengeOptions: [ChallengeOption] = [
    ChallengeOption(icon: "chart.pie", title: "I don't know where my money goes", subtitle: "Losing track of spending", key: "pain_money_tracking"),
    ChallengeOption(icon: "banknote", title: "I'm not saving enough", subtitle: "Struggling to set money aside", key: "pain_saving"),
    ChallengeOption(icon: "chart.line.uptrend.xyaxis", title: "I have too little to invest", subtitle: "I'm not sure how to get started", key: "pain_investing"),
    ChallengeOption(icon: "flame", title: "I want to retire early", subtitle: "I need a clear path to financial freedom", key: "pain_fire"),
]

// MARK: - Country / Currency
struct CurrencyOption: Identifiable {
    let id = UUID()
    let country: String
    let code: String
    let symbol: String
}

let currencyOptions: [CurrencyOption] = [
    CurrencyOption(country: "United States", code: "USD", symbol: "$"),
    CurrencyOption(country: "United Kingdom", code: "GBP", symbol: "£"),
    CurrencyOption(country: "European Union", code: "EUR", symbol: "€"),
    CurrencyOption(country: "Canada", code: "CAD", symbol: "C$"),
    CurrencyOption(country: "Australia", code: "AUD", symbol: "A$"),
    CurrencyOption(country: "Japan", code: "JPY", symbol: "¥"),
    CurrencyOption(country: "China", code: "CNY", symbol: "¥"),
    CurrencyOption(country: "India", code: "INR", symbol: "₹"),
    CurrencyOption(country: "Singapore", code: "SGD", symbol: "S$"),
    CurrencyOption(country: "Hong Kong", code: "HKD", symbol: "HK$"),
]
