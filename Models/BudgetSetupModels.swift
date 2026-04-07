//
//  BudgetSetupModels.swift
//  Flamora app
//
//  V2 Response models for Budget Setup flow
//  Matches: calculate-spending-stats, generate-plans, generate-spending-plan
//
//  NOTE on decoding:
//  APIService.perform uses keyDecodingStrategy = .convertFromSnakeCase, so all
//  response structs (Decodable) need NO explicit CodingKeys — the strategy maps
//  snake_case JSON keys to camelCase Swift properties automatically.
//
//  Request structs (Encodable only) DO have explicit CodingKeys because
//  JSONEncoder has no keyEncodingStrategy set, so snake_case must be specified.
//
//  Terminology: UI 与日志使用 Needs / Wants；模型属性名仍与后端一致（fixed / flexible 等）。
//

import Foundation

// MARK: - calculate-spending-stats Response

struct SpendingStatsResponse: Codable {
    let avgMonthlyIncome: Double
    let avgMonthlyExpenses: Double
    let avgMonthlySavings: Double
    let currentSavingsRate: Double

    let avgMonthlyFixed: Double
    let avgMonthlyFlexible: Double

    let fixedExpenses: [FixedExpenseItem]
    let flexibleBreakdown: [FlexibleBreakdownItem]

    let incomeSource: String              // "plaid" or "manual"
    let monthsAnalyzed: Int
    let dataQuality: String               // "good" or "limited"
    let totalTransactions: Int

    let monthlyBreakdown: [MonthlyBreakdownItem]
}

struct FixedExpenseItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let pfcDetailed: String?
    let avgMonthlyAmount: Double
    let monthsAppeared: Int
    let variancePct: Double
    let isAlwaysFixed: Bool
}

struct FlexibleBreakdownItem: Codable, Identifiable {
    var id: String { subcategory }
    let subcategory: String
    let avgMonthlyAmount: Double
    let shareOfFlexible: Double
    let transactionCount: Int
}

struct MonthlyBreakdownItem: Codable, Identifiable {
    var id: String { month }
    let month: String
    let income: Double
    let fixed: Double
    let flexible: Double
    let savings: Double
}

// MARK: - generate-plans Response

struct PlansResponse: Codable {
    let baseline: BaselinePlan
    let plans: ThreePlans
    let userTier: String                  // "in_debt", "beginner", "intermediate", "advanced"
    let maxPossibleRate: Double
    let critical: Bool
    let currentNetWorth: Double
    let currentAge: Int
    let assumptions: PlanAssumptions?
}

struct BaselinePlan: Codable {
    let savingsRate: Double
    let monthlySave: Double
    let projection1y: Double
    let projection5y: Double
    let projection10y: Double

    // .convertFromSnakeCase capitalises the letter after a digit boundary:
    // "projection_1y" → "projection1Y" (capital Y), not "projection1y".
    // Raw values here must match what the strategy actually produces.
    enum CodingKeys: String, CodingKey {
        case savingsRate
        case monthlySave
        case projection1y  = "projection1Y"
        case projection5y  = "projection5Y"
        case projection10y = "projection10Y"
    }
}

struct ThreePlans: Codable {
    let steady: PlanDetail
    let recommended: PlanDetail
    let accelerate: PlanDetail
}

struct PlanDetail: Codable, Identifiable {
    var id: String { "\(savingsRate)" }
    let savingsRate: Double
    let monthlySave: Double
    let monthlySpend: Double
    let flexibleSpend: Double
    let extraPerMonth: Double
    let flexibleCompressionPct: Double
    let projection1y: Double
    let projection5y: Double
    let projection10y: Double
    let gainVsBaseline10y: Double
    let feasibility: String               // "easy", "moderate", "challenging", "extreme"
    let status: String                    // "on_track", "breakeven", "deficit"

    // v3 FIRE-aware fields — optional so existing decoders don't break
    var spendingCeilingMonthly: Double? = nil  // alias for monthlySpend
    var officialFireDate: String? = nil
    var officialFireAge: Int? = nil
    var fireYearsVsBaseline: Double? = nil
    var tradeoffNote: String? = nil
    var positioningCopy: String? = nil

    // .convertFromSnakeCase capitalises the letter after a digit boundary:
    // "projection_1y" → "projection1Y" (capital Y), "gain_vs_baseline_10y" → "gainVsBaseline10Y".
    enum CodingKeys: String, CodingKey {
        case savingsRate
        case monthlySave
        case monthlySpend
        case flexibleSpend
        case extraPerMonth
        case flexibleCompressionPct
        case projection1y             = "projection1Y"
        case projection5y             = "projection5Y"
        case projection10y            = "projection10Y"
        case gainVsBaseline10y        = "gainVsBaseline10Y"
        case feasibility
        case status
        case spendingCeilingMonthly   = "spending_ceiling_monthly"
        case officialFireDate         = "official_fire_date"
        case officialFireAge          = "official_fire_age"
        case fireYearsVsBaseline      = "fire_years_vs_baseline"
        case tradeoffNote             = "tradeoff_note"
        case positioningCopy          = "positioning_copy"
    }
}

struct PlanAssumptions: Codable {
    let nominalReturn: Double
    let inflation: Double
    let realReturn: Double
}

// MARK: - generate-spending-plan Response

struct SpendingPlanResponse: Codable {
    let month: String
    let planRate: Double
    let planName: String

    let totalIncome: Double
    let totalSavings: Double
    let totalSpend: Double

    let fixedBudget: FixedBudget
    let flexibleBudget: FlexibleBudget

    let fixedExceedsBudget: Bool

    let ratios: BudgetRatios?
}

struct FixedBudget: Codable {
    let total: Double
    let items: [FixedBudgetItem]
}

struct FixedBudgetItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let pfcDetailed: String?
    let monthlyAmount: Double
    let isUserCorrected: Bool
}

struct FlexibleBudget: Codable {
    let total: Double
    let items: [FlexibleBudgetItem]
}

struct FlexibleBudgetItem: Codable, Identifiable {
    var id: String { subcategory }
    let subcategory: String
    let suggestedAmount: Double
    let historicalAvg: Double
    let changePct: Double
}

struct BudgetRatios: Codable {
    let savings: Double
    let fixed: Double
    let flexible: Double
}

// MARK: - generate-plans Request (sent from client)

struct GeneratePlansRequest: Encodable {
    let currentSavingsRate: Double
    let avgMonthlyIncome: Double
    let avgMonthlySavings: Double
    let avgMonthlyFixed: Double
    let avgMonthlyFlexible: Double
    let currentNetWorth: Double
    let currentAge: Int
    // v3: optional — server fetches from fire_goals if nil
    var fireNumber: Double? = nil
    var retirementSpendingMonthly: Double? = nil
    var returnAssumption: Double? = nil

    enum CodingKeys: String, CodingKey {
        case currentSavingsRate        = "current_savings_rate"
        case avgMonthlyIncome          = "avg_monthly_income"
        case avgMonthlySavings         = "avg_monthly_savings"
        case avgMonthlyFixed           = "avg_monthly_fixed"
        case avgMonthlyFlexible        = "avg_monthly_flexible"
        case currentNetWorth           = "current_net_worth"
        case currentAge                = "current_age"
        case fireNumber                = "fire_number"
        case retirementSpendingMonthly = "retirement_spending_monthly"
        case returnAssumption          = "return_assumption"
    }
}

// MARK: - generate-spending-plan Request (sent from client)

struct GenerateSpendingPlanRequest: Encodable {
    let selectedPlanRate: Double
    let selectedPlanName: String
    let avgMonthlyIncome: Double
    let fixedExpenses: [FixedExpenseInput]
    let flexibleBreakdown: [FlexibleBreakdownInput]
    let month: String

    enum CodingKeys: String, CodingKey {
        case selectedPlanRate = "selected_plan_rate"
        case selectedPlanName = "selected_plan_name"
        case avgMonthlyIncome = "avg_monthly_income"
        case fixedExpenses = "fixed_expenses"
        case flexibleBreakdown = "flexible_breakdown"
        case month
    }
}

struct FixedExpenseInput: Encodable {
    let name: String
    let pfcDetailed: String?
    let monthlyAmount: Double
    let isUserCorrected: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case pfcDetailed = "pfc_detailed"
        case monthlyAmount = "monthly_amount"
        case isUserCorrected = "is_user_corrected"
    }
}

struct FlexibleBreakdownInput: Encodable {
    let subcategory: String
    let avgMonthlyAmount: Double
    let shareOfFlexible: Double

    enum CodingKeys: String, CodingKey {
        case subcategory
        case avgMonthlyAmount = "avg_monthly_amount"
        case shareOfFlexible = "share_of_flexible"
    }
}

// MARK: - Financial Diagnosis (kept from V1, still uses existing AI function)

struct FinancialDiagnosisResponse: Codable {
    let metrics: DiagnosisMetrics
    let aiDiagnosis: AIDiagnosis
}

struct DiagnosisMetrics: Codable {
    let avgIncome: Double
    let avgSpending: Double
    let avgSavings: Double
    let savingsRate: Double
    let needsTotal: Double
    let wantsTotal: Double
    let needsRatio: Double
    let wantsRatio: Double
    let netWorth: Double
    let monthsAnalyzed: Int?
    let negativeSavingsMonths: Int?
    let spendingVolatility: Double?
}

struct AIDiagnosis: Codable {
    let insights: [DiagnosisInsight]
    let summary: String
}

struct DiagnosisInsight: Codable, Identifiable {
    var id: String { "\(type)-\(title)" }
    let type: String                      // "positive", "warning", "tip"
    let title: String
    let description: String
}

// MARK: - Diagnosis Request (adapted for V2 stats output)

struct DiagnosisRequestBody: Encodable {
    let manualIncome: Double
    let avgMonthlySpending: Double
    let avgMonthlyNeeds: Double           // mapped from fixed
    let avgMonthlyWants: Double           // mapped from flexible
    let avgMonthlyIncomeDetected: Double
    let monthsAnalyzed: Int
    let monthlyBreakdown: [MonthlyBreakdownForDiagnosis]
    let incomeDiscrepancy: Bool
    let fallback: Bool
    let plaidNetWorth: Double
    let age: Int

    enum CodingKeys: String, CodingKey {
        case manualIncome = "manual_income"
        case avgMonthlySpending = "avg_monthly_spending"
        case avgMonthlyNeeds = "avg_monthly_needs"
        case avgMonthlyWants = "avg_monthly_wants"
        case avgMonthlyIncomeDetected = "avg_monthly_income_detected"
        case monthsAnalyzed = "months_analyzed"
        case monthlyBreakdown = "monthly_breakdown"
        case incomeDiscrepancy = "income_discrepancy"
        case fallback
        case plaidNetWorth = "plaid_net_worth"
        case age
    }
}

struct MonthlyBreakdownForDiagnosis: Encodable {
    let month: String
    let needs: Double
    let wants: Double
    let total: Double
}

// MARK: - get-plaid-accounts Response

struct PlaidAccountsResponse: Codable {
    let accounts: [PlaidAccountItem]
    let totalAccounts: Int
    let hasTransactionAccounts: Bool
}

struct PlaidAccountItem: Codable, Identifiable {
    let id: String
    let accountId: String
    let name: String
    let officialName: String?
    let type: String
    let subtype: String?
    let mask: String?
    let balanceCurrent: Double?
    let institutionName: String?
    let hasTransactions: Bool
}

// MARK: - get-user-profile Response (unchanged from V1)

struct UserProfileForBudget: Codable {
    let monthlyIncome: Double
    let age: Int
    let currentNetWorth: Double
    let plaidNetWorth: Double?
    let hasLinkedBank: Bool
    let currencyCode: String
}

// MARK: - save-fire-goal v1 (spending-based, no target age required)

struct SaveFireGoalRequest: Encodable {
    // v1 minimum required
    let retirementSpendingMonthly: Double
    let lifestylePreset: String           // "lean" | "current" | "fat"

    // Optional — provide for FIRE date computation accuracy
    var fireNumber: Double? = nil
    var currentAge: Int? = nil
    var targetRetirementAge: Int? = nil

    // Assumption overrides (server uses defaults if absent)
    var withdrawalRateAssumption: Double? = nil
    var inflationAssumption: Double? = nil
    var returnAssumption: Double? = nil

    enum CodingKeys: String, CodingKey {
        case retirementSpendingMonthly  = "retirement_spending_monthly"
        case lifestylePreset            = "lifestyle_preset"
        case fireNumber                 = "fire_number"
        case currentAge                 = "current_age"
        case targetRetirementAge        = "target_retirement_age"
        case withdrawalRateAssumption   = "withdrawal_rate_assumption"
        case inflationAssumption        = "inflation_assumption"
        case returnAssumption           = "return_assumption"
    }
}

struct SaveFireGoalResponse: Codable {
    let goalId: String
    let fireNumber: Double
    let retirementSpendingMonthly: Double?
    let lifestylePreset: String?
    let requiredSavingsRate: Double
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case goalId                     = "goal_id"
        case fireNumber                 = "fire_number"
        case retirementSpendingMonthly  = "retirement_spending_monthly"
        case lifestylePreset            = "lifestyle_preset"
        case requiredSavingsRate        = "required_savings_rate"
        case isActive                   = "is_active"
    }
}
