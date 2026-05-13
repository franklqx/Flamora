//
//  BudgetSetupModels.swift
//  Meridian
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

    // V3 additions
    var hasDeficit: Bool? = nil
    var deficitAmount: Double? = nil
    var essentialFloor: Double? = nil
    var avgWants: Double? = nil
    var uncategorizedShareOfSpend: Double? = nil
    var canonicalBreakdown: [CanonicalBreakdownItem]? = nil
    var oneTimeTransactions: [OneTimeTransactionItem]? = nil
    var outlierThreshold: Double? = nil
    var monthlyBreakdownV3: [MonthlyBreakdownV3Item]? = nil
    var monthsInWindow: Int? = nil
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

struct CanonicalBreakdownItem: Codable, Identifiable {
    var id: String { canonicalId }
    let canonicalId: String
    let parent: String
    let avgMonthly: Double
    let transactionCount: Int
}

struct OneTimeTransactionItem: Codable, Identifiable {
    var id: String { "\(date)-\(canonicalId)-\(amount)" }
    let amount: Double
    let date: String
    let name: String?
    let pfcDetailed: String?
    let canonicalId: String
}

struct MonthlyBreakdownV3Item: Codable, Identifiable {
    var id: String { month }
    let month: String
    let status: String
    let income: Double
    let needsSpend: Double
    let wantsSpend: Double
    let uncategorizedSpend: Double
    let totalSpend: Double
    let savings: Double
}

// MARK: - generate-plans Response

struct PlansResponse: Codable {
    let plans: [BudgetPlanOption]
    let planCount: Int
    let primaryPlanLabel: String
    let currentNetWorth: Double
    let startingPortfolioBalance: Double?
    let startingPortfolioSource: String?
    let currentAge: Int
    let targetRetirementAge: Int
    let retirementSpendingMonthly: Double
    let fireNumber: Double
    let customSlider: CustomSliderRange
    let assumptions: PlanAssumptions?
    let committedDefaults: CommittedPlanDefaults
}

struct BudgetPlanOption: Codable, Identifiable {
    var id: String { "\(label)-\(monthlySave)-\(projectedFireAge)" }
    let feasibility: String
    let anchor: String
    let label: String
    let reason: String?
    let limitReason: String?
    let monthlySave: Double
    let monthlyBudget: Double
    let committedSpendCeiling: Double
    let savingsRate: Double              // ratio 0...1
    let fireNumber: Double
    let fireAgeMonths: Double?
    let projectedFireAge: Int
    let fireAgeYears: Int
    let gapMonths: Double?
    let gapYears: Int
    let headline: String
    let sub: String
    let badge: String?
    let cta: PlanCTA?
}

struct PlanCTA: Codable {
    let label: String
    let action: String
}

struct CustomSliderRange: Codable {
    let isAvailable: Bool
    let minMonthlySave: Double?
    let maxMonthlySave: Double?
}

struct CommittedPlanDefaults: Codable {
    let committedPlanLabel: String
    let committedMonthlySave: Double
    let committedSavingsRate: Double
    let committedSpendCeiling: Double
}

struct PlanAssumptions: Codable {
    let realReturn: Double
    let withdrawalRate: Double
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
    let avgMonthlyExpenses: Double
    let avgMonthlyFixed: Double
    let avgMonthlyFlexible: Double
    let currentNetWorth: Double
    let currentAge: Int
    // v3: optional — server fetches from fire_goals if nil
    var fireNumber: Double? = nil
    var retirementSpendingMonthly: Double? = nil
    var returnAssumption: Double? = nil

    // v3 optional fields for FIRE-aware plan generation
    var targetRetirementAge: Int? = nil       // "target_retirement_age"
    var withdrawalRate: Double? = nil         // "withdrawal_rate"
    var essentialFloor: Double? = nil         // "essential_floor"
    var avgWants: Double? = nil               // "avg_wants"
    var accountIds: [String]? = nil           // "account_ids"
    var month: String? = nil                  // "month"
    var startingPortfolioBalance: Double? = nil
    var startingPortfolioSource: String? = nil

    enum CodingKeys: String, CodingKey {
        case currentSavingsRate        = "current_savings_rate"
        case avgMonthlyIncome          = "avg_monthly_income"
        case avgMonthlySavings         = "avg_monthly_savings"
        case avgMonthlyExpenses        = "avg_monthly_expenses"
        case avgMonthlyFixed           = "avg_monthly_fixed"
        case avgMonthlyFlexible        = "avg_monthly_flexible"
        case currentNetWorth           = "current_net_worth"
        case currentAge                = "current_age"
        case fireNumber                = "fire_number"
        case retirementSpendingMonthly = "retirement_spending_monthly"
        case returnAssumption          = "return_assumption"
        case targetRetirementAge       = "target_retirement_age"
        case withdrawalRate            = "withdrawal_rate"
        case essentialFloor            = "essential_floor"
        case avgWants                  = "avg_wants"
        case accountIds                = "account_ids"
        case month
        case startingPortfolioBalance  = "starting_portfolio_balance"
        case startingPortfolioSource   = "starting_portfolio_source"
    }
}

// MARK: - generate-spending-plan Request (sent from client)

struct GenerateSpendingPlanRequest: Encodable {
    let selectedPlanRate: Double
    let selectedPlanName: String
    let avgMonthlyIncome: Double
    let fixedExpenses: [FixedExpenseInput]
    let flexibleBreakdown: [FlexibleBreakdownInput]
    var committedMonthlySave: Double? = nil
    var committedSpendCeiling: Double? = nil
    let month: String

    enum CodingKeys: String, CodingKey {
        case selectedPlanRate = "selected_plan_rate"
        case selectedPlanName = "selected_plan_name"
        case avgMonthlyIncome = "avg_monthly_income"
        case fixedExpenses = "fixed_expenses"
        case flexibleBreakdown = "flexible_breakdown"
        case committedMonthlySave = "committed_monthly_save"
        case committedSpendCeiling = "committed_spend_ceiling"
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
    let startingPortfolioBalance: Double?
    let startingPortfolioSource: String?
    let startingPortfolioUpdatedAt: String?
    let hasLinkedBank: Bool
    let currencyCode: String
}

// MARK: - update-user-profile Response
//
// Mirrors the success payload returned by the partial-update endpoint. We
// only decode the fields the manual-mode flow actually consumes; extra
// keys (timezone / has_linked_bank / etc.) are ignored by Codable.

struct UpdatedUserProfile: Codable {
    let userId: String
    let monthlyIncome: Double?
    let currentNetWorth: Double?
    let age: Int?
    let currencyCode: String?
    let plaidNetWorth: Double?
    let startingPortfolioBalance: Double?
    let startingPortfolioSource: String?
    let startingPortfolioUpdatedAt: String?
}

// MARK: - save-fire-goal v1 (spending-based, no target age required)

struct SaveFireGoalRequest: Encodable {
    // v1 minimum required
    let retirementSpendingMonthly: Double
    // V3 (Phase E): lifestylePreset is deprecated. Field kept Encodable-optional so
    // server still accepts (or ignores) the legacy "lifestyle_preset" key. New flows
    // pass nil; only retirement_spending_monthly is the source of truth.
    let lifestylePreset: String?

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
}

// MARK: - calculate-fire-goal Response

struct GoalFeasibilityResult: Codable {
    let phase: Int                          // 0 / 1 / 2
    let phaseSub: String                    // "0a","0b","0c","0d","1","2"
    let strategy: String                    // "goal_achievable" | "user_choice" | "impossible"
    let fireNumber: Double
    let gapToFire: Double
    let requiredMonthlyContribution: Double
    let requiredSavingsRate: Double
    let yearsToRetirement: Int
    let isAchievable: Bool
    let currentPath: FeasibilityPath
    let planA: FeasibilityPath?
    let planB: FeasibilityPath?
    let recommended: FeasibilityPath?
}

struct FeasibilityPath: Codable {
    let retirementAge: Int
    let savingsRate: Double
    let monthlySavings: Double
    let feasibility: String  // "comfortable" | "balanced" | "aggressive" | "unrealistic"
}
