//
//  APIService+BudgetSetup.swift
//  Flamora app
//
//  API methods for Budget Setup flow
//  Uses authenticatedRequest + perform (same as other APIService calls)
//  for consistent auth (apikey + Authorization) and snake_case decoding
//

import Foundation

extension APIService {

    // MARK: - Step 1: Loading (parallel calls)

    /// Fetch user profile for budget setup context
    func getUserProfileForBudget() async throws -> UserProfileForBudget {
        let request = try await authenticatedRequest(function: "get-user-profile")
        return try await perform(request)
    }

    /// Calculate average spending from Plaid transactions (past 6 months)
    func calculateAvgSpendingForSetup() async throws -> AvgSpendingResponse {
        let body = try JSONEncoder().encode(["months": 6])
        let request = try await authenticatedRequest(function: "calculate-avg-spending", body: body)
        return try await perform(request)
    }

    /// Generate AI-powered financial diagnosis
    func generateFinancialDiagnosis(data: DiagnosisRequestBody) async throws -> FinancialDiagnosisResponse {
        let body = try JSONEncoder().encode(data)
        let request = try await authenticatedRequest(function: "generate-financial-diagnosis", body: body)
        return try await perform(request)
    }

    // MARK: - Step 3: FIRE Goal

    /// Calculate FIRE goal with Plan A/B/Recommended
    func calculateFireGoal(targetRetirementAge: Int) async throws -> FireGoalResponse {
        let body = try JSONEncoder().encode(["target_retirement_age": targetRetirementAge])
        let request = try await authenticatedRequest(function: "calculate-fire-goal", body: body)
        return try await perform(request)
    }

    /// Save chosen FIRE goal plan
    func saveFireGoal(_ goal: SaveFireGoalRequest) async throws -> SaveFireGoalResponse {
        let body = try JSONEncoder().encode(goal)
        let request = try await authenticatedRequest(function: "save-fire-goal", body: body)
        return try await perform(request)
    }

    // MARK: - Step 4: Spending breakdown

    /// Get subcategory spending breakdown for current month
    func getSpendingSummaryForSetup(month: String) async throws -> SpendingSummaryResponse {
        let body = try JSONEncoder().encode(["month": month])
        let request = try await authenticatedRequest(function: "get-spending-summary", body: body)
        return try await perform(request)
    }

    // MARK: - Step 5: Save budget

    /// Generate and save monthly budget
    func generateMonthlyBudget(_ budget: GenerateMonthlyBudgetRequest) async throws -> APIMonthlyBudget {
        let body = try JSONEncoder().encode(budget)
        let request = try await authenticatedRequest(function: "generate-monthly-budget", body: body)
        return try await perform(request)
    }
}

// MARK: - Request body for generate-financial-diagnosis

struct DiagnosisRequestBody: Encodable {
    let manualIncome: Double
    let avgMonthlySpending: Double
    let avgMonthlyNeeds: Double
    let avgMonthlyWants: Double
    let avgMonthlyIncomeDetected: Double
    let monthsAnalyzed: Int
    let monthlyBreakdown: [MonthlySpendingBreakdown]
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
