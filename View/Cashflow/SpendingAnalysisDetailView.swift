//
//  SpendingAnalysisDetailView.swift
//  Flamora app
//
//  Light-shell redesign. Entry: BudgetCard → Needs / Wants section.
//  Structure: shellBg gradient → glass hero card (selected total + annual bar
//  chart + year picker) → glass categories card (inkDivider rows, drill-down).
//

import SwiftUI

// MARK: - Helper

/// Picks the initial selected month: prefer the requested month if it has data;
/// otherwise fall back to the latest month with data, then the requested month,
/// then month 0.
func preferredCashflowMonthIndex(in trend: [Double?], requested: Int?) -> Int {
    let hasAnyData = trend.contains { $0 != nil }
    if let requested, trend.indices.contains(requested) {
        if !hasAnyData || trend[requested] != nil {
            return requested
        }
    }
    if let last = trend.indices.last(where: { trend[$0] != nil }) {
        return last
    }
    if let requested, (0..<12).contains(requested) {
        return requested
    }
    return 0
}

// MARK: - Spending Detail View (Needs / Wants)

struct SpendingAnalysisDetailView: View {
    let data: SpendingDetailData
    /// "needs" 或 "wants"，用于向 get-transactions 传递正确的分类过滤。
    let flamoraCategory: String
    /// 子类目预算（canonical id → amount）。给设过预算的类目额外渲染进度条 + "Over"
    /// 徽章；没设的就只展示金额。预算是可选的——用户没设代表不想为该类目设上限，
    /// 不在这里推他去设。
    var categoryBudgets: [String: Double]? = nil
    var linkedAccounts: [Account] = []
    /// 来自 Cashflow 时传入 `persistTransactionClassification`；未传时在子页内调 API 并广播 `transactionClassificationDidPersist`。
    var onTransactionPersist: ((Transaction) async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBarIndex: Int
    @State private var selectedYear: Int
    @State private var isShowingAnnualTotal = false
    @State private var selectedCategory: SpendingDetailCategory?
    @State private var showYearSwitcher = false

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let monthsLong = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    init(
        data: SpendingDetailData,
        flamoraCategory: String = "needs",
        initialSelectedMonth: Int? = nil,
        initialSelectedYear: Int? = nil,
        categoryBudgets: [String: Double]? = nil,
        linkedAccounts: [Account] = [],
        onTransactionPersist: ((Transaction) async throws -> Void)? = nil
    ) {
        self.data = data
        self.flamoraCategory = flamoraCategory
        self.categoryBudgets = categoryBudgets
        self.linkedAccounts = linkedAccounts
        self.onTransactionPersist = onTransactionPersist
        let resolvedYear: Int = {
            if let y = initialSelectedYear, data.availableYears.contains(y) { return y }
            return data.availableYears.last ?? Calendar.current.component(.year, from: Date())
        }()
        let trend = data.trendsByYear[resolvedYear] ?? []
        _selectedYear = State(initialValue: resolvedYear)
        _selectedBarIndex = State(initialValue: preferredCashflowMonthIndex(in: trend, requested: initialSelectedMonth))
    }

    private struct DetailCategoryRow: Identifiable {
        let id: String
        let name: String
        let icon: String
        let spent: Double
        let budget: Double
        /// 重建 `SpendingDetailCategory` 用于交易钻取（保留原本的 percentage）。
        let drilldown: SpendingDetailCategory
    }

    /// 当月该桶的所有可展示子类目，按 canonical id 归一化（避免 "groceries" / "Groceries" 重复）。
    /// 排序：先展示用户设了预算的（按支出降序），再展示没设预算但有支出的（按支出降序）。
    /// 没设预算且支出为 0 的不显示。
    private var categoryRows: [DetailCategoryRow] {
        let budgetMap = categoryBudgets ?? [:]
        let bucketCatalog = TransactionCategoryCatalog.all.filter { $0.parent == flamoraCategory }

        struct SpentEntry {
            let icon: String
            let displayName: String
            let amount: Double
            let drilldown: SpendingDetailCategory
        }
        var spentByKey: [String: SpentEntry] = [:]
        for cat in selectedCategories {
            let canonical = TransactionCategoryCatalog.canonicalSubcategory(fromStored: cat.name)
                         ?? TransactionCategoryCatalog.id(forDisplayedSubcategory: cat.name)
            let key = canonical ?? cat.name.lowercased()
            let catalog = canonical.flatMap { id in bucketCatalog.first { $0.id == id } }
            let displayName = catalog?.name ?? TransactionCategoryCatalog.displayName(for: cat.name)
            spentByKey[key] = SpentEntry(
                icon: catalog?.icon ?? cat.icon,
                displayName: displayName,
                amount: max(cat.amount, 0),
                drilldown: cat
            )
        }

        var budgeted: [DetailCategoryRow] = []
        var budgetedKeys = Set<String>()
        for cat in bucketCatalog {
            let budget = budgetMap[cat.id] ?? 0
            guard budget > 0 else { continue }
            let entry = spentByKey[cat.id]
            let drill = entry?.drilldown ?? SpendingDetailCategory(
                id: "budgeted-\(cat.id)-\(selectedYear)-\(selectedBarIndex)",
                icon: cat.icon, name: cat.name, amount: 0, percentage: 0
            )
            budgeted.append(DetailCategoryRow(
                id: cat.id, name: cat.name, icon: cat.icon,
                spent: entry?.amount ?? 0, budget: budget, drilldown: drill
            ))
            budgetedKeys.insert(cat.id)
        }
        budgeted.sort { $0.spent > $1.spent }

        var unbudgeted: [DetailCategoryRow] = []
        for (key, entry) in spentByKey where !budgetedKeys.contains(key) && entry.amount > 0.005 {
            unbudgeted.append(DetailCategoryRow(
                id: key, name: entry.displayName, icon: entry.icon,
                spent: entry.amount, budget: 0, drilldown: entry.drilldown
            ))
        }
        unbudgeted.sort { $0.spent > $1.spent }

        return budgeted + unbudgeted
    }

    private var accentColor: Color {
        flamoraCategory == "wants" ? AppColors.budgetWantsPurple : AppColors.budgetNeedsBlue
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
    private var currentMonthlyData: [Int: SpendingDetailMonthData] {
        data.monthlyDataByYear[selectedYear] ?? [:]
    }

    private var maxChartValue: Double {
        let values = currentTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    private var selectedMonthData: SpendingDetailMonthData? {
        currentMonthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        if isShowingAnnualTotal { return annualTotal }
        return selectedMonthData?.total ?? (currentTrend.indices.contains(selectedBarIndex) ? currentTrend[selectedBarIndex] : nil) ?? 0
    }

    private var annualTotal: Double {
        currentTrend.reduce(0) { partial, amount in
            partial + max(amount ?? 0, 0)
        }
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
        let trend = data.trendsByYear[newYear] ?? []
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedYear = newYear
            selectedBarIndex = preferredCashflowMonthIndex(in: trend, requested: selectedBarIndex)
            isShowingAnnualTotal = false
        }
    }

    private var selectedCategories: [SpendingDetailCategory] {
        (selectedMonthData?.categories ?? []).sorted { $0.amount > $1.amount }
    }

    private var selectedMonthLabel: String { monthsFull[selectedBarIndex] }
    private var selectedMonthLongLabel: String { monthsLong[selectedBarIndex] }

    var body: some View {
        DetailSheetScaffold(title: data.title) {
            dismiss()
        } content: {
            heroCard
            categoriesCard
        }
        .fullScreenCover(item: $selectedCategory) { category in
            let monthStr = String(format: "%04d-%02d", selectedYear, selectedBarIndex + 1)
            SpendingCategoryTransactionsDetailView(
                category: category,
                monthLabel: selectedMonthLongLabel,
                month: monthStr,
                flamoraCategory: flamoraCategory,
                accentColor: accentColor,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: onTransactionPersist
            )
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
                    Text(flamoraCategory.uppercased())
                        .font(.cardHeader)
                        .foregroundStyle(AppColors.inkPrimary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Text(isShowingAnnualTotal ? "\(String(selectedYear)) Total" : "\(selectedMonthLabel) \(String(selectedYear))")
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
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        handleChartGesture(
                            value,
                            width: availableWidth,
                            barWidth: barWidth,
                            barSpacing: barSpacing,
                            barAreaHeight: barAreaHeight
                        )
                    }
            )
        }
    }

    private func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount: Double? = currentTrend.indices.contains(index) ? currentTrend[index] : nil
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = !isShowingAnnualTotal && index == selectedBarIndex

        return VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? accentColor : AppColors.inkTrack)
                .frame(width: barWidth, height: height)
                .opacity(amount == nil ? 0.5 : 1.0)

            Text(monthLabels[index])
                .font(.caption)
                .foregroundStyle(isSelected ? AppColors.inkPrimary : AppColors.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func handleChartGesture(
        _ value: DragGesture.Value,
        width: CGFloat,
        barWidth: CGFloat,
        barSpacing: CGFloat,
        barAreaHeight: CGFloat
    ) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        if abs(horizontal) > 30, abs(horizontal) > abs(vertical) {
            navigateYear(horizontal < 0 ? 1 : -1)
            return
        }

        guard abs(horizontal) < 10, abs(vertical) < 10 else { return }

        let x = value.location.x
        let y = value.location.y
        guard x >= 0, x <= width, y >= 0 else { return }

        let step = barWidth + barSpacing
        guard step > 0 else { return }

        let rawIndex = Int(floor(x / step))
        let index = min(max(rawIndex, 0), 11)
        let columnStart = CGFloat(index) * step
        let columnEnd = columnStart + barWidth
        let amount: Double? = currentTrend.indices.contains(index) ? currentTrend[index] : nil
        let height = barHeight(for: amount, maxHeight: barAreaHeight)
        let barTop = max(barAreaHeight - height, 0)

        withAnimation(.easeInOut(duration: 0.2)) {
            if x >= columnStart, x <= columnEnd, y >= barTop {
                selectedBarIndex = index
                isShowingAnnualTotal = false
            } else if y < barAreaHeight {
                isShowingAnnualTotal = true
            }
        }
    }

    private func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 14 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(14, maxHeight * CGFloat(ratio))
    }

    // MARK: Categories card

    @ViewBuilder
    private var categoriesCard: some View {
        let rows = categoryRows

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

            if rows.isEmpty {
                Text("No spend recorded in \(selectedMonthLongLabel)")
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.cardPadding)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { rowDivider }
                        Button { selectedCategory = row.drilldown } label: {
                            categoryRow(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    private var rowDivider: some View {
        Rectangle()
            .fill(AppColors.inkDivider)
            .frame(height: 0.5)
            .padding(.leading, AppSpacing.cardPadding + 38 + AppSpacing.md)
            .padding(.trailing, AppSpacing.cardPadding)
    }

    /// 一行展示一个子类目。设了预算 → 进度条 + "$X of $Y" + "Over" 徽章；
    /// 没设 → 只展示金额。预算是可选的，没设并不是缺失状态，所以不渲染任何
    /// "No budget" 提示或 CTA。
    private func categoryRow(_ row: DetailCategoryRow) -> some View {
        let hasBudget = row.budget > 0
        let safeBudget = max(row.budget, 0.0001)
        let progress = min(max(row.spent / safeBudget, 0), 1)
        let isOver = hasBudget && row.spent > row.budget
        let statusColor = AppColors.warning

        return VStack(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.md) {
                categoryIcon(row.icon, color: accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                    if hasBudget {
                        HStack(spacing: AppSpacing.xs) {
                            Text("\(formatCurrency(row.budget)) budget")
                                .font(.caption)
                                .foregroundStyle(AppColors.inkFaint)
                                .monospacedDigit()
                            if isOver {
                                Text("Over")
                                    .font(.miniLabel)
                                    .foregroundStyle(statusColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(statusColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(row.spent))
                        .font(.footnoteBold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkFaint)
            }

            if hasBudget {
                GeometryReader { geo in
                    let width = max(geo.size.width, 0)
                    let barColor = accentColor
                    let trackColor = accentColor.opacity(isOver ? 0.20 : 0.14)
                    ZStack(alignment: .leading) {
                        Capsule().fill(trackColor).frame(height: 5)
                        Capsule().fill(barColor).frame(width: width * progress, height: 5)
                    }
                }
                .frame(height: 5)
                .padding(.leading, 38 + AppSpacing.md)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm + 2)
    }

    private func categoryIcon(_ icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.14))
                .frame(width: 38, height: 38)
            Image(systemName: icon)
                .font(.footnoteSemibold)
                .foregroundStyle(color)
        }
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

// MARK: - Year switcher

struct CashflowYearSwitcherSheet: View {
    let years: [Int]
    let selected: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private var sortedYears: [Int] {
        years.sorted(by: >)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                Text("Select year")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
            }

            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(sortedYears, id: \.self) { year in
                        row(for: year)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.shellBg1)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(for year: Int) -> some View {
        Button {
            onSelect(year)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(year))
                        .font(.bodyRegular)
                        .foregroundStyle(AppColors.inkPrimary)
                    if Calendar.current.component(.year, from: Date()) == year {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
                Spacer()
                if selected == year {
                    Image(systemName: "checkmark")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.glassCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category drill-down

private struct SpendingCategoryTransaction: Identifiable {
    let id: String
    let merchant: String
    let subtitle: String
    let amount: Double
    let raw: APITransaction
}

private struct SpendingCategoryTransactionGroup: Identifiable {
    let id: String
    let title: String
    let items: [SpendingCategoryTransaction]
}

struct SpendingCategoryTransactionsDetailView: View {
    let category: SpendingDetailCategory
    let monthLabel: String
    /// 月份字符串，如 "2026-03"，用于向 get-transactions 传递日期范围过滤。
    let month: String
    /// "needs" 或 "wants"
    let flamoraCategory: String
    let accentColor: Color
    var linkedAccounts: [Account] = []
    var onTransactionPersist: ((Transaction) async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var groups: [SpendingCategoryTransactionGroup] = []
    @State private var isLoading = true
    @State private var selectedTransaction: Transaction? = nil

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                    header
                    heroCard
                    transactionsCard
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xl + AppSpacing.lg)
            }
        }
        .task { await loadTransactions() }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction, linkedAccounts: linkedAccounts) { updated in
                try await persistClassification(updated)
                await loadTransactions(mergingSticky: updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.shellBg1)
        }
    }

    // MARK: Header (back chevron + title + X)

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.navChevron)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(width: 34, height: 34, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: Hero card (category identity + total)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: category.icon)
                        .font(.footnoteSemibold)
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(TransactionCategoryCatalog.displayName(for: category.name).uppercased())
                        .font(.cardHeader)
                        .foregroundStyle(AppColors.inkPrimary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Text("Total spend in \(monthLabel)")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineLimit(1)
                }
                Spacer()
            }

            Text(formatCurrency(category.amount))
                .font(.currencyHero)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    // MARK: Transactions card (grouped by date)

    @ViewBuilder
    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TRANSACTIONS")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            if isLoading {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView().tint(AppColors.inkSoft)
                    Text("Loading transactions…")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
            } else if groups.isEmpty {
                Text("No transactions in \(monthLabel)")
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.cardPadding)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { sectionIndex, group in
                        if sectionIndex > 0 {
                            Rectangle()
                                .fill(AppColors.inkDivider)
                                .frame(height: 0.5)
                                .padding(.horizontal, AppSpacing.cardPadding)
                                .padding(.vertical, AppSpacing.sm)
                        }
                        HStack {
                            Text(group.title)
                                .font(.caption)
                                .foregroundStyle(AppColors.inkFaint)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.top, sectionIndex == 0 ? 0 : AppSpacing.xs)
                        .padding(.bottom, AppSpacing.xs)

                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Rectangle()
                                    .fill(AppColors.inkDivider)
                                    .frame(height: 0.5)
                                    .padding(.leading, AppSpacing.cardPadding + 38 + AppSpacing.md)
                                    .padding(.trailing, AppSpacing.cardPadding)
                            }
                            transactionRow(item)
                        }
                    }
                }
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

    private func transactionRow(_ item: SpendingCategoryTransaction) -> some View {
        Button {
            selectedTransaction = Transaction(from: item.raw)
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: category.icon)
                        .font(.footnoteSemibold)
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.merchant)
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(formatCurrency(item.amount))
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.sm + 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private func persistClassification(_ updated: Transaction) async throws {
        if let onTransactionPersist {
            try await onTransactionPersist(updated)
        } else {
            _ = try await APIService.shared.updateTransactionClassification(
                transactionId: updated.id,
                category: updated.category,
                subcategory: updated.subcategory
            )
            NotificationCenter.default.post(name: .transactionClassificationDidPersist, object: nil)
        }
    }

    private func loadTransactions(mergingSticky sticky: Transaction? = nil) async {
        let components = month.split(separator: "-").map { Int($0) ?? 0 }
        guard components.count == 2 else { isLoading = false; return }
        let year = components[0], mon = components[1]
        let lastDay = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: DateComponents(year: year, month: mon))!)?.count ?? 30
        let startDate = "\(month)-01"
        let endDate = String(format: "%04d-%02d-%02d", year, mon, lastDay)

        let response = try? await APIService.shared.getTransactions(
            page: 1,
            limit: 100,
            category: flamoraCategory,
            subcategory: category.name,
            startDate: startDate,
            endDate: endDate
        )
        var txs = response?.transactions ?? []
        if let sticky, !txs.contains(where: { $0.id == sticky.id }) {
            txs.append(sticky.asAPITransaction(normalizedDate: normalizedDateKey(for: sticky)))
        }
        groups = groupTransactionsByDate(txs)
        isLoading = false
    }

    /// 与 `get-transactions` 返回的 `date`（`yyyy-MM-dd`）对齐，供合并编辑后的行。
    private func normalizedDateKey(for tx: Transaction) -> String {
        let parts = tx.date.split(separator: "-").map { String($0) }
        if parts.count == 3, parts[0].count == 4 {
            return tx.date
        }
        let ym = month.split(separator: "-")
        guard ym.count == 2,
              parts.count == 2,
              let m = Int(parts[0]), let d = Int(parts[1]) else {
            return tx.date
        }
        return String(format: "%@-%02d-%02d", String(ym[0]), m, d)
    }

    private func groupTransactionsByDate(_ transactions: [APITransaction]) -> [SpendingCategoryTransactionGroup] {
        var byDate: [String: [APITransaction]] = [:]
        for tx in transactions { byDate[tx.date, default: []].append(tx) }

        let parseFmt = DateFormatter(); parseFmt.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter(); displayFmt.dateFormat = "MMM d"
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        return byDate.keys.sorted(by: >).compactMap { key in
            guard let date = parseFmt.date(from: key) else { return nil }
            let items = byDate[key]!.sorted { $0.amount > $1.amount }.map { tx in
                SpendingCategoryTransaction(
                    id: tx.id,
                    merchant: tx.merchantDisplay,
                    subtitle: tx.flamoraSubcategory.map { TransactionCategoryCatalog.displayName(for: $0) } ?? "",
                    amount: tx.amount,
                    raw: tx
                )
            }
            let groupDate = cal.startOfDay(for: date)
            let title: String
            if groupDate == today { title = "TODAY" }
            else if groupDate == yesterday { title = "YESTERDAY" }
            else { title = displayFmt.string(from: date).uppercased() }
            return SpendingCategoryTransactionGroup(id: key, title: title, items: items)
        }
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

#Preview("Spending Needs") {
    SpendingAnalysisDetailView(data: MockData.needsSpendingDetail, flamoraCategory: "needs")
}

#Preview("Spending Wants") {
    SpendingAnalysisDetailView(data: MockData.wantsSpendingDetail, flamoraCategory: "wants")
}
