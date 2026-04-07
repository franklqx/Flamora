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

    @State private var preview: SimulatorPreviewModel?
    @State private var setupStage: HomeSetupStage?
    @State private var controls = SimulatorControlState()
    @State private var didSeedControls = false
    @State private var showAdvanced = false
    @State private var errorMessage: String?
    @State private var previewTask: Task<Void, Never>?

    @Environment(PlaidManager.self) private var plaidManager

    init(
        displayState: Binding<SimulatorDisplayState>,
        bottomPadding: CGFloat = 0,
        isFireOn: Bool = true,
        onFireToggle: (() -> Void)? = nil
    ) {
        _displayState = displayState
        self.bottomPadding = bottomPadding
        self.isFireOn = isFireOn
        self.onFireToggle = onFireToggle
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
                            .font(.system(size: 40, weight: .semibold))
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                simulatorHeader
                resultCard
                comparisonGraph
                controlsSection

                if let errorMessage {
                    ErrorBanner(
                        message: errorMessage,
                        onRetry: { schedulePreviewRefresh(immediate: true) }
                    )
                }
            }
            .padding(.top, AppSpacing.md)
            .padding(.bottom, max(bottomPadding, AppSpacing.xl))
        }
    }

    var simulatorHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text(simulatorMode == .demo ? "DEMO SIMULATOR" : "SANDBOX")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    .tracking(AppTypography.Tracking.cardHeader)

                if simulatorMode == .demo {
                    Text("DEMO")
                        .font(.miniLabel)
                        .foregroundStyle(AppColors.textInverse)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColors.accentAmber)
                        .clipShape(Capsule())
                }

                Spacer()

                Button(action: { onFireToggle?() }) {
                    Image(systemName: "xmark")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(AppColors.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(simulatorMode == .demo
                 ? "Play with sample assumptions before your full setup is ready."
                 : "Test changes here without changing the official path shown on Home.")
                .font(.h4)
                .foregroundStyle(AppColors.textPrimary)

            Text(simulatorMode == .demo
                 ? "This second act is a preview playground. Your official Hero stays untouched."
                 : "Your official Hero remains real. Only the adjusted path below changes.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("CURRENT VS ADJUSTED")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                Spacer()
                legend
            }

            PreviewPathChart(
                officialPath: preview?.officialPath ?? [],
                adjustedPath: preview?.adjustedPath ?? []
            )
            .frame(height: 230)

            Text(simulatorMode == .demo
                 ? "Demo mode shows one sample path and one adjusted path."
                 : "The solid line is your official path. The brighter line is this sandbox scenario.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var legend: some View {
        HStack(spacing: AppSpacing.md) {
            legendItem(color: AppColors.surfaceBorder, text: "Current")
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

    var controlsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("QUICK ADJUSTMENTS")
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            VStack(spacing: AppSpacing.sm) {
                MoneyStepperRow(
                    title: "Monthly savings",
                    value: controls.savingsMonthly,
                    range: 0...20_000,
                    step: 250
                ) { controls.savingsMonthly = $0 }

                MoneyStepperRow(
                    title: "Retirement spending",
                    value: controls.retirementSpending,
                    range: 1_500...25_000,
                    step: 250
                ) { controls.retirementSpending = $0 }
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack {
                    Text("Advanced assumptions")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.overlayWhiteWash)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(spacing: AppSpacing.sm) {
                    PercentStepperRow(
                        title: "Return rate",
                        value: controls.returnRate,
                        range: 1...12,
                        step: 0.5
                    ) { controls.returnRate = $0 }

                    PercentStepperRow(
                        title: "Inflation",
                        value: controls.inflationRate,
                        range: 1...8,
                        step: 0.5
                    ) { controls.inflationRate = $0 }

                    PercentStepperRow(
                        title: "Withdrawal rule",
                        value: controls.withdrawalRate,
                        range: 2.5...6,
                        step: 0.25
                    ) { controls.withdrawalRate = $0 }

                    OptionalAgeRow(
                        title: "Target age",
                        value: controls.targetAge
                    ) { controls.targetAge = $0 }
                }
            }
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
}

private extension SimulatorView {
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
                netWorth: 75_000,
                sandboxSavings: controls.savingsMonthly
            )
            req.sandboxRetirementSpending = controls.retirementSpending
            req.sandboxReturnRate = controls.returnRate / 100
            req.sandboxInflationRate = controls.inflationRate / 100
            req.sandboxWithdrawalRate = controls.withdrawalRate / 100
            req.sandboxTargetAge = controls.targetAge
            return req

        case .officialPreview:
            return .officialPreview(
                sandboxSavings: controls.savingsMonthly,
                sandboxSpending: controls.retirementSpending,
                sandboxReturn: controls.returnRate / 100,
                sandboxWithdrawal: controls.withdrawalRate / 100,
                sandboxTargetAge: controls.targetAge
            )
        }
    }

    func seedControlsIfNeeded(from data: SimulatorPreviewModel) {
        guard !didSeedControls else { return }
        let effective = data.effectiveInputs

        controls = SimulatorControlState(
            savingsMonthly: effective?.savingsMonthly ?? 1_800,
            retirementSpending: effective?.retirementSpending ?? 5_000,
            returnRate: (effective?.returnRate ?? 0.07) * 100,
            inflationRate: 3.0,
            withdrawalRate: (effective?.withdrawalRate ?? 0.04) * 100,
            targetAge: effective?.currentAge.map { $0 + 15 }
        )
        didSeedControls = true
    }
}

private enum SimulatorMode {
    case demo
    case officialPreview
}

private struct SimulatorControlState: Equatable {
    var savingsMonthly: Double = 1_800
    var retirementSpending: Double = 5_000
    var returnRate: Double = 7.0
    var inflationRate: Double = 3.0
    var withdrawalRate: Double = 4.0
    var targetAge: Int? = nil
}

private struct MoneyStepperRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onChange: (Double) -> Void

    var body: some View {
        ControlRow(
            title: title,
            valueText: formatCurrency(value)
        ) {
            HStack(spacing: AppSpacing.sm) {
                stepButton(symbol: "minus") { onChange(max(range.lowerBound, value - step)) }
                stepButton(symbol: "plus") { onChange(min(range.upperBound, value + step)) }
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppColors.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct PercentStepperRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onChange: (Double) -> Void

    var body: some View {
        ControlRow(
            title: title,
            valueText: String(format: "%.2g%%", value)
        ) {
            HStack(spacing: AppSpacing.sm) {
                stepButton(symbol: "minus") { onChange(max(range.lowerBound, value - step)) }
                stepButton(symbol: "plus") { onChange(min(range.upperBound, value + step)) }
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppColors.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct OptionalAgeRow: View {
    let title: String
    let value: Int?
    let onChange: (Int?) -> Void

    var body: some View {
        ControlRow(
            title: title,
            valueText: value.map { "\($0)" } ?? "Off"
        ) {
            HStack(spacing: AppSpacing.sm) {
                Button("Clear") { onChange(nil) }
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.textSecondary)

                stepButton(symbol: "minus") {
                    onChange(max((value ?? 55) - 1, 35))
                }

                stepButton(symbol: "plus") {
                    onChange(min((value ?? 55) + 1, 80))
                }
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppColors.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct ControlRow<Trailing: View>: View {
    let title: String
    let valueText: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                Text(valueText)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer()

            trailing()
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct PreviewPathChart: View {
    let officialPath: [SimulatorDataPoint]
    let adjustedPath: [SimulatorDataPoint]

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
