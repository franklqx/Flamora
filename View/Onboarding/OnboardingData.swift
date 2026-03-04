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
    var primaryChallenge: String = ""
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

    // 后端 API 返回的 FIRE 摘要（由 OB_LoadingAnalysisView 写入，供 OB_RoadmapView 读取）
    var apiFireSummary: FireSummaryDisplayData? = nil

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
}

// MARK: - Challenge Flow Enum

enum ChallengeFlowType {
    case noVisibility
    case notSaving
    case tooLittleToInvest
    case retireEarly
}

extension OnboardingData {
    var challengeFlow: ChallengeFlowType {
        switch primaryChallenge {
        case "no_visibility":       return .noVisibility
        case "not_saving":          return .notSaving
        case "too_little_to_invest": return .tooLittleToInvest
        default:                    return .retireEarly
        }
    }
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
    MotivationOption(icon: "briefcase", title: "Quit the 9-to-5", subtitle: "Work because you want to.", key: "quit"),
    MotivationOption(icon: "person.2", title: "Family First", subtitle: "Be there for every moment that matters.", key: "family"),
    MotivationOption(icon: "shield", title: "Security", subtitle: "No money stress.", key: "security"),
    MotivationOption(icon: "airplane", title: "Adventure", subtitle: "Go anywhere, anytime.", key: "adventure"),
    MotivationOption(icon: "heart", title: "Passion", subtitle: "Build what you actually care about.", key: "passion"),
]

// MARK: - Financial Challenge Options

struct ChallengeOption: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let key: String
}

let challengeOptions: [ChallengeOption] = [
    ChallengeOption(
        icon: "magnifyingglass",
        title: "I don’t know where my money goes",
        subtitle: "Spending feels invisible or random.",
        key: "no_visibility"
    ),
    ChallengeOption(
        icon: "arrow.down.circle",
        title: "I’m not saving enough",
        subtitle: "I want to put more aside each month.",
        key: "not_saving"
    ),
    ChallengeOption(
        icon: "leaf",
        title: "I have too little to invest",
        subtitle: "I’m not sure how to get started.",
        key: "too_little_to_invest"
    ),
    ChallengeOption(
        icon: "flame",
        title: "I want to retire early",
        subtitle: "I need a clear path to financial freedom.",
        key: "retire_early_confused"
    ),
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
