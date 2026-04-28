//
//  HomeRoadmapContent.swift
//  Flamora app
//
//  Home Tab sheet primary content.
//
//  布局：顶部 Roadmap 引导（仅在未连接银行时显示）+ 下方 3 张卡片（未连接 = 锁态，连接后 = 真实数据）。
//    • NetWorthCard —— 净资产 + 6/1/3/12/ALL 时间段 trend chart
//    • SavingsRateCard —— 本月储蓄率，点击 → SavingsInputSheet 记录金额
//    • ReportsEntryCard —— Monthly / Issue Zero / Annual 入口（Reports Phase 3 实装）
//

import SwiftUI

struct HomeRoadmapContent: View {
    var onSelectTab: (MainTabItem) -> Void = { _ in }

    private struct SavingsEditTarget: Identifiable, Equatable {
        let year: Int
        let monthIndex: Int

        var id: String { "\(year)-\(monthIndex)" }
    }

    @Environment(PlaidManager.self) private var plaidManager

    @State private var netWorthSummary: APINetWorthSummary? = TabContentCache.shared.homeNetWorthSummary
    @State private var budget: APIMonthlyBudget? = TabContentCache.shared.cashflowBudget
    @State private var savingsByYear: [Int: [Double?]] = TabContentCache.shared.cashflowSavingsByYear
        ?? CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()
    @State private var isLoading: Bool = false

    @State private var editingSavingsTarget: SavingsEditTarget? = nil
    @State private var editingSavingsAmount: Double = 0
    @State private var showSavingsDetail: Bool = false
    @State private var showNetWorthDetail: Bool = false
    @State private var latestMonthlyReport: ReportSnapshot? = TabContentCache.shared.homeMonthlyReport
    @State private var latestIssueZeroReport: ReportSnapshot? = TabContentCache.shared.homeIssueZeroReport
    @State private var latestAnnualReport: ReportSnapshot? = TabContentCache.shared.homeAnnualReport
    @State private var selectedReport: ReportSnapshot? = nil
    @State private var setupState: HomeSetupStateResponse? = HomeSetupStateCache.load()
    @State private var fireGoal: APIFireGoal? = nil
    @State private var showTrustBridge = false

    @State private var netWorthHistory: [NetWorthRange: [NetWorthPoint]] = TabContentCache.shared.homeNetWorthHistory
        ?? [:]

    private var isConnected: Bool { plaidManager.hasLinkedBank }
    /// Authoritative setup completion comes from server `setupState`. Fall back
    /// to a local heuristic only when the server flag hasn't been loaded yet,
    /// so the Home cards aren't blank during cold start.
    private var hasBudgetSetup: Bool {
        if let flag = setupState?.monthlyPlanComplete { return flag }
        return (budget?.savingsRatio ?? 0) > 0
    }

    /// 月收入 = needs + wants + savings（50/30/20 模型里三者相加即收入）。
    private var monthlyIncome: Double {
        guard let b = budget else { return 0 }
        return b.needsBudget + b.wantsBudget + b.savingsBudget
    }

    private var targetRatePercent: Double {
        // Prefer the budget row's committed ratio (written by saveFinalBudget).
        if let ratio = budget?.savingsRatio, ratio > 0 { return ratio }
        // Fallback: derive from the active plan's monthly save target when the
        // monthly budget row hasn't loaded yet (e.g. right after first plan submit).
        if let monthlySave = fireGoal?.savingsTargetMonthly, monthlySave > 0 {
            let income = monthlyIncome
            if income > 0 { return (monthlySave / income) * 100 }
        }
        return 0
    }
    /// Savings target follows the active plan as the single source of truth;
    /// monthly_budget is only a fallback when the goal API hasn't loaded yet.
    private var targetAmount: Double {
        if let plan = fireGoal?.savingsTargetMonthly, plan > 0 { return plan }
        return budget?.savingsBudget ?? 0
    }
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var currentYearSavings: [Double?] {
        savingsByYear[currentYear] ?? Array(repeating: nil, count: 12)
    }
    private var journeyStartDate: Date? {
        guard let createdAt = fireGoal?.createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }
    private var planCreationYear: Int {
        guard let date = journeyStartDate else { return currentYear }
        return Calendar.current.component(.year, from: date)
    }
    private var savingsSnapshot: SavingsTrackingSnapshot? {
        guard hasBudgetSetup else { return nil }
        return SavingsTrackingBuilder.snapshot(
            year: currentYear,
            monthlyAmounts: currentYearSavings,
            targetAmount: targetAmount,
            targetRatePercent: targetRatePercent,
            journeyStartDate: journeyStartDate
        )
    }

    /// Setup checklist is the pre-plan onboarding card. Once the user has
    /// committed a plan the Hero takes over as the primary status surface, so
    /// this card hides — even if cashflow/portfolio steps are still open.
    /// Linking missing accounts can still be done from the relevant tabs.
    private var showSetupChecklist: Bool {
        if let flag = setupState?.monthlyPlanComplete { return !flag }
        return !hasBudgetSetup
    }

    /// Plan-snapshot model: disconnecting accounts after plan commit doesn't
    /// reset the plan, but tracking can't update. We surface a reconnect
    /// banner so the user has a clear path back.
    ///
    /// Why we don't trust `cashflowComplete` / `portfolioComplete`: those
    /// flags are re-derived live by the backend from "currently has accounts",
    /// so they flip to false after disconnect — making them useless for
    /// detecting "previously connected, now offline".
    ///
    /// Instead we lean on a persistent local flag (`everConnectedAccounts`)
    /// set the first time a Plaid link succeeds and never cleared. Combined
    /// with `monthlyPlanComplete` (plan exists) and `hasLinkedBank == false`
    /// (currently disconnected), this gives a reliable signal that survives
    /// across launches.
    private var everConnectedAccounts: Bool {
        UserDefaults.standard.bool(forKey: FlamoraStorageKey.everConnectedAccounts)
    }
    private var showReconnectBanner: Bool {
        guard everConnectedAccounts else { return false }
        guard !plaidManager.hasLinkedBank else { return false }
        // Plan must be committed — pre-plan users get the setup checklist instead.
        if let flag = setupState?.monthlyPlanComplete { return flag }
        return hasBudgetSetup
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                if showSetupChecklist {
                    setupChecklistCard
                } else if showReconnectBanner {
                    reconnectBanner
                }

                HomeNetWorthCard(
                    summary: netWorthSummary,
                    history: netWorthHistory,
                    isConnected: isConnected,
                    onCardTap: { showNetWorthDetail = true }
                )

                HomeSavingsRateCard(
                    snapshot: savingsSnapshot,
                    isConnected: isConnected,
                    hasBudgetSetup: hasBudgetSetup,
                    onMonthTap: beginEditingSavingsMonth,
                    onCardTap: { showSavingsDetail = true }
                )

                HomeReportsEntryCard(
                    isConnected: isConnected && hasBudgetSetup,
                    monthlyReport: latestMonthlyReport,
                    issueZeroReport: unreadIssueZeroReport,
                    annualReport: latestAnnualReport,
                    onSelect: handleReportSelection
                )
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.cardGap)
            .padding(.bottom, AppSpacing.xl + AppSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .task {
            await loadInitialData()
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadInitialData(force: true) }
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await loadInitialData(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            syncSavingsFromCache()
            Task { await loadInitialData(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetSetupFlowDidDismiss)) { _ in
            Task { await loadInitialData(force: true) }
        }
        .sheet(item: $editingSavingsTarget, onDismiss: handleSavingsSheetDismiss) { target in
            SavingsInputSheet(
                amount: $editingSavingsAmount,
                targetAmount: targetAmount
            ) { value in
                Task { await persistSavings(value, year: target.year, monthIndex: target.monthIndex) }
            }
        }
        .fullScreenCover(isPresented: $showSavingsDetail, onDismiss: {
            syncSavingsFromCache()
        }) {
            SavingsTargetDetailView2(
                savingsRatioPercent: targetRatePercent,
                savingsBudgetTarget: targetAmount,
                monthlyAmountsByYear: savingsByYear,
                planCreationYear: planCreationYear,
                onMonthlyAmountsChange: { updated in
                    savingsByYear = updated
                    TabContentCache.shared.setCashflowSavingsByYear(updated)
                }
            )
        }
        .fullScreenCover(isPresented: $showNetWorthDetail) {
            NetWorthDetailView(
                summary: netWorthSummary,
                history: netWorthHistory
            )
        }
        .fullScreenCover(item: $selectedReport, onDismiss: {
            Task { await loadInitialData(force: true) }
        }) { report in
            reportDestination(for: report)
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
    }

    // MARK: - Setup checklist

    private var setupChecklistCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your setup")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)
                .textCase(.uppercase)
                .padding(.bottom, AppSpacing.sm)

            VStack(spacing: 0) {
                setupStepRow(
                    index: 1,
                    title: "Connect Bank Account",
                    detail: cashflowStepDetail,
                    action: startPlaidLinkFlow
                )
                setupStepRow(
                    index: 2,
                    title: "Add Investment Portfolio",
                    detail: portfolioStepDetail,
                    action: startPlaidLinkFlow
                )
                setupStepRow(
                    index: 3,
                    title: "Build Plan",
                    detail: "Choose a monthly budget and saving target.",
                    action: { plaidManager.openBudgetSetup(mode: .fresh) },
                    isLast: true
                )
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .fill(AppColors.glassCardBg)
                .shadow(color: AppColors.glassCardShadow, radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private func setupStepRow(
        index: Int,
        title: String,
        detail: String,
        action: @escaping () -> Void,
        isLast: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColors.inkPrimary)
                        .frame(width: 32, height: 32)
                    Text("\(index)")
                        .font(.smallLabel)
                        .foregroundStyle(AppColors.ctaWhite)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: AppSpacing.sm)

                ZStack {
                    Circle()
                        .strokeBorder(AppColors.inkBorder, lineWidth: 1)
                        .background(Circle().fill(AppColors.ctaWhite))
                        .frame(width: 34, height: 34)
                    Image(systemName: "chevron.right")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary.opacity(0.54))
                }
            }
            .padding(.vertical, AppSpacing.rowItem)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(AppColors.inkDivider)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cashflowStepDetail: String {
        institutionDetail(
            names: setupState?.cashflowInstitutionNames ?? [],
            fallback: "Checking, savings, and credit accounts for income and spending."
        )
    }

    private var portfolioStepDetail: String {
        institutionDetail(
            names: setupState?.portfolioInstitutionNames ?? [],
            fallback: "Brokerage and retirement accounts for FIRE progress."
        )
    }

    private func institutionDetail(names: [String], fallback: String) -> String {
        guard let first = names.first else { return fallback }
        if names.count == 1 {
            return "Connected to \(first)"
        }
        return "Connected to \(first) + \(names.count - 1) more"
    }

    // MARK: - Reconnect banner

    private var reconnectBanner: some View {
        Button(action: startPlaidLinkFlow) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColors.warning.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.warning)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reconnect your accounts")
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("Resume cashflow and investment tracking.")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.inkFaint)
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                    .fill(AppColors.warning.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                    .stroke(AppColors.warning.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func startPlaidLinkFlow() {
        if plaidManager.shouldShowTrustBridge() {
            showTrustBridge = true
        } else {
            Task { await plaidManager.startLinkFlow() }
        }
    }

    // MARK: - Data loading

    private func loadInitialData(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        restoreFromCache()
        if !force, hasCachedHomePrimaryData {
            setupState = await APIService.shared.getSetupStatePersistingCache() ?? setupState
            return
        }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let currentMonth = f.string(from: Date())

        async let summary: APINetWorthSummary? = try? await APIService.shared.getNetWorthSummary()
        async let monthBudget: APIMonthlyBudget? = try? await APIService.shared.getMonthlyBudget(month: currentMonth)
        async let monthlyReport: ReportSnapshot? = try? await APIService.shared.getLatestReport(kind: .monthly)
        async let issueZeroReport: ReportSnapshot? = try? await APIService.shared.getLatestReport(kind: .issueZero)
        async let annualReport: ReportSnapshot? = try? await APIService.shared.getLatestReport(kind: .annual)
        async let savingsSeries: [Int: [Double?]]? = loadSavingsByYearFromAPI()
        async let setup: HomeSetupStateResponse? = APIService.shared.getSetupStatePersistingCache()
        async let goal: APIFireGoal? = try? await APIService.shared.getActiveFireGoal()

        let (s, b, monthly, issueZero, annual, series, setupResponse, goalResponse) = await (summary, monthBudget, monthlyReport, issueZeroReport, annualReport, savingsSeries, setup, goal)
        await MainActor.run {
            self.setupState = setupResponse ?? self.setupState
            self.fireGoal = goalResponse ?? self.fireGoal
            if let s {
                self.netWorthSummary = s
                TabContentCache.shared.setHomeNetWorth(summary: s, history: self.netWorthHistory)
            }
            if let b {
                self.budget = b
                TabContentCache.shared.setCashflowBudget(b)
                if let currentMonthValue = b.savingsActual {
                    self.setSavingsAmount(currentMonthValue, year: currentYear, monthIndex: currentMonthIndex)
                }
            }
            if let series {
                self.savingsByYear = series
                TabContentCache.shared.setCashflowSavingsByYear(series)
            }
            self.latestMonthlyReport = monthly
            self.latestIssueZeroReport = issueZero
            self.latestAnnualReport = annual
            TabContentCache.shared.setHomeReports(
                monthly: monthly ?? self.latestMonthlyReport,
                issueZero: issueZero ?? self.latestIssueZeroReport,
                annual: annual ?? self.latestAnnualReport
            )
        }
    }

    private func handleSavingsSheetDismiss() {
        syncSavingsFromCache()
    }

    private var unreadIssueZeroReport: ReportSnapshot? {
        guard let report = latestIssueZeroReport, report.viewedAt == nil else { return nil }
        return report
    }

    private func handleReportSelection(_ kind: HomeReportKind) {
        switch kind {
        case .monthly:
            selectedReport = latestMonthlyReport
        case .issueZero:
            selectedReport = unreadIssueZeroReport
        case .annual:
            selectedReport = latestAnnualReport
        }
    }

    @ViewBuilder
    private func reportDestination(for report: ReportSnapshot) -> some View {
        switch report.kind {
        case .weekly:
            WeeklyReportView(report: report)
        case .monthly:
            MonthlyReportView(report: report)
        case .annual:
            AnnualReportView(report: report)
        case .issueZero:
            IssueZeroView(report: report)
        }
    }

    private func beginEditingSavingsMonth(_ node: SavingsMonthNode) {
        guard node.isEditable else { return }
        editingSavingsAmount = node.amount ?? 0
        editingSavingsTarget = SavingsEditTarget(year: node.year, monthIndex: node.monthIndex)
    }

    private func syncSavingsFromCache() {
        if let cached = TabContentCache.shared.cashflowSavingsByYear {
            savingsByYear = cached
        }
    }

    private func restoreFromCache() {
        syncSavingsFromCache()
        if netWorthSummary == nil {
            netWorthSummary = TabContentCache.shared.homeNetWorthSummary
        }
        if let cachedHistory = TabContentCache.shared.homeNetWorthHistory {
            netWorthHistory = cachedHistory
        }
        if budget == nil {
            budget = TabContentCache.shared.cashflowBudget
        }
        if latestMonthlyReport == nil {
            latestMonthlyReport = TabContentCache.shared.homeMonthlyReport
        }
        if latestIssueZeroReport == nil {
            latestIssueZeroReport = TabContentCache.shared.homeIssueZeroReport
        }
        if latestAnnualReport == nil {
            latestAnnualReport = TabContentCache.shared.homeAnnualReport
        }
        if setupState == nil {
            setupState = HomeSetupStateCache.load()
        }
    }

    private var hasCachedHomePrimaryData: Bool {
        netWorthSummary != nil
            || budget != nil
            || TabContentCache.shared.cashflowSavingsByYear != nil
    }

    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date()) - 1
    }

    private func setSavingsAmount(_ amount: Double?, year: Int, monthIndex: Int) {
        var updated = savingsByYear
        var yearData = updated[year] ?? Array(repeating: nil, count: 12)
        while yearData.count < 12 { yearData.append(nil) }
        yearData[monthIndex] = amount
        updated[year] = yearData
        savingsByYear = updated
        TabContentCache.shared.setCashflowSavingsByYear(updated)
    }

    private func loadSavingsByYearFromAPI() async -> [Int: [Double?]]? {
        guard plaidManager.hasLinkedBank else { return nil }
        let through = Calendar.current.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: currentYear, throughMonth: through)
        guard !summaries.isEmpty else { return nil }
        return CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: currentYear)
    }

    @MainActor
    private func persistSavings(_ value: Double, year: Int, monthIndex: Int) async {
        let month = String(format: "%04d-%02d", year, monthIndex + 1)
        do {
            _ = try await APIService.shared.saveSavingsCheckIn(month: month, savingsActual: value)
            setSavingsAmount(value, year: year, monthIndex: monthIndex)
            NotificationCenter.default.post(name: .savingsCheckInDidPersist, object: nil)
            if year == currentYear, let b = try? await APIService.shared.getMonthlyBudget(month: month) {
                self.budget = b
                TabContentCache.shared.setCashflowBudget(b)
            }
        } catch {
            print("❌ [HomeRoadmapContent] Failed to persist savings: \(error)")
        }
    }
}
