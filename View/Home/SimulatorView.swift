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
    let showResultCard: Bool
    let contentTopPadding: CGFloat
    /// 与 `design-reference/home-rebuild-glass-prototype.html` 中 `.simulator-panel` 结构对齐（沙盒标题、柱状图、Retirement Detail 暗色面板）。
    let useHTMLPrototypeLayout: Bool
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

    @Environment(PlaidManager.self) private var plaidManager

    init(
        displayState: Binding<SimulatorDisplayState>,
        bottomPadding: CGFloat = 0,
        isFireOn: Bool = true,
        onFireToggle: (() -> Void)? = nil,
        showResultCard: Bool = true,
        contentTopPadding: CGFloat = TopHeaderBar.height + AppSpacing.md,
        useHTMLPrototypeLayout: Bool = false,
        fillsBackground: Bool = true
    ) {
        _displayState = displayState
        self.bottomPadding = bottomPadding
        self.isFireOn = isFireOn
        self.onFireToggle = onFireToggle
        self.showResultCard = showResultCard
        self.contentTopPadding = contentTopPadding
        self.useHTMLPrototypeLayout = useHTMLPrototypeLayout
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
            let isCompactPhone = proxy.size.height <= 812
            let chartHeight = compactLayout
                ? max(148, min(198, proxy.size.height * 0.29))
                : max(170, min(220, proxy.size.height * 0.31))

            Group {
                if useHTMLPrototypeLayout {
                    htmlPrototypeResults(
                        chartHeight: chartHeight,
                        compactLayout: compactLayout,
                        isCompactPhone: isCompactPhone
                    )
                } else {
                    VStack(alignment: .leading, spacing: compactLayout ? AppSpacing.xs : AppSpacing.sm) {
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
                        if showResultCard {
                            resultCard
                        }
                        comparisonGraph(isCompactPhone: isCompactPhone)
                            .frame(height: chartHeight)
                        controlsSection(isCompactPhone: isCompactPhone)

                        if !compactLayout {
                            swipeUpHint
                        }
                    }
                }
            }
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
    }

    var swipeUpHint: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(AppColors.overlayWhiteOnGlass)
                .frame(width: 44, height: 4)
            Text(useHTMLPrototypeLayout ? "Tap the bottom-left circle to return" : "Swipe up to return")
                .font(.caption)
                .foregroundStyle(AppColors.overlayWhiteOnGlass)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    func htmlPrototypeResults(
        chartHeight: CGFloat,
        compactLayout: Bool,
        isCompactPhone: Bool
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

                if showResultCard {
                    resultCard
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

    /// 静态 kicker + 动态 FIRE age outcome。统一字号，靠 uppercase + opacity + weight 拉层级。
    private var sandboxHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("TRY DIFFERENT SCENARIOS")
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                .tracking(AppTypography.Tracking.cardHeader)

            Text(sandboxOutcomeText)
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.35), value: sandboxOutcomeText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 输出：永远是 `FIRE at age <number>.`；数学层不可达时显示 `—`。
    private var sandboxOutcomeText: String {
        guard let age = preview?.previewFireAge else { return "FIRE at age —." }
        return "FIRE at age \(age)."
    }

    // MARK: - Lifecycle area chart (accumulation + decumulation to age 90)

    private func lifecycleChartSection(chartHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SandboxLifecycleChart(
                points: lifecyclePoints,
                fireAge: preview?.previewFireAge,
                currentAge: controls.currentAge,
                endAge: lifecycleEndAge,
                revealAnimation: chartRevealAnimation
            )
            .frame(height: chartHeight)

            // 横轴标签：Today / FIRE @X / Age 90
            HStack {
                Text("Today")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.heroTextHint)

                Spacer(minLength: 0)

                if let fireAge = preview?.previewFireAge,
                   fireAge > controls.currentAge,
                   fireAge < SandboxLifecycle.endAge {
                    Text("FIRE @\(fireAge)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                }

                Text("Age \(SandboxLifecycle.endAge)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.heroTextHint)
            }

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
    }

    /// 横轴终点：固定 age 90（用户拍板）。
    private var lifecycleEndAge: Int { SandboxLifecycle.endAge }

    /// 整段生命周期数据：从 currentAge 起，每月模拟 portfolio 演化到 age 90。
    /// 累积期：portfolio = portfolio*(1+r/12) + monthly_savings
    /// FIRE 后取款期：portfolio = portfolio*(1+r/12) − retirement_spending
    /// portfolio 跌到 0 之后保持 0（视觉上一条贴底直线）。
    private var lifecyclePoints: [SandboxLifecyclePoint] {
        SandboxLifecycle.compute(
            currentAge: controls.currentAge,
            startingNetWorth: controls.investableAssets,
            monthlySavings: controls.savingsMonthly,
            annualReturnPercent: controls.returnRate,
            retirementSpendingMonthly: controls.retirementSpending,
            fireNumber: preview?.previewFireNumber,
            fireAge: preview?.previewFireAge
        )
    }

    /// 图表下方一行 microlabel — 解释 portfolio 寿命。
    private var lifecycleMicrolabel: String {
        let pts = lifecyclePoints
        guard !pts.isEmpty else { return " " }

        // FIRE 都到不了
        if preview?.previewFireAge == nil {
            return "Not reaching FIRE within 50 years."
        }

        // 找第一个 portfolio == 0 的点（耗尽）
        if let depleted = pts.first(where: { $0.netWorth <= 0 && $0.age > controls.currentAge }) {
            return "Portfolio depletes at age \(depleted.age)."
        }
        return "Portfolio lasts beyond age \(SandboxLifecycle.endAge)."
    }

    private var htmlRetirementDetailPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Retirement Detail")
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            VStack(spacing: 0) {
                htmlDetailRow(
                    label: "Current Age",
                    value: "\(controls.currentAge)"
                ) {
                    editingField = .currentAge
                    editInput = "\(controls.currentAge)"
                }

                htmlDetailRow(
                    label: "Monthly Contribution",
                    value: NumberFormatter.appCurrency(controls.savingsMonthly)
                ) {
                    editingField = .monthlyInvestment
                    editInput = String(Int(controls.savingsMonthly.rounded()))
                }

                htmlDetailRow(
                    label: "Current Investment",
                    value: NumberFormatter.appCurrency(controls.investableAssets)
                ) {
                    editingField = .investableAssets
                    editInput = String(Int(controls.investableAssets.rounded()))
                }

                htmlDetailRow(
                    label: "Retire Monthly Expense",
                    value: NumberFormatter.appCurrency(controls.retirementSpending)
                ) {
                    editingField = .monthlyExpenses
                    editInput = String(Int(controls.retirementSpending.rounded()))
                }
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
                        value: String(format: "%.1f%%", controls.returnRate)
                    ) {
                        editingField = .expectedReturn
                        editInput = String(format: "%.1f", controls.returnRate)
                    }

                    htmlDetailStaticRow(label: "Inflation", value: "2.5%")

                    htmlDetailRow(
                        label: "Withdrawal Rate",
                        value: String(format: "%.2f%%", controls.withdrawalRate)
                    ) {
                        editingField = .withdrawalRate
                        editInput = String(format: "%.2f", controls.withdrawalRate)
                    }
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

    private func htmlDetailRow(
        label: String,
        value: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            htmlDetailRowContent(label: label, value: value, showChevron: true)
        }
        .buttonStyle(.plain)
    }

    private func htmlDetailStaticRow(label: String, value: String) -> some View {
        htmlDetailRowContent(label: label, value: value, showChevron: false)
    }

    private func htmlDetailRowContent(label: String, value: String, showChevron: Bool) -> some View {
        HStack {
            Text(label)
                .font(.bodySmall)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                Text(value)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textPrimary)
                if showChevron {
                    Image(systemName: "chevron.down")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                }
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.simDetailsBorder)
                .frame(height: 1)
        }
    }

    var resultCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(simulatorMode == .demo ? "SAMPLE RESULT" : "IF APPLIED")
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(preview?.previewFireDate ?? "—")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                deltaBadge
            }

            HStack(spacing: AppSpacing.sm) {
                statPill(
                    title: "Current path",
                    value: preview?.officialFireDate ?? (simulatorMode == .demo ? "Sample" : "—")
                )
                statPill(
                    title: "Adjusted path",
                    value: preview?.previewFireDate ?? "—"
                )
            }

            Text(resultSupportingCopy)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    @ViewBuilder
    var deltaBadge: some View {
        if let preview {
            Text(deltaLabel(for: preview))
                .font(.bodySmallSemibold)
                .foregroundStyle(preview.deltaMonths < 0 ? AppColors.success : AppColors.warning)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    (preview.deltaMonths < 0 ? AppColors.success : AppColors.warning).opacity(0.12)
                )
                .clipShape(Capsule())
        } else {
            EmptyView()
        }
    }

    func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            Text(value)
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    var resultSupportingCopy: String {
        guard let preview else {
            return "Use the controls below to compare your current path against a new scenario."
        }

        if preview.isDemoMode {
            return "Demo mode uses sample data. It helps you feel the product without changing your official progress."
        }

        if preview.deltaMonths == 0 {
            return "This scenario keeps your FIRE timing roughly unchanged. Try bigger savings or lower retirement spending."
        }

        if preview.deltaMonths < 0 {
            return "This scenario reaches FIRE earlier than your current official plan, but it does not change the Hero until you explicitly apply it later."
        }

        return "This scenario pushes FIRE further out than your official plan. The Home Hero still stays official."
    }

    func deltaLabel(for preview: SimulatorPreviewModel) -> String {
        if preview.deltaMonths == 0 {
            return "No change"
        }
        let direction = preview.deltaMonths < 0 ? "earlier" : "later"
        return "\(abs(preview.deltaMonths)) mo \(direction)"
    }

    func comparisonGraph(isCompactPhone: Bool) -> some View {
        let officialSeries = displayOfficialPath
        let adjustedSeries = displayAdjustedPath

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(showsOfficialSeries ? "PLAN VS ADJUSTED" : "LIVE ADJUSTED PATH")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                Spacer()
                legend
            }

            PreviewPathChart(
                officialPath: officialSeries,
                adjustedPath: adjustedSeries,
                currentProgressLabel: currentProgressLabel
            )
            .frame(maxHeight: .infinity)
        }
        .padding(panelPadding(isCompactPhone: isCompactPhone))
        .background(
            LinearGradient(
                colors: [
                    AppColors.glassBorder,
                    Color(hex: "#A7F3D0").opacity(0.06),
                    Color(hex: "#93C5FD").opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.heroTrack, lineWidth: 1)
        )
        .shadow(color: AppColors.overlayWhiteWash, radius: 8, y: -1)
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var legend: some View {
        HStack(spacing: AppSpacing.md) {
            if showsOfficialSeries {
                LegendItemView(color: AppColors.surfaceBorder, label: "Plan baseline", style: .dash)
            }
            LegendItemView(color: AppColors.accentBlueBright, label: "Adjusted", style: .dash)
        }
    }

    var displayOfficialPath: [SimulatorDataPoint] {
        guard showsOfficialSeries else { return [] }
        if let official = preview?.officialPath, official.count > 1 {
            return official
        }
        return fallbackTrendPath(
            seedNetWorth: controls.investableAssets,
            monthlyInvestment: controls.savingsMonthly * 0.9,
            annualReturnPercent: controls.returnRate * 0.92
        )
    }

    var displayAdjustedPath: [SimulatorDataPoint] {
        if let adjusted = preview?.adjustedPath, adjusted.count > 1 {
            return adjusted
        }
        return fallbackTrendPath(
            seedNetWorth: controls.investableAssets,
            monthlyInvestment: controls.savingsMonthly,
            annualReturnPercent: controls.returnRate
        )
    }

    func fallbackTrendPath(
        seedNetWorth: Double,
        monthlyInvestment: Double,
        annualReturnPercent: Double
    ) -> [SimulatorDataPoint] {
        let startYear = max(2026, Calendar.current.component(.year, from: .now))
        let safeSeed = max(seedNetWorth, 1_000)
        let safeMonthly = max(monthlyInvestment, 0)
        let annualRate = max(0.01, annualReturnPercent / 100)
        let monthlyRate = annualRate / 12

        var points: [SimulatorDataPoint] = []
        var running = safeSeed

        for offset in 0...8 {
            if offset > 0 {
                for _ in 0..<12 {
                    running += safeMonthly
                    running *= (1 + monthlyRate)
                }
            }
            points.append(
                SimulatorDataPoint(
                    year: startYear + offset,
                    netWorth: running
                )
            )
        }

        return points
    }

    var showsOfficialSeries: Bool {
        simulatorMode == .officialPreview
    }

    var currentProgressLabel: String {
        guard let targetAge = preview?.previewFireAge, targetAge > controls.currentAge else {
            return "Age \(controls.currentAge)"
        }
        let ratio = Double(controls.currentAge) / Double(targetAge)
        let percent = min(99, max(1, Int((ratio * 100).rounded())))
        return "Age \(controls.currentAge) · \(percent)%"
    }

    func controlsSection(isCompactPhone: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(AppColors.successAlt)
                Text("SCENARIO CONTROLS")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            }

            LazyVGrid(columns: gridColumns(isCompactPhone: isCompactPhone), spacing: gridCellGap(isCompactPhone: isCompactPhone)) {
                compactControlCell(
                    isCompactPhone: isCompactPhone,
                    title: "Monthly Investment",
                    valueText: NumberFormatter.appCurrency(controls.savingsMonthly),
                    range: 0...20_000,
                    step: 250,
                    currentValue: controls.savingsMonthly,
                    onChange: { controls.savingsMonthly = $0 },
                    onEdit: {
                        editingField = .monthlyInvestment
                        editInput = String(Int(controls.savingsMonthly.rounded()))
                    }
                )

                compactControlCell(
                    isCompactPhone: isCompactPhone,
                    title: "Investable Assets",
                    valueText: NumberFormatter.appCurrency(controls.investableAssets),
                    range: 0...2_500_000,
                    step: 5_000,
                    currentValue: controls.investableAssets,
                    onChange: { controls.investableAssets = $0 },
                    onEdit: {
                        editingField = .investableAssets
                        editInput = String(Int(controls.investableAssets.rounded()))
                    }
                )

                compactControlCell(
                    isCompactPhone: isCompactPhone,
                    title: "Expected Return",
                    valueText: String(format: "%.1f%%", controls.returnRate),
                    range: 1...12,
                    step: 0.5,
                    currentValue: controls.returnRate,
                    onChange: { controls.returnRate = $0 },
                    onEdit: {
                        editingField = .expectedReturn
                        editInput = String(format: "%.1f", controls.returnRate)
                    }
                )

                compactControlCell(
                    isCompactPhone: isCompactPhone,
                    title: "Monthly Expenses",
                    valueText: NumberFormatter.appCurrency(controls.retirementSpending),
                    range: 1_500...25_000,
                    step: 250,
                    currentValue: controls.retirementSpending,
                    onChange: { controls.retirementSpending = $0 },
                    onEdit: {
                        editingField = .monthlyExpenses
                        editInput = String(Int(controls.retirementSpending.rounded()))
                    }
                )

                compactControlCell(
                    isCompactPhone: isCompactPhone,
                    title: "Withdrawal Rate",
                    valueText: String(format: "%.2f%%", controls.withdrawalRate),
                    range: 2.5...6,
                    step: 0.25,
                    currentValue: controls.withdrawalRate,
                    onChange: { controls.withdrawalRate = $0 },
                    onEdit: {
                        editingField = .withdrawalRate
                        editInput = String(format: "%.2f", controls.withdrawalRate)
                    }
                )

                compactControlCell(
                    isCompactPhone: isCompactPhone,
                    title: "Current Age",
                    valueText: "\(controls.currentAge)",
                    range: 18...70,
                    step: 1,
                    currentValue: Double(controls.currentAge),
                    onChange: { controls.currentAge = Int($0.rounded()) },
                    onEdit: {
                        editingField = .currentAge
                        editInput = "\(controls.currentAge)"
                    }
                )
            }
        }
        .padding(panelPadding(isCompactPhone: isCompactPhone))
        .background(
            LinearGradient(
                colors: [
                    AppColors.glassBorder,
                    Color(hex: "#D1FAE5").opacity(0.06),
                    Color(hex: "#BFDBFE").opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.glassPillStroke, lineWidth: 1)
        )
        .shadow(color: AppColors.overlayWhiteWash, radius: 8, y: -1)
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

private extension SimulatorView {
    func panelPadding(isCompactPhone: Bool) -> CGFloat {
        isCompactPhone ? AppSpacing.sm : AppSpacing.md
    }

    func gridCellGap(isCompactPhone: Bool) -> CGFloat {
        isCompactPhone ? 6 : AppSpacing.xs
    }

    func controlButtonSize(isCompactPhone: Bool) -> CGFloat {
        isCompactPhone ? 40 : 44
    }

    func controlCellPadding(isCompactPhone: Bool) -> CGFloat {
        isCompactPhone ? 6 : 8
    }

    func controlRowGap(isCompactPhone: Bool) -> CGFloat {
        isCompactPhone ? 4 : 6
    }

    func gridColumns(isCompactPhone: Bool) -> [GridItem] {
        let gap = gridCellGap(isCompactPhone: isCompactPhone)
        return [
            GridItem(.flexible(), spacing: gap),
            GridItem(.flexible(), spacing: gap)
        ]
    }

    @ViewBuilder
    func compactControlCell(
        isCompactPhone: Bool,
        title: String,
        valueText: String,
        range: ClosedRange<Double>,
        step: Double,
        currentValue: Double,
        onChange: @escaping (Double) -> Void,
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: controlRowGap(isCompactPhone: isCompactPhone)) {
            Text(title.uppercased())
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.leading, 2)

            HStack(spacing: 6) {
                Button {
                    let next = max(range.lowerBound, currentValue - step)
                    onChange(next)
                } label: {
                    Image(systemName: "minus")
                        .font(.footnoteSemibold)
                        .frame(width: controlButtonSize(isCompactPhone: isCompactPhone), height: controlButtonSize(isCompactPhone: isCompactPhone))
                        .background(AppColors.cardTopHighlight)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(AppColors.overlayWhiteHigh, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    Text(valueText)
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, minHeight: controlButtonSize(isCompactPhone: isCompactPhone))
                        .background(AppColors.overlayWhiteStroke)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(AppColors.overlayWhiteHigh, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
                .buttonStyle(.plain)

                Button {
                    let next = min(range.upperBound, currentValue + step)
                    onChange(next)
                } label: {
                    Image(systemName: "plus")
                        .font(.footnoteSemibold)
                        .frame(width: controlButtonSize(isCompactPhone: isCompactPhone), height: controlButtonSize(isCompactPhone: isCompactPhone))
                        .foregroundStyle(AppColors.successAlt)
                        .background(AppColors.cardTopHighlight)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(AppColors.successAlt.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(controlCellPadding(isCompactPhone: isCompactPhone))
        .background(
            LinearGradient(
                colors: [AppColors.overlayWhiteStroke, AppColors.overlayWhiteWash],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.simDetailsBorder, lineWidth: 1)
        )
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
    var returnRate: Double = 7.0
    var withdrawalRate: Double = 4.0
    var currentAge: Int = 33
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
        case .investableAssets: return "Investable Assets"
        case .expectedReturn: return "Expected Return (%)"
        case .monthlyExpenses: return "Monthly Expenses"
        case .withdrawalRate: return "Withdrawal Rate (%)"
        case .currentAge: return "Current Age"
        }
    }

    var subtitle: String {
        switch self {
        case .monthlyInvestment: return "How much you invest each month."
        case .investableAssets: return "Total amount currently invested."
        case .expectedReturn: return "Annual nominal return assumption."
        case .monthlyExpenses: return "Spending you'll need each month in retirement."
        case .withdrawalRate: return "Safe withdrawal rate (Trinity Study uses 4%)."
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

/// 单点：年龄 + portfolio 估值。一年一个点。
private struct SandboxLifecyclePoint: Equatable {
    let age: Int
    let netWorth: Double
}

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
        fireAge: Int?
    ) -> [SandboxLifecyclePoint] {
        guard currentAge < endAge else {
            return [SandboxLifecyclePoint(age: currentAge, netWorth: startingNetWorth)]
        }
        let annualRate = max(0.001, annualReturnPercent / 100.0)
        let monthlyRate = annualRate / 12.0
        var portfolio = max(0, startingNetWorth)
        var points: [SandboxLifecyclePoint] = [
            SandboxLifecyclePoint(age: currentAge, netWorth: portfolio)
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
            points.append(SandboxLifecyclePoint(age: age, netWorth: portfolio))
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
    let points: [SandboxLifecyclePoint]
    let fireAge: Int?
    let currentAge: Int
    let endAge: Int
    let revealAnimation: Bool

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

                // FIRE marker (vertical dashed line + glass dot)
                if let fireMarker = layout.fireMarker {
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
            }
            .scaleEffect(x: 1, y: revealAnimation ? 1 : 0.02, anchor: .bottom)
            .opacity(revealAnimation ? 1 : 0)
        }
    }

    private struct Layout {
        let linePoints: [CGPoint]
        let fireMarker: CGPoint?
    }

    private func computeLayout(in size: CGSize) -> Layout {
        guard points.count > 1, endAge > currentAge else {
            return Layout(linePoints: [], fireMarker: nil)
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

        return Layout(linePoints: linePoints, fireMarker: fireMarker)
    }
}

private struct PreviewPathChart: View {
    let officialPath: [SimulatorDataPoint]
    let adjustedPath: [SimulatorDataPoint]
    let currentProgressLabel: String

    var body: some View {
        GeometryReader { proxy in
            let points = combinedPoints(in: proxy.size)

            ZStack(alignment: .bottomLeading) {
                Color.clear

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(AppColors.overlayWhiteStroke)
                            .frame(height: 1)
                        Spacer()
                    }
                }
                .padding(.vertical, AppSpacing.md)
                .padding(.horizontal, AppSpacing.sm)

                if points.adjusted.count > 1 {
                    path(points.adjusted)
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.accentBlueBright, AppColors.warning],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                }

                if let currentPoint = points.adjusted.first {
                    Circle()
                        .fill(AppColors.accentBlueBright)
                        .frame(width: 8, height: 8)
                        .position(currentPoint)

                    Text(currentProgressLabel)
                        .font(.label)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(AppColors.surface.opacity(0.9))
                        .clipShape(Capsule())
                        .position(x: min(proxy.size.width - 52, currentPoint.x + 52), y: max(12, currentPoint.y - 14))
                }

                if points.official.count > 1 {
                    path(points.official)
                        .stroke(
                            AppColors.surfaceBorder,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [7, 6])
                        )
                }
            }
        }
    }

    private func combinedPoints(in size: CGSize) -> (official: [CGPoint], adjusted: [CGPoint]) {
        let combined = (officialPath + adjustedPath).map(\.netWorth)
        let maxValue = max(combined.max() ?? 1, 1)
        let minValue = min(combined.min() ?? 0, 0)
        let range = max(maxValue - minValue, 1)

        func normalize(_ series: [SimulatorDataPoint]) -> [CGPoint] {
            guard series.count > 1 else { return [] }
            let width = size.width
            let height = size.height
            return series.enumerated().map { index, point in
                let x = CGFloat(index) / CGFloat(series.count - 1) * width
                let normalized = (point.netWorth - minValue) / range
                let y = height - CGFloat(normalized) * (height - 12) - 6
                return CGPoint(x: x, y: y)
            }
        }

        return (normalize(officialPath), normalize(adjustedPath))
    }

    private func path(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
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

            TextField("Value", text: $input)
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

#Preview {
    SimulatorView(displayState: .constant(.results))
        .environment(PlaidManager.shared)
}
