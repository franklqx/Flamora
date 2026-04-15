//
//  BudgetSetupViewModel.swift
//  Flamora app
//
//  V3 ViewModel for Budget Setup flow
//  Step 0: Goal Setup (retirement spending + lifestyle preset)
//  Step 1: Connect Accounts (Plaid)
//  Step 2: Loading (calculate-spending-stats + AI diagnosis)
//  Step 3: Accounts Review (confirm linked accounts)
//  Step 4: Financial Snapshot (diagnosis)
//  Step 5: Choose Plan (3 cards: Steady / Recommended / Accelerate)
//  Step 6: Apply Plan (confirm + apply-selected-plan)
//

import Foundation
import SwiftUI

@MainActor
@Observable
class BudgetSetupViewModel {
    private let budgetRoundingUnit: Double = 10

    // MARK: - Navigation

    enum Step: Int, CaseIterable {
        case goalSetup       = 0
        case accountSelection = 1
        case loading         = 2
        case accountsReview  = 3
        case diagnosis       = 4
        case choosePath      = 5
        case confirm         = 6
    }

    var currentStep: Step = .goalSetup
    var isNavigatingForward = true
    var postLoadingStep: Step = .accountsReview
    var isResumingState = true

    // MARK: - Step 0: Goal Setup

    var retirementSpendingMonthly: Double = 0
    var targetRetirementAge: Int = 0
    var lifestylePreset: String = "current"   // "lean" | "current" | "fat"
    var isSavingGoal = false
    var goalSaveError: String?

    // MARK: - Step 1: Account Selection

    var plaidAccounts: [PlaidAccountItem] = []
    var selectedAccountIds: Set<String> = []
    var isLoadingAccounts = false
    var accountsError: String?

    var hasTransactionAccounts: Bool {
        plaidAccounts.contains { ["depository", "credit"].contains($0.type) }
    }

    var selectedTransactionAccountCount: Int {
        plaidAccounts.filter { selectedAccountIds.contains($0.id) && ["depository", "credit"].contains($0.type) }.count
    }

    var canProceedFromAccountSelection: Bool {
        selectedTransactionAccountCount > 0
    }

    // MARK: - Step 1: Loading State
    
    var isLoadingProfile = true
    var isLoadingStats = true
    var isLoadingDiagnosis = true
    var loadingError: String?
    
    var allLoadingComplete: Bool {
        !isLoadingProfile && !isLoadingStats && !isLoadingDiagnosis && loadingError == nil
    }
    
    // MARK: - User Profile Data
    
    var monthlyIncome: Double = 0
    var currentAge: Int = 28
    var currentNetWorth: Double = 0
    var currencyCode: String = "USD"
    
    // MARK: - Step 2: Spending Stats & Diagnosis

    var spendingStats: SpendingStatsResponse?
    var diagnosis: FinancialDiagnosisResponse?
    var goalFeasibility: GoalFeasibilityResult? = nil
    var isLoadingFeasibility = false
    
    // MARK: - Step 3: Plans
    
    var plansResponse: PlansResponse?
    var isLoadingPlans = false
    
    enum PlanSelection: String, CaseIterable {
        case steady
        case recommended
        case accelerate
    }

    var selectedPlanType: PlanSelection = .recommended

    var selectedPlan: PlanDetail? {
        guard let plans = plansResponse?.plans else { return nil }
        switch selectedPlanType {
        case .steady:       return plans.steady
        case .recommended:  return plans.recommended
        case .accelerate:   return plans.accelerate
        }
    }

    var baseline: BaselinePlan? { plansResponse?.baseline }
    var userTier: String { plansResponse?.userTier ?? "beginner" }

    var selectedPlanName: String {
        switch selectedPlanType {
        case .steady:       return "Steady"
        case .recommended:  return "Recommended"
        case .accelerate:   return "Accelerate"
        }
    }

    // MARK: - Step 4: Spending Plan
    
    var spendingPlan: SpendingPlanResponse?
    var isLoadingSpendingPlan = false
    
    // Editable Wants 分项金额（API `flexibleBudget`；用户可在后续步骤调整）
    var editedFlexibleAmounts: [String: Double] = [:]

    // Optional per-category budgets (user opts in per category in Step 5)
    var categoryBudgets: [String: Double] = [:]
    var showCategoryBudgets = false
    
    var effectiveFlexibleItems: [FlexibleBudgetItem] {
        guard let items = spendingPlan?.flexibleBudget.items else { return [] }
        return items.map { item in
            if let edited = editedFlexibleAmounts[item.subcategory] {
                return FlexibleBudgetItem(
                    subcategory: item.subcategory,
                    suggestedAmount: edited,
                    historicalAvg: item.historicalAvg,
                    changePct: item.historicalAvg > 0
                        ? ((edited - item.historicalAvg) / item.historicalAvg) * 100
                        : 0
                )
            }
            return item
        }
    }
    
    var totalEditedFlexible: Double {
        effectiveFlexibleItems.reduce(0) { $0 + $1.suggestedAmount }
    }
    
    var flexibleBudgetRemaining: Double {
        (spendingPlan?.flexibleBudget.total ?? 0) - totalEditedFlexible
    }
    
    // MARK: - Step 5: Save State
    
    var isSaving = false
    var saveError: String?
    /// 生成 spending plan（进确认页前）失败时的说明，供 Choose Path 提示。
    var spendingPlanError: String?
    
    // MARK: - Currency Helper
    
    var currencySymbol: String {
        let locale = Locale(identifier: "en_US")
        return locale.currencySymbol ?? "$"
    }
    
    private func roundBudgetAmount(_ value: Double) -> Double {
        (value / budgetRoundingUnit).rounded() * budgetRoundingUnit
    }

    private func roundPercentage(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
    
    /// Client-side compound growth projection (matches backend formula)
    private func projectPortfolio(monthlySavings: Double, startingPortfolio: Double, years: Int) -> Double {
        let monthlyRate = FIREAssumptions.realAnnualReturn / 12
        var portfolio = startingPortfolio
        let totalMonths = years * 12
        
        for _ in 0..<totalMonths {
            portfolio = portfolio * (1 + monthlyRate) + monthlySavings
        }
        
        return (portfolio * 100).rounded() / 100
    }
    
    // MARK: - API Calls

    func loadAccounts() async {
        isLoadingAccounts = true
        accountsError = nil
        do {
            let response = try await APIService.shared.getPlaidAccounts()
            plaidAccounts = response.accounts

            // 默认选中 depository 和 credit 类型
            selectedAccountIds = Set(
                response.accounts
                    .filter { ["depository", "credit"].contains($0.type) }
                    .map { $0.id }
            )

            isLoadingAccounts = false
            print("✅ [BudgetSetup] loadAccounts success — \(response.totalAccounts) accounts")
        } catch {
            print("❌ [BudgetSetup] loadAccounts error: \(error)")
            accountsError = "Failed to load your accounts."
            isLoadingAccounts = false
        }
    }

    func toggleAccount(_ accountId: String) {
        if selectedAccountIds.contains(accountId) {
            selectedAccountIds.remove(accountId)
        } else {
            selectedAccountIds.insert(accountId)
        }
    }

    func refreshAccountsAfterNewConnection() async {
        await loadAccounts()
    }

    func loadInitialData() async {
        isLoadingProfile = true
        isLoadingStats = true
        isLoadingDiagnosis = true
        loadingError = nil

        async let profileTask: () = loadProfile()
        async let statsTask: () = loadSpendingStats()

        await profileTask
        await statsTask

        // Restore goal fields from DB — covers old users, mid-flow exits, multi-device
        await restoreFromActiveFireGoal()

        if spendingStats != nil {
            await loadDiagnosis()
        } else {
            isLoadingDiagnosis = false
        }

        await loadGoalFeasibility()
    }

    private func restoreFromActiveFireGoal() async {
        do {
            let goal = try await APIService.shared.getActiveFireGoal()
            if let spending = goal.retirementSpendingMonthly, spending > 0 {
                retirementSpendingMonthly = spending
            }
            if let age = goal.targetRetirementAge, age > 0 {
                targetRetirementAge = age
            }
        } catch {
            print("⚠️ [BudgetSetup] no active fire goal to restore: \(error)")
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
            isLoadingProfile = false
            print("✅ [BudgetSetup] loadProfile success — income: \(monthlyIncome), age: \(currentAge)")
        } catch {
            print("❌ [BudgetSetup] loadProfile error: \(error)")
            loadingError = "Failed to load your profile."
            isLoadingProfile = false
        }
    }
    
    private func loadSpendingStats() async {
        do {
            var requestBody: [String: Any] = ["months": 6]
            if !selectedAccountIds.isEmpty {
                requestBody["account_ids"] = Array(selectedAccountIds)
            }
            let body = try JSONSerialization.data(withJSONObject: requestBody)
            let request = try await APIService.shared.authenticatedRequest(function: "calculate-spending-stats", body: body)
            let response: SpendingStatsResponse = try await APIService.shared.perform(request)
            spendingStats = response
            
            // Update income from Plaid if available
            if response.incomeSource == "plaid" && response.avgMonthlyIncome > 0 {
                monthlyIncome = response.avgMonthlyIncome
            }
            
            isLoadingStats = false
            print("✅ [BudgetSetup] loadSpendingStats success — income: \(response.avgMonthlyIncome), savings rate: \(response.currentSavingsRate)%")
            print("   Needs (avg_monthly_fixed): $\(response.avgMonthlyFixed), Wants (avg_monthly_flexible): $\(response.avgMonthlyFlexible)")
            print("   Needs line items: \(response.fixedExpenses.count), Wants categories: \(response.flexibleBreakdown.count)")
            print("   monthlyBreakdown (\(response.monthlyBreakdown.count) months):")
            for item in response.monthlyBreakdown {
                print("     \(item.month): income=\(item.income), needs=\(item.fixed), wants=\(item.flexible), savings=\(item.savings)")
            }
        } catch {
            print("❌ [BudgetSetup] loadSpendingStats error: \(error)")
            loadingError = "Failed to analyze your spending."
            isLoadingStats = false
        }
    }
    
    func loadGoalFeasibility() async {
        guard targetRetirementAge > 0,
              retirementSpendingMonthly > 0,
              let stats = spendingStats else { return }

        isLoadingFeasibility = true
        do {
            goalFeasibility = try await APIService.shared.calculateFireGoal(
                targetRetirementAge: targetRetirementAge,
                monthlyIncome: stats.avgMonthlyIncome,
                currentMonthlyExpenses: stats.avgMonthlyExpenses,
                desiredMonthlyExpenses: retirementSpendingMonthly,
                currentNetWorth: currentNetWorth > 0 ? currentNetWorth : nil,
                currentAge: currentAge > 0 ? currentAge : nil
            )
            print("✅ [BudgetSetup] loadGoalFeasibility success — phase: \(goalFeasibility?.phase ?? -1), achievable: \(goalFeasibility?.isAchievable ?? false)")
        } catch {
            print("❌ [BudgetSetup] loadGoalFeasibility error: \(error)")
        }
        isLoadingFeasibility = false
    }

    private func loadDiagnosis() async {
        guard let stats = spendingStats else {
            isLoadingDiagnosis = false
            return
        }
        
        do {
            // Map V2 stats to V1 diagnosis request format (reuse existing AI function)
            let breakdown = stats.monthlyBreakdown.map { item in
                MonthlyBreakdownForDiagnosis(
                    month: item.month,
                    needs: item.fixed,
                    wants: item.flexible,
                    total: item.fixed + item.flexible
                )
            }
            
            let requestBody = DiagnosisRequestBody(
                manualIncome: monthlyIncome,
                avgMonthlySpending: stats.avgMonthlyExpenses,
                avgMonthlyNeeds: stats.avgMonthlyFixed,
                avgMonthlyWants: stats.avgMonthlyFlexible,
                avgMonthlyIncomeDetected: stats.incomeSource == "plaid" ? stats.avgMonthlyIncome : 0,
                monthsAnalyzed: stats.monthsAnalyzed,
                monthlyBreakdown: breakdown,
                incomeDiscrepancy: false,
                fallback: stats.dataQuality == "limited",
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
    
    func loadPlans() async {
        guard let stats = spendingStats else { return }

        isLoadingPlans = true
        do {
            var requestBody = GeneratePlansRequest(
                currentSavingsRate: stats.currentSavingsRate,
                avgMonthlyIncome: stats.avgMonthlyIncome,
                avgMonthlySavings: stats.avgMonthlySavings,
                avgMonthlyFixed: stats.avgMonthlyFixed,
                avgMonthlyFlexible: stats.avgMonthlyFlexible,
                currentNetWorth: currentNetWorth,
                currentAge: currentAge
            )
            // Transmit latest ViewModel goal values as override (Step 4 → Step 5 drift safety).
            // Server priority: request override > fire_goals active row > null.
            if retirementSpendingMonthly > 0 {
                requestBody.retirementSpendingMonthly = retirementSpendingMonthly
            }
            if targetRetirementAge > 0 {
                requestBody.targetRetirementAge = targetRetirementAge
            }
            if !selectedAccountIds.isEmpty {
                requestBody.accountIds = Array(selectedAccountIds)
            }
            requestBody.month = DateFormatter.currentMonthString

            let response = try await APIService.shared.generatePlans(data: requestBody)
            plansResponse = response

            isLoadingPlans = false
            print("✅ [BudgetSetup] loadPlans success")
            print("   Steady: \(response.plans.steady.savingsRate)%, Recommended: \(response.plans.recommended.savingsRate)%, Accelerate: \(response.plans.accelerate.savingsRate)%")
            print("   User tier: \(response.userTier), phase: \(response.phase ?? -1), goalDriven: \(response.goalDriven ?? false)")
        } catch {
            print("❌ [BudgetSetup] loadPlans error: \(error)")
            isLoadingPlans = false
        }
    }

    // MARK: - Goal Setup API

    func saveFireGoal() async -> Bool {
        guard retirementSpendingMonthly > 0 else {
            goalSaveError = "Please enter your expected monthly spending in retirement."
            return false
        }
        isSavingGoal = true
        goalSaveError = nil
        do {
            var request = SaveFireGoalRequest(
                retirementSpendingMonthly: retirementSpendingMonthly,
                lifestylePreset: lifestylePreset
            )
            if targetRetirementAge > 0 { request.targetRetirementAge = targetRetirementAge }
            if currentAge > 0 { request.currentAge = currentAge }
            _ = try await APIService.shared.saveFireGoal(data: request)
            isSavingGoal = false
            return true
        } catch {
            print("❌ [BudgetSetup] saveFireGoal error: \(error)")
            goalSaveError = "Failed to save your goal. Please try again."
            isSavingGoal = false
            return false
        }
    }

    // MARK: - Apply Plan API

    func applyPlan() async -> Bool {
        guard let plan = selectedPlan else { return false }
        do {
            let request = ApplyPlanRequest.from(planDetail: plan, planType: selectedPlanType.rawValue)
            _ = try await APIService.shared.applySelectedPlan(data: request)
            try await APIService.shared.markSetupStep("snapshot_reviewed")
            print("✅ [BudgetSetup] applyPlan success")
            return true
        } catch {
            print("❌ [BudgetSetup] applyPlan error: \(error)")
            return false
        }
    }

    /// Finalize the setup flow in a safer order:
    /// 1. Save the derived monthly budget
    /// 2. Apply the chosen plan as the official active plan
    ///
    /// This avoids the worse failure mode where an official active plan is written
    /// but the budget layer never saves.
    func finalizeSetup() async -> Bool {
        let budgetSaved = await saveFinalBudget()
        guard budgetSaved else { return false }

        let planApplied = await applyPlan()
        if !planApplied {
            saveError = "Your budget was saved, but we couldn't activate this plan. Please try again."
        }
        return planApplied
    }

    /// Continue from Connected Accounts Review.
    /// If initial stats are already loaded, go straight to diagnosis.
    /// Otherwise, enter loading and continue to diagnosis after loading completes.
    func continueFromAccountsReview() async {
        do {
            try await APIService.shared.markSetupStep("accounts_reviewed")
        } catch {
            print("⚠️ [BudgetSetup] mark accounts_reviewed failed: \(error)")
        }

        await MainActor.run {
            if spendingStats != nil && diagnosis != nil && loadingError == nil {
                goToStep(.diagnosis)
            } else {
                prepareLoading(nextStep: .diagnosis)
                goToStep(.loading)
            }
        }
    }

    // MARK: - Setup Resume

    /// Reads the server-side setup state and advances currentStep to the correct resume point.
    func resumeFromSetupState() async {
        defer { isResumingState = false }

        // Restore goal fields before routing so we can check targetRetirementAge
        await restoreFromActiveFireGoal()

        do {
            let state = try await APIService.shared.getSetupState()

            // Intercept: goal exists but targetRetirementAge was never filled in
            // (old users created before S1-1). Must complete goal setup before continuing.
            if state.resumeStage != .noGoal && targetRetirementAge == 0 {
                goalSaveError = "We need one more detail — please set your target retirement age to continue."
                currentStep = .goalSetup
                print("⚠️ [BudgetSetup] intercepted: goal exists but targetRetirementAge == nil → goalSetup")
                return
            }

            switch state.resumeStage {
            case .noGoal:
                currentStep = .goalSetup
            case .goalSet:
                currentStep = .accountSelection
            case .accountsLinked:
                if plaidAccounts.isEmpty {
                    await loadAccounts()
                }
                currentStep = .accountsReview
            case .snapshotPending:
                prepareLoading(nextStep: .diagnosis)
                currentStep = .loading
            case .planPending:
                prepareLoading(nextStep: .choosePath)
                currentStep = .loading
            case .active:
                prepareLoading(nextStep: .choosePath)
                currentStep = .loading
            }
            print("✅ [BudgetSetup] resumeFromSetupState → \(state.resumeStage)")
        } catch {
            print("⚠️ [BudgetSetup] resumeFromSetupState failed (starting fresh): \(error)")
        }
    }
    
    func loadSpendingPlan() async {
        spendingPlanError = nil
        isLoadingSpendingPlan = true
        defer { isLoadingSpendingPlan = false }

        guard let stats = spendingStats, let plan = selectedPlan else {
            spendingPlanError = "Missing spending data or plan. Go back and try again."
            return
        }

        editedFlexibleAmounts = [:]  // Reset edits

        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let calendar = Calendar.current
            let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let monthString = dateFormatter.string(from: firstOfMonth)
            
            let fixedInputs = stats.fixedExpenses.map { item in
                FixedExpenseInput(
                    name: item.name,
                    pfcDetailed: item.pfcDetailed,
                    monthlyAmount: item.avgMonthlyAmount,
                    isUserCorrected: false
                )
            }
            
            let flexInputs = stats.flexibleBreakdown.map { item in
                FlexibleBreakdownInput(
                    subcategory: item.subcategory,
                    avgMonthlyAmount: item.avgMonthlyAmount,
                    shareOfFlexible: item.shareOfFlexible
                )
            }
            
            let requestBody = GenerateSpendingPlanRequest(
                selectedPlanRate: plan.savingsRate,
                selectedPlanName: selectedPlanType.rawValue,
                avgMonthlyIncome: stats.avgMonthlyIncome,
                fixedExpenses: fixedInputs,
                flexibleBreakdown: flexInputs,
                month: monthString
            )
            
            let body = try JSONEncoder().encode(requestBody)
            let request = try await APIService.shared.authenticatedRequest(function: "generate-spending-plan", body: body)
            let response: SpendingPlanResponse = try await APIService.shared.perform(request)
            spendingPlan = response

            print("✅ [BudgetSetup] loadSpendingPlan success")
            print("   Savings: $\(response.totalSavings), Needs budget: $\(response.fixedBudget.total), Wants budget: $\(response.flexibleBudget.total)")
        } catch {
            print("❌ [BudgetSetup] loadSpendingPlan error: \(error)")
            spendingPlanError = "Couldn’t build your spending plan. Check your connection and try again."
        }
    }
    
    func updateFlexibleAmount(subcategory: String, amount: Double) {
        editedFlexibleAmounts[subcategory] = max(0, amount)
    }
    
    func saveFinalBudget() async -> Bool {
        guard let plan = spendingPlan else { return false }
        
        isSaving = true
        saveError = nil
        
        do {
            // Use the existing generate-monthly-budget endpoint for backward compatibility
            // Map V2 data to V1 format
            let savingsRatio = plan.ratios?.savings ?? plan.planRate
            let fixedRatio = plan.ratios?.fixed ?? 0
            let flexibleRatio = plan.ratios?.flexible ?? 0
            
            // Ensure ratios sum to 100
            let total = savingsRatio + fixedRatio + flexibleRatio
            let adjustedFlexible = flexibleRatio + (100 - total)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let calendar = Calendar.current
            let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let monthString = dateFormatter.string(from: firstOfMonth)
            
            // Build upsert body directly.
            // UI 使用 Needs/Wants；`plan.fixedBudget` / `flexibleBudget` 与 API 字段名仍对应 needs/wants 预算（阶段 1 / 路线图 1.4）。
            var upsertBody: [String: Any] = [
                "month": monthString,
                "needs_ratio": fixedRatio,
                "wants_ratio": adjustedFlexible,
                "savings_ratio": savingsRatio,
                "needs_budget": plan.fixedBudget.total,
                "wants_budget": plan.flexibleBudget.total,
                "savings_budget": plan.totalSavings,
                "savings_rate": plan.planRate,
                "fixed_budget": plan.fixedBudget.total,
                "flexible_budget": plan.flexibleBudget.total,
                "selected_plan": plan.planName,
                "source": "setup"
            ]

            // Include user-set category budgets if any
            if !categoryBudgets.isEmpty {
                upsertBody["category_budgets"] = categoryBudgets
            }
            
            let body = try JSONSerialization.data(withJSONObject: upsertBody)
            let request = try await APIService.shared.authenticatedRequest(function: "generate-monthly-budget", body: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ [BudgetSetup] saveFinalBudget HTTP \(statusCode): \(body)")
                throw APIError.httpError(statusCode)
            }
            print("✅ [BudgetSetup] saveFinalBudget success")
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

    func prepareLoading(nextStep: Step) {
        postLoadingStep = nextStep
        loadingError = nil
        isLoadingProfile = true
        isLoadingStats = true
        isLoadingDiagnosis = true
    }
    
    func goToStep(_ step: Step) {
        isNavigatingForward = step.rawValue > currentStep.rawValue
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = step
        }
    }
    
    func goBack() {
        let targetRaw = currentStep.rawValue - 1
        guard let previous = Step(rawValue: targetRaw),
              previous.rawValue >= Step.goalSetup.rawValue else { return }
        isNavigatingForward = false
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = previous
        }
    }
}
