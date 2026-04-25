//
//  HomeHeroModel.swift
//  Flamora app
//
//  Official Hero data model — decoded from `get-active-fire-goal` v2 response.
//  Used by the rebuilt Home Hero card (Phase 3).
//
//  Separate from APIFireGoal (legacy model kept for transition period).
//  When JourneyView is rebuilt, it will switch to HomeHeroModel.
//

import Foundation

// MARK: - Hero Model

struct HomeHeroModel: Codable {

    // ── Identity ──────────────────────────────────────────────
    let goalId: String
    let dataSource: String           // "plaid" | "manual"

    // ── Progress ──────────────────────────────────────────────
    let fireNumber: Double
    let currentNetWorth: Double
    let startingPortfolioBalance: Double?
    let startingPortfolioSource: String?
    let progressPercentage: Double   // 0..100
    let gapToFire: Double
    let onTrack: Bool

    // ── Official FIRE estimates (nil until active plan exists) ──
    let officialFireDate: String?    // "Mar 2042"
    let officialFireAge: Int?
    let officialYearsRemaining: Int? // computed from savings math, not age diff

    // ── Status copy (1 line, Hero voice) ─────────────────────
    let progressStatus: String       // "Your current path is improving"

    // ── Active plan metadata ──────────────────────────────────
    let activePlanType: String?      // "steady" | "recommended" | "accelerate"
    let activePlanLabel: String?     // "Recommended"
    let savingsTargetMonthly: Double?

    // ── Spending-based goal fields ────────────────────────────
    let retirementSpendingMonthly: Double?
    let lifestylePreset: String?     // "lean" | "current" | "fat"

    // ── Legacy / compat fields ────────────────────────────────
    let targetRetirementAge: Int?    // optional — v1 goals may omit
    let currentAge: Int?
    let requiredSavingsRate: Double?
    let yearsRemaining: Int          // legacy field; use officialYearsRemaining in new code
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case goalId                    = "goal_id"
        case dataSource                = "data_source"
        case fireNumber                = "fire_number"
        case currentNetWorth           = "current_net_worth"
        case startingPortfolioBalance  = "starting_portfolio_balance"
        case startingPortfolioSource   = "starting_portfolio_source"
        case progressPercentage        = "progress_percentage"
        case gapToFire                 = "gap_to_fire"
        case onTrack                   = "on_track"
        case officialFireDate          = "official_fire_date"
        case officialFireAge           = "official_fire_age"
        case officialYearsRemaining    = "official_years_remaining"
        case progressStatus            = "progress_status"
        case activePlanType            = "active_plan_type"
        case activePlanLabel           = "active_plan_label"
        case savingsTargetMonthly      = "savings_target_monthly"
        case retirementSpendingMonthly = "retirement_spending_monthly"
        case lifestylePreset           = "lifestyle_preset"
        case targetRetirementAge       = "target_retirement_age"
        case currentAge                = "current_age"
        case requiredSavingsRate       = "required_savings_rate"
        case yearsRemaining            = "years_remaining"
        case createdAt                 = "created_at"
    }
}

// MARK: - Formatting helpers

extension HomeHeroModel {

    /// Display-ready FIRE date. Falls back to age-based estimate if official date absent.
    var displayFireDate: String? {
        if let d = officialFireDate { return d }
        guard let years = officialYearsRemaining ?? (yearsRemaining > 0 ? yearsRemaining : nil),
              years > 0 else { return nil }
        let arrival = Calendar.current.date(byAdding: .year, value: years, to: Date()) ?? Date()
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return f.string(from: arrival)
    }

    /// Display-ready FIRE age string. Nil if age unknown.
    var displayFireAge: String? {
        guard let age = officialFireAge else { return nil }
        return "Age \(age)"
    }

    /// Compact fire_number string e.g. "$2.4M"
    var fireNumberFormatted: String { Self.formatCurrency(fireNumber) }

    private static func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }
}
