//
//  MeridianTests.swift
//  MeridianTests
//
//  Created by Frank Li on 2/2/26.
//

import XCTest
@testable import Meridian

final class MeridianTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testStepConfigWelcomeUsesWelcomeExceptionTheme() {
        let config = OB_ContainerView.config(for: 1)
        XCTAssertEqual(config.themeSurface, .welcomeException)
        XCTAssertFalse(config.allowsBack)
        XCTAssertNil(config.headerProgress)
    }

    func testStepConfigIntroHasExpectedHeaderProgress() {
        let config = OB_ContainerView.config(for: 3)
        XCTAssertEqual(config.headerProgress, 1)
        XCTAssertTrue(config.allowsBack)
        XCTAssertEqual(config.themeSurface, .lightShell)
    }

    func testStepConfigPaywallUsesLightShellTheme() {
        let config = OB_ContainerView.config(for: 17)
        XCTAssertEqual(config.themeSurface, .lightShell)
        XCTAssertTrue(config.allowsBack)
    }

    func testStepConfigMiddleStepsUseLightShellTheme() {
        XCTAssertEqual(OB_ContainerView.config(for: 2).themeSurface, .lightShell)   // SignIn
        XCTAssertEqual(OB_ContainerView.config(for: 9).themeSurface, .lightShell)   // Age
        XCTAssertEqual(OB_ContainerView.config(for: 14).themeSurface, .lightShell)  // Loading
        XCTAssertEqual(OB_ContainerView.config(for: 15).themeSurface, .immersiveDark) // Roadmap exception
    }

    func testNextStepSkipsAhaMomentStep() {
        XCTAssertEqual(OB_ContainerView.nextStep(after: 15), 17)
        XCTAssertEqual(OB_ContainerView.previousStep(before: 17), 15)
    }

    // MARK: - Expanded overlay routing
    //
    // The previous `MainTabView.overlayKind(for:hasLinkedBank:)` static helper was
    // removed in commit a3bb9f2 ("Liquid Glass tab bar"). Routing now lives inline
    // in `MainTabView.simulatorOverlay`, switching directly on `selectedTab` —
    // there is no longer an `OverlayKind` enum to assert against. If routing
    // becomes pluggable again, reintroduce a pure helper and reinstate the tests.

    // MARK: - TabContentCache monthly summaries

    func testCacheClearAfterBankDisconnectClearsMonthySummaries() {
        // Not directly testable without a spy; verify the property is nil by default.
        let cache = TabContentCache.shared
        // After clearAfterBankDisconnect the property must be nil.
        cache.clearAfterBankDisconnect()
        XCTAssertNil(cache.cashflowMonthlySummaries)
    }

    @MainActor
    func testBudgetSetupAccountToggleInvalidatesCachedAnalysis() {
        let viewModel = BudgetSetupViewModel()
        viewModel.selectedAccountIds = ["account-a", "account-b"]
        viewModel.spendingStats = Self.makeSpendingStats()
        viewModel.committedMonthlySave = 500
        viewModel.categoryBudgets = ["shopping": 100]

        viewModel.toggleAccount("account-b")

        XCTAssertNil(viewModel.spendingStats)
        XCTAssertNil(viewModel.committedMonthlySave)
        XCTAssertTrue(viewModel.categoryBudgets.isEmpty)
    }

    private static func makeSpendingStats() -> SpendingStatsResponse {
        SpendingStatsResponse(
            avgMonthlyIncome: 4_000,
            avgMonthlyExpenses: 2_500,
            avgMonthlySavings: 1_500,
            currentSavingsRate: 37.5,
            avgMonthlyFixed: 1_500,
            avgMonthlyFlexible: 1_000,
            fixedExpenses: [],
            flexibleBreakdown: [],
            incomeSource: "plaid",
            monthsAnalyzed: 3,
            dataQuality: "good",
            totalTransactions: 12,
            monthlyBreakdown: []
        )
    }
}
