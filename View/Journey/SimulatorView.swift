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

    @State private var preview: SimulatorPreviewModel?
    @State private var setupStage: HomeSetupStage?
    @State private var controls = SimulatorControlState()
    @State private var didSeedControls = false
    @State private var errorMessage: String?
    @State private var previewTask: Task<Void, Never>?
    @State private var editingField: SimulatorEditableField?
    @State private var editInput = ""

    @Environment(PlaidManager.self) private var plaidManager

    init(
        displayState: Binding<SimulatorDisplayState>,
        bottomPadding: CGFloat = 0,
        isFireOn: Bool = true,
        onFireToggle: (() -> Void)? = nil,
        showResultCard: Bool = true,
        contentTopPadding: CGFloat = TopHeaderBar.height + AppSpacing.md
    ) {
        _displayState = displayState
        self.bottomPadding = bottomPadding
        self.isFireOn = isFireOn
        self.onFireToggle = onFireToggle
        self.showResultCard = showResultCard
        self.contentTopPadding = contentTopPadding
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            switch displayState {
            case .overview, .loading:
                loadingContent
            case .results:
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

            VStack(alignment: .leading, spacing: compactLayout ? AppSpacing.xs : AppSpacing.sm) {
                if showResultCard {
                    resultCard
                }
                comparisonGraph
                    .frame(height: chartHeight)
                controlsSection

                if !compactLayout {
                    swipeUpHint
                }
            }
            .padding(.top, contentTopPadding)
            .padding(.bottom, max(bottomPadding, compactLayout ? AppSpacing.xs : AppSpacing.sm))
        }
        .alert(
            "Edit Value",
            isPresented: Binding(
                get: { editingField != nil },
                set: { if !$0 { editingField = nil } }
            )
        ) {
            TextField("Value", text: $editInput)
            Button("Save") { commitManualEdit() }
            Button("Cancel", role: .cancel) { editingField = nil }
        } message: {
            Text(editingField?.displayTitle ?? "")
        }
    }

    var swipeUpHint: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(AppColors.overlayWhiteOnGlass)
                .frame(width: 44, height: 4)
            Text("Swipe up to return")
                .font(.caption)
                .foregroundStyle(AppColors.overlayWhiteOnGlass)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
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
            let faster = preview.deltaMonths < 0
            Text(deltaLabel(for: preview))
                .font(.bodySmallSemibold)
                .foregroundStyle(faster ? AppColors.success : AppColors.warning)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background((faster ? AppColors.success : AppColors.warning).opacity(0.12))
                .clipShape(Capsule())
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

    var comparisonGraph: some View {
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
        .padding(panelPadding)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
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
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.white.opacity(0.03), radius: 8, y: -1)
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var legend: some View {
        HStack(spacing: AppSpacing.md) {
            if showsOfficialSeries {
                legendItem(color: AppColors.surfaceBorder, text: "Plan baseline")
            }
            legendItem(color: AppColors.accentBlueBright, text: "Adjusted")
        }
    }

    func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 3)
            Text(text)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
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

    var controlsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(AppColors.successAlt)
                Text("SCENARIO CONTROLS")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            }

            LazyVGrid(columns: gridColumns, spacing: gridCellGap) {
                compactControlCell(
                    title: "Monthly Investment",
                    valueText: formatCurrency(controls.savingsMonthly),
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
                    title: "Investable Assets",
                    valueText: formatCurrency(controls.investableAssets),
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
                    title: "Monthly Expenses",
                    valueText: formatCurrency(controls.retirementSpending),
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
        .padding(panelPadding)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
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
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.white.opacity(0.03), radius: 8, y: -1)
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

private extension SimulatorView {
    var isCompactPhone: Bool {
        UIScreen.main.bounds.height <= 812
    }

    var panelPadding: CGFloat {
        isCompactPhone ? AppSpacing.sm : AppSpacing.md
    }

    var gridCellGap: CGFloat {
        isCompactPhone ? 6 : AppSpacing.xs
    }

    var controlButtonSize: CGFloat {
        isCompactPhone ? 40 : 44
    }

    var controlCellPadding: CGFloat {
        isCompactPhone ? 6 : 8
    }

    var controlRowGap: CGFloat {
        isCompactPhone ? 4 : 6
    }

    var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridCellGap),
            GridItem(.flexible(), spacing: gridCellGap)
        ]
    }

    @ViewBuilder
    func compactControlCell(
        title: String,
        valueText: String,
        range: ClosedRange<Double>,
        step: Double,
        currentValue: Double,
        onChange: @escaping (Double) -> Void,
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: controlRowGap) {
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
                        .frame(width: controlButtonSize, height: controlButtonSize)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
                        .frame(maxWidth: .infinity, minHeight: controlButtonSize)
                        .background(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
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
                        .frame(width: controlButtonSize, height: controlButtonSize)
                        .foregroundStyle(AppColors.successAlt)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(AppColors.successAlt.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(controlCellPadding)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    @MainActor
    func bootstrapIfNeeded() async {
        guard preview == nil else { return }
        displayState = .loading
        errorMessage = nil

        let state = try? await APIService.shared.getSetupState()
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
        if preview == nil || immediate {
            displayState = .loading
        }

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
            returnRate: (effective?.returnRate ?? 0.07) * 100,
            withdrawalRate: (effective?.withdrawalRate ?? 0.04) * 100,
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

private enum SimulatorEditableField {
    case monthlyInvestment
    case investableAssets
    case expectedReturn
    case monthlyExpenses
    case withdrawalRate
    case currentAge

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
}

private struct PreviewPathChart: View {
    let officialPath: [SimulatorDataPoint]
    let adjustedPath: [SimulatorDataPoint]
    let currentProgressLabel: String

    var body: some View {
        GeometryReader { proxy in
            let points = combinedPoints(in: proxy.size)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.backgroundSecondary)

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

private func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "$0"
}

#Preview {
    SimulatorView(displayState: .constant(.overview))
        .environment(PlaidManager.shared)
}
