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

    /// Generate dynamic 1-3 budget plans aligned to the Phase C/D contract.
    /// Server returns `plans[]` plus committed defaults for Step 5 → Step 6 handoff.
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

    // MARK: - Goal Feasibility

    /// Calculate FIRE goal feasibility given target retirement age and spending data.
    /// Backend fetches profile defaults for any omitted optional fields.
    func calculateFireGoal(
        targetRetirementAge: Int,
        monthlyIncome: Double,
        currentMonthlyExpenses: Double,
        desiredMonthlyExpenses: Double,
        currentNetWorth: Double?,
        currentAge: Int?,
        startingPortfolioBalance: Double? = nil
    ) async throws -> GoalFeasibilityResult {
        var body: [String: Any] = [
            "target_retirement_age": targetRetirementAge,
            "monthly_income": monthlyIncome,
            "current_monthly_expenses": currentMonthlyExpenses,
            "desired_monthly_expenses": desiredMonthlyExpenses,
        ]
        if let nw = currentNetWorth, nw > 0 { body["current_net_worth"] = nw }
        if let startingPortfolioBalance { body["starting_portfolio_balance"] = startingPortfolioBalance }
        if let age = currentAge, age > 0 { body["current_age"] = age }
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try await authenticatedRequest(function: "calculate-fire-goal", body: data)
        return try await perform(request)
    }

    // MARK: - Cash Flow in-place budget edit

    /// Upsert current monthly budget from Cash Flow edit mode.
    /// Reuses the existing `generate-monthly-budget` endpoint for compatibility.
    func upsertMonthlyBudget(payload: [String: Any]) async throws {
        print("▶️ [APIService] upsertMonthlyBudget START")
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try await authenticatedRequest(function: "generate-monthly-budget", body: body)
        print("▶️ [APIService] upsertMonthlyBudget request built, sending…")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("◀️ [APIService] upsertMonthlyBudget status=\(status) body=\(String(data: data, encoding: .utf8) ?? "<nil>")")
        guard (200...299).contains(status) else {
            throw APIError.httpError(status)
        }
    }
}
