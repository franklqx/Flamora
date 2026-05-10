//
//  SimulatorView.swift
//  Flamora app
//
//  Step 5 sandbox simulator:
//  - Demo mode before full setup
//  - Official preview after plan activation
//  - Never mutates official Hero data
//

import SwiftUI

struct SimulatorView: View {
    @Binding var displayState: SimulatorDisplayState

    let isFireOn: Bool
    let onFireToggle: (() -> Void)?
    let bottomPadding: CGFloat
    let contentTopPadding: CGFloat
    /// When false, root is clear so a parent (e.g. `BrandHeroBackground` in `MainTabView`) provides the atmospheric gradient.
    let fillsBackground: Bool

    @State private var preview: SimulatorPreviewModel?
    @State private var setupStage: HomeSetupStage?
    @State private var controls = SimulatorControlState()
    @State private var didSeedControls = false
    @State private var errorMessage: String?
    @State private var previewTask: Task<Void, Never>?
    @State private var editingField: SimulatorEditableField?
    @State private var editInput = ""
    @State private var showAdvancedDetails = false
    @State private var chartRevealAnimation = false
    @State private var selectedLifecyclePoint: SimulatorLifecyclePoint?
    @State private var infoField: SimulatorInfoField?

    @Environment(PlaidManager.self) private var plaidManager

    init(
        displayState: Binding<SimulatorDisplayState>,
        bottomPadding: CGFloat = 0,
        isFireOn: Bool = true,
        onFireToggle: (() -> Void)? = nil,
        contentTopPadding: CGFloat = TopHeaderBar.height + AppSpacing.md,
        fillsBackground: Bool = true
    ) {
        _displayState = displayState
        self.bottomPadding = bottomPadding
        self.isFireOn = isFireOn
        self.onFireToggle = onFireToggle
        self.contentTopPadding = contentTopPadding
        self.fillsBackground = fillsBackground
    }

    var body: some View {
        ZStack {
            Group {
                if fillsBackground {
                    AppColors.backgroundPrimary
                } else {
                    Color.clear
                }
            }
            .ignoresSafeArea()

            switch displayState {
            case .overview:
                loadingContent
            case .loading, .results:
                resultsContent
            }
        }
        .animation(.easeInOut(duration: 0.2), value: displayState)
        .task { await bootstrapIfNeeded() }
        .onChange(of: controls) { _, _ in
            guard displayState == .results else { return }
            schedulePreviewRefresh()
        }
        .onDisappear {
            previewTask?.cancel()
            previewTask = nil
        }
    }
}

enum SimulatorDisplayState {
    case overview
    case loading
    case results
}

private extension SimulatorView {
    var simulatorMode: SimulatorMode {
        if (setupStage ?? .accountsLinked) == .active {
            return .officialPreview
        }
        return .demo
    }

    var loadingContent: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(AppColors.overlayWhiteStroke, style: StrokeStyle(lineWidth: 2, dash: [5, 8]))
                    .frame(width: 220, height: 220)

                Circle()
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: simulatorMode == .demo ? "sparkles" : "flame.fill")
                            .font(.display)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: simulatorMode == .demo
                                        ? [AppColors.accentBlue, AppColors.accentPurple]
                                        : AppColors.gradientFire,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }

            VStack(spacing: AppSpacing.sm) {
                Text(simulatorMode == .demo ? "Loading demo simulator…" : "Loading your sandbox…")
                    .font(.detailTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text(simulatorMode == .demo
                     ? "This uses sample data so you can test ideas before setup is complete."
                     : "Your official Hero stays fixed while the sandbox builds preview paths.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.screenPadding)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, AppSpacing.screenPadding)
            }

            Spacer()
        }
        .padding(.bottom, max(bottomPadding, AppSpacing.lg))
    }

    var resultsContent: some View {
        GeometryReader { proxy in
            let compactLayout = proxy.size.height < 780
            let chartHeight = compactLayout
                ? max(148, min(198, proxy.size.height * 0.29))
                : max(170, min(220, proxy.size.height * 0.31))

            htmlPrototypeResults(
                chartHeight: chartHeight,
                compactLayout: compactLayout
            )
            .padding(.top, contentTopPadding)
            .padding(.bottom, max(bottomPadding, compactLayout ? AppSpacing.xs : AppSpacing.sm))
        }
        .sheet(item: $editingField) { field in
            SimulatorEditValueSheet(
                field: field,
                initialText: editInput,
                onSave: { newText in
                    editInput = newText
                    commitManualEdit()
                },
                onCancel: {
                    editingField = nil
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.shellBg1)
        }
        .sheet(item: $infoField) { field in
            SimulatorInfoSheet(
                title: field.title,
                message: infoBody(for: field),
                onDismiss: { infoField = nil }
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.shellBg1)
        }
    }

    private func infoBody(for field: SimulatorInfoField) -> String {
        switch field {
        case .inflation:
            let real = max(0, controls.returnRate - 3.0)
            return String(
                format: "Inflation slowly erodes purchasing power. We assume 3%% per year and subtract it from your expected return so all numbers in this simulator are in today's dollars.\n\nWith your %.1f%% expected return, projections use a real return of %.1f%%.",
                controls.returnRate, real
            )
        case .withdrawalRate:
            return "The Safe Withdrawal Rule estimates how large your portfolio needs to be before retirement. The default 4% comes from the Trinity Study and is a common rule of thumb for portfolios meant to last 30+ years."
        }
    }

    var swipeUpHint: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(AppColors.overlayWhiteOnGlass)
                .frame(width: 44, height: 4)
            Text("Tap the bottom-left circle to return")
                .font(.caption)
                .foregroundStyle(AppColors.overlayWhiteOnGlass)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    func htmlPrototypeResults(
        chartHeight: CGFloat,
        compactLayout: Bool
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: compactLayout ? AppSpacing.sm : AppSpacing.md) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                        .background(AppColors.warning.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        .padding(.horizontal, AppSpacing.screenPadding)
                }

                sandboxHeader
                    .padding(.horizontal, AppSpacing.screenPadding)

                lifecycleChartSection(chartHeight: chartHeight)
                    .padding(.horizontal, AppSpacing.screenPadding)

                htmlRetirementDetailPanel
                    .padding(.horizontal, AppSpacing.screenPadding)

                if !compactLayout {
                    swipeUpHint
                        .padding(.top, AppSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sandbox header (kicker + outcome)

    /// Kicker + headline + two-column readout (PORTFOLIO | AGE).
    /// Readout follows the dragged chart point (defaulting to the FIRE point so
    /// the header always has a value).
    private var sandboxHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PREDICT")
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                .tracking(AppTypography.Tracking.cardHeader)

            Text(sandboxOutcomeText)
                .font(.detailTitle)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.35), value: sandboxOutcomeText)

            if let columns = headlineColumns {
                headlineReadoutColumns(columns)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sandboxOutcomeText: String {
        guard let age = preview?.previewFireAge else {
            return "Your scenario doesn't reach financial independence before age \(lifecycleEndAge)."
        }
        return "You will reach financial independence at age \(age)"
    }

    /// Default = FIRE point (or today's point if FIRE unreachable).
    /// Updates live as the user drags on the chart.
    private var headlinePortfolioPoint: SimulatorLifecyclePoint? {
        if let selected = selectedLifecyclePoint { return selected }
        let pts = lifecyclePoints
        if let fireAge = preview?.previewFireAge,
           let firePoint = pts.first(where: { $0.age == fireAge }) {
            return firePoint
        }
        return pts.first
    }

    /// Two-column readout: PORTFOLIO ($amount) | AGE (X · phase).
    private var headlineColumns: (portfolio: String, ageWithPhase: String)? {
        guard let p = headlinePortfolioPoint else { return nil }
        let amount = NumberFormatter.appCurrency(p.netWorth)
        let ageWithPhase = "\(p.age) · \(phaseDisplayName(p.phase))"
        return (amount, ageWithPhase)
    }

    private func headlineReadoutColumns(_ columns: (portfolio: String, ageWithPhase: String)) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xxl) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PORTFOLIO")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    .tracking(AppTypography.Tracking.cardHeader)
                Text(columns.portfolio)
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.18), value: columns.portfolio)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AGE")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    .tracking(AppTypography.Tracking.cardHeader)
                Text(columns.ageWithPhase)
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.18), value: columns.ageWithPhase)
            }

            Spacer(minLength: 0)
        }
    }

    private func phaseDisplayName(_ phase: String) -> String {
        switch phase {
        case "fire_reached": return "FIRE reached"
        case "withdrawing":  return "Withdrawing"
        case "depleted":     return "Portfolio depleted"
        default:             return "Accumulating"
        }
    }


    // MARK: - Lifecycle area chart (accumulation + decumulation to age 90)

    private func lifecycleChartSection(chartHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SandboxLifecycleChart(
                points: lifecyclePoints,
                fireAge: preview?.previewFireAge,
                currentAge: controls.currentAge,
                endAge: lifecycleEndAge,
                revealAnimation: chartRevealAnimation,
                selectedPoint: selectedLifecyclePoint,
                onSelect: { selectedLifecyclePoint = $0 },
                onEndSelection: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedLifecyclePoint = nil
                    }
                }
            )
            .frame(height: chartHeight)

            lifecycleAxisLabels
                .frame(height: 20)

            Text(lifecycleMicrolabel)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, AppSpacing.xxs)
        }
        .padding(.vertical, AppSpacing.sm)
        .onAppear {
            chartRevealAnimation = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                chartRevealAnimation = true
            }
        }
        .onChange(of: lifecyclePoints) { _, points in
            guard let selectedLifecyclePoint else { return }
            self.selectedLifecyclePoint = points.first(where: { $0.age == selectedLifecyclePoint.age })
        }
    }

    /// 横轴终点：固定 age 90（用户拍板）。
    private var lifecycleEndAge: Int { preview?.lifecycleEndAge ?? SandboxLifecycle.endAge }

    private var lifecycleAxisLabels: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = max(1, lifecycleEndAge - controls.currentAge)
            let fireX = preview?.previewFireAge.map { fireAge in
                CGFloat(fireAge - controls.currentAge) / CGFloat(span) * width
            }

            ZStack(alignment: .leading) {
                Text("Today")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.heroTextHint)
                    .position(x: 28, y: 10)

                if let fireAge = preview?.previewFireAge,
                   fireAge > controls.currentAge,
                   fireAge < lifecycleEndAge,
                   let fireX {
                    Text("FIRE @\(fireAge)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .position(x: min(max(fireX, 42), max(42, width - 42)), y: 10)
                }

                Text("Age \(lifecycleEndAge)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.heroTextHint)
                    .position(x: max(40, width - 40), y: 10)
            }
        }
    }

    /// 整段生命周期数据：从 currentAge 起，每月模拟 portfolio 演化到 age 90。
    /// 累积期：portfolio = portfolio*(1+r/12) + monthly_savings
    /// FIRE 后取款期：portfolio = portfolio*(1+r/12) − retirement_spending
    /// portfolio 跌到 0 之后保持 0（视觉上一条贴底直线）。
    private var lifecyclePoints: [SimulatorLifecyclePoint] {
        if let points = preview?.adjustedLifecyclePath, points.count > 1 {
            return points
        }
        // Match server: controls.returnRate is NOMINAL, subtract inflation for the
        // real-dollar lifecycle projection.
        let realReturn = max(0, controls.returnRate - FIREAssumptions.inflationRate * 100)
        return SandboxLifecycle.compute(
            currentAge: controls.currentAge,
            startingNetWorth: controls.investableAssets,
            monthlySavings: controls.savingsMonthly,
            annualReturnPercent: realReturn,
            retirementSpendingMonthly: controls.retirementSpending,
            fireNumber: preview?.previewFireNumber,
            fireAge: preview?.previewFireAge,
            endAge: lifecycleEndAge
        )
    }

    /// 图表下方一行 microlabel — 解释 portfolio 寿命。
    private var lifecycleMicrolabel: String {
        let pts = lifecyclePoints
        guard !pts.isEmpty else { return " " }

        guard let fireAge = preview?.previewFireAge,
              fireAge <= lifecycleEndAge else {
            return "This scenario does not reach FIRE before age \(lifecycleEndAge)."
        }

        if let depletionAge = preview?.portfolioDepletionAge {
            return "In today’s dollars, this portfolio runs out at age \(depletionAge)."
        }

        if let depleted = pts.first(where: { $0.netWorth <= 0 && $0.age > controls.currentAge }) {
            return "In today’s dollars, this portfolio runs out at age \(depleted.age)."
        }
        return "In today’s dollars, this portfolio lasts beyond age \(lifecycleEndAge)."
    }

    private var htmlRetirementDetailPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Retirement Detail")
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            VStack(spacing: 0) {
                htmlDetailRow(
                    label: "Current Age",
                    value: "\(controls.currentAge)",
                    onTap: {
                        editingField = .currentAge
                        editInput = "\(controls.currentAge)"
                    }
                )

                htmlDetailRow(
                    label: "Monthly Investment",
                    value: NumberFormatter.appCurrency(controls.savingsMonthly),
                    onTap: {
                        editingField = .monthlyInvestment
                        editInput = String(Int(controls.savingsMonthly.rounded()))
                    }
                )

                htmlDetailRow(
                    label: "Current Portfolio",
                    value: NumberFormatter.appCurrency(controls.investableAssets),
                    onTap: {
                        editingField = .investableAssets
                        editInput = String(Int(controls.investableAssets.rounded()))
                    }
                )

                htmlDetailRow(
                    label: "Monthly Retirement Spending",
                    value: NumberFormatter.appCurrency(controls.retirementSpending),
                    onTap: {
                        editingField = .monthlyExpenses
                        editInput = String(Int(controls.retirementSpending.rounded()))
                    }
                )
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showAdvancedDetails.toggle()
                }
            } label: {
                HStack {
                    Text("Advanced Details")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                        .rotationEffect(.degrees(showAdvancedDetails ? 180 : 0))
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .buttonStyle(.plain)

            if showAdvancedDetails {
                VStack(spacing: 0) {
                    htmlDetailRow(
                        label: "Expected Return",
                        value: String(format: "%.1f%%", controls.returnRate),
                        onTap: {
                            editingField = .expectedReturn
                            editInput = String(format: "%.1f", controls.returnRate)
                        }
                    )

                    htmlDetailRow(
                        label: "Inflation",
                        value: "3.0%",
                        info: .inflation
                    )

                    htmlDetailRow(
                        label: "Safe Withdrawal Rule",
                        value: String(format: "%.2f%%", controls.withdrawalRate),
                        info: .withdrawalRate,
                        onTap: {
                            editingField = .withdrawalRate
                            editInput = String(format: "%.2f", controls.withdrawalRate)
                        }
                    )
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            LinearGradient(
                colors: [AppColors.simDetailsBg1, AppColors.simDetailsBg2],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.simDetailsBorder, lineWidth: 1)
        )
    }

    /// One row in Retirement Detail / Advanced Details.
    /// - `onTap`: nil → static row (no chevron, not tappable). Non-nil → editable row with chevron.
    /// - `info`: when set, an ⓘ icon appears next to the label and opens an info sheet.
    private func htmlDetailRow(
        label: String,
        value: String,
        info: SimulatorInfoField? = nil,
        onTap: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.bodySmall)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            if let info {
                Button {
                    infoField = info
                } label: {
                    Image(systemName: "info.circle")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) info")
            }

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                Text(value)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textPrimary)
                if onTap != nil {
                    Image(systemName: "chevron.down")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                }
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.simDetailsBorder)
                .frame(height: 1)
        }
    }

    @MainActor
    func bootstrapIfNeeded() async {
        guard preview == nil else { return }
        errorMessage = nil

        let state = await APIService.shared.getSetupStatePersistingCache()
        setupStage = state?.setupStage ?? (plaidManager.hasLinkedBank ? .accountsLinked : .noGoal)
        await refreshPreview(immediate: true)
    }

    func schedulePreviewRefresh(immediate: Bool = false) {
        previewTask?.cancel()
        previewTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(220))
            }
            guard !Task.isCancelled else { return }
            await refreshPreview(immediate: immediate)
        }
    }

    @MainActor
    func refreshPreview(immediate: Bool) async {
        do {
            let data = try await APIService.shared.previewSimulator(data: buildRequest())
            preview = data
            seedControlsIfNeeded(from: data)
            errorMessage = nil
            displayState = .results
        } catch {
            errorMessage = "Couldn't refresh this scenario."
            displayState = .results
        }
    }

    func buildRequest() -> SimulatorPreviewRequest {
        switch simulatorMode {
        case .demo:
            var req = SimulatorPreviewRequest.demo(
                retirementSpending: max(controls.retirementSpending, 4500),
                netWorth: controls.investableAssets,
                sandboxSavings: controls.savingsMonthly
            )
            req.officialAge = controls.currentAge
            req.sandboxRetirementSpending = controls.retirementSpending
            req.sandboxReturnRate = controls.returnRate / 100
            req.sandboxWithdrawalRate = controls.withdrawalRate / 100
            return req

        case .officialPreview:
            var req = SimulatorPreviewRequest.officialPreview(
                sandboxSavings: controls.savingsMonthly,
                sandboxSpending: controls.retirementSpending,
                sandboxReturn: controls.returnRate / 100,
                sandboxWithdrawal: controls.withdrawalRate / 100,
                sandboxTargetAge: nil
            )
            req.officialNetWorth = controls.investableAssets
            req.officialAge = controls.currentAge
            return req
        }
    }

    func seedControlsIfNeeded(from data: SimulatorPreviewModel) {
        guard !didSeedControls else { return }
        let effective = data.effectiveInputs

        controls = SimulatorControlState(
            savingsMonthly: effective?.savingsMonthly ?? 1_800,
            retirementSpending: effective?.retirementSpending ?? 5_000,
            investableAssets: effective?.netWorth ?? 310_000,
            returnRate: (effective?.returnRate ?? FIREAssumptions.nominalAnnualReturn) * 100,
            withdrawalRate: (effective?.withdrawalRate ?? FIREAssumptions.withdrawalRate) * 100,
            currentAge: effective?.currentAge ?? 33
        )
        didSeedControls = true
    }

    func commitManualEdit() {
        guard let field = editingField else { return }
        switch field {
        case .monthlyInvestment:
            if let value = Double(editInput) {
                controls.savingsMonthly = min(max(0, value), 20_000)
            }
        case .investableAssets:
            if let value = Double(editInput) {
                controls.investableAssets = min(max(0, value), 2_500_000)
            }
        case .expectedReturn:
            if let value = Double(editInput) {
                controls.returnRate = min(max(1, value), 12)
            }
        case .monthlyExpenses:
            if let value = Double(editInput) {
                controls.retirementSpending = min(max(1_500, value), 25_000)
            }
        case .withdrawalRate:
            if let value = Double(editInput) {
                controls.withdrawalRate = min(max(2.5, value), 6)
            }
        case .currentAge:
            if let value = Int(editInput) {
                controls.currentAge = min(max(18, value), 70)
            }
        }
        editingField = nil
    }
}

private enum SimulatorMode {
    case demo
    case officialPreview
}

private struct SimulatorControlState: Equatable {
    var savingsMonthly: Double = 1_800
    var retirementSpending: Double = 5_000
    var investableAssets: Double = 310_000
    var returnRate: Double = 7.0           // nominal; real return = 7 − 3 inflation = 4
    var withdrawalRate: Double = 4.0
    var currentAge: Int = 33
}

private enum SimulatorInfoField: String, Identifiable {
    case inflation
    case withdrawalRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inflation:      return "Inflation"
        case .withdrawalRate: return "Safe Withdrawal Rule"
        }
    }
}

private enum SimulatorEditableField: Identifiable {
    case monthlyInvestment
    case investableAssets
    case expectedReturn
    case monthlyExpenses
    case withdrawalRate
    case currentAge

    var id: String {
        switch self {
        case .monthlyInvestment: return "monthlyInvestment"
        case .investableAssets:  return "investableAssets"
        case .expectedReturn:    return "expectedReturn"
        case .monthlyExpenses:   return "monthlyExpenses"
        case .withdrawalRate:    return "withdrawalRate"
        case .currentAge:        return "currentAge"
        }
    }

    var displayTitle: String {
        switch self {
        case .monthlyInvestment: return "Monthly Investment"
        case .investableAssets: return "Current Portfolio"
        case .expectedReturn: return "Expected Return (%)"
        case .monthlyExpenses: return "Monthly Retirement Spending"
        case .withdrawalRate: return "Safe Withdrawal Rule (%)"
        case .currentAge: return "Current Age"
        }
    }

    var subtitle: String {
        switch self {
        case .monthlyInvestment: return "How much you invest each month."
        case .investableAssets: return "Your current FIRE portfolio balance."
        case .expectedReturn: return "Annual real return assumption, after inflation."
        case .monthlyExpenses: return "Monthly spending you'll need in retirement."
        case .withdrawalRate: return "Rule used to estimate how large your portfolio needs to be."
        case .currentAge: return "Your age today."
        }
    }

    /// iOS 数字键盘类型：整数 vs 小数。
    var prefersDecimal: Bool {
        switch self {
        case .expectedReturn, .withdrawalRate: return true
        default: return false
        }
    }
}

// MARK: - Sandbox Lifecycle (accumulation + decumulation)

/// 生命周期模拟逻辑 + 横轴常量。
/// - 横轴永远从 currentAge → endAge (90)
/// - 累积期：每月 portfolio = portfolio*(1+r/12) + savings_monthly
/// - FIRE 后取款期：每月 portfolio = portfolio*(1+r/12) − retirement_spending
/// - portfolio ≤ 0 之后保持 0（视觉上贴底）
private enum SandboxLifecycle {
    /// 横轴终点年龄（用户拍板）。介于 longevity-aware 与可读性之间。
    static let endAge: Int = 90

    static func compute(
        currentAge: Int,
        startingNetWorth: Double,
        monthlySavings: Double,
        annualReturnPercent: Double,
        retirementSpendingMonthly: Double,
        fireNumber: Double?,
        fireAge: Int?,
        endAge: Int = SandboxLifecycle.endAge
    ) -> [SimulatorLifecyclePoint] {
        guard currentAge < endAge else {
            return [
                SimulatorLifecyclePoint(
                    age: currentAge,
                    year: Calendar.current.component(.year, from: .now),
                    netWorth: startingNetWorth,
                    phase: "accumulating"
                )
            ]
        }
        let annualRate = max(0.001, annualReturnPercent / 100.0)
        let monthlyRate = annualRate / 12.0
        var portfolio = max(0, startingNetWorth)
        let currentYear = Calendar.current.component(.year, from: .now)
        var points: [SimulatorLifecyclePoint] = [
            SimulatorLifecyclePoint(
                age: currentAge,
                year: currentYear,
                netWorth: portfolio,
                phase: fireAge == currentAge ? "fire_reached" : "accumulating"
            )
        ]

        // 决定何时切换到取款期：用 fireAge 作为 boundary；如果 fireAge 不可达，
        // 则永远在累积期（最后一年仍可能远低于 fire_number，视觉上仍单调上升）。
        let switchAge: Int = fireAge ?? Int.max

        for age in (currentAge + 1)...endAge {
            let isWithdrawing = age > switchAge
            for _ in 0..<12 {
                if isWithdrawing {
                    portfolio = portfolio * (1 + monthlyRate) - retirementSpendingMonthly
                } else {
                    portfolio = portfolio * (1 + monthlyRate) + monthlySavings
                }
                if portfolio < 0 { portfolio = 0 }
            }
            let phase: String
            if portfolio <= 0 {
                phase = "depleted"
            } else if age == switchAge {
                phase = "fire_reached"
            } else if isWithdrawing {
                phase = "withdrawing"
            } else {
                phase = "accumulating"
            }
            points.append(
                SimulatorLifecyclePoint(
                    age: age,
                    year: currentYear + (age - currentAge),
                    netWorth: portfolio,
                    phase: phase
                )
            )
        }
        return points
    }
}

// MARK: - Sandbox Lifecycle Chart (area chart, blue-purple gradient)

/// 完整生命周期 area chart。
/// - 蓝紫渐变线 + 软填充
/// - FIRE 节点：垂直虚线 + 玻璃圆点
/// - portfolio 耗尽后曲线贴底
private struct SandboxLifecycleChart: View {
    let points: [SimulatorLifecyclePoint]
    let fireAge: Int?
    let currentAge: Int
    let endAge: Int
    let revealAnimation: Bool
    let selectedPoint: SimulatorLifecyclePoint?
    let onSelect: (SimulatorLifecyclePoint) -> Void
    let onEndSelection: () -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(in: geo.size)
            ZStack {
                // Area fill
                Path { path in
                    guard let first = layout.linePoints.first else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    path.addLine(to: first)
                    for p in layout.linePoints.dropFirst() {
                        path.addLine(to: p)
                    }
                    if let last = layout.linePoints.last {
                        path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#60A5FA").opacity(0.32),
                            Color(hex: "#818CF8").opacity(0.10),
                            Color(hex: "#818CF8").opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line stroke
                Path { path in
                    guard let first = layout.linePoints.first else { return }
                    path.move(to: first)
                    for p in layout.linePoints.dropFirst() {
                        path.addLine(to: p)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: AppColors.gradientShellAccent,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color(hex: "#60A5FA").opacity(0.40), radius: 6, y: 4)

                // FIRE marker (vertical dashed line + glass dot).
                // Hidden while user is dragging — only the drag dot shows then.
                if let fireMarker = layout.fireMarker, selectedPoint == nil {
                    Path { path in
                        path.move(to: CGPoint(x: fireMarker.x, y: 0))
                        path.addLine(to: CGPoint(x: fireMarker.x, y: geo.size.height))
                    }
                    .stroke(
                        AppColors.overlayWhiteForegroundMuted,
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                    )

                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#60A5FA"), lineWidth: 2.5)
                        )
                        .shadow(color: Color(hex: "#60A5FA").opacity(0.6), radius: 6)
                        .position(x: fireMarker.x, y: fireMarker.y)
                }

                if let selectedMarker = layout.selectedMarker {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(AppColors.accentBlueBright, lineWidth: 2))
                        .shadow(color: AppColors.accentBlueBright.opacity(0.55), radius: 7)
                        .position(selectedMarker)
                }
            }
            .scaleEffect(x: 1, y: revealAnimation ? 1 : 0.02, anchor: .bottom)
            .opacity(revealAnimation ? 1 : 0)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectNearestPoint(to: value.location.x, in: layout)
                    }
                    .onEnded { _ in
                        onEndSelection()
                    }
            )
        }
    }

    private struct Layout {
        let linePoints: [CGPoint]
        let fireMarker: CGPoint?
        let selectedMarker: CGPoint?
    }

    private func computeLayout(in size: CGSize) -> Layout {
        guard points.count > 1, endAge > currentAge else {
            return Layout(linePoints: [], fireMarker: nil, selectedMarker: nil)
        }

        let values = points.map(\.netWorth)
        let maxV = max(values.max() ?? 1, 1)
        let minV: Double = 0  // 总是从 0 起算，让"耗尽"的视觉贴底
        let range = max(maxV - minV, 1)

        let topPad: CGFloat = 14   // 给 FIRE 圆点留头顶空间
        let bottomPad: CGFloat = 4
        let h = size.height
        let usableH = max(1, h - topPad - bottomPad)
        let w = size.width
        let xSpan = CGFloat(endAge - currentAge)

        let linePoints: [CGPoint] = points.map { p in
            let x = CGFloat(p.age - currentAge) / xSpan * w
            let normalized = (p.netWorth - minV) / range
            let y = h - bottomPad - CGFloat(normalized) * usableH
            return CGPoint(x: x, y: y)
        }

        // FIRE marker：找 fireAge 对应的曲线 y
        var fireMarker: CGPoint? = nil
        if let fireAge,
           fireAge > currentAge,
           fireAge < endAge,
           let firePoint = points.first(where: { $0.age == fireAge })
        {
            let x = CGFloat(fireAge - currentAge) / xSpan * w
            let normalized = (firePoint.netWorth - minV) / range
            let y = h - bottomPad - CGFloat(normalized) * usableH
            fireMarker = CGPoint(x: x, y: y)
        }

        let selectedMarker = selectedPoint.flatMap { selected in
            points.firstIndex(where: { $0.age == selected.age }).map { linePoints[$0] }
        }

        return Layout(linePoints: linePoints, fireMarker: fireMarker, selectedMarker: selectedMarker)
    }

    private func selectNearestPoint(to x: CGFloat, in layout: Layout) {
        guard !points.isEmpty, !layout.linePoints.isEmpty else { return }
        let index = layout.linePoints.enumerated().min { lhs, rhs in
            abs(lhs.element.x - x) < abs(rhs.element.x - x)
        }?.offset ?? 0
        onSelect(points[index])
    }

}

// MARK: - Edit Value Sheet (light-shell modal, replaces system .alert)

private struct SimulatorEditValueSheet: View {
    let field: SimulatorEditableField
    let initialText: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var input: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Edit Value")
                    .font(.h4)
                    .foregroundStyle(AppColors.inkPrimary)

                Text(field.displayTitle)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
            }

            TextField("", text: $input)
                .keyboardType(field.prefersDecimal ? .decimalPad : .numberPad)
                .focused($isFocused)
                .font(.fieldBodyMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .tint(AppColors.inkPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm + 2)
                .background(AppColors.ctaWhite)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.inkBorder, lineWidth: 1)
                )

            HStack(spacing: AppSpacing.sm) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(AppColors.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.inkTrack)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)

                Button {
                    onSave(input)
                } label: {
                    Text("Save")
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: AppColors.gradientShellAccent,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.lg)
        .onAppear {
            input = initialText
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
    }
}

// MARK: - Info Sheet (light-shell modal for ⓘ icon explanations)

private struct SimulatorInfoSheet: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(.h4)
                .foregroundStyle(AppColors.inkPrimary)

            Text(message)
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Text("Got it")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: AppColors.gradientShellAccent,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.lg)
    }
}

#Preview {
    SimulatorView(displayState: .constant(.results))
        .environment(PlaidManager.shared)
}
