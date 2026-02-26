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

// MARK: - Motivation Options
struct MotivationOption: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let key: String
}

let motivationOptions: [MotivationOption] = [
    MotivationOption(icon: "airplane.departure", title: "Quit the 9-to-5", subtitle: "Work because you want to, not have to", key: "quit"),
    MotivationOption(icon: "figure.2.and.child.holdinghands", title: "Family First", subtitle: "Be there for every moment that matters", key: "family"),
    MotivationOption(icon: "shield.checkered", title: "Security", subtitle: "Sleep well knowing you're covered", key: "security"),
    MotivationOption(icon: "globe.americas", title: "Adventure", subtitle: "Go anywhere, anytime", key: "adventure"),
    MotivationOption(icon: "paintpalette", title: "Passion", subtitle: "Build what you actually care about", key: "passion"),
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
