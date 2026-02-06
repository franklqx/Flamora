//
//  MockData.swift
//  Fiamora app
//
//  完整的 Mock Data - 所有页面使用
//

import Foundation

// MARK: - Journey Data Models

struct JourneyData: Codable {
    let netWorth: NetWorth
    let budget: Budget
    let passiveIncome: PassiveIncome
    let savingsRate: SavingsRate
    let fireProgress: FireProgress
}

struct NetWorth: Codable {
    let total: Double
    let growthAmount: Double
    let growthPercent: Double
}

struct Budget: Codable {
    let spent: Double
    let limit: Double
    let percent: Int
    let period: String
    let daysLeft: Int
    
    enum CodingKeys: String, CodingKey {
        case spent, limit, percent, period
        case daysLeft = "days_left"
    }
}

struct PassiveIncome: Codable {
    let projected: Double
    let target: Double
    let percent: Int
}

struct SavingsRate: Codable {
    let current: Double
    let target: Double
    let months: [MonthStatus]
}

struct MonthStatus: Codable {
    let month: String
    let status: String  // "success", "failed", "pending"
}

struct FireProgress: Codable {
    let percent: Int
    let targetAge: Int
    let currentAge: Int
}

// MARK: - Simulator Data Models

struct SimulatorData: Codable {
    let currentProfile: CurrentProfile
    let fireCalculation: FireCalculation
    let advancedSettings: AdvancedSettings
    
    enum CodingKeys: String, CodingKey {
        case currentProfile = "current_profile"
        case fireCalculation = "fire_calculation"
        case advancedSettings = "advanced_settings"
    }
}

struct CurrentProfile: Codable {
    let age: Int
    let monthlyIncome: Double
    let monthlyContribution: Double
    let expectedBudget: Double
    let currentInvestment: Double
    
    enum CodingKeys: String, CodingKey {
        case age
        case monthlyIncome = "monthly_income"
        case monthlyContribution = "monthly_contribution"
        case expectedBudget = "expected_budget"
        case currentInvestment = "current_investment"
    }
}

struct FireCalculation: Codable {
    let targetAmount: Double
    let currentNetWorth: Double
    let idealMonthlySpending: Double
    let fireAge: Int
    let fireDate: String
    let progressPercent: Int
    
    enum CodingKeys: String, CodingKey {
        case targetAmount = "target_amount"
        case currentNetWorth = "current_net_worth"
        case idealMonthlySpending = "ideal_monthly_spending"
        case fireAge = "fire_age"
        case fireDate = "fire_date"
        case progressPercent = "progress_percent"
    }
}

struct AdvancedSettings: Codable {
    let inflationRate: Double
    let forecastGrowthRate: Double
    
    enum CodingKeys: String, CodingKey {
        case inflationRate = "inflation_rate"
        case forecastGrowthRate = "forecast_growth_rate"
    }
}

// MARK: - Calibration Data Models

struct CalibrationData: Codable {
    let gap: Double
    let gapExists: Bool
    let requiredMonthlySavings: Double
    let currentMonthlySavings: Double
    let scenarios: Scenarios
    
    enum CodingKeys: String, CodingKey {
        case gap
        case gapExists = "gap_exists"
        case requiredMonthlySavings = "required_monthly_savings"
        case currentMonthlySavings = "current_monthly_savings"
        case scenarios
    }
}

struct Scenarios: Codable {
    let strictFire: PlanScenario
    let balanced: PlanScenario
    let lifestyle: PlanScenario
    
    enum CodingKeys: String, CodingKey {
        case strictFire = "strict_fire"
        case balanced
        case lifestyle
    }
}

struct PlanScenario: Codable {
    let retireYear: Int
    let totalBudget: Double
    let wantsCut: Double
    let feasible: Bool
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case retireYear = "retire_year"
        case totalBudget = "total_budget"
        case wantsCut = "wants_cut"
        case feasible
        case reason
    }
}

// MARK: - Cashflow Data Models

struct CashflowData: Codable {
    let month: String
    let savingsTarget: SavingsTarget
    let income: Income
    let spending: Spending
    let toReview: ToReview
    
    enum CodingKeys: String, CodingKey {
        case month
        case savingsTarget = "savings_target"
        case income
        case spending
        case toReview = "to_review"
    }
}

struct SavingsTarget: Codable {
    let current: Double
    let goal: Double
    let percent: Int
}

struct Income: Codable {
    let total: Double
    let active: Double
    let passive: Double
    let sources: [IncomeSource]
}

struct IncomeSource: Codable {
    let id: String
    let name: String
    let amount: Double
    let type: String  // "active" or "passive"
}

struct Spending: Codable {
    let total: Double
    let needs: Double
    let wants: Double
    let budgetLimit: Double
    
    enum CodingKeys: String, CodingKey {
        case total, needs, wants
        case budgetLimit = "budget_limit"
    }
}

struct ToReview: Codable {
    let count: Int
    let transactions: [Transaction]
}

struct Transaction: Codable {
    let id: String
    let merchant: String
    let amount: Double
    let date: String
    let pendingClassification: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, merchant, amount, date
        case pendingClassification = "pending_classification"
    }
}

// MARK: - Investment Data Models

struct InvestmentData: Codable {
    let portfolio: Portfolio
    let accounts: [Account]
    let allocation: Allocation
}

struct Portfolio: Codable {
    let totalBalance: Double
    let performance: Performance
    let chartData: [ChartPoint]
    
    enum CodingKeys: String, CodingKey {
        case totalBalance = "total_balance"
        case performance
        case chartData = "chart_data"
    }
}

struct Performance: Codable {
    let oneDay: Double
    let oneWeek: Double
    let oneMonth: Double
    let oneYear: Double
    
    enum CodingKeys: String, CodingKey {
        case oneDay = "1d"
        case oneWeek = "1w"
        case oneMonth = "1m"
        case oneYear = "1y"
    }
}

struct ChartPoint: Codable {
    let date: String
    let value: Double
}

struct Account: Codable {
    let id: String
    let institution: String
    let type: String
    let balance: Double
    let connected: Bool
}

struct Allocation: Codable {
    let stocks: AssetClass
    let bonds: AssetClass
    let cash: AssetClass
}

struct AssetClass: Codable {
    let percent: Int
    let amount: Double
}

// MARK: - Mock Data Instance

struct MockData {
    
    // MARK: Journey Mock Data
    static let journeyData = JourneyData(
        netWorth: NetWorth(
            total: 342850.45,
            growthAmount: 8240.00,
            growthPercent: 2.4
        ),
        budget: Budget(
            spent: 2050.00,
            limit: 4000.00,
            percent: 51,
            period: "Nov 2023",
            daysLeft: 12
        ),
        passiveIncome: PassiveIncome(
            projected: 1250.00,
            target: 3000.00,
            percent: 42
        ),
        savingsRate: SavingsRate(
            current: 0.20,
            target: 0.40,
            months: [
                MonthStatus(month: "Aug", status: "success"),
                MonthStatus(month: "Sep", status: "success"),
                MonthStatus(month: "Oct", status: "failed"),
                MonthStatus(month: "Nov", status: "pending")
            ]
        ),
        fireProgress: FireProgress(
            percent: 25,
            targetAge: 45,
            currentAge: 35
        )
    )
    
    // MARK: Simulator Mock Data
    static let simulatorData = SimulatorData(
        currentProfile: CurrentProfile(
            age: 35,
            monthlyIncome: 6000.00,
            monthlyContribution: 1000.00,
            expectedBudget: 5000.00,
            currentInvestment: 59299.00
        ),
        fireCalculation: FireCalculation(
            targetAmount: 2000000.00,
            currentNetWorth: 500000.00,
            idealMonthlySpending: 8000.00,
            fireAge: 45,
            fireDate: "2035-06-15",
            progressPercent: 25
        ),
        advancedSettings: AdvancedSettings(
            inflationRate: 0.02,
            forecastGrowthRate: 0.07
        )
    )
    
    // MARK: Calibration Mock Data
    static let calibrationData = CalibrationData(
        gap: 1500.00,
        gapExists: true,
        requiredMonthlySavings: 3000.00,
        currentMonthlySavings: 1500.00,
        scenarios: Scenarios(
            strictFire: PlanScenario(
                retireYear: 2035,
                totalBudget: 3500.00,
                wantsCut: 1500.00,
                feasible: true,
                reason: nil
            ),
            balanced: PlanScenario(
                retireYear: 2038,
                totalBudget: 4250.00,
                wantsCut: 750.00,
                feasible: true,
                reason: nil
            ),
            lifestyle: PlanScenario(
                retireYear: 2042,
                totalBudget: 5000.00,
                wantsCut: 0,
                feasible: true,
                reason: nil
            )
        )
    )
    
    // MARK: Cashflow Mock Data
    static let cashflowData = CashflowData(
        month: "2024-02",
        savingsTarget: SavingsTarget(
            current: 4250.00,
            goal: 5000.00,
            percent: 85
        ),
        income: Income(
            total: 8427.64,
            active: 6159.72,
            passive: 2267.92,
            sources: [
                IncomeSource(id: "1", name: "Business", amount: 3317.74, type: "active"),
                IncomeSource(id: "2", name: "Salary", amount: 2841.98, type: "active"),
                IncomeSource(id: "3", name: "Investment", amount: 2267.92, type: "passive")
            ]
        ),
        spending: Spending(
            total: 2050.00,
            needs: 1500.00,
            wants: 550.00,
            budgetLimit: 4000.00
        ),
        toReview: ToReview(
            count: 6,
            transactions: [
                Transaction(id: "1", merchant: "Starbucks", amount: 5.50, date: "2024-02-01", pendingClassification: true),
                Transaction(id: "2", merchant: "Whole Foods", amount: 87.32, date: "2024-02-01", pendingClassification: true),
                Transaction(id: "3", merchant: "Shell Gas Station", amount: 45.00, date: "2024-02-02", pendingClassification: true)
            ]
        )
    )
    
    // MARK: Investment Mock Data
    static let investmentData = InvestmentData(
        portfolio: Portfolio(
            totalBalance: 125450.80,
            performance: Performance(
                oneDay: 0.5,
                oneWeek: 2.1,
                oneMonth: 4.3,
                oneYear: 15.7
            ),
            chartData: [
                ChartPoint(date: "2024-01-01", value: 120000.00),
                ChartPoint(date: "2024-01-15", value: 122000.00),
                ChartPoint(date: "2024-02-01", value: 125450.80)
            ]
        ),
        accounts: [
            Account(id: "1", institution: "Fidelity", type: "Investment", balance: 85000.00, connected: true),
            Account(id: "2", institution: "Schwab", type: "Brokerage", balance: 25000.00, connected: true),
            Account(id: "3", institution: "Coinbase", type: "Crypto", balance: 15450.80, connected: true)
        ],
        allocation: Allocation(
            stocks: AssetClass(percent: 80, amount: 100360.64),
            bonds: AssetClass(percent: 15, amount: 18817.62),
            cash: AssetClass(percent: 5, amount: 6272.54)
        )
    )
}
