//
//  SavingsTargetDetailView2.swift
//  Flamora app
//
//  Savings target detail view - complete rewrite
//

import SwiftUI

struct SavingsTargetDetailView2: View {
    /// API 储蓄比例（百分比，如 25 表示 25%）。
    private let savingsRatioPercent: Double
    private let targetRate: Double
    private let targetAmount: Double

    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var monthlyAmountsByYear: [Int: [Double?]]
    @State private var editingMonthIndex: Int? = nil
    @State private var editingAmount: Double = 0
    @State private var isShowingEditSheet: Bool = false
    @State private var chartHoverIndex: Int? = nil
    @State private var dragOffset: CGFloat = 0

    private let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private let monthsShort = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    /// 阶段 0 / 路线图 0.2：目标与序列由调用方传入；年度月度序列在阶段 2 可换为 API。
    init(
        savingsRatioPercent: Double,
        savingsBudgetTarget: Double,
        monthlyAmountsByYear: [Int: [Double?]]
    ) {
        self.savingsRatioPercent = savingsRatioPercent
        self.targetRate = savingsRatioPercent / 100.0
        self.targetAmount = savingsBudgetTarget
        let byYear = monthlyAmountsByYear
        let latest = byYear.keys.sorted().last ?? Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: latest)
        _monthlyAmountsByYear = State(initialValue: byYear)
    }

    private var availableYears: [Int] { monthlyAmountsByYear.keys.sorted() }
    private var canGoPrev: Bool { (availableYears.first ?? Int.max) < selectedYear }
    private var canGoNext: Bool { (availableYears.last  ?? Int.min) > selectedYear }

    private var currentMonthlyAmounts: [Double?] {
        monthlyAmountsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
    }

    private var annualSaved: Double {
        currentMonthlyAmounts.compactMap { $0 }.reduce(0, +)
    }

    private func navigateYear(_ delta: Int) {
        guard let idx = availableYears.firstIndex(of: selectedYear) else { return }
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < availableYears.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedYear = availableYears[newIdx]
            chartHoverIndex = nil
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Header
                    HStack(alignment: .firstTextBaseline) {
                        Text("Saving overview")
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.bodySmallSemibold)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, -4)

                    // Total saved
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(formatMoney(annualSaved))
                            .font(.display)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Total saved this year")
                            .font(.supportingText)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    // Chart section with year picker
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Text("ANNUAL TREND")
                                .font(.cardHeader)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(1.5)

                            Spacer()

                            yearPicker
                        }

                        chartView
                            .frame(height: 220)
                            .padding(.top, AppSpacing.xs)
                    }
                    .padding(.top, AppSpacing.sm)

                    // Target info — 仅在 Budget Setup 完成（targetAmount > 0）后展示
                    if targetAmount > 0 {
                        HStack(spacing: AppSpacing.xl) {
                            VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
                                Text("TARGET SAVING RATE")
                                    .font(.cardHeader)
                                    .foregroundColor(AppColors.textTertiary)

                                Text("\(Int(savingsRatioPercent))%")
                                    .font(.detailTitle)
                                    .foregroundStyle(AppColors.textPrimary)
                            }

                            Divider()
                                .frame(height: 50)
                                .background(AppColors.surfaceBorder)

                            VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
                                Text("TARGET SAVING")
                                    .font(.cardHeader)
                                    .foregroundColor(AppColors.textTertiary)

                                Text(formatMoney(targetAmount))
                                    .font(.detailTitle)
                                    .foregroundStyle(AppColors.textPrimary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.sm)
                    }

                    // Monthly milestones
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("MONTHLY MILESTONES")
                            .font(.smallLabel)
                            .foregroundColor(AppColors.textTertiary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm + AppSpacing.xs) {
                            ForEach(0..<12) { index in
                                monthCard(index: index)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.tabBarReserve + AppSpacing.md)
            }
        }
        .preferredColorScheme(.dark)
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
        .sheet(isPresented: $isShowingEditSheet, onDismiss: {
            applyEditedAmount()
        }) {
            SavingsInputSheet(amount: $editingAmount)
                .ignoresSafeArea(.container, edges: .bottom)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppRadius.button)
                .presentationBackground(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            Button { navigateYear(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.footnoteRegular)
                    .foregroundColor(canGoPrev ? AppColors.textSecondary : AppColors.textTertiary)
            }
            .disabled(!canGoPrev)
            .buttonStyle(.plain)

            Text(String(selectedYear))
                .font(.footnoteRegular)
                .foregroundColor(AppColors.textSecondary)
                .frame(minWidth: 36)

            Button { navigateYear(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.footnoteRegular)
                    .foregroundColor(canGoNext ? AppColors.textSecondary : AppColors.textTertiary)
            }
            .disabled(!canGoNext)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Chart View

    /// 动态图表最大值：取实际储蓄数据与目标值中的较大者，避免固定量程失真。
    private var maxChartAmount: Double {
        let dataMax = currentMonthlyAmounts.compactMap { $0 }.max() ?? 0
        return max(dataMax, targetAmount, 1)
    }

    private var chartView: some View {
        GeometryReader { geometry in
            let barAreaHeight = geometry.size.height - 30 // 30 for month labels
            let targetRatio = CGFloat(targetAmount / maxChartAmount)
            let targetY = geometry.size.height - 30 - barAreaHeight * targetRatio

            ZStack(alignment: .bottomLeading) {
                // Target line — 仅在 Budget Setup 完成后展示
                if targetAmount > 0 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: targetY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: targetY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundColor(AppColors.textTertiary)
                }

                HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                    ForEach(0..<12) { index in
                        barView(index: index, maxHeight: barAreaHeight)
                    }
                }

                chartHoverOverlay(geometry: geometry)

                // Target label — 仅在 Budget Setup 完成后展示
                if targetAmount > 0 {
                    Text("TARGET")
                        .font(.label)
                        .foregroundColor(AppColors.textTertiary)
                        .position(x: geometry.size.width - 30, y: targetY - 10)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    navigateYear(value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private func barView(index: Int, maxHeight: CGFloat) -> some View {
        let amount = index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil
        let height = calculateHeight(amount: amount, maxHeight: maxHeight)
        let isTarget = targetAmount > 0 && (amount ?? 0) >= targetAmount

        return VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(barColor(amount: amount, isTarget: isTarget))
                .frame(height: height)

            Text(monthsShort[index])
                .font(.cardHeader)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chartHoverOverlay(geometry: GeometryProxy) -> some View {
        let step = geometry.size.width / 12
        let maxHeight = geometry.size.height - 30

        return ZStack {
            if let index = chartHoverIndex {
                let amount = index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil
                let barHeight = calculateHeight(amount: amount, maxHeight: maxHeight)
                let xPosition = step * (CGFloat(index) + 0.5)
                let yPosition = max(18, geometry.size.height - barHeight - 40)

                VStack(spacing: AppSpacing.sm) {
                    Text(months[index])
                        .font(.label)
                        .foregroundColor(AppColors.textSecondary)

                    Text(amount == nil ? "--" : formatMoney(amount ?? 0))
                        .font(.smallLabel)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.vertical, AppSpacing.sm)
                .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.surfaceBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .position(x: xPosition, y: yPosition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let clampedX = min(max(value.location.x, 0), geometry.size.width - 1)
                    let index = Int(clampedX / step)
                    chartHoverIndex = min(max(index, 0), 11)
                }
                .onEnded { _ in
                    chartHoverIndex = nil
                }
        )
        .onTapGesture {
            chartHoverIndex = nil
        }
    }

    private func calculateHeight(amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 20 }
        let ratio = min(amount / maxChartAmount, 1.0)
        return max(20, maxHeight * CGFloat(ratio))
    }

    private func barColor(amount: Double?, isTarget: Bool) -> AnyShapeStyle {
        if amount == nil {
            return AnyShapeStyle(AppColors.surfaceBorder)
        }
        if isTarget {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppColors.accentPurple, AppColors.accentPink, AppColors.accentAmber],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(AppColors.surfaceElevated)
    }

    // MARK: - Month Card

    private func monthCard(index: Int) -> some View {
        let amount = index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil
        let hasTarget = targetAmount > 0
        let isTarget = hasTarget && (amount ?? 0) >= targetAmount
        let hasData = amount != nil

        return VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
            HStack {
                Text(months[index])
                    .font(.smallLabel)
                    .foregroundColor(hasData ? AppColors.textSecondary : AppColors.textTertiary)

                Spacer()

                if isTarget {
                    flameBadge
                }
            }

            if let amount = amount {
                if hasTarget {
                    Text("\(formatMoney(amount)) / \(formatMoney(targetAmount))")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                } else {
                    Text(formatMoney(amount))
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
            } else {
                if hasTarget {
                    Text("-- / \(formatMoney(targetAmount))")
                        .font(.bodySmallSemibold)
                        .foregroundColor(AppColors.textTertiary)
                } else {
                    Text("--")
                        .font(.bodySmallSemibold)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(hasData ? AppColors.surfaceBorder : AppColors.surfaceBorder.opacity(0.5), lineWidth: 1)
        )
        .opacity(hasData ? 1.0 : 0.7)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .onTapGesture {
            beginEditMonth(index: index)
        }
    }

    private var flameBadge: some View {
        LinearGradient(
            colors: [AppColors.accentPurple, AppColors.accentPink, AppColors.accentAmber],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask(
            FlameIcon(size: 16, color: AppColors.textPrimary)
        )
        .frame(width: 16, height: 16)
    }

    private func beginEditMonth(index: Int) {
        editingMonthIndex = index
        editingAmount = (index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil) ?? 0
        isShowingEditSheet = true
    }

    private func applyEditedAmount() {
        guard let index = editingMonthIndex else { return }
        var amounts = monthlyAmountsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
        if editingAmount > 0 {
            amounts[index] = editingAmount
        } else {
            amounts[index] = nil
        }
        monthlyAmountsByYear[selectedYear] = amounts
    }

    // MARK: - Helper

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
        savingsRatioPercent: MockData.apiMonthlyBudget.savingsRatio,
        savingsBudgetTarget: MockData.apiMonthlyBudget.savingsBudget,
        monthlyAmountsByYear: MockData.savingsByYear
    )
}

/// Home → Plan → 储蓄全屏：无父级传入 `apiBudget` 时在内部拉取当月预算（与 `CashflowView` 显式传入二选一）。
struct SavingsTargetDetailView2Container: View {
    @Environment(PlaidManager.self) private var plaidManager
    @State private var apiBudget = APIMonthlyBudget.empty
    @State private var monthlyAmountsByYear: [Int: [Double?]] = CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()

    var body: some View {
        SavingsTargetDetailView2(
            savingsRatioPercent: apiBudget.savingsRatio,
            savingsBudgetTarget: apiBudget.savingsBudget,
            monthlyAmountsByYear: monthlyAmountsByYear
        )
        .onAppear {
            // 优先使用共享缓存（与 CashflowView / JourneyView 同一组数据），避免数据不一致
            if let cached = TabContentCache.shared.cashflowSavingsByYear {
                monthlyAmountsByYear = cached
            }
            if let cachedBudget = TabContentCache.shared.cashflowBudget {
                apiBudget = cachedBudget
            }
        }
        .task {
            await loadBudgetAndSavingsSeries()
        }
    }

    private func loadBudgetAndSavingsSeries() async {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let month = f.string(from: Date())
        async let budgetResult = try? await APIService.shared.getMonthlyBudget(month: month)
        async let savingsSeries = loadSavingsByYearFromAPI()
        let (b, series) = await (budgetResult, savingsSeries)
        if let b {
            apiBudget = b
            TabContentCache.shared.setCashflowBudget(b)
        }
        if let series {
            monthlyAmountsByYear = series
            TabContentCache.shared.setCashflowSavingsByYear(series)
        } else {
            monthlyAmountsByYear = CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()
        }
    }

    /// 已连接银行时用多月份 `get-spending-summary` 推导每月储蓄；否则为当年全 nil 序列（非 Mock）。
    private func loadSavingsByYearFromAPI() async -> [Int: [Double?]]? {
        guard plaidManager.hasLinkedBank else { return nil }
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
        guard !summaries.isEmpty else { return nil }
        return CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
    }
}
