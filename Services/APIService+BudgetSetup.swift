//
//  APIService+BudgetSetup.swift
//  Flamora app
//
//  API methods for Budget Setup flow (V2)
//  Uses authenticatedRequest + perform (same as other APIService calls)
//  for consistent auth (apikey + Authorization) and snake_case decoding
//

import Foundation

extension APIService {

    // MARK: - Account Selection

    /// Fetch user's connected Plaid accounts
    func getPlaidAccounts() async throws -> PlaidAccountsResponse {
        let request = try await authenticatedRequest(function: "get-plaid-accounts")
        return try await perform(request)
    }

    // MARK: - Goal Setup (v1 minimum — no target age required)

    /// Save a FIRE goal using the v1 spending-based minimum input.
    /// `targetRetirementAge` is optional — omit it in v1 onboarding.
    func saveFireGoal(data: SaveFireGoalRequest) async throws -> SaveFireGoalResponse {
        let body = try JSONEncoder().encode(data)
        let request = try await authenticatedRequest(function: "save-fire-goal", body: body)
        return try await perform(request)
    }

    // MARK: - Loading / Profile

    /// Fetch user profile for budget setup context
    func getUserProfileForBudget() async throws -> UserProfileForBudget {
        let request = try await authenticatedRequest(function: "get-user-profile")
        return try await perform(request)
    }

    /// Calculate spending stats from Plaid transactions (past 6 months)
    func calculateSpendingStats() async throws -> SpendingStatsResponse {
        let body = try JSONEncoder().encode(["months": 6])
        let request = try await authenticatedRequest(function: "calculate-spending-stats", body: body)
        return try await perform(request)
    }

    /// Generate AI-powered financial diagnosis
    func generateFinancialDiagnosis(data: DiagnosisRequestBody) async throws -> FinancialDiagnosisResponse {
        let body = try JSONEncoder().encode(data)
        let request = try await authenticatedRequest(function: "generate-financial-diagnosis", body: body)
        return try await perform(request)
    }

    // MARK: - Plan Generation

    /// Generate Steady / Recommended / Accelerate plans.
    /// Pass `fireNumber` or `retirementSpendingMonthly` in the request to enable
    /// FIRE date projections per plan (server fetches from fire_goals if absent).
    func generatePlans(data: GeneratePlansRequest) async throws -> PlansResponse {
        let body = try JSONEncoder().encode(data)
        let request = try await authenticatedRequest(function: "generate-plans", body: body)
        return try await perform(request)
    }

    // MARK: - Spending Plan (budget derivation)

    /// Translate selected savings rate into a concrete monthly budget.
    func generateSpendingPlan(data: GenerateSpendingPlanRequest) async throws -> SpendingPlanResponse {
        let body = try JSONEncoder().encode(data)
        let request = try await authenticatedRequest(function: "generate-spending-plan", body: body)
        return try await perform(request)
    }
}
