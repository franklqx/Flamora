//
//  SimulatorPreviewModel.swift
//  Flamora app
//
//  Simulator preview data — decoded from `preview-simulator` Edge Function.
//  Strictly separate from HomeHeroModel / APIFireGoal.
//  Hero NEVER reads from this model.
//

import Foundation

// MARK: - Preview Model

struct SimulatorPreviewModel: Codable {
    let mode: String                  // "demo" | "official_preview"

    // Official baseline (nil in demo mode)
    let officialFireDate: String?
    let officialFireAge: Int?
    let officialFireNumber: Double?

    // Sandbox preview result
    let previewFireDate: String?
    let previewFireAge: Int?
    let previewFireNumber: Double

    // Delta (negative = faster, positive = slower vs official)
    let deltaMonths: Int
    let deltaYears: Double

    // Graph series
    let officialPath: [SimulatorDataPoint]   // empty in demo mode
    let adjustedPath: [SimulatorDataPoint]
    let officialLifecyclePath: [SimulatorLifecyclePoint]?
    let adjustedLifecyclePath: [SimulatorLifecyclePoint]?
    let portfolioDepletionAge: Int?
    let lifecycleEndAge: Int?
    let projectionBasis: String?

    // Effective inputs echoed back for display
    let effectiveInputs: SimulatorEffectiveInputs?

    enum CodingKeys: String, CodingKey {
        case mode
        case officialFireDate    = "official_fire_date"
        case officialFireAge     = "official_fire_age"
        case officialFireNumber  = "official_fire_number"
        case previewFireDate     = "preview_fire_date"
        case previewFireAge      = "preview_fire_age"
        case previewFireNumber   = "preview_fire_number"
        case deltaMonths         = "delta_months"
        case deltaYears          = "delta_years"
        case officialPath        = "official_path"
        case adjustedPath        = "adjusted_path"
        case officialLifecyclePath = "official_lifecycle_path"
        case adjustedLifecyclePath = "adjusted_lifecycle_path"
        case portfolioDepletionAge = "portfolio_depletion_age"
        case lifecycleEndAge = "lifecycle_end_age"
        case projectionBasis = "projection_basis"
        case effectiveInputs     = "effective_inputs"
    }

    var isDemoMode: Bool { mode == "demo" }
}

// MARK: - Graph Data Point

struct SimulatorDataPoint: Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let netWorth: Double

    enum CodingKeys: String, CodingKey {
        case year
        case netWorth = "net_worth"
    }
}

struct SimulatorLifecyclePoint: Codable, Identifiable, Equatable {
    var id: Int { age }
    let age: Int
    let year: Int
    let netWorth: Double
    let phase: String

    enum CodingKeys: String, CodingKey {
        case age
        case year
        case netWorth = "net_worth"
        case phase
    }
}

// MARK: - Effective Inputs

struct SimulatorEffectiveInputs: Codable {
    let savingsMonthly: Double
    let retirementSpending: Double
    let returnRate: Double
    let withdrawalRate: Double
    let netWorth: Double
    let currentAge: Int?

    enum CodingKeys: String, CodingKey {
        case savingsMonthly     = "savings_monthly"
        case retirementSpending = "retirement_spending"
        case returnRate         = "return_rate"
        case withdrawalRate     = "withdrawal_rate"
        case netWorth           = "net_worth"
        case currentAge         = "current_age"
    }
}

// MARK: - Preview Request

struct SimulatorPreviewRequest: Encodable {
    let mode: String                         // "demo" | "official_preview"

    // Official plan anchors (optional — server loads from DB if absent in official_preview)
    var officialSavingsMonthly: Double?
    var officialRetirementSpending: Double?
    var officialNetWorth: Double?
    var officialAge: Int?

    // Sandbox overrides
    var sandboxSavingsMonthly: Double?
    var sandboxRetirementSpending: Double?
    var sandboxReturnRate: Double?           // default 0.04 real return
    var sandboxInflationRate: Double?        // default 0.03
    var sandboxWithdrawalRate: Double?       // default 0.04
    var sandboxTargetAge: Int?               // optional, sandbox-only

    enum CodingKeys: String, CodingKey {
        case mode
        case officialSavingsMonthly     = "official_savings_monthly"
        case officialRetirementSpending = "official_retirement_spending"
        case officialNetWorth           = "official_net_worth"
        case officialAge                = "official_age"
        case sandboxSavingsMonthly      = "sandbox_savings_monthly"
        case sandboxRetirementSpending  = "sandbox_retirement_spending"
        case sandboxReturnRate          = "sandbox_return_rate"
        case sandboxInflationRate       = "sandbox_inflation_rate"
        case sandboxWithdrawalRate      = "sandbox_withdrawal_rate"
        case sandboxTargetAge           = "sandbox_target_age"
    }

    /// Convenience: demo mode with no official data
    static func demo(
        retirementSpending: Double = 5000,
        netWorth: Double = 50000,
        sandboxSavings: Double? = nil
    ) -> SimulatorPreviewRequest {
        var req = SimulatorPreviewRequest(mode: "demo")
        req.officialRetirementSpending = retirementSpending
        req.officialNetWorth = netWorth
        req.sandboxSavingsMonthly = sandboxSavings
        return req
    }

    /// Convenience: official preview — server loads official anchors from DB
    static func officialPreview(
        sandboxSavings: Double? = nil,
        sandboxSpending: Double? = nil,
        sandboxReturn: Double? = nil,
        sandboxWithdrawal: Double? = nil,
        sandboxTargetAge: Int? = nil
    ) -> SimulatorPreviewRequest {
        var req = SimulatorPreviewRequest(mode: "official_preview")
        req.sandboxSavingsMonthly = sandboxSavings
        req.sandboxRetirementSpending = sandboxSpending
        req.sandboxReturnRate = sandboxReturn
        req.sandboxWithdrawalRate = sandboxWithdrawal
        req.sandboxTargetAge = sandboxTargetAge
        return req
    }
}
