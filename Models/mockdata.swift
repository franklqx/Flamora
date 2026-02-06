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

// MARK: - Income Detail Models

struct IncomeDetailSource: Identifiable {
    let id: String
    let name: String
    let account: String
    let amount: Double
    let percentage: Double
}

struct IncomeMonthData {
    let total: Double
    let sources: [IncomeDetailSource]
}

struct IncomeDetailData {
    let title: String          // "Active Income" or "Passive Income"
    let accentColor: String    // hex color
    let annualTrend: [Double?] // 12 months of data (nil = no data)
    let monthlyData: [Int: IncomeMonthData] // month index (0-11) -> sources for that month
}

struct TotalIncomeMonthData {
    let total: Double
    let activeAmount: Double
    let passiveAmount: Double
    let activePercentage: Double
    let passivePercentage: Double
}

struct TotalIncomeDetailData {
    let title: String          // "Total Income"
    let annualTrend: [Double?] // 12 months of combined data
    let monthlyData: [Int: TotalIncomeMonthData]
}

// MARK: - Spending Detail Models

struct SpendingDetailCategory: Identifiable {
    let id: String
    let icon: String
    let name: String
    let amount: Double
    let percentage: Double
}

struct SpendingDetailMonthData {
    let total: Double
    let categories: [SpendingDetailCategory]
}

struct SpendingDetailData {
    let title: String          // "Spending Analysis (Needs/Wants)"
    let accentColor: String    // hex color
    let annualTrend: [Double?] // 12 months spending totals
    let monthlyData: [Int: SpendingDetailMonthData]
}

struct TotalSpendingMonthData {
    let total: Double
    let needsAmount: Double
    let wantsAmount: Double
    let needsPercentage: Double
    let wantsPercentage: Double
}

struct TotalSpendingDetailData {
    let title: String          // "Spending Analysis"
    let annualTrend: [Double?] // 12 months total spending
    let monthlyData: [Int: TotalSpendingMonthData]
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
// MARK: - 🔥 Backend API Models (Phase 0 - 后端数据契约)

/// 对应后端 GET /active-fire-goal
struct APIFireGoal: Codable {
    let goalId: String
    let fireNumber: Double
    let currentNetWorth: Double
    let gapToFire: Double
    let requiredSavingsRate: Double
    let targetRetirementAge: Int
    let currentAge: Int
    let yearsRemaining: Int
    let progressPercentage: Double
    let onTrack: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case fireNumber = "fire_number"
        case currentNetWorth = "current_net_worth"
        case gapToFire = "gap_to_fire"
        case requiredSavingsRate = "required_savings_rate"
        case targetRetirementAge = "target_retirement_age"
        case currentAge = "current_age"
        case yearsRemaining = "years_remaining"
        case progressPercentage = "progress_percentage"
        case onTrack = "on_track"
        case createdAt = "created_at"
    }
}

/// 对应后端 GET /monthly-budget
struct APIMonthlyBudget: Codable {
    let budgetId: String
    let month: String
    let needsBudget: Double
    let wantsBudget: Double
    let savingsBudget: Double
    let needsSpent: Double
    let wantsSpent: Double
    let savingsActual: Double
    let needsRatio: Double
    let wantsRatio: Double
    let savingsRatio: Double
    let isCustom: Bool

    enum CodingKeys: String, CodingKey {
        case budgetId = "budget_id"
        case month
        case needsBudget = "needs_budget"
        case wantsBudget = "wants_budget"
        case savingsBudget = "savings_budget"
        case needsSpent = "needs_spent"
        case wantsSpent = "wants_spent"
        case savingsActual = "savings_actual"
        case needsRatio = "needs_ratio"
        case wantsRatio = "wants_ratio"
        case savingsRatio = "savings_ratio"
        case isCustom = "is_custom"
    }
}

/// 对应后端 GET /user-profile
struct APIUserProfile: Codable {
    let profileId: String
    let userId: String
    let monthlyIncome: Double
    let currentNetWorth: Double
    let currentMonthlyExpenses: Double
    let currencyCode: String
    let timezone: String
    let onboardingCompleted: Bool
    let onboardingStep: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case userId = "user_id"
        case monthlyIncome = "monthly_income"
        case currentNetWorth = "current_net_worth"
        case currentMonthlyExpenses = "current_monthly_expenses"
        case currencyCode = "currency_code"
        case timezone
        case onboardingCompleted = "onboarding_completed"
        case onboardingStep = "onboarding_step"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 对应后端 GET /net-worth-summary
struct APINetWorthSummary: Codable {
    let totalNetWorth: Double
    let previousNetWorth: Double
    let growthAmount: Double
    let growthPercentage: Double
    let asOfDate: String
    let breakdown: NetWorthBreakdown
    let accounts: [APIAccount]

    enum CodingKeys: String, CodingKey {
        case totalNetWorth = "total_net_worth"
        case previousNetWorth = "previous_net_worth"
        case growthAmount = "growth_amount"
        case growthPercentage = "growth_percentage"
        case asOfDate = "as_of_date"
        case breakdown
        case accounts
    }

    struct NetWorthBreakdown: Codable {
        let assets: Double
        let liabilities: Double
    }
}

struct APIAccount: Codable {
    let accountId: String
    let name: String
    let type: String
    let balance: Double
    let institution: String

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name, type, balance, institution
    }
}

// MARK: - 🔥 Backend API Mock Data

extension MockData {

    /// 用户显示名称 (后端暂未提供name字段，临时mock)
    static let displayName = "Enxi Lin"

    // MARK: - Income Detail Mock Data

    static let activeIncomeDetail: IncomeDetailData = {
        let salaryBase = 5800.0
        let consultBase = 200.0
        let trend: [Double?] = [6250, 3800, 4200, 3600, 4800, 3200, 4500, 5200, 5600, 5800, 6100, 6400]
        var monthly: [Int: IncomeMonthData] = [:]
        for i in 0..<12 {
            if let total = trend[i] {
                let salaryAmount = total * 0.96
                let consultAmount = total * 0.04
                monthly[i] = IncomeMonthData(
                    total: total,
                    sources: [
                        IncomeDetailSource(id: "active-1-\(i)", name: "Tech Corp Salary", account: "Main Account", amount: salaryAmount, percentage: 96),
                        IncomeDetailSource(id: "active-2-\(i)", name: "Consulting", account: "Business Account", amount: consultAmount, percentage: 4)
                    ]
                )
            }
        }
        return IncomeDetailData(
            title: "Active Income",
            accentColor: "#93C5FD",
            annualTrend: trend,
            monthlyData: monthly
        )
    }()

    static let passiveIncomeDetail: IncomeDetailData = {
        let trend: [Double?] = [1250, 2400, 2800, 3100, 3500, 2900, 4200, 4800, 5100, 5400, 5800, 6200]
        var monthly: [Int: IncomeMonthData] = [:]
        for i in 0..<12 {
            if let total = trend[i] {
                let dividendAmount = total * 0.68
                let realEstateAmount = total * 0.32
                monthly[i] = IncomeMonthData(
                    total: total,
                    sources: [
                        IncomeDetailSource(id: "passive-1-\(i)", name: "Dividends & Interest", account: "Chase Savings", amount: dividendAmount, percentage: 68),
                        IncomeDetailSource(id: "passive-2-\(i)", name: "Real Estate", account: "Main Account", amount: realEstateAmount, percentage: 32)
                    ]
                )
            }
        }
        return IncomeDetailData(
            title: "Passive Income",
            accentColor: "#A78BFA",
            annualTrend: trend,
            monthlyData: monthly
        )
    }()

    // MARK: - Total Income Detail Mock Data

    static let totalIncomeDetail: TotalIncomeDetailData = {
        let activeTrend: [Double?] = activeIncomeDetail.annualTrend
        let passiveTrend: [Double?] = passiveIncomeDetail.annualTrend
        var combinedTrend: [Double?] = []
        var monthly: [Int: TotalIncomeMonthData] = [:]
        for i in 0..<12 {
            let activeVal = activeTrend[i]
            let passiveVal = passiveTrend[i]
            if let a = activeVal, let p = passiveVal {
                let total = a + p
                let activePct = (a / total) * 100.0
                let passivePct = (p / total) * 100.0
                combinedTrend.append(total)
                monthly[i] = TotalIncomeMonthData(
                    total: total,
                    activeAmount: a,
                    passiveAmount: p,
                    activePercentage: activePct,
                    passivePercentage: passivePct
                )
            } else {
                combinedTrend.append(nil)
            }
        }
        return TotalIncomeDetailData(
            title: "Total Income",
            annualTrend: combinedTrend,
            monthlyData: monthly
        )
    }()

    // MARK: - Spending Detail Mock Data

    static let needsSpendingDetail: SpendingDetailData = {
        let trend: [Double?] = [3000, 3250, 3090, 3440, 3180, 3590, 3360, 3040, 3220, 3470, 3810, 3350]
        let baseCategories: [(name: String, icon: String, amount: Double)] = [
            ("Rent & Housing", "house.fill", 1850.00),
            ("Groceries", "cart.fill", 642.50),
            ("Utilities", "bolt.fill", 310.20),
            ("Transportation", "car.fill", 215.00),
            ("Health & Fitness", "cross.case.fill", 120.00)
        ]

        return SpendingDetailData(
            title: "Spending Analysis (Needs)",
            accentColor: "#A78BFA",
            annualTrend: trend,
            monthlyData: buildSpendingMonthlyData(
                prefix: "needs",
                trend: trend,
                baseCategories: baseCategories
            )
        )
    }()

    static let wantsSpendingDetail: SpendingDetailData = {
        let trend: [Double?] = [1240, 1420, 1290, 1640, 1360, 1760, 1480, 1290, 1420, 1560, 1850, 1570]
        let baseCategories: [(name: String, icon: String, amount: Double)] = [
            ("Dining & Social", "fork.knife", 420.00),
            ("Shopping", "bag.fill", 325.50),
            ("Subscriptions", "tv.fill", 155.00),
            ("Travel", "airplane", 210.00),
            ("Hobbies & Leisure", "paintpalette.fill", 129.50)
        ]

        return SpendingDetailData(
            title: "Spending Analysis (Wants)",
            accentColor: "#93C5FD",
            annualTrend: trend,
            monthlyData: buildSpendingMonthlyData(
                prefix: "wants",
                trend: trend,
                baseCategories: baseCategories
            )
        )
    }()

    static let totalSpendingDetail: TotalSpendingDetailData = {
        let needsTrend = needsSpendingDetail.annualTrend
        let wantsTrend = wantsSpendingDetail.annualTrend
        var totalTrend: [Double?] = []
        var monthly: [Int: TotalSpendingMonthData] = [:]

        for index in 0..<12 {
            let needsAmount = needsTrend[index]
            let wantsAmount = wantsTrend[index]
            if let needs = needsAmount, let wants = wantsAmount {
                let total = needs + wants
                let needsPct = total > 0 ? (needs / total) * 100.0 : 0
                let wantsPct = total > 0 ? (wants / total) * 100.0 : 0
                totalTrend.append(total)
                monthly[index] = TotalSpendingMonthData(
                    total: total,
                    needsAmount: needs,
                    wantsAmount: wants,
                    needsPercentage: needsPct,
                    wantsPercentage: wantsPct
                )
            } else {
                totalTrend.append(nil)
            }
        }

        return TotalSpendingDetailData(
            title: "Spending Analysis",
            annualTrend: totalTrend,
            monthlyData: monthly
        )
    }()

    private static func buildSpendingMonthlyData(
        prefix: String,
        trend: [Double?],
        baseCategories: [(name: String, icon: String, amount: Double)]
    ) -> [Int: SpendingDetailMonthData] {
        let baseTotal = max(baseCategories.reduce(0) { $0 + $1.amount }, 1)
        var monthly: [Int: SpendingDetailMonthData] = [:]

        for index in 0..<12 {
            guard let total = trend[index] else { continue }
            let scale = total / baseTotal

            let categories = baseCategories.enumerated().map { item -> SpendingDetailCategory in
                let (offset, value) = item
                let scaledAmount = rounded2(value.amount * scale)
                let percentage = total > 0 ? (scaledAmount / total) * 100 : 0
                return SpendingDetailCategory(
                    id: "\(prefix)-\(offset)-\(index)",
                    icon: value.icon,
                    name: value.name,
                    amount: scaledAmount,
                    percentage: percentage
                )
            }
            .sorted { $0.amount > $1.amount }

            monthly[index] = SpendingDetailMonthData(total: total, categories: categories)
        }

        return monthly
    }

    private static func rounded2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// 模拟后端 /active-fire-goal 返回
    static let apiFireGoal = APIFireGoal(
        goalId: "a6d9e6d5-46ef-48d8-a85a-45beb992506f",
        fireNumber: 900000.00,
        currentNetWorth: 200000.00,
        gapToFire: 700000.00,
        requiredSavingsRate: 11.88,
        targetRetirementAge: 50,
        currentAge: 30,
        yearsRemaining: 20,
        progressPercentage: 22.22,
        onTrack: true,
        createdAt: "2026-02-05T13:25:44Z"
    )

    /// 模拟后端 /monthly-budget 返回
    static let apiMonthlyBudget = APIMonthlyBudget(
        budgetId: "b8410610-d803-471d-929c-89fcbabb920c",
        month: "2026-02-01",
        needsBudget: 5000.00,
        wantsBudget: 3000.00,
        savingsBudget: 2000.00,
        needsSpent: 2450.30,
        wantsSpent: 1820.50,
        savingsActual: 2100.00,
        needsRatio: 50.00,
        wantsRatio: 30.00,
        savingsRatio: 20.00,
        isCustom: false
    )

    /// 模拟后端 /user-profile 返回
    static let apiUserProfile = APIUserProfile(
        profileId: "mock-profile-id",
        userId: "00000000-0000-0000-0000-000000000001",
        monthlyIncome: 10000.00,
        currentNetWorth: 200000.00,
        currentMonthlyExpenses: 5000.00,
        currencyCode: "USD",
        timezone: "America/New_York",
        onboardingCompleted: true,
        onboardingStep: 5,
        createdAt: "2026-02-01T10:00:00Z",
        updatedAt: "2026-02-05T13:25:44Z"
    )

    /// 模拟后端 /net-worth-summary 返回
    static let apiNetWorthSummary = APINetWorthSummary(
        totalNetWorth: 208240.00,
        previousNetWorth: 200000.00,
        growthAmount: 8240.00,
        growthPercentage: 4.12,
        asOfDate: "2026-02-05",
        breakdown: APINetWorthSummary.NetWorthBreakdown(
            assets: 250000.00,
            liabilities: 41760.00
        ),
        accounts: [
            APIAccount(
                accountId: "mock-account-1",
                name: "Fidelity 401(k)",
                type: "investment",
                balance: 150000.00,
                institution: "Fidelity"
            ),
            APIAccount(
                accountId: "mock-account-2",
                name: "Chase Checking",
                type: "cash",
                balance: 25000.00,
                institution: "Chase"
            )
        ]
    )
}
