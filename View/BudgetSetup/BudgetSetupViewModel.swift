//
//  BudgetSetupViewModel.swift
//  Flamora app
//
//  ViewModel for Budget Setup flow (Steps 1-5)
//  @Observable class — manages all state, API calls, and calculations
//

import Foundation
import SwiftUI

@Observable
class BudgetSetupViewModel {

    // MARK: - Navigation State

    enum Step: Int, CaseIterable {
        case loading = 1
        case diagnosis = 2
        case fireGoal = 3
        case setBudget = 4
        case confirm = 5
    }

    var currentStep: Step = .loading
    var isNavigatingForward = true

    // MARK: - Step 1: Loading State

    var isLoadingProfile = true
    var isLoadingSpending = true
    var isLoadingDiagnosis = true
    var loadingError: String?

    var allLoadingComplete: Bool {
        !isLoadingProfile && !isLoadingSpending && !isLoadingDiagnosis && loadingError == nil
    }

    // MARK: - User Profile Data

    var monthlyIncome: Double = 0
    var currentAge: Int = 28
    var currentNetWorth: Double = 0
    var currencyCode: String = "USD"

    // MARK: - Step 2: Diagnosis Data

    var avgSpending: AvgSpendingResponse?
    var diagnosis: FinancialDiagnosisResponse?

    // MARK: - Step 3: FIRE Goal Data

    var targetRetirementAge: Int = 45
    var minTargetAge: Int { currentAge + 5 }
    var maxTargetAge: Int { 75 }

    var isCalculating = false
    var hasCalculated = false
    var fireGoalResult: FireGoalResponse?

    var selectedPlanType: String?
    var selectedPlan: FireGoalPlan? {
        guard let result = fireGoalResult, let planType = selectedPlanType else { return nil }
        switch planType {
        case "current": return result.currentPath
        case "plan_a": return result.planA
        case "plan_b": return result.planB
        case "recommended": return result.recommended
        default: return nil
        }
    }

    // MARK: - Step 4: Budget Allocation

    var savingsAmount: Double {
        guard let plan = selectedPlan else { return 0 }
        return monthlyIncome * (plan.savingsRate / 100)
    }

    var remaining: Double {
        monthlyIncome - savingsAmount
    }

    var needsBudget: Double = 0 {
        didSet { recalculateWants() }
    }
    var wantsBudget: Double = 0
    var needsCategories: [SpendingCategory] = []
    var needsWarning: NeedsWarning = .none

    enum NeedsWarning {
        case none
        case belowAverage
        case significantlyBelow
        case noRoomForWants
    }

    var wantsComparisonAmount: Double {
        guard let avg = avgSpending else { return 0 }
        return wantsBudget - avg.avgMonthlyWants
    }

    // MARK: - Step 5: Confirm

    var isSaving = false
    var saveError: String?

    var needsRatio: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (needsBudget / monthlyIncome) * 100
    }

    var wantsRatio: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (wantsBudget / monthlyIncome) * 100
    }

    var savingsRatio: Double {
        guard let plan = selectedPlan else { return 0 }
        return plan.savingsRate
    }

    var freedomAge: Int {
        guard let plan = selectedPlan else { return 0 }
        let monthlySavings = plan.monthlySavings
        var accumulated = currentNetWorth
        var years = 0
        let fireNumber = fireGoalResult?.fireNumber ?? 0
        guard fireNumber > 0 else { return 0 }
        while accumulated < fireNumber && years < 100 {
            accumulated = accumulated * 1.09 + monthlySavings * 12
            years += 1
        }
        return currentAge + years
    }

    var currencySymbol: String {
        let locale = Locale(identifier: "en_US")
        return locale.currencySymbol ?? "$"
    }

    // MARK: - API Calls

    func loadInitialData() async {
        loadingError = nil

        async let profileTask: () = loadProfile()
        async let spendingTask: () = loadSpending()

        await profileTask
        await spendingTask

        if avgSpending != nil {
            await loadDiagnosis()
        } else {
            isLoadingDiagnosis = false
        }
    }

    private func loadProfile() async {
        do {
            let request = try await APIService.shared.authenticatedRequest(function: "get-user-profile")
            let profile: UserProfileForBudget = try await APIService.shared.perform(request)

            monthlyIncome = profile.monthlyIncome
            currentAge = profile.age
            currentNetWorth = profile.plaidNetWorth ?? profile.currentNetWorth
            currencyCode = profile.currencyCode
            targetRetirementAge = min(max(currentAge + 15, minTargetAge), maxTargetAge)
            isLoadingProfile = false
            print("✅ [BudgetSetup] loadProfile success — income: \(monthlyIncome), age: \(currentAge)")
        } catch {
            print("❌ [BudgetSetup] loadProfile error type: \(type(of: error))")
            print("❌ [BudgetSetup] loadProfile error detail: \(String(describing: error))")
            loadingError = "Failed to load your profile."
            isLoadingProfile = false
        }
    }

    private func loadSpending() async {
        do {
            let body = try JSONEncoder().encode(["months": 6])
            let request = try await APIService.shared.authenticatedRequest(function: "calculate-avg-spending", body: body)
            let spending: AvgSpendingResponse = try await APIService.shared.perform(request)
            avgSpending = spending
            isLoadingSpending = false
            print("✅ [BudgetSetup] loadSpending success — avg: \(avgSpending?.avgMonthlySpending ?? 0)")
        } catch {
            print("❌ [BudgetSetup] loadSpending error type: \(type(of: error))")
            print("❌ [BudgetSetup] loadSpending error detail: \(String(describing: error))")
            loadingError = "Failed to analyze your spending."
            isLoadingSpending = false
        }
    }

    private func loadDiagnosis() async {
        guard let spending = avgSpending else {
            isLoadingDiagnosis = false
            return
        }
        do {
            let requestBody = DiagnosisRequestBody(
                manualIncome: monthlyIncome,
                avgMonthlySpending: spending.avgMonthlySpending,
                avgMonthlyNeeds: spending.avgMonthlyNeeds,
                avgMonthlyWants: spending.avgMonthlyWants,
                avgMonthlyIncomeDetected: spending.avgMonthlyIncomeDetected,
                monthsAnalyzed: spending.monthsAnalyzed,
                monthlyBreakdown: spending.monthlyBreakdown,
                incomeDiscrepancy: spending.incomeDiscrepancy,
                fallback: spending.fallback,
                plaidNetWorth: currentNetWorth,
                age: currentAge
            )
            diagnosis = try await APIService.shared.generateFinancialDiagnosis(data: requestBody)
            isLoadingDiagnosis = false
            print("✅ [BudgetSetup] loadDiagnosis success")
        } catch {
            print("❌ [BudgetSetup] loadDiagnosis error: \(error)")
            isLoadingDiagnosis = false
        }
    }

    func calculateFireGoal() async {
        isCalculating = true
        do {
            fireGoalResult = try await APIService.shared.calculateFireGoal(
                targetRetirementAge: targetRetirementAge
            )

            if let result = fireGoalResult {
                switch result.effectivePhaseSub {
                case "0a", "0b", "0c":
                    selectedPlanType = "current"
                case "0d":
                    selectedPlanType = "plan_a"
                default:
                    selectedPlanType = nil
                }
            }

            hasCalculated = true
            isCalculating = false
        } catch {
            print("❌ [BudgetSetup] calculateFireGoal error: \(error)")
            isCalculating = false
        }
    }

    func saveFireGoalAndProceed() async -> Bool {
        guard let result = fireGoalResult,
              let plan = selectedPlan,
              let planType = selectedPlanType else { return false }

        isSaving = true
        do {
            let request = SaveFireGoalRequest(
                currentAge: currentAge,
                targetRetirementAge: plan.retirementAge,
                desiredMonthlyExpenses: Double(result.fireNumber) / 300.0,
                fireNumber: result.fireNumber,
                requiredMonthlyContribution: plan.monthlySavings,
                requiredSavingsRate: plan.savingsRate,
                selectedPlan: planType,
                adjustmentPhase: result.phase,
                adjustmentPhaseSub: result.effectivePhaseSub,
                adjustmentStrategy: result.strategy
            )
            _ = try await APIService.shared.saveFireGoal(request)

            initializeBudgetDefaults()

            isSaving = false
            return true
        } catch {
            print("❌ [BudgetSetup] saveFireGoal error: \(error)")
            saveError = "Failed to save your plan. Please try again."
            isSaving = false
            return false
        }
    }

    func initializeBudgetDefaults() {
        guard let spending = avgSpending else {
            needsBudget = remaining * 0.60
            wantsBudget = remaining * 0.40
            return
        }

        if spending.avgMonthlyNeeds <= remaining {
            needsBudget = spending.avgMonthlyNeeds
        } else if spending.avgMonthlyNeeds <= remaining * 1.2 {
            needsBudget = remaining
            needsWarning = .noRoomForWants
        } else {
            needsBudget = remaining * 0.85
            needsWarning = .noRoomForWants
        }

        recalculateWants()

        Task {
            await loadNeedsCategories()
        }
    }

    private func loadNeedsCategories() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        let currentMonth = dateFormatter.string(from: Date())

        do {
            let summary = try await APIService.shared.getSpendingSummaryForSetup(month: currentMonth)
            needsCategories = summary.categories.filter { $0.flamoraCategory == "needs" }
        } catch {
            print("❌ [BudgetSetup] loadNeedsCategories error: \(error)")
        }
    }

    func adjustNeeds(to newAmount: Double) {
        guard let spending = avgSpending else { return }

        let minNeeds = spending.avgMonthlyNeeds * 0.50
        let maxNeeds = remaining
        needsBudget = min(max(newAmount, minNeeds), maxNeeds)

        if needsBudget < spending.avgMonthlyNeeds * 0.90 {
            needsWarning = .significantlyBelow
        } else if needsBudget < spending.avgMonthlyNeeds {
            needsWarning = .belowAverage
        } else {
            needsWarning = .none
        }

        if wantsBudget <= 0 {
            needsWarning = .noRoomForWants
        }

        if spending.avgMonthlyNeeds > 0 {
            let scaleFactor = needsBudget / spending.avgMonthlyNeeds
            needsCategories = needsCategories.map { cat in
                SpendingCategory(
                    name: cat.name,
                    amount: cat.amount * scaleFactor,
                    flamoraCategory: cat.flamoraCategory
                )
            }
        }
    }

    private func recalculateWants() {
        wantsBudget = max(0, remaining - needsBudget)
    }

    func saveFinalBudget() async -> Bool {
        isSaving = true
        saveError = nil

        var finalNeedsRatio = round(needsRatio * 10) / 10
        var finalWantsRatio = round(wantsRatio * 10) / 10
        let finalSavingsRatio = savingsRatio

        let diff = 100.0 - (finalNeedsRatio + finalWantsRatio + finalSavingsRatio)
        finalWantsRatio += diff

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let monthString = dateFormatter.string(from: firstOfMonth)

        do {
            let request = GenerateMonthlyBudgetRequest(
                month: monthString,
                needsRatio: finalNeedsRatio,
                wantsRatio: finalWantsRatio,
                savingsRatio: finalSavingsRatio,
                source: "setup"
            )
            _ = try await APIService.shared.generateMonthlyBudget(request)
            isSaving = false
            return true
        } catch {
            print("❌ [BudgetSetup] saveFinalBudget error: \(error)")
            saveError = "Failed to save your budget. Please try again."
            isSaving = false
            return false
        }
    }

    // MARK: - Navigation

    func goToStep(_ step: Step) {
        isNavigatingForward = step.rawValue > currentStep.rawValue
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = step
        }
    }

    func goBack() {
        guard let previous = Step(rawValue: currentStep.rawValue - 1), previous.rawValue >= Step.diagnosis.rawValue else { return }
        isNavigatingForward = false
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = previous
        }
    }
}
