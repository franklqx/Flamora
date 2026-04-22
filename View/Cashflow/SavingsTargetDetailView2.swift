//
//  SavingsTargetDetailView2.swift
//  Flamora app
//
//  Full-year savings tracking detail.
//

import SwiftUI
import Charts

struct SavingsTargetDetailView2: View {
    private let savingsRatioPercent: Double
    private let targetAmount: Double
    private let onMonthlyAmountsChange: (([Int: [Double?]]) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var selectedMonthIndex: Int
    @State private var monthlyAmountsByYear: [Int: [Double?]]
    @State private var editingMonthIndex: Int? = nil
    @State private var editingAmountValue: Double = 0
    @State private var isShowingEditSheet: Bool = false
    @State private var isPersistingEdit: Bool = false
    @State private var dragOffset: CGFloat = 0

    init(
        savingsRatioPercent: Double,
        savingsBudgetTarget: Double,
        monthlyAmountsByYear: [Int: [Double?]],
        onMonthlyAmountsChange: (([Int: [Double?]]) -> Void)? = nil
    ) {
        self.savingsRatioPercent = savingsRatioPercent
        self.targetAmount = savingsBudgetTarget
        self.onMonthlyAmountsChange = onMonthlyAmountsChange

        let latestYear = monthlyAmountsByYear.keys.sorted().last ?? Calendar.current.component(.year, from: Date())
        let currentMonthIndex = Calendar.current.component(.month, from: Date()) - 1
        _selectedYear = State(initialValue: latestYear)
        _selectedMonthIndex = State(initialValue: currentMonthIndex)
        _monthlyAmountsByYear = State(initialValue: monthlyAmountsByYear)
    }

    private var availableYears: [Int] { monthlyAmountsByYear.keys.sorted() }
    private var canGoPrev: Bool { (availableYears.first ?? Int.max) < selectedYear }
    private var canGoNext: Bool { (availableYears.last ?? Int.min) > selectedYear }
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
    private var selectedNode: SavingsMonthNode {
        snapshot.fullYearNodes[min(max(selectedMonthIndex, 0), 11)]
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

    private var shellBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.shellBg1, AppColors.shellBg2],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            shellBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                    header
                    yearOverviewCard
                    trendCard
                    summaryCard
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.tabBarReserve + AppSpacing.md)
            }
        }
        .offset(y: dragOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(isPresented: $isShowingEditSheet, onDismiss: applyEditedAmount) {
            SavingsInputSheet(amount: $editingAmountValue)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedYear) { _, _ in
            if selectedMonthIndex < 0 || selectedMonthIndex > 11 {
                selectedMonthIndex = Calendar.current.component(.month, from: Date()) - 1
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Savings")
                .font(.h1)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(-0.5)

            Spacer()

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.inkTrack)
                        .frame(width: 34, height: 34)
                    Image(systemName: "xmark")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var yearOverviewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("MONTHLY CHECK-INS")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkFaint)
                    .tracking(AppTypography.Tracking.cardHeader)

                Spacer()

                yearPicker
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm + AppSpacing.xs), count: 4),
                spacing: AppSpacing.md
            ) {
                ForEach(snapshot.fullYearNodes) { node in
                    Button {
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

            Text("This page tracks the entire year. Tap any completed or current month to update its savings check-in.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
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
                    .foregroundStyle(AppColors.inkFaint)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }

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
                    .foregroundStyle(barStyle(for: node))
                    .cornerRadius(8)
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
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
            .frame(height: 220)
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private func barStyle(for node: SavingsMonthNode) -> AnyShapeStyle {
        switch node.state {
        case .future:
            return AnyShapeStyle(AppColors.inkTrack)
        case .pending:
            return AnyShapeStyle(AppColors.glassBlockBg)
        case .missed:
            return AnyShapeStyle(AppColors.inkTrack)
        case .belowTarget:
            return AnyShapeStyle(AppColors.inkPrimary.opacity(0.72))
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
        String(node.shortLabel.prefix(1))
    }

    private var summaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            summaryMetric(label: "YTD AVG", value: annualAverageRateText)
            summaryMetric(label: "ON TARGET", value: "\(snapshot.monthsOnTarget)")
            summaryMetric(label: "SAVED", value: formatMoney(annualSaved))
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private func summaryMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
            Text(value)
                .font(.footnoteBold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var yearPicker: some View {
        HStack(spacing: AppSpacing.sm) {
            Button { navigateYear(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.footnoteSemibold)
                    .foregroundStyle(canGoPrev ? AppColors.inkPrimary : AppColors.inkFaint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(AppColors.inkTrack))
            }
            .disabled(!canGoPrev)
            .buttonStyle(.plain)

            Text(String(selectedYear))
                .font(.inlineLabel)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(minWidth: 40)
                .monospacedDigit()

            Button { navigateYear(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.footnoteSemibold)
                    .foregroundStyle(canGoNext ? AppColors.inkPrimary : AppColors.inkFaint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(AppColors.inkTrack))
            }
            .disabled(!canGoNext)
            .buttonStyle(.plain)
        }
    }

    private func navigateYear(_ delta: Int) {
        guard let idx = availableYears.firstIndex(of: selectedYear) else { return }
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < availableYears.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedYear = availableYears[newIdx]
            selectedMonthIndex = min(selectedMonthIndex, 11)
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
