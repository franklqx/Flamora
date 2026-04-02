//
//  BudgetSetupViewModel.swift
//  Flamora app
//
//  V2 ViewModel for Budget Setup flow
//  - Step 1: Loading (calculate-spending-stats + AI diagnosis)
//  - Step 2: Financial Snapshot (income/expenses/savings + AI insights)
//  - Step 3: Spending Breakdown（Needs vs Wants；API 仍为 fixed/flexible 字段）
//  - Step 4: Choose your path (generate-plans → 3 plans + baseline)
//  - Step 5: Spending plan (ring chart + optional category budgets)
//  - Step 6: Confirm & save
//

import Foundation
import SwiftUI

@Observable
class BudgetSetupViewModel {
    private let budgetRoundingUnit: Double = 10
    
    // MARK: - Navigation
    
    enum Step: Int, CaseIterable {
        case accountSelection = 0
        case loading = 1
        case diagnosis = 2
        case spendingBreakdown = 3
        case choosePath = 4
        case spendingPlan = 5
        case confirm = 6
    }

    var currentStep: Step = .accountSelection
    var isNavigatingForward = true

    // MARK: - Step 0: Account Selection

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
    
    // MARK: - Step 3: Plans
    
    var plansResponse: PlansResponse?
    var isLoadingPlans = false
    
    enum PlanSelection: String, CaseIterable {
        case steady
        case recommended
        case accelerate
        case custom
    }
    
    var selectedPlanType: PlanSelection = .recommended
    var customSavingsRate: Double = 20
    
    var selectedPlan: PlanDetail? {
        guard let plans = plansResponse?.plans else { return nil }
        switch selectedPlanType {
        case .steady: return plans.steady
        case .recommended: return plans.recommended
        case .accelerate: return plans.accelerate
        case .custom: return buildCustomPlan()
        }
    }
    
    var baseline: BaselinePlan? { plansResponse?.baseline }
    var userTier: String { plansResponse?.userTier ?? "beginner" }

    var selectedPlanName: String {
        switch selectedPlanType {
        case .steady: return "Steady"
        case .recommended: return "Recommended"
        case .accelerate: return "Accelerate"
        case .custom: return "Custom"
        }
    }

    /// Compound growth from extra monthly savings only (not existing portfolio).
    /// Formula: FV = monthlyExtra × 12 × ((1.055^years - 1) / 0.055)
    func compoundGrowth(monthlyExtra: Double, years: Int) -> Double {
        let realReturn = 0.055
        let annualContribution = monthlyExtra * 12
        return annualContribution * ((pow(1 + realReturn, Double(years)) - 1) / realReturn)
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
    
    // MARK: - Custom Plan (client-side calculation)
    
    private func buildCustomPlan() -> PlanDetail {
        let income = spendingStats?.avgMonthlyIncome ?? monthlyIncome
        let savings = spendingStats?.avgMonthlySavings ?? 0
        let fixed = spendingStats?.avgMonthlyFixed ?? 0
        let flexible = spendingStats?.avgMonthlyFlexible ?? 0
        let rate = customSavingsRate
        
        let monthlySaveRaw = income * (rate / 100)
        let monthlySpendRaw = income - monthlySaveRaw
        let flexibleSpendRaw = max(0, monthlySpendRaw - fixed)
        let monthlySave = roundBudgetAmount(monthlySaveRaw)
        let monthlySpend = roundBudgetAmount(monthlySpendRaw)
        let flexibleSpend = roundBudgetAmount(flexibleSpendRaw)
        let extra = roundBudgetAmount(monthlySave - roundBudgetAmount(savings))
        let compressionPct = flexible > 0 ? (1 - flexibleSpend / flexible) * 100 : 0
        
        let p1y = projectPortfolio(monthlySavings: monthlySave, startingPortfolio: currentNetWorth, years: 1)
        let p5y = projectPortfolio(monthlySavings: monthlySave, startingPortfolio: currentNetWorth, years: 5)
        let p10y = projectPortfolio(monthlySavings: monthlySave, startingPortfolio: currentNetWorth, years: 10)
        
        let baselineP10y = baseline?.projection10y ?? projectPortfolio(
            monthlySavings: max(0, savings),
            startingPortfolio: currentNetWorth,
            years: 10
        )
        
        let currentRate = spendingStats?.currentSavingsRate ?? 0
        let jump = rate - currentRate
        let feasibility: String = {
            if jump <= 5 { return "easy" }
            if jump <= 15 { return "moderate" }
            if jump <= 30 { return "challenging" }
            return "extreme"
        }()
        
        return PlanDetail(
            savingsRate: roundPercentage(rate),
            monthlySave: monthlySave,
            monthlySpend: monthlySpend,
            flexibleSpend: flexibleSpend,
            extraPerMonth: extra,
            flexibleCompressionPct: compressionPct,
            projection1y: p1y,
            projection5y: p5y,
            projection10y: p10y,
            gainVsBaseline10y: p10y - baselineP10y,
            feasibility: feasibility,
            status: monthlySave < 0 ? "deficit" : (currentRate < 0 && monthlySave >= 0 ? "breakeven" : "on_track")
        )
    }

    private func roundBudgetAmount(_ value: Double) -> Double {
        (value / budgetRoundingUnit).rounded() * budgetRoundingUnit
    }

    private func roundPercentage(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
    
    /// Client-side compound growth projection (matches backend formula)
    private func projectPortfolio(monthlySavings: Double, startingPortfolio: Double, years: Int) -> Double {
        let monthlyRate = 0.055 / 12  // 5.5% real annual return
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
        loadingError = nil
        
        async let profileTask: () = loadProfile()
        async let statsTask: () = loadSpendingStats()
        
        await profileTask
        await statsTask
        
        if spendingStats != nil {
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
            let requestBody = GeneratePlansRequest(
                currentSavingsRate: stats.currentSavingsRate,
                avgMonthlyIncome: stats.avgMonthlyIncome,
                avgMonthlySavings: stats.avgMonthlySavings,
                avgMonthlyFixed: stats.avgMonthlyFixed,
                avgMonthlyFlexible: stats.avgMonthlyFlexible,
                currentNetWorth: currentNetWorth,
                currentAge: currentAge
            )
            
            let body = try JSONEncoder().encode(requestBody)
            let request = try await APIService.shared.authenticatedRequest(function: "generate-plans", body: body)
            let response: PlansResponse = try await APIService.shared.perform(request)
            plansResponse = response
            
            // Initialize custom rate to recommended plan's rate
            customSavingsRate = response.plans.recommended.savingsRate
            
            isLoadingPlans = false
            print("✅ [BudgetSetup] loadPlans success")
            print("   Steady: \(response.plans.steady.savingsRate)%, Recommended: \(response.plans.recommended.savingsRate)%, Accelerate: \(response.plans.accelerate.savingsRate)%")
            print("   User tier: \(response.userTier)")
        } catch {
            print("❌ [BudgetSetup] loadPlans error: \(error)")
            isLoadingPlans = false
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
    
    func goToStep(_ step: Step) {
        isNavigatingForward = step.rawValue > currentStep.rawValue
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = step
        }
    }
    
    func goBack() {
        var targetRaw = currentStep.rawValue - 1
        // Skip spendingPlan (step 5) — removed from the flow
        if targetRaw == Step.spendingPlan.rawValue {
            targetRaw -= 1
        }
        guard let previous = Step(rawValue: targetRaw),
              previous.rawValue >= Step.accountSelection.rawValue else { return }
        isNavigatingForward = false
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = previous
        }
    }
}
