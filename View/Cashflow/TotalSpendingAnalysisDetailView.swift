//
//  TotalSpendingAnalysisDetailView.swift
//  Flamora app
//
//  Light-shell redesign for combined (Needs + Wants) spending breakdown.
//  Entry: BudgetCard → total spending card; Journey → total spending tile.
//  Structure: shellBg gradient → glass hero card (total + stacked annual bars)
//  → glass sources card (Needs / Wants rows, drill into SpendingAnalysisDetailView).
//

import SwiftUI

struct TotalSpendingAnalysisDetailView: View {
    let data: TotalSpendingDetailData
    let needsDetailData: SpendingDetailData
    let wantsDetailData: SpendingDetailData
    /// 子类目预算（canonical id → amount）。透传给 Needs / Wants L2，给设了预算的子类目
    /// 渲染进度条 + Over 徽章。
    var categoryBudgets: [String: Double]? = nil
    var linkedAccounts: [Account] = []
    var onTransactionPersist: ((Transaction) async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBarIndex: Int?
    @State private var selectedYear: Int
    @State private var showNeedsDetail = false
    @State private var showWantsDetail = false
    @State private var showYearSwitcher = false

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private var needsColor: Color { AppColors.budgetNeedsBlue }
    private var wantsColor: Color { AppColors.budgetWantsPurple }

    init(
        data: TotalSpendingDetailData,
        needsDetailData: SpendingDetailData = .emptyNeeds,
        wantsDetailData: SpendingDetailData = .emptyWants,
        initialSelectedMonth: Int? = nil,
        initialSelectedYear: Int? = nil,
        categoryBudgets: [String: Double]? = nil,
        linkedAccounts: [Account] = [],
        onTransactionPersist: ((Transaction) async throws -> Void)? = nil
    ) {
        self.data = data
        self.needsDetailData = needsDetailData
        self.wantsDetailData = wantsDetailData
        self.categoryBudgets = categoryBudgets
        self.linkedAccounts = linkedAccounts
        self.onTransactionPersist = onTransactionPersist
        let resolvedYear: Int = {
            if let y = initialSelectedYear, data.availableYears.contains(y) { return y }
            return data.availableYears.last ?? Calendar.current.component(.year, from: Date())
        }()
        _selectedYear = State(initialValue: resolvedYear)
        _selectedBarIndex = State(initialValue: nil)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var currentTrend: [Double?] {
        data.trendsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
    }
    private var currentMonthlyData: [Int: TotalSpendingMonthData] {
        data.monthlyDataByYear[selectedYear] ?? [:]
    }

    private var maxChartValue: Double {
        let values = currentTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    private var selectedMonthData: TotalSpendingMonthData? {
        guard let selectedBarIndex else { return nil }
        return currentMonthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        if let selectedBarIndex {
            return selectedMonthData?.total ?? (currentTrend.indices.contains(selectedBarIndex) ? currentTrend[selectedBarIndex] : nil) ?? 0
        }
        return yearModeData?.total ?? 0
    }

    private var latestDataMonthIndex: Int? {
        currentTrend.indices.last { index in
            currentTrend[index] != nil || currentMonthlyData[index] != nil
        }
    }

    private var selectedMonthLabel: String {
        guard let selectedBarIndex else { return yearModeRangeLabel }
        return monthsFull[selectedBarIndex]
    }

    private var selectedPeriodLabel: String {
        guard let selectedBarIndex else { return yearModeTitleLabel }
        return "\(monthsFull[selectedBarIndex]) \(String(selectedYear))"
    }

    private var yearModeTitleLabel: String {
        "\(String(selectedYear)) YTD"
    }

    private var yearModeRangeLabel: String {
        guard let latestDataMonthIndex else { return String(selectedYear) }
        return "Jan-\(monthsFull[latestDataMonthIndex]) \(String(selectedYear))"
    }

    private var displayedSpendData: TotalSpendingMonthData? {
        selectedMonthData ?? yearModeData
    }

    private var yearModeData: TotalSpendingMonthData? {
        let months = currentMonthlyData.values
        guard !months.isEmpty else { return nil }
        let needs = months.reduce(0) { $0 + max($1.needsAmount, 0) }
        let wants = months.reduce(0) { $0 + max($1.wantsAmount, 0) }
        let total = needs + wants
        guard total > 0 else { return nil }
        return TotalSpendingMonthData(
            total: total,
            needsAmount: needs,
            wantsAmount: wants,
            needsPercentage: needs / total * 100,
            wantsPercentage: wants / total * 100
        )
    }

    private var canGoPrev: Bool { (data.availableYears.first ?? Int.max) < selectedYear }
    private var canGoNext: Bool { (data.availableYears.last  ?? Int.min) > selectedYear }

    private var selectableYears: [Int] {
        let years = data.availableYears
        if years.isEmpty { return [selectedYear] }
        return years
    }

    private func navigateYear(_ delta: Int) {
        let years = data.availableYears
        guard let idx = years.firstIndex(of: selectedYear) else { return }
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < years.count else { return }
        selectYear(years[newIdx])
    }

    private func selectYear(_ newYear: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedYear = newYear
            selectedBarIndex = nil
        }
    }

    var body: some View {
        DetailSheetScaffold(title: data.title) {
            dismiss()
        } content: {
            heroCard
            sourcesCard
        }
        .fullScreenCover(isPresented: $showNeedsDetail) {
            SpendingAnalysisDetailView(
                data: needsDetailData,
                flamoraCategory: "needs",
                initialSelectedMonth: selectedBarIndex,
                initialSelectedYear: selectedYear,
                categoryBudgets: categoryBudgets,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: onTransactionPersist
            )
        }
        .fullScreenCover(isPresented: $showWantsDetail) {
            SpendingAnalysisDetailView(
                data: wantsDetailData,
                flamoraCategory: "wants",
                initialSelectedMonth: selectedBarIndex,
                initialSelectedYear: selectedYear,
                categoryBudgets: categoryBudgets,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: onTransactionPersist
            )
        }
        .onChange(of: data.trendsByYear.isEmpty) { _, isEmpty in
            guard !isEmpty else { return }
            selectedBarIndex = nil
        }
        .sheet(isPresented: $showYearSwitcher) {
            CashflowYearSwitcherSheet(
                years: selectableYears,
                selected: selectedYear
            ) { year in
                selectYear(year)
            }
        }
    }

    // MARK: Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL SPEND")
                        .font(.cardHeader)
                        .foregroundStyle(AppColors.inkPrimary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Text(selectedPeriodLabel)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                }
                Spacer()
                yearPicker
            }

            Text(formatCurrencyNoCents(selectedTotal))
                .font(.currencyHero)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)

            chartView.frame(height: 180)

            if displayedSpendData != nil {
                legend
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBarIndex = nil
            }
        }
    }

    private var yearPicker: some View {
        Button {
            showYearSwitcher = true
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(String(selectedYear))
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkFaint)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var legend: some View {
        HStack(spacing: AppSpacing.md) {
            legendChip(color: needsColor, label: "Needs")
            legendChip(color: wantsColor, label: "Wants")
            Spacer()
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
        }
    }

    private var chartView: some View {
        GeometryReader { geometry in
            let rawHeight = geometry.size.height.isFinite ? geometry.size.height : 0
            let barAreaHeight = max(rawHeight - 26, 0)
            let barSpacing: CGFloat = 8
            let totalSpacing = barSpacing * 11
            let availableWidth = geometry.size.width.isFinite ? max(geometry.size.width, 0) : 0
            let barWidth = max((availableWidth - totalSpacing) / 12, 0)

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<12, id: \.self) { index in
                    barColumn(index: index, barWidth: barWidth, maxHeight: barAreaHeight)
                        .highPriorityGesture(
                            TapGesture().onEnded {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedBarIndex = index
                            }
                        })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    navigateYear(value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount: Double? = currentTrend.indices.contains(index) ? currentTrend[index] : nil
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = selectedBarIndex == index

        return VStack(spacing: 8) {
            Group {
                if amount != nil, let monthData = currentMonthlyData[index] {
                    stackedBarFill(for: monthData, isSelected: isSelected)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.inkTrack)
                }
            }
            .frame(width: barWidth, height: height)
            .opacity(amount == nil ? 0.5 : 1.0)

            Text(monthLabels[index])
                .font(.caption)
                .foregroundStyle(isSelected ? AppColors.inkPrimary : AppColors.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func stackedBarFill(for monthData: TotalSpendingMonthData, isSelected: Bool) -> some View {
        let total = max(monthData.total, 0.0001)
        let opacity: Double = isSelected ? 1.0 : 0.55
        return GeometryReader { geometry in
            let h = geometry.size.height.isFinite ? max(geometry.size.height, 0) : 0
            VStack(spacing: 0) {
                Rectangle().fill(wantsColor.opacity(opacity))
                    .frame(height: h * CGFloat(monthData.wantsAmount / total))
                Rectangle().fill(needsColor.opacity(opacity))
                    .frame(height: h * CGFloat(monthData.needsAmount / total))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 14 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(14, maxHeight * CGFloat(ratio))
    }

    // MARK: Sources card

    @ViewBuilder
    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CATEGORIES")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            if let monthData = displayedSpendData {
                Button { showNeedsDetail = true } label: {
                    sourceRow(
                        name: "Needs",
                        icon: "house.fill",
                        amount: monthData.needsAmount,
                        percentage: monthData.needsPercentage,
                        color: needsColor
                    )
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(AppColors.inkDivider)
                    .frame(height: 0.5)
                    .padding(.leading, AppSpacing.cardPadding + 38 + AppSpacing.md)
                    .padding(.trailing, AppSpacing.cardPadding)

                Button { showWantsDetail = true } label: {
                    sourceRow(
                        name: "Wants",
                        icon: "heart.fill",
                        amount: monthData.wantsAmount,
                        percentage: monthData.wantsPercentage,
                        color: wantsColor
                    )
                }
                .buttonStyle(.plain)
                    .padding(.bottom, AppSpacing.sm)
            } else {
                EmptyStateView(
                    icon: "tray",
                    title: "No spend yet",
                    message: "We haven't recorded any spending for \(selectedPeriodLabel). Once transactions sync, the breakdown will appear here."
                )
                .padding(.bottom, AppSpacing.sm)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private func sourceRow(name: String, icon: String, amount: Double, percentage: Double, color: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.footnoteSemibold)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("\(Int(percentage.rounded()))% of total")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkFaint)
            }

            Spacer()

            Text(formatCurrency(amount))
                .font(.footnoteBold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm + 2)
    }

    // MARK: Formatters

    private func formatCurrencyNoCents(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Journey entry container
/// Journey 入口 → 总支出详情的数据加载容器，与 CashflowView 使用同一 CashflowAPICharts 数据源。
struct TotalSpendingDetailContainer: View {
    @Environment(PlaidManager.self) private var plaidManager
    @State private var spendingTotalDetail: TotalSpendingDetailData?
    @State private var needsDetail: SpendingDetailData?
    @State private var wantsDetail: SpendingDetailData?
    @State private var linkedAccounts: [Account] = []

    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date()) - 1
    }

    var body: some View {
        TotalSpendingAnalysisDetailView(
            data: spendingTotalDetail ?? .empty,
            needsDetailData: needsDetail ?? .emptyNeeds,
            wantsDetailData: wantsDetail ?? .emptyWants,
            initialSelectedMonth: currentMonthIndex,
            linkedAccounts: linkedAccounts,
            onTransactionPersist: { tx in try await persistClassificationFromJourney(tx) }
        )
        .onAppear { syncFromCache() }
        .task { await loadData() }
    }

    private func syncFromCache() {
        let c = TabContentCache.shared
        if spendingTotalDetail == nil { spendingTotalDetail = c.cashflowSpendingTotalDetail }
        if needsDetail == nil { needsDetail = c.cashflowNeedsDetail }
        if wantsDetail == nil { wantsDetail = c.cashflowWantsDetail }
    }

    private func persistClassificationFromJourney(_ tx: Transaction) async throws {
        _ = try await APIService.shared.updateTransactionClassification(
            transactionId: tx.id,
            category: tx.category,
            subcategory: tx.subcategory
        )
        NotificationCenter.default.post(name: .transactionClassificationDidPersist, object: nil)
        await loadData()
    }

    private func loadData() async {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        async let netWorth = try? await APIService.shared.getNetWorthSummary()
        async let summariesTask = CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)

        if let nw = await netWorth {
            linkedAccounts = nw.accounts.map { Account.fromNetWorthAccount($0) }
        }
        guard plaidManager.hasLinkedBank else { return }
        let summaries = await summariesTask
        guard !summaries.isEmpty else { return }
        let total = CashflowAPICharts.totalSpendingDetail(summaries: summaries, year: year)
        let needs = CashflowAPICharts.needsSpendingDetail(summaries: summaries, year: year)
        let wants = CashflowAPICharts.wantsSpendingDetail(summaries: summaries, year: year)
        spendingTotalDetail = total
        needsDetail = needs
        wantsDetail = wants
        TabContentCache.shared.setCashflowSpendingDetails(total: total, needs: needs, wants: wants)
    }
}

#Preview("Spending Total") {
    TotalSpendingAnalysisDetailView(data: MockData.totalSpendingDetail)
}
