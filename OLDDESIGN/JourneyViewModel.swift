//
//  JourneyViewModel.swift
//  Flamora app
//
//  Archived with `JourneyView` (OLDDESIGN). Not part of the shipping target; kept for reference.
//  MainTabView uses `HomeHeroCardSurface` for hero data.
//

import SwiftUI

@MainActor
@Observable
final class JourneyViewModel {

    // MARK: - Readable State

    private(set) var setupState: HomeSetupStateResponse?
    private(set) var homeHero: HomeHeroModel?
    private(set) var netWorthSummary = APINetWorthSummary.empty
    private(set) var apiBudget = APIMonthlyBudget.empty
    private(set) var currentMonthSummary: APISpendingSummary?
    private(set) var loadErrorMessage: String?
    private(set) var isLoadingData = false
    private(set) var hasCompletedInitialHomeLoad = false

    // MARK: - Private

    private var needsReloadAfterCurrentPass = false
    private let plaidManager: PlaidManager

    // MARK: - Init

    init(plaidManager: PlaidManager) {
        self.plaidManager = plaidManager
    }

    // MARK: - Computed View State

    var homeSetupStage: HomeSetupStage {
        if let stage = setupState?.setupStage { return stage }
        return plaidManager.hasLinkedBank ? .accountsLinked : .noGoal
    }

    var hasFireGoal: Bool {
        setupState?.activeGoalId != nil
    }

    var budgetSetupCompleted: Bool {
        homeSetupStage == .active
    }

    var saveStatusText: String {
        let actual = currentMonthSummary?.savings.actual ?? apiBudget.savingsActual ?? 0
        if let target = homeHero?.savingsTargetMonthly, target > 0 {
            return "\(NumberFormatter.compactCurrency(actual)) / \(NumberFormatter.compactCurrency(target))"
        }
        if actual > 0 { return "\(NumberFormatter.compactCurrency(actual)) saved" }
        return "Track savings"
    }

    var budgetStatusText: String {
        let planned = apiBudget.needsBudget + apiBudget.wantsBudget
        let actual = (currentMonthSummary?.needs.total ?? 0) + (currentMonthSummary?.wants.total ?? 0)
        guard planned > 0 else { return "Build your plan" }
        let delta = ((actual - planned) / planned) * 100
        if abs(delta) < 1 { return "On plan" }
        if delta > 0 { return "\(Int(delta.rounded()))% over plan" }
        return "\(Int(abs(delta).rounded()))% under plan"
    }

    var investStatusText: String {
        if let growth = netWorthSummary.growthAmount {
            let prefix = growth >= 0 ? "+" : "-"
            return "\(prefix)\(NumberFormatter.compactCurrency(abs(growth))) this month"
        }
        if let total = netWorthSummary.breakdown.investmentTotal, total > 0 {
            return "\(NumberFormatter.compactCurrency(total)) invested"
        }
        return "View portfolio"
    }

    func openSetupFlow() {
        plaidManager.showBudgetSetup = true
    }

    // MARK: - Data Loading

    @MainActor
    func loadData() async {
        if isLoadingData {
            needsReloadAfterCurrentPass = true
            return
        }

        isLoadingData = true
        needsReloadAfterCurrentPass = false
        let shouldLoadExecution = plaidManager.hasLinkedBank

        defer {
            isLoadingData = false
            if needsReloadAfterCurrentPass {
                needsReloadAfterCurrentPass = false
                Task { await self.loadData() }
            }
        }

        loadErrorMessage = nil

        let monthStr = DateFormatter.currentMonthString
        let state = await fetchSetupState()

        if let state { setupState = state }
        if !hasCompletedInitialHomeLoad { hasCompletedInitialHomeLoad = true }

        let shouldLoadHero = (state ?? setupState)?.setupStage == .active
        async let netWorthTask = fetchNetWorth()
        async let executionTask = fetchExecutionData(month: monthStr, shouldLoad: shouldLoadExecution)
        async let heroTask: HomeHeroModel? = shouldLoadHero ? fetchHomeHero() : nil

        let (hero, netWorth, executionData) = await (heroTask, netWorthTask, executionTask)

        homeHero = hero
        if let netWorth { netWorthSummary = netWorth }
        apiBudget = executionData.budget ?? .empty
        currentMonthSummary = executionData.summary

        if state == nil && setupState == nil {
            loadErrorMessage = "Couldn't load your home state."
        }
    }

    // MARK: - Private Fetch Helpers

    private func fetchSetupState() async -> HomeSetupStateResponse? {
        await APIService.shared.getSetupStatePersistingCache()
    }

    private func fetchHomeHero() async -> HomeHeroModel? {
        do {
            return try await APIService.shared.getHomeHero()
        } catch {
            print("⚠️ [Journey] getHomeHero failed: \(error)")
            return nil
        }
    }

    private func fetchNetWorth() async -> APINetWorthSummary? {
        do {
            return try await APIService.shared.getNetWorthSummary()
        } catch {
            print("⚠️ [Journey] getNetWorthSummary failed: \(error)")
            return nil
        }
    }

    private func fetchExecutionData(
        month: String,
        shouldLoad: Bool
    ) async -> (budget: APIMonthlyBudget?, summary: APISpendingSummary?) {
        guard shouldLoad else { return (nil, nil) }
        async let budgetTask = fetchBudget(month: month)
        async let summaryTask = fetchCurrentMonthSummary(month: month)
        return await (budgetTask, summaryTask)
    }

    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }

    private func fetchCurrentMonthSummary(month: String) async -> APISpendingSummary? {
        try? await APIService.shared.getSpendingSummary(month: month)
    }
}
