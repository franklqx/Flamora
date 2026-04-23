//
//  BudgetSetupViewModel.swift
//  Flamora app
//
//  V3 ViewModel for Budget Setup flow (Phase E refactor — 6-step contract)
//  Step 1 Connect:  Plaid Link or Skip → manual 4 fields
//  Step 2 Loading:  calculate-spending-stats + (no AI diagnosis in V3)
//  Step 3 Reality:  3 metric blocks + sparkline + one-time note
//  Step 4 Target:   target age slider + retirement spending sheet
//  Step 5 Plan:     1-3 dynamic plans + custom save slider + caps sheet entry
//  Step 6 Confirm:  Monthly save · Monthly budget · FIRE progress
//

import Foundation
import SwiftUI

@MainActor
@Observable
class BudgetSetupViewModel {
    private let budgetRoundingUnit: Double = 10

    // MARK: - Navigation

    enum Step: Int, CaseIterable {
        case connect = 0
        case loading = 1
        case reality = 2
        case target  = 3
        case plan    = 4
        case confirm = 5
    }

    var currentStep: Step = .connect
    var isNavigatingForward = true
    var postLoadingStep: Step = .reality
    var isResumingState = true

    // MARK: - Step 4: Target (FIRE goal)

    var retirementSpendingMonthly: Double = 0
    var targetRetirementAge: Int = 0

    // MARK: - Step 1: Manual input branch (Skip Plaid)
    //
    // Per plan §"无 Plaid 手动输入分支": user enters 4 numbers, downstream
    // algorithm receives the same essentialFloor / avgWants / avgIncome /
    // netWorth shape as the Plaid path. essentialSpending is taken as a
    // direct floor (not multiplied by 0.6 — user already estimated essentials).

    var isManualMode: Bool = false
    var manualIncome: Double = 0
    var manualEssentialSpending: Double = 0
    var manualOtherSpending: Double = 0
    var manualNetWorth: Double = 0
    /// Manual-mode age input. Pre-filled from `loadProfile()` when an
    /// onboarding profile already supplies one; otherwise the user must
    /// enter it before continuing. `generate-plans` requires a current
    /// age (server returns 400 MISSING_CURRENT_AGE without it), so we
    /// hard-block the CTA rather than silently failing later.
    var manualAge: Int = 0

    var canProceedFromManualInput: Bool {
        manualIncome > 0
            && (manualEssentialSpending + manualOtherSpending) > 0
            && effectiveManualAge > 0
    }

    /// Resolve the age the manual flow will commit. Prefer the user's
    /// edit (`manualAge`); fall back to whatever onboarding stored on the
    /// profile (`currentAge`). Both can be 0 for a fresh-signup user that
    /// somehow reached manual mode without an onboarding profile.
    var effectiveManualAge: Int {
        if manualAge > 0 { return manualAge }
        if currentAge > 0 { return currentAge }
        return 0
    }

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

    var plans: [BudgetPlanOption] = []
    var isLoadingPlans = false
    var selectedPlanIndex: Int = 0
    var customSliderRange: CustomSliderRange?

    var committedSavingsRate: Double?
    var committedMonthlySave: Double?
    var committedSpendCeiling: Double?
    var committedPlanLabel: String?

    var selectedPlan: BudgetPlanOption? {
        guard plans.indices.contains(selectedPlanIndex) else { return nil }
        return plans[selectedPlanIndex]
    }

    var primaryPlan: BudgetPlanOption? { plans.first }

    var selectedPlanName: String {
        let rawLabel = committedPlanLabel ?? selectedPlan?.label ?? "target-aligned"
        return displayName(for: rawLabel)
    }

    var fireProgressRatio: Double {
        guard let selectedPlan else { return 0 }
        guard selectedPlan.fireNumber > 0 else { return 0 }
        return min(1, max(0, currentNetWorth / selectedPlan.fireNumber))
    }

    var hasCustomSaveAdjustment: Bool {
        customSliderRange?.isAvailable == true
    }

    var isUsingCustomPlan: Bool {
        committedPlanLabel == "custom"
    }

    var currentSnapshotIncome: Double {
        if isManualMode { return manualIncome }
        return spendingStats?.avgMonthlyIncome ?? monthlyIncome
    }

    var currentSnapshotSpend: Double {
        if isManualMode { return manualEssentialSpending + manualOtherSpending }
        return spendingStats?.avgMonthlyExpenses ?? 0
    }

    var currentSnapshotEssentialFloor: Double {
        if isManualMode { return manualEssentialSpending }
        return spendingStats?.essentialFloor ?? spendingStats?.avgMonthlyFixed ?? 0
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

    func displayName(for label: String) -> String {
        switch label {
        case "target-aligned": return "Target-aligned"
        case "closest_near": return "Closest reasonable"
        case "closest_far": return "Adjust target"
        case "already_fire": return "Already FIRE"
        case "comfortable": return "Comfortable"
        case "accelerated": return "Accelerated"
        case "custom": return "Custom"
        default:
            return label
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    func selectPlan(at index: Int) {
        guard plans.indices.contains(index) else { return }
        selectedPlanIndex = index
        syncCommittedState(with: plans[index])
    }

    private func syncCommittedState(with plan: BudgetPlanOption) {
        committedPlanLabel = plan.label
        committedMonthlySave = plan.monthlySave
        committedSavingsRate = plan.savingsRate
        committedSpendCeiling = plan.committedSpendCeiling
    }

    func resetCommittedToSelectedPlan() {
        guard let selectedPlan else { return }
        syncCommittedState(with: selectedPlan)
    }

    func applyCustomMonthlySave(_ value: Double) {
        let income = currentSnapshotIncome
        guard income > 0 else { return }
        let clamped = max(0, min(value, income))
        committedPlanLabel = "custom"
        committedMonthlySave = clamped
        committedSavingsRate = income > 0 ? clamped / income : 0
        committedSpendCeiling = max(0, income - clamped)
    }

    var committedProjectedFireAge: Int? {
        guard let selectedPlan else { return nil }
        guard let monthlySave = committedMonthlySave else { return selectedPlan.projectedFireAge }
        let months = FIREMath.monthsToFIRE(
            netWorth: currentNetWorth,
            monthlySave: monthlySave,
            fireNumber: selectedPlan.fireNumber,
            annualRealReturn: FIREAssumptions.realAnnualReturn
        )
        guard months.isFinite else { return nil }
        return currentAge + Int(ceil(months / 12))
    }

    var committedGapYears: Int {
        guard let committedProjectedFireAge else { return 0 }
        return max(0, committedProjectedFireAge - targetRetirementAge)
    }

    func seedDefaultsForTargetStep() {
        if retirementSpendingMonthly <= 0 {
            retirementSpendingMonthly = max(0, currentSnapshotSpend)
        }
        if targetRetirementAge <= currentAge {
            targetRetirementAge = max(currentAge + 1, min(80, currentAge + 15))
        }
    }

    func enterManualMode() {
        isManualMode = true
    }

    func exitManualMode() {
        isManualMode = false
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
        seedDefaultsForTargetStep()
        isLoadingDiagnosis = false
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
            // Seed manual-mode age from the profile so returning manual
            // users don't have to retype it. The CTA still requires
            // `effectiveManualAge > 0`; if the profile somehow has age 0
            // we fall through to the inline age input.
            if manualAge <= 0 && profile.age > 0 {
                manualAge = profile.age
            }
            isLoadingProfile = false
            print("✅ [BudgetSetup] loadProfile success — income: \(monthlyIncome), age: \(currentAge)")
        } catch {
            print("❌ [BudgetSetup] loadProfile error: \(error)")
            loadingError = "Failed to load your profile."
            isLoadingProfile = false
        }
    }
    
    /// Push the latest manual numbers into `user_profiles` so downstream
    /// readers (Home Hero, `get-active-fire-goal`, `generate-plans`) see the
    /// values the user just typed instead of whatever onboarding stored.
    /// Idempotent and safe to call repeatedly. Best-effort — failures are
    /// logged but never bubble up, because the calling flow always carries
    /// the same numbers in its outgoing request bodies.
    private func syncManualProfileSnapshot() async {
        guard isManualMode else { return }

        let ageToSync: Int? = effectiveManualAge > 0 ? effectiveManualAge : nil
        let incomeToSync: Double? = manualIncome > 0 ? manualIncome : nil
        let netWorthToSync: Double? = manualNetWorth
        let expensesToSync: Double? = (manualEssentialSpending + manualOtherSpending) > 0
            ? (manualEssentialSpending + manualOtherSpending)
            : nil

        do {
            _ = try await APIService.shared.updateUserProfile(
                age: ageToSync,
                monthlyIncome: incomeToSync,
                currentNetWorth: netWorthToSync,
                currentMonthlyExpenses: expensesToSync,
                currencyCode: nil
            )
            print("✅ [BudgetSetup] syncManualProfileSnapshot success — age: \(ageToSync ?? -1), income: \(incomeToSync ?? -1), netWorth: \(netWorthToSync ?? .nan)")
        } catch {
            print("⚠️ [BudgetSetup] syncManualProfileSnapshot failed: \(error)")
        }
    }

    /// Called from the Target step when the user inline-edits their current
    /// age. Updates local state, pushes to the backend, clamps the target age
    /// slider, and invalidates any cached plans so a subsequent Plan-step
    /// visit re-runs `generate-plans` with the corrected age.
    /// Best-effort on the backend write — the local value is the source of
    /// truth for request bodies built later in the flow.
    func updateCurrentAge(_ newAge: Int) async {
        guard newAge > 0, newAge <= 120 else { return }
        let clamped = min(max(newAge, 1), 120)

        await MainActor.run {
            currentAge = clamped
            if isManualMode { manualAge = clamped }
            // Keep the target-age slider above currentAge.
            if targetRetirementAge <= clamped {
                targetRetirementAge = max(clamped + 1, min(80, clamped + 15))
            }
            // Invalidate cached plans so the next Plan-step visit refetches
            // with the corrected age. Also clear committedDefaults — those
            // were computed from the old age and would otherwise leak into
            // the Confirm step.
            plans = []
            selectedPlanIndex = 0
            committedPlanLabel = nil
            committedMonthlySave = nil
            committedSpendCeiling = nil
        }

        do {
            _ = try await APIService.shared.updateUserProfile(
                age: clamped,
                monthlyIncome: nil,
                currentNetWorth: nil,
                currentMonthlyExpenses: nil,
                currencyCode: nil
            )
            print("✅ [BudgetSetup] updateCurrentAge → \(clamped) synced to backend")
        } catch {
            print("⚠️ [BudgetSetup] updateCurrentAge backend sync failed (local still updated): \(error)")
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
                avgMonthlyExpenses: stats.avgMonthlyExpenses,
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
            requestBody.essentialFloor = stats.essentialFloor ?? stats.avgMonthlyFixed
            requestBody.avgWants = stats.avgWants ?? stats.avgMonthlyFlexible
            if !selectedAccountIds.isEmpty {
                requestBody.accountIds = Array(selectedAccountIds)
            }
            requestBody.month = DateFormatter.currentMonthString

            let response = try await APIService.shared.generatePlans(data: requestBody)
            plans = response.plans
            customSliderRange = response.customSlider
            selectedPlanIndex = 0

            if let primary = response.plans.first {
                syncCommittedState(with: primary)
            }
            committedPlanLabel = response.committedDefaults.committedPlanLabel
            committedMonthlySave = response.committedDefaults.committedMonthlySave
            committedSavingsRate = response.committedDefaults.committedSavingsRate
            committedSpendCeiling = response.committedDefaults.committedSpendCeiling

            isLoadingPlans = false
            print("✅ [BudgetSetup] loadPlans success")
            print("   Returned \(response.planCount) plan(s), primary: \(response.primaryPlanLabel)")
            if let primary = response.plans.first {
                print("   Primary save: $\(primary.monthlySave), budget: $\(primary.monthlyBudget), FIRE age: \(primary.projectedFireAge)")
            }
        } catch {
            print("❌ [BudgetSetup] loadPlans error: \(error)")
            isLoadingPlans = false
        }
    }

    // MARK: - Step 4 Target: Save FIRE goal
    //
    // V3: lifestylePreset removed entirely. retirementSpendingMonthly is the
    // direct dollar figure from the Step 4 sheet. saveFireGoal is now called
    // from Step 4 Continue, NOT from a dedicated Step 0 page.

    var isSavingGoal = false
    var goalSaveError: String?

    func saveFireGoal() async -> Bool {
        guard retirementSpendingMonthly > 0 else {
            goalSaveError = "Please enter your expected monthly spending in retirement."
            return false
        }
        guard targetRetirementAge > 0, targetRetirementAge > currentAge else {
            goalSaveError = "Please pick a target retirement age above your current age."
            return false
        }
        isSavingGoal = true
        goalSaveError = nil
        do {
            var request = SaveFireGoalRequest(
                retirementSpendingMonthly: retirementSpendingMonthly,
                lifestylePreset: nil
            )
            request.targetRetirementAge = targetRetirementAge
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
            let fixedBudgetMonthly = spendingPlan?.fixedBudget.total
                ?? min(plan.committedSpendCeiling, spendingStats?.avgMonthlyFixed ?? 0)
            let flexibleBudgetMonthly = spendingPlan?.flexibleBudget.total
                ?? max(0, plan.committedSpendCeiling - fixedBudgetMonthly)

            let request = ApplyPlanRequest.from(
                plan: plan,
                committedPlanLabel: committedPlanLabel ?? plan.label,
                fixedBudgetMonthly: fixedBudgetMonthly,
                flexibleBudgetMonthly: flexibleBudgetMonthly
            )
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

    /// V3 (Phase E): Continue from Step 1 Connect into Loading → Reality.
    /// Replaces `continueFromAccountsReview` (BS_AccountsReviewView is deleted).
    /// Marks the server step so resumeFromSetupState can route correctly.
    func continueFromConnect() async {
        if isManualMode {
            // Manual mode skips the Loading view entirely, so we must hydrate the
            // bits the Loading path normally fills before synthesizing stats:
            //   • loadProfile()   → currentAge / currencyCode (generate-plans needs current_age)
            //   • restoreFromActiveFireGoal() → returning manual users keep saved goal prefill
            // Both are best-effort; manual values override anything they set.
            await loadProfile()
            await restoreFromActiveFireGoal()
            // loadProfile flips `loadingError` on failure, but we never show the
            // Loading view here, so swallow the message — UI cues for missing
            // manual numbers are surfaced inline in BS_AccountSelectionView.
            loadingError = nil
            isLoadingProfile = false
            isLoadingStats = false
            isLoadingDiagnosis = false

            let totalSpend = manualEssentialSpending + manualOtherSpending
            let monthlySave = manualIncome - totalSpend
            let savingsRatePct = manualIncome > 0 ? max(0, (monthlySave / manualIncome) * 100) : 0
            let currentMonth = DateFormatter.currentMonthString.prefix(7)

            spendingStats = SpendingStatsResponse(
                avgMonthlyIncome: manualIncome,
                avgMonthlyExpenses: totalSpend,
                avgMonthlySavings: monthlySave,
                currentSavingsRate: savingsRatePct,
                avgMonthlyFixed: manualEssentialSpending,
                avgMonthlyFlexible: manualOtherSpending,
                fixedExpenses: [
                    FixedExpenseItem(
                        name: "essentials",
                        pfcDetailed: nil,
                        avgMonthlyAmount: manualEssentialSpending,
                        monthsAppeared: 1,
                        variancePct: 0,
                        isAlwaysFixed: true
                    )
                ],
                flexibleBreakdown: manualOtherSpending > 0 ? [
                    FlexibleBreakdownItem(
                        subcategory: "other",
                        avgMonthlyAmount: manualOtherSpending,
                        shareOfFlexible: 1,
                        transactionCount: 1
                    )
                ] : [],
                incomeSource: "manual",
                monthsAnalyzed: 1,
                dataQuality: "limited",
                totalTransactions: 0,
                monthlyBreakdown: [
                    MonthlyBreakdownItem(
                        month: String(currentMonth),
                        income: manualIncome,
                        fixed: manualEssentialSpending,
                        flexible: manualOtherSpending,
                        savings: monthlySave
                    )
                ],
                hasDeficit: monthlySave < 0,
                deficitAmount: max(0, -monthlySave),
                essentialFloor: manualEssentialSpending,
                avgWants: manualOtherSpending,
                uncategorizedShareOfSpend: 0,
                canonicalBreakdown: [
                    CanonicalBreakdownItem(
                        canonicalId: "essentials",
                        parent: "needs",
                        avgMonthly: manualEssentialSpending,
                        transactionCount: 1
                    ),
                    CanonicalBreakdownItem(
                        canonicalId: "other",
                        parent: "wants",
                        avgMonthly: manualOtherSpending,
                        transactionCount: manualOtherSpending > 0 ? 1 : 0
                    )
                ],
                oneTimeTransactions: [],
                outlierThreshold: nil,
                monthlyBreakdownV3: [
                    MonthlyBreakdownV3Item(
                        month: String(currentMonth),
                        status: "complete",
                        income: manualIncome,
                        needsSpend: manualEssentialSpending,
                        wantsSpend: manualOtherSpending,
                        uncategorizedSpend: 0,
                        totalSpend: totalSpend,
                        savings: monthlySave
                    )
                ],
                monthsInWindow: 1
            )
            monthlyIncome = manualIncome
            currentNetWorth = manualNetWorth
            // Commit the manual age into `currentAge` so generate-plans /
            // generate-spending-plan / calculate-fire-goal request bodies
            // pick it up via `currentAge > 0` checks below. The CTA
            // already enforces `effectiveManualAge > 0` so this is safe.
            if effectiveManualAge > 0 {
                currentAge = effectiveManualAge
            }
            seedDefaultsForTargetStep()

            // Sync the manual snapshot back to `user_profiles` so other
            // surfaces (Home Hero, get-active-fire-goal's net-worth
            // fallback, generate-plans' age fallback) immediately see the
            // numbers the user just typed instead of stale onboarding
            // estimates. This is best-effort: we still proceed even if
            // the call fails — the request bodies below carry the same
            // values explicitly.
            await syncManualProfileSnapshot()

            // Best-effort: tell the server we cleared the Connect step so a
            // mid-flow resume routes back into Reality (not Connect).
            do {
                try await APIService.shared.markSetupStep("accounts_reviewed")
            } catch {
                print("⚠️ [BudgetSetup] mark accounts_reviewed (manual) failed: \(error)")
            }

            await MainActor.run {
                goToStep(.reality)
            }
            return
        }

        do {
            try await APIService.shared.markSetupStep("accounts_reviewed")
        } catch {
            print("⚠️ [BudgetSetup] mark accounts_reviewed failed: \(error)")
        }

        await MainActor.run {
            if spendingStats != nil && loadingError == nil {
                goToStep(.reality)
            } else {
                prepareLoading(nextStep: .reality)
                goToStep(.loading)
            }
        }
    }

    // MARK: - Setup Resume

    /// Fresh entry from Home / Cash Flow / Settings should always start at
    /// account confirmation. This keeps the analysis scope visible instead of
    /// silently resuming into Loading and skipping the account-selection gate.
    func beginFreshSetup() async {
        currentStep = .connect
        isResumingState = false
    }

    /// Reads the server-side setup state and advances currentStep to the correct resume point.
    /// V3 (Phase E): goal is collected in Step 4 Target (after Reality), so we no longer
    /// gate routing on `targetRetirementAge` — users always flow through Reality first.
    func resumeFromSetupState() async {
        defer { isResumingState = false }

        // Restore goal fields before routing so Step 4 sliders pre-fill.
        await restoreFromActiveFireGoal()

        do {
            let state = try await APIService.shared.getSetupState()

            switch state.resumeStage {
            case .noGoal, .goalSet:
                // Both pre-Plaid stages land on Step 1 Connect.
                currentStep = .connect
            case .accountsLinked:
                // Accounts are linked but stats not yet computed → enter Loading → Reality.
                if plaidAccounts.isEmpty {
                    await loadAccounts()
                }
                prepareLoading(nextStep: .reality)
                currentStep = .loading
            case .snapshotPending:
                prepareLoading(nextStep: .reality)
                currentStep = .loading
            case .planPending, .active:
                // V3 contract: users always flow through Reality first (see doc
                // at function top). Even when a plan already exists, re-entry
                // lands on Reality so the user re-orients against current data
                // before touching Target/Plan — their numbers may have shifted
                // since the last committed plan.
                prepareLoading(nextStep: .reality)
                currentStep = .loading
            }
            print("✅ [BudgetSetup] resumeFromSetupState → \(state.resumeStage) → \(currentStep)")
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
                selectedPlanRate: (committedSavingsRate ?? plan.savingsRate) * 100,
                selectedPlanName: committedPlanLabel ?? plan.label,
                avgMonthlyIncome: stats.avgMonthlyIncome,
                fixedExpenses: fixedInputs,
                flexibleBreakdown: flexInputs,
                committedMonthlySave: committedMonthlySave ?? plan.monthlySave,
                committedSpendCeiling: committedSpendCeiling ?? plan.committedSpendCeiling,
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

    func suggestedCategoryBudgets() -> [String: Double] {
        guard let stats = spendingStats else { return [:] }
        let totalSpend = max(0.01, currentSnapshotSpend)
        let ceiling = committedSpendCeiling ?? currentSnapshotSpend
        var suggested: [String: Double] = [:]
        for item in stats.fixedExpenses {
            suggested[item.name] = roundBudgetAmount(item.avgMonthlyAmount / totalSpend * ceiling)
        }
        for item in stats.flexibleBreakdown {
            suggested[item.subcategory] = roundBudgetAmount(item.avgMonthlyAmount / totalSpend * ceiling)
        }
        return suggested
    }

    func ensureCategoryBudgetsSeeded() {
        if categoryBudgets.isEmpty {
            categoryBudgets = suggestedCategoryBudgets()
        }
    }

    var categoryBudgetTotal: Double {
        categoryBudgets.values.reduce(0, +)
    }

    var categoryBudgetRemaining: Double {
        (committedSpendCeiling ?? currentSnapshotSpend) - categoryBudgetTotal
    }
    
    func saveFinalBudget() async -> Bool {
        guard let plan = spendingPlan else { return false }
        guard let selectedPlan else { return false }
        
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
                "selected_plan": committedPlanLabel ?? selectedPlan.label,
                "committed_savings_rate": committedSavingsRate ?? selectedPlan.savingsRate,
                "committed_monthly_save": committedMonthlySave ?? selectedPlan.monthlySave,
                "committed_spend_ceiling": committedSpendCeiling ?? selectedPlan.committedSpendCeiling,
                "committed_plan_label": committedPlanLabel ?? selectedPlan.label,
                "snapshot_avg_income": spendingStats?.avgMonthlyIncome ?? monthlyIncome,
                "snapshot_avg_spend": spendingStats?.avgMonthlyExpenses ?? 0,
                "snapshot_net_worth": currentNetWorth,
                "snapshot_essential_floor": spendingStats?.essentialFloor ?? spendingStats?.avgMonthlyFixed ?? 0,
                "snapshot_date": ISO8601DateFormatter().string(from: Date()),
                "retirement_spending_monthly": retirementSpendingMonthly,
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
            // Defensive re-sync: the user may have edited the manual
            // numbers between Connect and Confirm. The Connect-time
            // sync covers the common path; this catches any drift so
            // the snapshot stored on user_profiles always matches the
            // budget snapshot we just wrote.
            if isManualMode {
                await syncManualProfileSnapshot()
            }
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
        if currentStep == .reality {
            isNavigatingForward = false
            withAnimation(.easeOut(duration: 0.3)) {
                currentStep = .connect
            }
            return
        }

        let targetRaw = currentStep.rawValue - 1
        guard let previous = Step(rawValue: targetRaw),
              previous.rawValue >= Step.connect.rawValue else { return }
        isNavigatingForward = false
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = previous
        }
    }
}
