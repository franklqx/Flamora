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
    let savedThisMonth: Double
    let streakMonths: Int
    let monthlySavings: [Double]
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

struct TransactionCategory: Identifiable {
    let id: String
    let name: String    // e.g. "Rent & Housing"
    let icon: String    // SF Symbol name
    let parent: String  // "needs" | "wants"
}

struct Transaction: Codable, Identifiable {
    let id: String
    let merchant: String
    let amount: Double
    let date: String        // "MM-DD" or "YYYY-MM-DD"
    let time: String?       // "HH:mm" e.g. "09:32"
    var pendingClassification: Bool
    var subcategory: String?   // e.g. "Rent & Housing" — drives category
    var category: String?      // "needs" | "wants" — derived from subcategory, stored for API
    var note: String?
    var accountId: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, merchant, amount, date, time, subcategory, category, note
        case pendingClassification = "pending_classification"
        case accountId = "account_id"
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

struct Allocation: Codable {
    let stocks: AssetClass
    let bonds: AssetClass    // Crypto
    let cash: AssetClass
    let other: AssetClass?   // Other (gold, alts, etc.)
}

struct AssetClass: Codable {
    let percent: Int
    let amount: Double
}

// MARK: - Account Type

enum AccountType: String, Codable, CaseIterable {
    case brokerage = "Brokerage"
    case crypto    = "Crypto"
    case bank      = "Bank"

    var isInvestment: Bool { self == .brokerage || self == .crypto }

    var displayLabel: String {
        switch self {
        case .brokerage: return "Brokerage"
        case .crypto:    return "Crypto"
        case .bank:      return "Bank Account"
        }
    }
}

// MARK: - Holding

struct Holding: Identifiable {
    let id: String
    let accountId: String
    let symbol: String
    let name: String
    let shares: Double
    let totalValue: Double
    var logoUrl: String? = nil
    var accountName: String? = nil
    var accountMask: String? = nil
}

// MARK: - Balance Snapshot（账户趋势图用）

struct BalanceSnapshot: Identifiable {
    let id: String
    let accountId: String
    let date: Date
    let balance: Double
}

struct Account: Codable, Identifiable {
    let id: String
    let institution: String
    let accountType: AccountType
    let balance: Double
    let connected: Bool
    let logoUrl: String?
    /// Account-level name from the brokerage (e.g. "Taxable Brokerage"). nil when source is net-worth-summary.
    var name: String? = nil
    /// Last-4 mask of the account number (e.g. "7892"). nil when source is net-worth-summary.
    var mask: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, institution, balance, connected, logoUrl
        case accountType = "type"
    }
}

struct InvestmentAccountsBreakdownData: Codable {
    let title: String
    let totalAmount: Double
    let positions: [InvestmentAccountPosition]
}

struct InvestmentAccountPosition: Codable, Identifiable {
    let id: String
    let symbol: String
    let institution: String
    let amount: Double
}

// MARK: - Income Detail Models

enum IncomeSourceType: String, CaseIterable {
    case active
    case passive

    var displayName: String {
        rawValue.capitalized
    }
}

struct IncomeDetailSource: Identifiable {
    let id: String
    var name: String
    let account: String
    let amount: Double
    let percentage: Double
    let colorHex: String
    var type: IncomeSourceType
}

struct IncomeMonthData {
    let total: Double
    let sources: [IncomeDetailSource]
}

struct IncomeDetailData {
    let title: String
    let accentColor: String
    let trendsByYear: [Int: [Double?]]              // year -> 12 months
    let monthlyDataByYear: [Int: [Int: IncomeMonthData]] // year -> (month -> data)
    var availableYears: [Int] { trendsByYear.keys.sorted() }
}

struct TotalIncomeMonthData {
    let total: Double
    let activeAmount: Double
    let passiveAmount: Double
    let activePercentage: Double
    let passivePercentage: Double
}

struct TotalIncomeDetailData {
    let title: String
    let trendsByYear: [Int: [Double?]]
    let monthlyDataByYear: [Int: [Int: TotalIncomeMonthData]]
    var availableYears: [Int] { trendsByYear.keys.sorted() }
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
    let title: String
    let accentColor: String
    let trendsByYear: [Int: [Double?]]
    let monthlyDataByYear: [Int: [Int: SpendingDetailMonthData]]
    var availableYears: [Int] { trendsByYear.keys.sorted() }
}

struct TotalSpendingMonthData {
    let total: Double
    let needsAmount: Double
    let wantsAmount: Double
    let needsPercentage: Double
    let wantsPercentage: Double
}

struct TotalSpendingDetailData {
    let title: String
    let trendsByYear: [Int: [Double?]]
    let monthlyDataByYear: [Int: [Int: TotalSpendingMonthData]]
    var availableYears: [Int] { trendsByYear.keys.sorted() }
}

// MARK: - Mock Data Instance

struct MockData {
    
    // MARK: Journey Mock Data
    static let journeyData = JourneyData(
        netWorth: NetWorth(
            total: 208240.00,
            growthAmount: 8240.00,
            growthPercent: 4.12
        ),
        budget: Budget(
            spent: 4380.00,
            limit: 6000.00,
            percent: 73,
            period: "Mar 2026",
            daysLeft: 7
        ),
        passiveIncome: PassiveIncome(
            projected: 2268.00,
            target: 5000.00,
            percent: 45
        ),
        savingsRate: SavingsRate(
            current: 0.26,
            target: 0.40,
            months: [
                MonthStatus(month: "Dec", status: "success"),
                MonthStatus(month: "Jan", status: "success"),
                MonthStatus(month: "Feb", status: "success"),
                MonthStatus(month: "Mar", status: "pending")
            ],
            savedThisMonth: 2200.00,
            streakMonths: 3,
            monthlySavings: [1950, 2050, 1800, 2100, 2050, 2200]
        ),
        fireProgress: FireProgress(
            percent: 22,
            targetAge: 50,
            currentAge: 30
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
        month: "2026-03",
        savingsTarget: SavingsTarget(
            current: 2200.00,
            goal: 2000.00,
            percent: 110
        ),
        income: Income(
            total: 8428.00,
            active: 6160.00,
            passive: 2268.00,
            sources: [
                IncomeSource(id: "1", name: "Tech Corp Salary", amount: 5913.60, type: "active"),
                IncomeSource(id: "2", name: "Consulting",       amount:  246.40, type: "active"),
                IncomeSource(id: "3", name: "Dividends & Interest", amount: 1542.24, type: "passive"),
                IncomeSource(id: "4", name: "Real Estate",      amount:  725.76, type: "passive")
            ]
        ),
        spending: Spending(
            total: 4380.00,
            needs: 3090.00,
            wants: 1290.00,
            budgetLimit: 6000.00
        ),
        toReview: ToReview(
            count: 2,
            transactions: [
                Transaction(id: "1", merchant: "Target",    amount: 54.20, date: "2026-03-18", time: "14:33", pendingClassification: true, subcategory: nil, category: nil, note: nil),
                Transaction(id: "2", merchant: "Uber Eats", amount: 32.50, date: "2026-03-20", time: "20:07", pendingClassification: true, subcategory: nil, category: nil, note: nil)
            ]
        )
    )
    
    // MARK: Yearly Income Mock (Jan 1 – today YTD; swap with API after bank link)
    // NOTE: These are placeholder values. Real data will come from the backend
    //       once the user links their bank account via Plaid.
    // YTD Jan–Mar 2026: Jan(5800+1950) + Feb(6000+2100) + Mar(6160+2268)
    static let yearlyIncome = Income(
        total: 24_278.00,
        active: 17_960.00,
        passive:  6_318.00,
        sources: [
            IncomeSource(id: "y1", name: "Tech Corp Salary",      amount: 17_228.16, type: "active"),
            IncomeSource(id: "y2", name: "Consulting",            amount:    731.84, type: "active"),
            IncomeSource(id: "y3", name: "Dividends & Interest",  amount:  4_296.24, type: "passive"),
            IncomeSource(id: "y4", name: "Real Estate",           amount:  2_021.76, type: "passive")
        ]
    )

    /// 与 `TransactionCategoryCatalog.all` 同步；保留别名供旧代码引用。
    static let transactionCategories: [TransactionCategory] = TransactionCategoryCatalog.all

    static func categoryParent(for subcategory: String) -> String? {
        TransactionCategoryCatalog.parent(for: subcategory)
    }

    // MARK: All Transactions Mock Data
    static let allTransactions: [Transaction] = [
        Transaction(id: "t1",  merchant: "Rent",              amount: 1850.00, date: "2026-03-01", time: "09:00", pendingClassification: false, subcategory: "Rent & Housing",   category: "needs", note: "Monthly rent",  accountId: "4"),
        Transaction(id: "t2",  merchant: "Whole Foods",       amount:   92.40, date: "2026-03-03", time: "11:24", pendingClassification: false, subcategory: "Groceries",        category: "needs", note: nil,            accountId: "5"),
        Transaction(id: "t3",  merchant: "Con Edison",        amount:   98.50, date: "2026-03-04", time: "08:00", pendingClassification: false, subcategory: "Utilities",        category: "needs", note: nil,            accountId: "4"),
        Transaction(id: "t4",  merchant: "Netflix",           amount:   15.99, date: "2026-03-07", time: "00:01", pendingClassification: false, subcategory: "Subscriptions",    category: "wants", note: nil,            accountId: "4"),
        Transaction(id: "t5",  merchant: "Shell Gas Station", amount:   48.00, date: "2026-03-10", time: "17:48", pendingClassification: false, subcategory: "Transportation",   category: "needs", note: nil,            accountId: "5"),
        Transaction(id: "t6",  merchant: "Starbucks",         amount:    6.75, date: "2026-03-12", time: "08:15", pendingClassification: false, subcategory: "Dining & Social",  category: "wants", note: nil,            accountId: "4"),
        Transaction(id: "t7",  merchant: "Apple Music",       amount:   10.99, date: "2026-03-14", time: "00:01", pendingClassification: false, subcategory: "Subscriptions",    category: "wants", note: nil,            accountId: "4"),
        Transaction(id: "t8",  merchant: "CVS Pharmacy",      amount:   34.20, date: "2026-03-15", time: "13:05", pendingClassification: false, subcategory: "Health & Fitness", category: "needs", note: nil,            accountId: "5"),
        Transaction(id: "t9",  merchant: "Trader Joe's",      amount:   76.80, date: "2026-03-17", time: "10:30", pendingClassification: false, subcategory: "Groceries",        category: "needs", note: nil,            accountId: "5"),
        Transaction(id: "t10", merchant: "Target",            amount:   54.20, date: "2026-03-18", time: "14:33", pendingClassification: true,  subcategory: nil,                category: nil,     note: nil,            accountId: "4"),
        Transaction(id: "t11", merchant: "Uber Eats",         amount:   32.50, date: "2026-03-20", time: "20:07", pendingClassification: true,  subcategory: nil,                category: nil,     note: nil,            accountId: "4"),
        Transaction(id: "t12", merchant: "Equinox",           amount:   85.00, date: "2026-03-22", time: "07:00", pendingClassification: false, subcategory: "Health & Fitness", category: "needs", note: nil,            accountId: "5")
    ]

    // MARK: Holdings Mock Data
    static let holdings: [Holding] = [
        // Fidelity (id: "1")
        Holding(id: "h1", accountId: "1", symbol: "VTI",  name: "Vanguard Total Stock Market ETF", shares: 180.0, totalValue: 42500.00, logoUrl: "https://www.google.com/s2/favicons?domain=vanguard.com&sz=64"),
        Holding(id: "h2", accountId: "1", symbol: "AAPL", name: "Apple Inc.",                       shares: 120.0, totalValue: 24800.00, logoUrl: "https://www.google.com/s2/favicons?domain=apple.com&sz=64"),
        Holding(id: "h3", accountId: "1", symbol: "MSFT", name: "Microsoft Corporation",             shares: 55.0,  totalValue: 17700.00, logoUrl: "https://www.google.com/s2/favicons?domain=microsoft.com&sz=64"),
        // Schwab (id: "2")
        Holding(id: "h4", accountId: "2", symbol: "VOO",  name: "Vanguard S&P 500 ETF",             shares: 60.0,  totalValue: 16500.00, logoUrl: "https://www.google.com/s2/favicons?domain=vanguard.com&sz=64"),
        Holding(id: "h5", accountId: "2", symbol: "QQQ",  name: "Invesco QQQ Trust",                shares: 25.0,  totalValue: 8500.00,  logoUrl: "https://www.google.com/s2/favicons?domain=invesco.com&sz=64"),
        // Coinbase (id: "3")
        Holding(id: "h6", accountId: "3", symbol: "BTC",  name: "Bitcoin",                          shares: 0.12,  totalValue: 10200.00, logoUrl: "https://assets.coincap.io/assets/icons/btc@2x.png"),
        Holding(id: "h7", accountId: "3", symbol: "ETH",  name: "Ethereum",                         shares: 2.5,   totalValue: 5250.80,  logoUrl: "https://assets.coincap.io/assets/icons/eth@2x.png"),
        // Other — Gold
        Holding(id: "h8", accountId: "other", symbol: "GLD",  name: "SPDR Gold Shares ETF",         shares: 52.0,  totalValue: 11480.00, logoUrl: nil),
        Holding(id: "h9", accountId: "other", symbol: "IAU",  name: "iShares Gold Trust",            shares: 148.0, totalValue: 7337.62,  logoUrl: nil),
    ]

    // MARK: Account Balance History Mock Data
    static let accountBalanceHistory: [String: [BalanceSnapshot]] = makeAccountBalanceHistory()

    private static func makeAccountBalanceHistory() -> [String: [BalanceSnapshot]] {
        func make(_ id: String, _ data: [(Int, Double)]) -> [BalanceSnapshot] {
            let cal = Calendar.current
            let now = Date()
            return data.enumerated().map { i, tuple in
                let date = cal.date(byAdding: .weekOfYear, value: -tuple.0, to: now) ?? now
                return BalanceSnapshot(id: "\(id)_\(i)", accountId: id, date: date, balance: tuple.1)
            }.sorted { $0.date < $1.date }
        }
        return [
            "1": make("1", [(52,72000),(44,74500),(36,76800),(28,75200),(20,78000),(12,80500),(8,82000),(4,84000),(2,85000),(0,85000)]),
            "2": make("2", [(52,20000),(44,20800),(36,21500),(28,22000),(20,22800),(12,23500),(8,24200),(4,24800),(2,25000),(0,25000)]),
            "3": make("3", [(52,9000),(44,10200),(36,11500),(28,10800),(20,12000),(12,13500),(8,14000),(4,15000),(2,15300),(0,15450)]),
            "4": make("4", [(52,10800),(48,9200),(44,11600),(40,9500),(36,12100),(32,10200),(28,12400),(24,10800),(20,12500),(16,11000),(12,12800),(8,11500),(4,12600),(2,12300),(0,12500)]),
            "5": make("5", [(52,7000),(44,7400),(36,7100),(28,7800),(20,8100),(12,7900),(8,8200),(4,8300),(2,8150),(0,8200)])
        ]
    }

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
                ChartPoint(date: "2025-04-01", value: 98500.00),
                ChartPoint(date: "2025-07-01", value: 105200.00),
                ChartPoint(date: "2025-10-01", value: 112800.00),
                ChartPoint(date: "2026-01-01", value: 119300.00),
                ChartPoint(date: "2026-02-01", value: 122600.00),
                ChartPoint(date: "2026-03-24", value: 125450.80)
            ]
        ),
        accounts: [
            Account(id: "1", institution: "Fidelity",  accountType: .brokerage, balance: 85000.00,  connected: true, logoUrl: "https://www.google.com/s2/favicons?domain=fidelity.com&sz=64"),
            Account(id: "2", institution: "Schwab",    accountType: .brokerage, balance: 25000.00,  connected: true, logoUrl: "https://www.google.com/s2/favicons?domain=schwab.com&sz=64"),
            Account(id: "3", institution: "Coinbase",  accountType: .crypto,    balance: 15450.80,  connected: true, logoUrl: "https://www.google.com/s2/favicons?domain=coinbase.com&sz=64")
        ],
        allocation: Allocation(
            stocks: AssetClass(percent: 68, amount: 85306.54),
            bonds: AssetClass(percent: 12, amount: 15054.10),  // Crypto
            cash: AssetClass(percent: 5, amount: 6272.54),
            other: AssetClass(percent: 15, amount: 18817.62)
        )
    )

    static let bankAccounts: [Account] = [
        Account(id: "4", institution: "Chase",           accountType: .bank, balance: 12500.00, connected: true, logoUrl: "https://www.google.com/s2/favicons?domain=chase.com&sz=64"),
        Account(id: "5", institution: "Bank of America", accountType: .bank, balance: 8200.00,  connected: true, logoUrl: "https://www.google.com/s2/favicons?domain=bankofamerica.com&sz=64")
    ]

    static var allAccounts: [Account] {
        investmentData.accounts + bankAccounts
    }

    static let accountLastUpdated: [String: Date] = {
        let now = Date()
        return [
            "1": now.addingTimeInterval(-5 * 60),         // 5 min ago
            "2": now.addingTimeInterval(-12 * 60),        // 12 min ago
            "3": now.addingTimeInterval(-2 * 60),         // 2 min ago
            "4": now.addingTimeInterval(-60 * 60),        // 1 hour ago
            "5": now.addingTimeInterval(-3 * 60 * 60)     // 3 hours ago
        ]
    }()

    static let investmentAccountsBreakdown = InvestmentAccountsBreakdownData(
        title: "Stocks breakdown",
        totalAmount: 81543.00,
        positions: [
            InvestmentAccountPosition(id: "position-1", symbol: "VTI", institution: "Fidelity", amount: 45200.00),
            InvestmentAccountPosition(id: "position-2", symbol: "VOO", institution: "Schwab", amount: 20150.00),
            InvestmentAccountPosition(id: "position-3", symbol: "BTC", institution: "Coinbase", amount: 12500.00),
            InvestmentAccountPosition(id: "position-4", symbol: "AAPL", institution: "Robinhood", amount: 3693.00)
        ]
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
    let needsSpent: Double?
    let wantsSpent: Double?
    let savingsActual: Double?
    let needsRatio: Double
    let wantsRatio: Double
    let savingsRatio: Double
    let selectedPlan: String?
    let isCustom: Bool

    static let empty = APIMonthlyBudget(
        budgetId: "",
        month: "",
        needsBudget: 0,
        wantsBudget: 0,
        savingsBudget: 0,
        needsSpent: nil,
        wantsSpent: nil,
        savingsActual: nil,
        needsRatio: 0,
        wantsRatio: 0,
        savingsRatio: 0,
        selectedPlan: nil,
        isCustom: false
    )
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
    // No explicit CodingKeys — let .convertFromSnakeCase handle snake_case → camelCase
    let totalNetWorth: Double
    let previousNetWorth: Double?   // null when no Plaid connection
    let growthAmount: Double?       // null when no Plaid connection
    let growthPercentage: Double?   // null when no Plaid connection
    let asOfDate: String
    let breakdown: NetWorthBreakdown
    let accounts: [APIAccount]
    let lastSyncedAt: String?       // ISO 8601 timestamp of last Plaid sync; null if no Plaid

    struct NetWorthBreakdown: Codable {
        // Matches backend: { investment_total, depository_total, credit_total, loan_total }
        let investmentTotal: Double?
        let depositoryTotal: Double?
        let creditTotal: Double?
        let loanTotal: Double?
    }

    static let empty = APINetWorthSummary(
        totalNetWorth: 0,
        previousNetWorth: nil,
        growthAmount: nil,
        growthPercentage: nil,
        asOfDate: "",
        breakdown: NetWorthBreakdown(investmentTotal: nil, depositoryTotal: nil, creditTotal: nil, loanTotal: nil),
        accounts: [],
        lastSyncedAt: nil
    )
}

struct APIAccount: Codable {
    /// `plaid_accounts.id`（UUID）；若 JSON 省略 `id` 则回退解码 `account_id`（Plaid 账户 id）。
    let id: String
    let name: String
    let type: String
    let subtype: String?
    let balance: Double?    // null for some account types
    let mask: String?
    /// `get-net-worth-summary` 在 `plaid_items` 未关联到时可返回 null，必须为可选否则整包解码失败、金额全为 0。
    let institution: String?

    var logoUrl: String? { nil }

    enum CodingKeys: String, CodingKey {
        case id, name, type, subtype, balance, mask, institution
        case accountId = "account_id"
    }

    init(id: String, name: String, type: String, subtype: String?, balance: Double?, mask: String?, institution: String?) {
        self.id = id
        self.name = name
        self.type = type
        self.subtype = subtype
        self.balance = balance
        self.mask = mask
        self.institution = institution
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idOpt = try c.decodeIfPresent(String.self, forKey: .id)
        let accountIdOpt = try c.decodeIfPresent(String.self, forKey: .accountId)
        let resolvedId: String
        if let s = idOpt, !s.isEmpty {
            resolvedId = s
        } else if let s = accountIdOpt, !s.isEmpty {
            resolvedId = s
        } else {
            resolvedId = ""
        }
        id = resolvedId
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "depository"
        subtype = try c.decodeIfPresent(String.self, forKey: .subtype)
        balance = try c.decodeIfPresent(Double.self, forKey: .balance)
        mask = try c.decodeIfPresent(String.self, forKey: .mask)
        institution = try c.decodeIfPresent(String.self, forKey: .institution)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(subtype, forKey: .subtype)
        try c.encodeIfPresent(balance, forKey: .balance)
        try c.encodeIfPresent(mask, forKey: .mask)
        try c.encodeIfPresent(institution, forKey: .institution)
    }
}

// MARK: - 🔥 Backend API Mock Data

extension MockData {

    /// 用户显示名称 (后端暂未提供name字段，临时mock)
    static let displayName = "Enxi Lin"

    // MARK: - Income Detail Mock Data

    static let activeIncomeDetail: IncomeDetailData = {
        let trend2025: [Double?] = [5200, 5300, 5400, 5500, 5600, 5650, 5700, 5750, 5700, 5800, 5850, 5900]
        let trend2026: [Double?] = [5800, 6000, 6160, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        return IncomeDetailData(
            title: "Active Income",
            accentColor: "#34D399",
            trendsByYear: [2025: trend2025, 2026: trend2026],
            monthlyDataByYear: [
                2025: buildActiveMonthly(trend: trend2025, yearTag: "2025"),
                2026: buildActiveMonthly(trend: trend2026, yearTag: "2026")
            ]
        )
    }()

    private static func buildActiveMonthly(trend: [Double?], yearTag: String) -> [Int: IncomeMonthData] {
        var monthly: [Int: IncomeMonthData] = [:]
        for i in 0..<12 {
            guard let total = trend[i] else { continue }
            monthly[i] = IncomeMonthData(total: total, sources: [
                IncomeDetailSource(id: "active-1-\(yearTag)-\(i)", name: "Tech Corp Salary", account: "Main Account",    amount: total * 0.96, percentage: 96, colorHex: "#93C5FD", type: .active),
                IncomeDetailSource(id: "active-2-\(yearTag)-\(i)", name: "Consulting",        account: "Business Account", amount: total * 0.04, percentage:  4, colorHex: "#FDBA74", type: .active)
            ])
        }
        return monthly
    }

    static let passiveIncomeDetail: IncomeDetailData = {
        let trend2025: [Double?] = [800, 850, 950, 1000, 1100, 1150, 1200, 1300, 1400, 1500, 1700, 1900]
        let trend2026: [Double?] = [1950, 2100, 2268, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        return IncomeDetailData(
            title: "Passive Income",
            accentColor: "#A78BFA",
            trendsByYear: [2025: trend2025, 2026: trend2026],
            monthlyDataByYear: [
                2025: buildPassiveMonthly(trend: trend2025, yearTag: "2025"),
                2026: buildPassiveMonthly(trend: trend2026, yearTag: "2026")
            ]
        )
    }()

    private static func buildPassiveMonthly(trend: [Double?], yearTag: String) -> [Int: IncomeMonthData] {
        var monthly: [Int: IncomeMonthData] = [:]
        for i in 0..<12 {
            guard let total = trend[i] else { continue }
            monthly[i] = IncomeMonthData(total: total, sources: [
                IncomeDetailSource(id: "passive-1-\(yearTag)-\(i)", name: "Dividends & Interest", account: "Chase Savings", amount: total * 0.68, percentage: 68, colorHex: "#A78BFA", type: .passive),
                IncomeDetailSource(id: "passive-2-\(yearTag)-\(i)", name: "Real Estate",           account: "Main Account",  amount: total * 0.32, percentage: 32, colorHex: "#5EEAD4", type: .passive)
            ])
        }
        return monthly
    }

    // MARK: - Total Income Detail Mock Data

    static let totalIncomeDetail: TotalIncomeDetailData = {
        var trendsByYear: [Int: [Double?]] = [:]
        var monthlyDataByYear: [Int: [Int: TotalIncomeMonthData]] = [:]
        for year in [2025, 2026] {
            let at = activeIncomeDetail.trendsByYear[year] ?? Array(repeating: nil, count: 12)
            let pt = passiveIncomeDetail.trendsByYear[year] ?? Array(repeating: nil, count: 12)
            var combined: [Double?] = []
            var monthly: [Int: TotalIncomeMonthData] = [:]
            for i in 0..<12 {
                if let a = at[i], let p = pt[i] {
                    let total = a + p
                    combined.append(total)
                    monthly[i] = TotalIncomeMonthData(total: total, activeAmount: a, passiveAmount: p,
                                                      activePercentage: a/total*100, passivePercentage: p/total*100)
                } else { combined.append(nil) }
            }
            trendsByYear[year] = combined
            monthlyDataByYear[year] = monthly
        }
        return TotalIncomeDetailData(title: "Total Income", trendsByYear: trendsByYear, monthlyDataByYear: monthlyDataByYear)
    }()

    // MARK: - Spending Detail Mock Data

    static let needsSpendingDetail: SpendingDetailData = {
        let trend2025: [Double?] = [2800, 2850, 2900, 2950, 2900, 2950, 3000, 2950, 2980, 3000, 3050, 3000]
        let trend2026: [Double?] = [3000, 3050, 3090, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        let base: [(name: String, icon: String, amount: Double)] = [
            ("Rent & Housing",   "house.fill",      1850.00),
            ("Groceries",        "cart.fill",         642.50),
            ("Utilities",        "bolt.fill",         310.20),
            ("Transportation",   "car.fill",          215.00),
            ("Health & Fitness", "cross.case.fill",   120.00)
        ]
        return SpendingDetailData(
            title: "Spending Analysis (Needs)", accentColor: "#2563EB",
            trendsByYear: [2025: trend2025, 2026: trend2026],
            monthlyDataByYear: [
                2025: buildSpendingMonthlyData(prefix: "needs-2025", trend: trend2025, baseCategories: base),
                2026: buildSpendingMonthlyData(prefix: "needs-2026", trend: trend2026, baseCategories: base)
            ]
        )
    }()

    static let wantsSpendingDetail: SpendingDetailData = {
        let trend2025: [Double?] = [1100, 1150, 1200, 1300, 1250, 1400, 1350, 1300, 1280, 1350, 1500, 1600]
        let trend2026: [Double?] = [1240, 1270, 1290, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        let base: [(name: String, icon: String, amount: Double)] = [
            ("Dining & Social",   "fork.knife",         420.00),
            ("Shopping",          "bag.fill",            325.50),
            ("Subscriptions",     "tv.fill",             155.00),
            ("Travel",            "airplane",            210.00),
            ("Hobbies & Leisure", "paintpalette.fill",   129.50)
        ]
        return SpendingDetailData(
            title: "Spending Analysis (Wants)", accentColor: "#D97706",
            trendsByYear: [2025: trend2025, 2026: trend2026],
            monthlyDataByYear: [
                2025: buildSpendingMonthlyData(prefix: "wants-2025", trend: trend2025, baseCategories: base),
                2026: buildSpendingMonthlyData(prefix: "wants-2026", trend: trend2026, baseCategories: base)
            ]
        )
    }()

    static let totalSpendingDetail: TotalSpendingDetailData = {
        var trendsByYear: [Int: [Double?]] = [:]
        var monthlyDataByYear: [Int: [Int: TotalSpendingMonthData]] = [:]
        for year in [2025, 2026] {
            let nt = needsSpendingDetail.trendsByYear[year] ?? Array(repeating: nil, count: 12)
            let wt = wantsSpendingDetail.trendsByYear[year] ?? Array(repeating: nil, count: 12)
            var combined: [Double?] = []
            var monthly: [Int: TotalSpendingMonthData] = [:]
            for i in 0..<12 {
                if let n = nt[i], let w = wt[i] {
                    let total = n + w
                    combined.append(total)
                    monthly[i] = TotalSpendingMonthData(total: total, needsAmount: n, wantsAmount: w,
                                                        needsPercentage: n/total*100, wantsPercentage: w/total*100)
                } else { combined.append(nil) }
            }
            trendsByYear[year] = combined
            monthlyDataByYear[year] = monthly
        }
        return TotalSpendingDetailData(title: "Spending Analysis", trendsByYear: trendsByYear, monthlyDataByYear: monthlyDataByYear)
    }()

    /// Monthly savings by year — used by SavingsTargetDetailView2
    static let savingsByYear: [Int: [Double?]] = [
        2025: [1800, 1900, 2050, 2150, 2200, 2100, 2300, 2250, 2150, 2200, 2380, 2450],
        2026: [1800, 2100, 2200, nil,  nil,  nil,  nil,  nil,  nil,  nil,  nil,  nil ]
    ]

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
            let categories = baseCategories.enumerated().map { (offset, value) -> SpendingDetailCategory in
                let scaledAmount = rounded2(value.amount * scale)
                return SpendingDetailCategory(
                    id: "\(prefix)-\(offset)-\(index)", icon: value.icon, name: value.name,
                    amount: scaledAmount, percentage: total > 0 ? (scaledAmount / total) * 100 : 0
                )
            }.sorted { $0.amount > $1.amount }
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
        createdAt: "2026-03-01T09:00:00Z"
    )

    /// 模拟后端 /monthly-budget 返回
    static let apiMonthlyBudget = APIMonthlyBudget(
        budgetId: "b8410610-d803-471d-929c-89fcbabb920c",
        month: "2026-03-01",
        needsBudget: 4000.00,
        wantsBudget: 2000.00,
        savingsBudget: 2000.00,
        needsSpent: 3090.00,
        wantsSpent: 1290.00,
        savingsActual: 2200.00,
        needsRatio: 50.00,
        wantsRatio: 25.00,
        savingsRatio: 25.00,
        selectedPlan: nil,
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
        createdAt: "2025-09-01T10:00:00Z",
        updatedAt: "2026-03-24T10:00:00Z"
    )

    /// 模拟后端 /net-worth-summary 返回
    static let apiNetWorthSummary = APINetWorthSummary(
        totalNetWorth: 208240.00,
        previousNetWorth: 200000.00,
        growthAmount: 8240.00,
        growthPercentage: 4.12,
        asOfDate: "2026-03-24",
        breakdown: APINetWorthSummary.NetWorthBreakdown(
            investmentTotal: 150000.00,
            depositoryTotal: 100000.00,
            creditTotal: 5000.00,
            loanTotal: 36760.00
        ),
        accounts: [
            APIAccount(
                id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1",
                name: "Fidelity 401(k)",
                type: "investment",
                subtype: "401k",
                balance: 150000.00,
                mask: "1234",
                institution: "Fidelity"
            ),
            APIAccount(
                id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2",
                name: "Chase Checking",
                type: "depository",
                subtype: "checking",
                balance: 25000.00,
                mask: "5678",
                institution: "Chase"
            )
        ],
        lastSyncedAt: nil
    )
}
