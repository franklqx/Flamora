//
//  BudgetSetupModels.swift
//  Flamora app
//
//  Response models for Budget Setup flow (Steps 1-5)
//  Matches calculate-fire-goal v2, save-fire-goal v2, calculate-avg-spending, generate-financial-diagnosis
//

import Foundation

// MARK: - calculate-fire-goal Response

struct FireGoalResponse: Codable {
    let phase: Int                          // 0, 2, or 3
    let phaseSub: String?                   // nil — backend doesn't return this
    let strategy: String                    // "goal_achievable", "user_choice", "impossible"
    let fireNumber: Double
    let gapToFire: Double
    let requiredMonthlyContribution: Double
    let requiredSavingsRate: Double
    let yearsToRetirement: Int
    let isAchievable: Bool
    let currentPath: FireGoalPlan
    let planA: FireGoalPlan?
    let planB: FireGoalPlan?
    let recommended: FireGoalPlan?
    let incomeGrowthHint: IncomeGrowthHint?

    /// Derive sub-phase from phase + gapToFire (backend doesn't compute phase_sub)
    var effectivePhaseSub: String {
        if let sub = phaseSub { return sub }
        if phase == 0 {
            return gapToFire <= 0 ? "0a" : "0b"
        }
        return phase == 2 ? "1" : "2"
    }
}

struct FireGoalPlan: Codable {
    let retirementAge: Int
    let savingsRate: Double
    let monthlySavings: Double
    let feasibility: String                 // "comfortable", "balanced", "aggressive", "unrealistic"
}

struct IncomeGrowthHint: Codable {
    let requiredIncome: Double
    let increasePercent: Double
    let targetRate: Double
}

struct FireGoalMeta: Codable {
    let timestamp: String
    let userId: String
    let returnRateAssumption: Double
    let withdrawalRate: Double
    let inputs: FireGoalInputs
}

struct FireGoalInputs: Codable {
    let currentAge: Int
    let targetRetirementAge: Int
    let desiredMonthlyExpenses: Double
    let currentNetWorth: Double
    let monthlyIncome: Double
    let currentMonthlyExpenses: Double
    let netWorthSource: String
}

// MARK: - save-fire-goal Request & Response

struct SaveFireGoalRequest: Encodable {
    let currentAge: Int
    let targetRetirementAge: Int
    let desiredMonthlyExpenses: Double
    let fireNumber: Double
    let requiredMonthlyContribution: Double
    let requiredSavingsRate: Double
    let selectedPlan: String                // "current", "plan_a", "plan_b", "recommended"
    let adjustmentPhase: Int
    let adjustmentPhaseSub: String
    let adjustmentStrategy: String

    enum CodingKeys: String, CodingKey {
        case currentAge = "current_age"
        case targetRetirementAge = "target_retirement_age"
        case desiredMonthlyExpenses = "desired_monthly_expenses"
        case fireNumber = "fire_number"
        case requiredMonthlyContribution = "required_monthly_contribution"
        case requiredSavingsRate = "required_savings_rate"
        case selectedPlan = "selected_plan"
        case adjustmentPhase = "adjustment_phase"
        case adjustmentPhaseSub = "adjustment_phase_sub"
        case adjustmentStrategy = "adjustment_strategy"
    }
}

struct SaveFireGoalResponse: Codable {
    let goalId: String
    let userId: String
    let targetRetirementAge: Int
    let fireNumber: Double
    let requiredSavingsRate: Double
    let requiredMonthlyContribution: Double
    let selectedPlan: String
    let adjustmentPhase: Int?
    let adjustmentPhaseSub: String?
    let isActive: Bool
}

// MARK: - calculate-avg-spending Response (extended for budget setup)

struct AvgSpendingResponse: Codable {
    let avgMonthlySpending: Double
    let avgMonthlyNeeds: Double
    let avgMonthlyWants: Double
    let avgMonthlyIncomeDetected: Double
    let monthsAnalyzed: Int
    let outliersRemoved: Int
    let incomeDiscrepancy: Bool
    let manualIncome: Double
    let monthlyBreakdown: [MonthlySpendingBreakdown]
    let fallback: Bool
}

struct MonthlySpendingBreakdown: Codable {
    let month: String
    let needs: Double
    let wants: Double
    let total: Double
}

// MARK: - generate-financial-diagnosis Response

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
    let type: String                        // "positive", "warning", "tip"
    let title: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case type, title, description
    }
}

// MARK: - generate-monthly-budget Request & Response

struct GenerateMonthlyBudgetRequest: Encodable {
    let month: String
    let needsRatio: Double
    let wantsRatio: Double
    let savingsRatio: Double
    let source: String                      // "setup" for initial, "manual" for later adjustments

    enum CodingKeys: String, CodingKey {
        case month
        case needsRatio = "needs_ratio"
        case wantsRatio = "wants_ratio"
        case savingsRatio = "savings_ratio"
        case source
    }
}

// MARK: - get-user-profile Response (for budget setup)
struct UserProfileForBudget: Codable {
    let monthlyIncome: Double
    let age: Int
    let currentNetWorth: Double
    let plaidNetWorth: Double?
    let hasLinkedBank: Bool
    let currencyCode: String
}

// MARK: - Spending Summary (subcategory breakdown for Step 4)

struct SpendingSummaryResponse: Codable {
    let month: String
    let categories: [SpendingCategory]
    let needsTotal: Double
    let wantsTotal: Double
}

struct SpendingCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
    let flamoraCategory: String             // "needs" or "wants"
}
