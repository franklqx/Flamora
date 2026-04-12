//
//  CashflowExpandedOverlayView.swift
//  Flamora app
//
//  Cash Flow 下拉展开专用页面（独立于 Home Simulator）。
//

import SwiftUI

struct CashflowExpandedOverlayView: View {
    private enum Surface: String, CaseIterable {
        case calendar = "Calendar"
        case trend = "Trend"
    }

    private enum TrendMode: String, CaseIterable {
        case expense = "Expense"
        case income = "Income"
    }

    private struct TrendPoint: Identifiable {
        let id: Int
        let label: String
        let value: Double
    }

    private struct CashCategoryRow: Identifiable {
        let id: String
        let name: String
        let icon: String
        let amount: Double
        let percentage: Double
    }

    private struct DayCell: Identifiable {
        let id: String
        let day: Int?
        let amount: Double
        let txCount: Int
        let isCurrentMonth: Bool
    }

    private struct DayTransaction: Identifiable {
        let id: String
        let merchant: String
        let amount: Double
        let category: String
    }

    private enum DataState {
        case placeholder
        case demo
        case live
    }

    let topPadding: CGFloat
    let onClose: () -> Void

    @Environment(PlaidManager.self) private var plaidManager
    @State private var selectedSurface: Surface = .calendar
    @State private var trendMode: TrendMode = .expense
    @State private var selectedMonthIndex = max(0, Calendar.current.component(.month, from: Date()) - 1)
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    @State private var selectedCategory: String?

    @State private var dataState: DataState = .placeholder
    @State private var loading = false
    @State private var summaries: [Int: APISpendingSummary] = [:]
    @State private var transactions: [Transaction] = []

    private let cal = Calendar.current
    private let monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let weekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Text("Cash Flow")
                        .font(.h1)
                        .foregroundStyle(AppColors.heroTextPrimary)
                    Spacer()
                }
                .padding(.top, topPadding)

                Text(currentMonthTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.heroTextFaint)

                surfaceSwitch

                if selectedSurface == .calendar {
                    calendarSection
                } else {
                    trendSection
                }

                if dataState == .demo {
                    Text("Using static preview data until API data is ready.")
                        .font(.caption)
                        .foregroundStyle(AppColors.heroTextHint)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.xl)
        }
        .onAppear {
            if selectedDay <= 0 { selectedDay = 1 }
            // Restore from cache immediately to avoid empty flash when overlay reopens.
            if let cached = TabContentCache.shared.cashflowMonthlySummaries, !cached.isEmpty {
                summaries = cached
                dataState = .live
            }
        }
        .task(id: plaidManager.hasLinkedBank) {
            await loadOverlayData()
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await loadOverlayData() }
        }
    }
}

private extension CashflowExpandedOverlayView {
    private var currentYear: Int {
        cal.component(.year, from: Date())
    }

    private var monthCountInScope: Int {
        max(1, cal.component(.month, from: Date()))
    }

    private var currentMonthTitle: String {
        "\(monthShort[selectedMonthIndex]) \(currentYear)"
    }

    private var isPlaceholder: Bool {
        dataState == .placeholder
    }

    private var trendPoints: [TrendPoint] {
        // Never show fake amounts for an unconnected user.
        if isPlaceholder { return [] }

        let pts: [TrendPoint] = (0..<monthCountInScope).map { index in
            let value: Double
            if let s = summaries[index] {
                value = (trendMode == .expense) ? s.totalSpending : s.totalIncome
            } else {
                value = 0
            }
            return TrendPoint(id: index, label: monthShort[index], value: value)
        }

        // Return real (possibly all-zero) points; never fabricate fake amounts for a connected user.
        return pts
    }

    private var categoryRows: [CashCategoryRow] {
        // categoriesSection is hidden when isPlaceholder; this guard is a safety belt.
        if isPlaceholder { return [] }

        if let s = summaries[selectedMonthIndex] {
            if trendMode == .expense {
                let merged = (s.needs.subcategories + s.wants.subcategories)
                let total = max(merged.reduce(0) { $0 + $1.amount }, 0.0001)
                if !merged.isEmpty {
                    return merged
                        .sorted { $0.amount > $1.amount }
                        .prefix(6)
                        .map { row in
                            CashCategoryRow(
                                id: row.subcategory.lowercased(),
                                name: row.subcategory,
                                icon: TransactionCategoryCatalog.icon(forStoredSubcategory: row.subcategory) ?? "tag.fill",
                                amount: row.amount,
                                percentage: row.amount / total
                            )
                        }
                }
            } else {
                let merged = (s.incomeActiveSources ?? []) + (s.incomePassiveSources ?? [])
                let total = max(merged.reduce(0) { $0 + $1.amount }, 0.0001)
                if !merged.isEmpty {
                    return merged
                        .sorted { $0.amount > $1.amount }
                        .prefix(6)
                        .map { src in
                            CashCategoryRow(
                                id: src.name.lowercased(),
                                name: src.name,
                                icon: TransactionCategoryCatalog.icon(forStoredSubcategory: src.name) ?? "dollarsign.circle.fill",
                                amount: src.amount,
                                percentage: src.amount / total
                            )
                        }
                }
            }
        }

        // No summary data yet for this month — return empty rather than fabricating amounts.
        return []
    }

    private var selectedPoint: TrendPoint {
        guard !trendPoints.isEmpty else {
            return TrendPoint(id: selectedMonthIndex, label: monthShort[selectedMonthIndex], value: 0)
        }
        let safe = min(max(0, selectedMonthIndex), max(0, trendPoints.count - 1))
        return trendPoints[safe]
    }

    private var calendarGrid: [DayCell] {
        guard let firstDay = cal.date(from: DateComponents(year: currentYear, month: selectedMonthIndex + 1, day: 1)),
              let dayRange = cal.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: firstDay)
        let leading = max(0, firstWeekday - 1)
        var cells: [DayCell] = Array(repeating: DayCell(id: UUID().uuidString, day: nil, amount: 0, txCount: 0, isCurrentMonth: false), count: leading)

        for day in dayRange {
            let txs = transactionsOnDay(day: day, monthIndex: selectedMonthIndex)
            let expense = txs.filter { $0.amount >= 0 }.reduce(0) { $0 + $1.amount }
            cells.append(
                DayCell(
                    id: "day-\(day)",
                    day: day,
                    amount: expense,
                    txCount: txs.count,
                    isCurrentMonth: true
                )
            )
        }
        while cells.count % 7 != 0 {
            cells.append(DayCell(id: UUID().uuidString, day: nil, amount: 0, txCount: 0, isCurrentMonth: false))
        }
        return cells
    }

    private var dayTransactions: [DayTransaction] {
        guard !isPlaceholder else {
            return [
                DayTransaction(id: "p1", merchant: "—", amount: 0, category: "Needs"),
                DayTransaction(id: "p2", merchant: "—", amount: 0, category: "Wants"),
                DayTransaction(id: "p3", merchant: "—", amount: 0, category: "Needs"),
            ]
        }

        let txs = transactionsOnDay(day: selectedDay, monthIndex: selectedMonthIndex)
        if !txs.isEmpty {
            return txs.prefix(6).map { tx in
                DayTransaction(
                    id: tx.id,
                    merchant: tx.merchant,
                    amount: tx.amount,
                    category: (tx.category ?? "needs").capitalized
                )
            }
        }

        return [
            DayTransaction(id: "d1", merchant: "No transactions yet", amount: 0, category: "—")
        ]
    }

    private var dayExpenseTotal: Double {
        guard !isPlaceholder else { return 0 }
        return dayTransactions.filter { $0.amount >= 0 }.reduce(0) { $0 + $1.amount }
    }

    private var seriesForSelectedCategory: [TrendPoint] {
        guard let selectedCategory else { return trendPoints }
        let normalized = selectedCategory.lowercased()

        if dataState == .live {
            let points: [TrendPoint] = (0..<monthCountInScope).map { idx in
                guard let summary = summaries[idx] else {
                    return TrendPoint(id: idx, label: monthShort[idx], value: 0)
                }
                if trendMode == .expense {
                    let merged = summary.needs.subcategories + summary.wants.subcategories
                    let v = merged.first(where: { $0.subcategory.lowercased() == normalized })?.amount ?? 0
                    return TrendPoint(id: idx, label: monthShort[idx], value: v)
                } else {
                    let merged = (summary.incomeActiveSources ?? []) + (summary.incomePassiveSources ?? [])
                    let v = merged.first(where: { $0.name.lowercased() == normalized })?.amount ?? 0
                    return TrendPoint(id: idx, label: monthShort[idx], value: v)
                }
            }
            if points.contains(where: { $0.value > 0 }) { return points }
        }

        let base = max(selectedPoint.value * 0.35, 120)
        return trendPoints.map { pt in
            let wobble = (Double((pt.id % 4) - 2) * 0.08) + 1
            return TrendPoint(id: pt.id, label: pt.label, value: max(0, base * wobble))
        }
    }

    private var averageForSelectedCategory: Double {
        let points = seriesForSelectedCategory
        guard !points.isEmpty else { return 0 }
        return points.reduce(0) { $0 + $1.value } / Double(points.count)
    }

    private var peakForSelectedCategory: TrendPoint? {
        seriesForSelectedCategory.max(by: { $0.value < $1.value })
    }

    private var shareForSelectedCategory: Double {
        guard selectedPoint.value > 0 else { return 0 }
        let v = seriesForSelectedCategory.first(where: { $0.id == selectedMonthIndex })?.value ?? 0
        return (v / selectedPoint.value) * 100
    }

    private var surfaceSwitch: some View {
        let selectedFill = Color(hex: "#20388F").opacity(0.92)
        let unselectedFill = Color(hex: "#6D7EEA").opacity(0.24)
        return HStack(spacing: 6) {
            ForEach(Surface.allCases, id: \.self) { view in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSurface = view
                        selectedCategory = nil
                    }
                }) {
                    Text(view.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedSurface == view ? AppColors.heroTextPrimary : AppColors.heroTextSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedSurface == view ? selectedFill : unselectedFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#9BA9FF").opacity(0.24))
        )
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.heroTextPrimary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.overlayWhiteWash)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(selectedMonthIndex == 0)
                .opacity(selectedMonthIndex == 0 ? 0.45 : 1)

                Spacer()
                Text(currentMonthTitle.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.heroTextSoft)
                    .tracking(0.6)
                Spacer()

                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.heroTextPrimary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.overlayWhiteWash)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(selectedMonthIndex >= monthCountInScope - 1)
                .opacity(selectedMonthIndex >= monthCountInScope - 1 ? 0.45 : 1)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(weekdayShort, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.heroTextHint)
                        .frame(maxWidth: .infinity)
                }
                ForEach(calendarGrid) { cell in
                    dayCellView(cell)
                }
            }
            .accessibilityIdentifier("cashflow_calendar_grid")

            // Only show day-detail tray once the user has connected and data is available.
            if !isPlaceholder {
                calendarDetailTray
            } else {
                Text("Connect a bank account to see daily spending detail.")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.heroTextHint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityIdentifier("cashflow_calendar_connect_hint")
            }
        }
    }

    @ViewBuilder
    private func dayCellView(_ cell: DayCell) -> some View {
        if let day = cell.day {
            Button(action: { selectedDay = day }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(day)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.heroTextPrimary)
                    Spacer(minLength: 0)
                    if cell.txCount > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<min(3, cell.txCount), id: \.self) { _ in
                                Circle()
                                    .fill(AppColors.accentGreen.opacity(0.72))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                }
                .padding(8)
                .frame(height: 64)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(day == selectedDay ? AppColors.accentBlueBright.opacity(0.52) : AppColors.overlayWhiteWash)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(day == selectedDay ? AppColors.overlayWhiteHigh : AppColors.overlayWhiteStroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 64)
        }
    }

    private var calendarDetailTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAY DETAIL")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.inkMeta)
                        .tracking(0.8)
                    Text(detailTitleText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.inkPrimary)
                }
                Spacer()
                Text(dayTotalText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.inkPrimary)
            }

            VStack(spacing: 8) {
                ForEach(dayTransactions) { tx in
                    transactionRow(tx)
                }
            }
            .redacted(reason: isPlaceholder ? .placeholder : [])
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.86), Color(hex: "#F8F9FF").opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
        .accessibilityIdentifier("cashflow_day_detail_tray")
    }

    private var detailTitleText: String {
        "\(monthShort[selectedMonthIndex]) \(selectedDay)"
    }

    private var dayTotalText: String {
        isPlaceholder ? "—" : "-\(NumberFormatter.appCurrency(dayExpenseTotal))"
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(selectedCategory ?? (trendMode == .expense ? "Total Expense" : "Total Income"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.heroTextHint)
                    .textCase(.uppercase)
                Text(isPlaceholder ? "—" : NumberFormatter.appCurrency(selectedPoint.value))
                    .font(.h1)
                    .foregroundStyle(AppColors.heroTextPrimary)
                Text("\(selectedPoint.label) \(currentYear)")
                    .font(.caption)
                    .foregroundStyle(AppColors.heroTextFaint)
            }

            HStack(spacing: 8) {
                ForEach(TrendMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            trendMode = mode
                            selectedCategory = nil
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(trendMode == mode ? AppColors.inkPrimary : AppColors.heroTextSoft)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(trendMode == mode ? Color.white : AppColors.overlayWhiteWash)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if isPlaceholder {
                // Unconnected: show an honest empty state instead of fake chart/categories.
                trendUnconnectedEmptyState
            } else {
                trendBarChart
                categoriesSection
            }
        }
    }

    private var trendUnconnectedEmptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.h1)
                .foregroundStyle(AppColors.heroTextHint)
            Text("Connect a bank account to see your spending trends and category breakdowns.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.heroTextHint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .accessibilityIdentifier("cashflow_trend_empty_state")
    }

    private var trendBarChart: some View {
        let maxValue = max(trendPoints.map { $0.value }.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(trendPoints) { point in
                Button(action: { selectedMonthIndex = point.id }) {
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(point.id == selectedMonthIndex ? Color.white : Color.white.opacity(0.22))
                            .frame(width: 12, height: max(16, CGFloat(point.value / maxValue) * 132))
                        Text(point.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(point.id == selectedMonthIndex ? AppColors.heroTextPrimary : AppColors.heroTextHint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 170, alignment: .bottom)
        .padding(.vertical, 8)
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Categories")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.inkMeta)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text("\(selectedPoint.label) \(currentYear)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.inkSoft)
            }

            if selectedCategory != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { self.selectedCategory = nil }) {
                        Label("Back to all categories", systemImage: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.inkSoft)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        metricCard(title: "Average", value: NumberFormatter.appCurrency(averageForSelectedCategory))
                        metricCard(title: "Peak", value: peakMetricValue)
                        metricCard(title: "Share", value: "\(Int(shareForSelectedCategory.rounded()))%")
                    }

                    VStack(spacing: 8) {
                        ForEach(seriesForSelectedCategory) { point in
                            Button(action: { selectedMonthIndex = point.id }) {
                                HStack {
                                    Text(point.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.inkPrimary)
                                    Spacer()
                                    Text(NumberFormatter.appCurrency(point.value))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppColors.inkPrimary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(point.id == selectedMonthIndex ? Color.white.opacity(0.92) : Color.white.opacity(0.58))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .redacted(reason: isPlaceholder ? .placeholder : [])
            } else {
                VStack(spacing: 8) {
                    ForEach(categoryRows) { row in
                        Button(action: { selectedCategory = row.name }) {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(AppColors.overlayWhiteMid)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: row.icon)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppColors.inkSoft)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.inkPrimary)
                                    Text("\(Int((row.percentage * 100).rounded()))%")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(AppColors.inkMeta)
                                }
                                Spacer()
                                Text(row.amount == 0 ? "—" : NumberFormatter.appCurrency(row.amount))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.inkPrimary)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.8), Color.white.opacity(0.56)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .redacted(reason: isPlaceholder ? .placeholder : [])
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.86), Color(hex: "#F8F9FF").opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
        .accessibilityIdentifier("cashflow_categories_section")
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.inkMeta)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
    }

    private func transactionRow(_ tx: DayTransaction) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.overlayWhiteMid)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: TransactionCategoryCatalog.icon(forStoredSubcategory: tx.category) ?? "tag.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.inkSoft)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.inkPrimary)
                Text(tx.category.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.inkMeta)
            }
            Spacer()
            Text(tx.amount == 0 ? "—" : NumberFormatter.appCurrency(tx.amount))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.inkPrimary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
    }

    private var peakMetricValue: String {
        guard let peakForSelectedCategory else { return "—" }
        return "\(peakForSelectedCategory.label) \(NumberFormatter.appCurrency(peakForSelectedCategory.value))"
    }

    private func shiftMonth(_ delta: Int) {
        let next = max(0, min(monthCountInScope - 1, selectedMonthIndex + delta))
        selectedMonthIndex = next
        selectedCategory = nil
    }

    private func transactionsOnDay(day: Int, monthIndex: Int) -> [Transaction] {
        guard day > 0 else { return [] }
        return transactions.filter { tx in
            guard let date = parseDate(tx.date) else { return false }
            let components = cal.dateComponents([.year, .month, .day], from: date)
            return components.year == currentYear && components.month == monthIndex + 1 && components.day == day
        }
        .sorted { $0.amount > $1.amount }
    }

    private func parseDate(_ value: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.date(from: value)
    }

    private func apiDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }

    @MainActor
    private func loadOverlayData() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }

        if !plaidManager.hasLinkedBank {
            dataState = .placeholder
            summaries = [:]
            transactions = []
            return
        }

        let through = monthCountInScope
        let fetchedSummaries = await CashflowAPICharts.fetchMonthlySummaries(year: currentYear, throughMonth: through)
        var fetchedTransactions: [Transaction] = []

        do {
            let startDate = String(format: "%04d-01-01", currentYear)
            let endDate = apiDate(Date())
            let response = try await APIService.shared.getTransactions(
                page: 1,
                limit: 300,
                startDate: startDate,
                endDate: endDate
            )
            fetchedTransactions = response.transactions.map { Transaction(from: $0) }
        } catch {
            fetchedTransactions = []
        }

        summaries = fetchedSummaries
        transactions = fetchedTransactions
        dataState = fetchedSummaries.isEmpty ? .demo : .live
        TabContentCache.shared.setCashflowMonthlySummaries(fetchedSummaries.isEmpty ? nil : fetchedSummaries)
    }
}
