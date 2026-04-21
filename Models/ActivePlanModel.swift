//
//  ActivePlanModel.swift
//  Flamora app
//
//  Official active plan record — decoded from `apply-selected-plan` response
//  and used by Home Action Strip, CashFlow budget card, and plan summary.
//

import Foundation

// MARK: - Active Plan

struct ActivePlanModel: Codable {
    let planId: String
    let planType: String             // "target-aligned" | "comfortable" | "accelerated" | ...
    let planLabel: String
    let savingsTargetMonthly: Double
    let savingsRateTarget: Double    // kept as percentage for active_plans backward compatibility
    let spendingCeilingMonthly: Double
    let fixedBudgetMonthly: Double
    let flexibleBudgetMonthly: Double
    let officialFireDate: String?    // "Mar 2042"
    let officialFireAge: Int?
    let tradeoffNote: String?
    let positioningCopy: String?
    let isActive: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case planId                  = "plan_id"
        case planType                = "plan_type"
        case planLabel               = "plan_label"
        case savingsTargetMonthly    = "savings_target_monthly"
        case savingsRateTarget       = "savings_rate_target"
        case spendingCeilingMonthly  = "spending_ceiling_monthly"
        case fixedBudgetMonthly      = "fixed_budget_monthly"
        case flexibleBudgetMonthly   = "flexible_budget_monthly"
        case officialFireDate        = "official_fire_date"
        case officialFireAge         = "official_fire_age"
        case tradeoffNote            = "tradeoff_note"
        case positioningCopy         = "positioning_copy"
        case isActive                = "is_active"
        case createdAt               = "created_at"
    }
}

// MARK: - Apply Plan Request

struct ApplyPlanRequest: Encodable {
    let planType: String
    let savingsTargetMonthly: Double
    let savingsRateTarget: Double
    let spendingCeilingMonthly: Double
    let fixedBudgetMonthly: Double
    let flexibleBudgetMonthly: Double
    let officialFireDate: String?
    let officialFireAge: Int?
    let tradeoffNote: String?
    let positioningCopy: String?

    enum CodingKeys: String, CodingKey {
        case planType                = "plan_type"
        case savingsTargetMonthly    = "savings_target_monthly"
        case savingsRateTarget       = "savings_rate_target"
        case spendingCeilingMonthly  = "spending_ceiling_monthly"
        case fixedBudgetMonthly      = "fixed_budget_monthly"
        case flexibleBudgetMonthly   = "flexible_budget_monthly"
        case officialFireDate        = "official_fire_date"
        case officialFireAge         = "official_fire_age"
        case tradeoffNote            = "tradeoff_note"
        case positioningCopy         = "positioning_copy"
    }

    /// Build from a Phase D `BudgetPlanOption` after plan selection.
    /// `active_plans` still stores a percentage-style savings rate for backward compatibility.
    static func from(
        plan: BudgetPlanOption,
        committedPlanLabel: String,
        fixedBudgetMonthly: Double,
        flexibleBudgetMonthly: Double
    ) -> ApplyPlanRequest {
        ApplyPlanRequest(
            planType:               committedPlanLabel,
            savingsTargetMonthly:   plan.monthlySave,
            savingsRateTarget:      plan.savingsRate * 100,
            spendingCeilingMonthly: plan.committedSpendCeiling,
            fixedBudgetMonthly:     fixedBudgetMonthly,
            flexibleBudgetMonthly:  flexibleBudgetMonthly,
            officialFireDate:       nil,
            officialFireAge:        plan.projectedFireAge,
            tradeoffNote:           plan.sub,
            positioningCopy:        plan.headline
        )
    }
}
