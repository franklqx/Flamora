//
//  MeridianUITests.swift
//  MeridianUITests
//
//  Created by Frank Li on 2/2/26.
//

import XCTest

final class MeridianUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Cash Flow overlay state tests
    //
    // These tests require the app to be launched in an "unconnected" state.
    // Pass `FLAMORA_PLAID_UNCONNECTED=1` as a launch argument to skip bank-auth
    // so the overlay enters the placeholder path without a real Plaid session.
    //
    // State setup: add `ProcessInfo.processInfo.environment["FLAMORA_PLAID_UNCONNECTED"] == "1"`
    // guard in PlaidManager.loadStatus() to stay unconnected during UI tests.

    /// Verify that an unconnected user who expands Cash Flow does NOT see the day-detail tray.
    @MainActor
    func testCashFlowOverlayUnconnectedHidesDayDetailTray() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FLAMORA_PLAID_UNCONNECTED"] = "1"
        app.launch()

        let cashflowTab = app.buttons["tab_cashflow"]
        XCTAssertTrue(cashflowTab.waitForExistence(timeout: 5), "Cash Flow tab should be reachable in UI-test main-tabs mode")
        cashflowTab.tap()

        let sheet = app.otherElements["home_bottom_sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Main sheet should exist")

        // Swipe DOWN on the drag-handle (NOT the whole sheet — the gesture only lives on the
        // 24pt handle area; the body is a ScrollView and would absorb the swipe). Pulling the
        // sheet down past the threshold flips homeState into `.simulator`, which mounts
        // `CashflowExpandedOverlayView`. (sheetDragGesture only reacts to downward translation
        // — see `MainTabView.sheetDragGesture`.)
        let sheetHandle = app.otherElements["home_bottom_sheet_handle"]
        XCTAssertTrue(sheetHandle.waitForExistence(timeout: 3), "Sheet drag handle should exist")
        let handleStart = sheetHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        handleStart.press(forDuration: 0.05, thenDragTo: dragTarget)

        let detailTray = app.otherElements["cashflow_day_detail_tray"]
        XCTAssertFalse(detailTray.waitForExistence(timeout: 3),
                       "Day detail tray must not appear for unconnected users")

        let calendarConnectHint = app.otherElements["cashflow_calendar_connect_hint"]
        XCTAssertTrue(calendarConnectHint.waitForExistence(timeout: 3),
                      "Connect hint should appear in calendar when unconnected")
    }

    /// Verify that switching to Trend while unconnected does NOT show fake category rows.
    @MainActor
    func testCashFlowOverlayUnconnectedTrendHidesFakeCategories() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FLAMORA_PLAID_UNCONNECTED"] = "1"
        app.launch()

        let cashflowTab = app.buttons["tab_cashflow"]
        XCTAssertTrue(cashflowTab.waitForExistence(timeout: 5), "Cash Flow tab should be reachable in UI-test main-tabs mode")
        cashflowTab.tap()

        let sheet = app.otherElements["home_bottom_sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Main sheet should exist")

        // Swipe DOWN on the drag-handle (NOT the whole sheet — the gesture only lives on the
        // 24pt handle area; the body is a ScrollView and would absorb the swipe). Pulling the
        // sheet down past the threshold flips homeState into `.simulator`, which mounts
        // `CashflowExpandedOverlayView`. (sheetDragGesture only reacts to downward translation
        // — see `MainTabView.sheetDragGesture`.)
        let sheetHandle = app.otherElements["home_bottom_sheet_handle"]
        XCTAssertTrue(sheetHandle.waitForExistence(timeout: 3), "Sheet drag handle should exist")
        let handleStart = sheetHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        handleStart.press(forDuration: 0.05, thenDragTo: dragTarget)

        // Switch to the Trend surface.
        app.buttons["Trend"].firstMatch.tap()

        // Categories section must NOT appear.
        let categoriesSection = app.otherElements["cashflow_categories_section"]
        XCTAssertFalse(categoriesSection.waitForExistence(timeout: 3),
                       "Categories section must not appear for unconnected users in Trend view")

        // Empty state must appear.
        let emptyState = app.otherElements["cashflow_trend_empty_state"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3),
                      "Trend empty state must appear for unconnected users")
    }
}
