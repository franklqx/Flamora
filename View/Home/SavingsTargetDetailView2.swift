//
//  SavingsTargetDetailView2.swift
//  Meridian
//
//  Full-year savings tracking detail.
//

import SwiftUI
import Charts
import UIKit

struct SavingsTargetDetailView2: View {
    private let savingsRatioPercent: Double
    private let targetAmount: Double
    private let planCreationYear: Int
    private let onMonthlyAmountsChange: (([Int: [Double?]]) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var selectedMonthIndex: Int? = nil  // nil = YTD (no month focus)
    @State private var monthlyAmountsByYear: [Int: [Double?]]
    @State private var editingMonthIndex: Int? = nil
    @State private var editingAmountValue: Double = 0
    @State private var isShowingEditSheet: Bool = false
    @State private var isPersistingEdit: Bool = false
    @State private var isShowingYearSheet: Bool = false

    init(
        savingsRatioPercent: Double,
        savingsBudgetTarget: Double,
        monthlyAmountsByYear: [Int: [Double?]],
        planCreationYear: Int = Calendar.current.component(.year, from: Date()),
        onMonthlyAmountsChange: (([Int: [Double?]]) -> Void)? = nil
    ) {
        self.savingsRatioPercent = savingsRatioPercent
        self.targetAmount = savingsBudgetTarget
        self.planCreationYear = planCreationYear
        self.onMonthlyAmountsChange = onMonthlyAmountsChange

        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
        _monthlyAmountsByYear = State(initialValue: monthlyAmountsByYear)
    }

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var availableYears: [Int] {
        let start = min(planCreationYear, currentYear)
        return Array(start...currentYear)
    }
    private var currentMonthlyAmounts: [Double?] {
        monthlyAmountsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
    }
    private var snapshot: SavingsTrackingSnapshot {
        SavingsTrackingBuilder.snapshot(
            year: selectedYear,
            monthlyAmounts: currentMonthlyAmounts,
            targetAmount: targetAmount,
            targetRatePercent: savingsRatioPercent
        )
    }
    private var selectedNode: SavingsMonthNode? {
        guard let idx = selectedMonthIndex else { return nil }
        return snapshot.fullYearNodes[min(max(idx, 0), 11)]
    }
    private var inferredMonthlyIncome: Double? {
        guard targetAmount > 0, savingsRatioPercent > 0 else { return nil }
        return targetAmount / (savingsRatioPercent / 100.0)
    }
    private var annualSaved: Double {
        currentMonthlyAmounts.compactMap { $0 }.reduce(0, +)
    }
    private var annualAverageRateText: String {
        snapshot.ytdAverageText
    }

    private var heroLabel: String {
        if let node = selectedNode { return "\(node.label.capitalized) \(selectedYear)" }
        return "Saved \(selectedYear == currentYear ? "this year" : "in \(selectedYear)")"
    }

    private var heroValue: Double {
        if let node = selectedNode { return node.amount ?? 0 }
        return annualSaved
    }

    private var heroDeltaText: String? {
        guard targetAmount > 0 else { return nil }
        if let node = selectedNode {
            guard let amount = node.amount else { return nil }
            return deltaText(actual: amount, target: targetAmount)
        }
        // YTD: compare YTD avg to target
        let completed = currentMonthlyAmounts.compactMap { $0 }
        guard !completed.isEmpty else { return nil }
        let avg = completed.reduce(0, +) / Double(completed.count)
        return deltaText(actual: avg, target: targetAmount)
    }

    private var heroDeltaColor: Color {
        guard let text = heroDeltaText else { return AppColors.inkSoft }
        if text.hasPrefix("+") { return AppColors.progressGreen }
        if text == "On target" { return AppColors.inkSoft }
        return AppColors.accentAmber
    }

    private func deltaText(actual: Double, target: Double) -> String {
        let pct = ((actual - target) / target) * 100
        let rounded = Int(abs(pct).rounded())
        if rounded == 0 { return "On target" }
        if pct > 0 { return "+\(rounded)% vs target" }
        return "-\(rounded)% vs target"
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        DetailSheetScaffold(
            title: "Savings",
            contentBottomPadding: AppSpacing.tabBarReserve + AppSpacing.md
        ) {
            dismiss()
        } content: {
            yearHeader
            benchmarkCard
            trendCard
            yearOverviewCard
        }
        .sheet(isPresented: $isShowingEditSheet, onDismiss: applyEditedAmount) {
            SavingsInputSheet(
                amount: $editingAmountValue,
                targetAmount: targetAmount
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingYearSheet) {
            yearPickerSheet
        }
        .onChange(of: selectedYear) { _, _ in
            // Switching years clears any per-month focus.
            selectedMonthIndex = nil
        }
    }

    private var yearHeader: some View {
        HStack {
            Spacer()
            Button {
                isShowingYearSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text(String(selectedYear))
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.inkSoft)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var yearPickerSheet: some View {
        VStack(spacing: 0) {
            Text("SELECT A YEAR")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkSoft)
                .tracking(AppTypography.Tracking.cardHeader)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(availableYears.reversed(), id: \.self) { year in
                        Button {
                            if year != selectedYear {
                                selectedYear = year
                                selectedMonthIndex = nil
                            }
                            isShowingYearSheet = false
                        } label: {
                            HStack {
                                Text(String(year))
                                    .font(.bodyRegular)
                                    .foregroundStyle(AppColors.inkPrimary)
                                    .monospacedDigit()
                                Spacer()
                                if year == selectedYear {
                                    Image(systemName: "checkmark")
                                        .font(.footnoteSemibold)
                                        .foregroundStyle(AppColors.inkPrimary)
                                }
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if year != availableYears.first {
                            Rectangle()
                                .fill(AppColors.inkDivider)
                                .frame(height: 0.5)
                                .padding(.horizontal, AppSpacing.lg)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .presentationDetents([.height(yearSheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColors.shellBg1)
    }

    private var yearSheetHeight: CGFloat {
        let rowHeight: CGFloat = 56
        let header: CGFloat = 80
        let bottomPadding: CGFloat = 32
        let computed = CGFloat(availableYears.count) * rowHeight + header + bottomPadding
        return min(max(computed, 220), 460)
    }

    private var benchmarkCard: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TARGET")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Text("\(formatMoney(targetAmount))/month")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("RATE")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Text(formatPercent(savingsRatioPercent))
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private func formatPercent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))%"
        }
        return String(format: "%.1f%%", rounded)
    }

    private var yearOverviewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("MONTHLY CHECK-INS")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm + AppSpacing.xs), count: 4),
                spacing: AppSpacing.md
            ) {
                ForEach(snapshot.fullYearNodes) { node in
                    Button {
                        // Sync selection with chart, then open input if editable
                        selectedMonthIndex = node.monthIndex
                        if node.isEditable {
                            beginEditMonth(index: node.monthIndex)
                        }
                    } label: {
                        SavingsMonthOrb(
                            node: node,
                            isSelected: node.monthIndex == selectedMonthIndex,
                            diameter: 52
                        )
                        .opacity(node.isEditable ? 1.0 : 0.72)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("ANNUAL TREND")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }

            heroBlock

            Chart {
                if targetAmount > 0 {
                    RuleMark(y: .value("Target", targetAmount))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(AppColors.inkFaint)
                }

                ForEach(snapshot.fullYearNodes) { node in
                    BarMark(
                        x: .value("Month", axisLabel(for: node)),
                        y: .value("Saved", node.amount ?? 0)
                    )
                    .foregroundStyle(barStyle(for: node, isSelected: node.monthIndex == selectedMonthIndex))
                    .cornerRadius(8)
                }

                if let idx = selectedMonthIndex {
                    let selectedLabel = axisLabel(for: snapshot.fullYearNodes[idx])
                    RuleMark(x: .value("Selected", selectedLabel))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(AppColors.inkPrimary.opacity(0.35))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(AppColors.inkDivider)
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(String(label.prefix(1)))
                                .font(.caption)
                                .foregroundStyle(AppColors.inkFaint)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleChartGesture(at: value.location, proxy: proxy, geo: geo)
                                }
                        )
                }
            }
            .frame(height: 220)

            trendSubline
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heroLabel)
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)

            HStack(alignment: .firstTextBaseline) {
                Text(formatMoney(heroValue))
                    .font(.h2)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.18), value: heroValue)

                Spacer()

                if let delta = heroDeltaText {
                    Text(delta)
                        .font(.footnoteSemibold)
                        .foregroundStyle(heroDeltaColor)
                        .transition(.opacity)
                }
            }
        }
    }

    private var trendSubline: some View {
        HStack(spacing: 6) {
            Text("YTD AVG \(annualAverageRateText)")
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
            Text("·")
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
            Text("\(snapshot.monthsOnTarget) of \(snapshot.completedMonths) on target")
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
            Spacer()
        }
    }

    private func barStyle(for node: SavingsMonthNode, isSelected: Bool) -> AnyShapeStyle {
        // Selection only changes the orb ring + RuleMark guide; the bar itself
        // keeps its natural color so the chart visual stays stable when scrubbing.
        switch node.state {
        case .future:
            return AnyShapeStyle(AppColors.inkTrack)
        case .pending:
            return AnyShapeStyle(AppColors.glassBlockBg)
        case .missed:
            return AnyShapeStyle(AppColors.inkTrack)
        case .belowTarget:
            return AnyShapeStyle(AppColors.inkFaint)
        case .onTarget:
            return AnyShapeStyle(
                LinearGradient(
                    colors: AppColors.gradientShellAccent,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func axisLabel(for node: SavingsMonthNode) -> String {
        // Three-letter labels keep month identity unambiguous for the gesture
        // hit-test (J would otherwise collapse Jan/Jun/Jul).
        node.shortLabel
    }

    private func handleChartGesture(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotFrame = geo[proxy.plotAreaFrame]
        let xPos = location.x - plotFrame.origin.x
        let yPos = location.y - plotFrame.origin.y
        guard xPos >= 0, xPos <= plotFrame.width, yPos >= 0, yPos <= plotFrame.height else {
            clearChartSelection()
            return
        }
        guard let label: String = proxy.value(atX: xPos),
              let idx = snapshot.fullYearNodes.firstIndex(where: { axisLabel(for: $0) == label }) else {
            clearChartSelection()
            return
        }
        guard isPointOnBar(monthIndex: idx, xPos: xPos, yPos: yPos, proxy: proxy, plotFrame: plotFrame) else {
            clearChartSelection()
            return
        }
        if selectedMonthIndex != idx {
            selectedMonthIndex = idx
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func isPointOnBar(
        monthIndex: Int,
        xPos: CGFloat,
        yPos: CGFloat,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> Bool {
        let node = snapshot.fullYearNodes[monthIndex]
        guard node.state != .future, let amount = node.amount, amount > 0 else { return false }
        let label = axisLabel(for: node)
        guard let barCenterX = proxy.position(forX: label),
              let barTopY = proxy.position(forY: amount),
              let baselineY = proxy.position(forY: 0) else {
            return false
        }

        let monthBandWidth = plotFrame.width / 12
        let hitHalfWidth = max(16, monthBandWidth * 0.34)
        let top = min(barTopY, baselineY)
        let bottom = max(barTopY, baselineY)

        return abs(xPos - barCenterX) <= hitHalfWidth
            && yPos >= top
            && yPos <= bottom
    }

    private func clearChartSelection() {
        if selectedMonthIndex != nil {
            selectedMonthIndex = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func beginEditMonth(index: Int) {
        editingMonthIndex = index
        let existing = index < currentMonthlyAmounts.count ? (currentMonthlyAmounts[index] ?? 0) : 0
        editingAmountValue = existing
        isShowingEditSheet = true
    }

    private func applyEditedAmount() {
        guard let idx = editingMonthIndex else { return }
        var arr = monthlyAmountsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
        while arr.count < 12 { arr.append(nil) }
        arr[idx] = editingAmountValue > 0 ? editingAmountValue : nil
        monthlyAmountsByYear[selectedYear] = arr
        onMonthlyAmountsChange?(monthlyAmountsByYear)
        TabContentCache.shared.setCashflowSavingsByYear(monthlyAmountsByYear)
        Task { await persistEditedAmount(year: selectedYear, monthIndex: idx, amount: arr[idx]) }
        editingMonthIndex = nil
    }

    @MainActor
    private func persistEditedAmount(year: Int, monthIndex: Int, amount: Double?) async {
        guard !isPersistingEdit else { return }
        isPersistingEdit = true
        defer { isPersistingEdit = false }

        do {
            let month = String(format: "%04d-%02d", year, monthIndex + 1)
            _ = try await APIService.shared.saveSavingsCheckIn(month: month, savingsActual: amount)
            NotificationCenter.default.post(name: .savingsCheckInDidPersist, object: nil)
        } catch {
            print("❌ [SavingsTargetDetailView2] Failed to persist savings check-in: \(error)")
        }
    }

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    SavingsTargetDetailView2(
        savingsRatioPercent: 18,
        savingsBudgetTarget: 1_000,
        monthlyAmountsByYear: [
            2026: [1_200, 800, nil, 1_450, nil, nil, nil, nil, nil, nil, nil, nil]
        ]
    )
}

struct SavingsTargetDetailView2Container: View {
    @Environment(PlaidManager.self) private var plaidManager
    @State private var apiBudget: APIMonthlyBudget = TabContentCache.shared.cashflowBudget ?? APIMonthlyBudget.empty
    @State private var monthlyAmountsByYear: [Int: [Double?]] = TabContentCache.shared.cashflowSavingsByYear
        ?? CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()

    var body: some View {
        SavingsTargetDetailView2(
            savingsRatioPercent: apiBudget.savingsRatio,
            savingsBudgetTarget: apiBudget.savingsBudget,
            monthlyAmountsByYear: monthlyAmountsByYear,
            onMonthlyAmountsChange: { updated in
                monthlyAmountsByYear = updated
                TabContentCache.shared.setCashflowSavingsByYear(updated)
            }
        )
        .onAppear {
            syncFromCache()
        }
        .task {
            await loadBudgetAndSavingsSeries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            syncFromCache()
        }
    }

    private func syncFromCache() {
        if let cached = TabContentCache.shared.cashflowSavingsByYear {
            monthlyAmountsByYear = cached
        }
        if let cachedBudget = TabContentCache.shared.cashflowBudget {
            apiBudget = cachedBudget
        }
    }

    private func loadBudgetAndSavingsSeries() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: Date())

        async let budgetResult = try? await APIService.shared.getMonthlyBudget(month: month)
        async let savingsSeries = loadSavingsByYearFromAPI()
        let (budget, series) = await (budgetResult, savingsSeries)

        if let budget {
            apiBudget = budget
            TabContentCache.shared.setCashflowBudget(budget)
        }

        if let cached = TabContentCache.shared.cashflowSavingsByYear {
            monthlyAmountsByYear = cached
        } else if let series {
            monthlyAmountsByYear = series
            TabContentCache.shared.setCashflowSavingsByYear(series)
        } else {
            monthlyAmountsByYear = CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()
        }
    }

    private func loadSavingsByYearFromAPI() async -> [Int: [Double?]]? {
        guard plaidManager.hasLinkedBank else { return nil }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let through = calendar.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
        guard !summaries.isEmpty else { return nil }
        return CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
    }
}
