//
//  CashflowExpandedOverlayView.swift
//  Flamora app
//
//  Cash Flow 下拉展开专用页面（独立于 Home Simulator）。
//

import SwiftUI
import UIKit

struct CashflowExpandedOverlayView: View {
    private enum Surface: String, CaseIterable {
        case calendar = "Calendar"
        case trend = "Trend"
    }

    private struct TrendPoint: Identifiable {
        let id: Int
        let label: String
        let value: Double?
    }

    private struct NetBarShape: Shape {
        enum RoundedEdge {
            case top
            case bottom
        }

        let roundedEdge: RoundedEdge
        let radius: CGFloat

        func path(in rect: CGRect) -> Path {
            let r = min(radius, rect.width / 2, rect.height / 2)
            var path = Path()

            switch roundedEdge {
            case .top:
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + r, y: rect.minY),
                    control: CGPoint(x: rect.minX, y: rect.minY)
                )
                path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.minY + r),
                    control: CGPoint(x: rect.maxX, y: rect.minY)
                )
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.closeSubpath()
            case .bottom:
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - r),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                path.closeSubpath()
            }

            return path
        }
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
    @State private var selectedMonthIndex = max(0, Calendar.current.component(.month, from: Date()) - 1)
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    @State private var calendarDragOffset: CGFloat = 0

    @State private var dataState: DataState = .placeholder
    @State private var loading = false
    @State private var summaries: [Int: APISpendingSummary] = [:]
    @State private var transactions: [Transaction] = []

    private let cal = Calendar.current
    private let monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let monthInitials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
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

        let pts: [TrendPoint] = (0..<12).map { index in
            let value = summaries[index].map { $0.totalIncome - $0.totalSpending }
            return TrendPoint(id: index, label: monthShort[index], value: value)
        }

        // Return real (possibly all-zero) points; never fabricate fake amounts for a connected user.
        return pts
    }

    private var selectedPoint: TrendPoint {
        guard !trendPoints.isEmpty else {
            return TrendPoint(id: selectedMonthIndex, label: monthShort[selectedMonthIndex], value: nil)
        }
        let safe = min(max(0, selectedMonthIndex), max(0, trendPoints.count - 1))
        return trendPoints[safe]
    }

    private var selectedSummary: APISpendingSummary? {
        summaries[selectedMonthIndex]
    }

    private var selectedIncome: Double {
        max(selectedSummary?.totalIncome ?? 0, 0)
    }

    private var selectedExpense: Double {
        max(selectedSummary?.totalSpending ?? 0, 0)
    }

    private var selectedNetCashFlow: Double {
        selectedIncome - selectedExpense
    }

    private var netCashFlowLabel: String {
        let formatted = NumberFormatter.appCurrency(abs(selectedNetCashFlow))
        if selectedNetCashFlow > 0 { return "+\(formatted)" }
        if selectedNetCashFlow < 0 { return "-\(formatted)" }
        return formatted
    }

    private var netSurplusColor: Color { Color.white }
    private var netDeficitColor: Color { AppColors.warning }
    private var netBreakdownColor: Color {
        selectedNetCashFlow >= 0 ? AppColors.inkSoft : netDeficitColor
    }

    private var incomeRows: [CashCategoryRow] {
        guard let s = selectedSummary else { return [] }
        let merged = (s.incomeActiveSources ?? []) + (s.incomePassiveSources ?? [])
        if merged.isEmpty, selectedIncome > 0 {
            return [
                CashCategoryRow(
                    id: "income",
                    name: "Income",
                    icon: "dollarsign.circle.fill",
                    amount: selectedIncome,
                    percentage: 1
                )
            ]
        }
        let total = max(merged.reduce(0) { $0 + $1.amount }, 0.0001)
        return merged
            .sorted { $0.amount > $1.amount }
            .prefix(3)
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

    private var expenseSplitRows: [CashCategoryRow] {
        guard let s = selectedSummary else { return [] }
        let needs = max(s.needs.total, 0)
        let wants = max(s.wants.total, 0)
        let other = max(selectedExpense - needs - wants, 0)
        let total = max(needs + wants + other, 0.0001)
        return [
            CashCategoryRow(id: "needs", name: "Needs", icon: "house.fill", amount: needs, percentage: needs / total),
            CashCategoryRow(id: "wants", name: "Wants", icon: "sparkles", amount: wants, percentage: wants / total),
            CashCategoryRow(id: "other", name: "Other", icon: "tag.fill", amount: other, percentage: other / total)
        ].filter { $0.amount > 0.005 }
    }

    private var calendarGrid: [DayCell] {
        calendarGrid(monthIndex: selectedMonthIndex)
    }

    private func calendarGrid(monthIndex: Int) -> [DayCell] {
        guard let firstDay = cal.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: 1)),
              let dayRange = cal.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: firstDay)
        let leading = max(0, firstWeekday - 1)
        var cells: [DayCell] = Array(repeating: DayCell(id: UUID().uuidString, day: nil, amount: 0, txCount: 0, isCurrentMonth: false), count: leading)

        for day in dayRange {
            let txs = transactionsOnDay(day: day, monthIndex: monthIndex)
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

    private var surfaceSwitch: some View {
        let selectedFill = Color(hex: "#20388F").opacity(0.92)
        let unselectedFill = Color(hex: "#6D7EEA").opacity(0.24)
        return HStack(spacing: 6) {
            ForEach(Surface.allCases, id: \.self) { view in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSurface = view
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
                .accessibilityIdentifier(view.rawValue)
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
            calendarMonthPager

            // Only show day-detail tray once the user has connected and data is available.
            if !isPlaceholder {
                calendarDetailTray
            } else {
                // Wrap in VStack so the accessibility tree exposes this as an
                // `otherElement` (matches the test query `app.otherElements[...]`).
                VStack(spacing: 0) {
                    Text("Connect a bank account to see daily spending detail.")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.heroTextHint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, AppSpacing.sm)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("cashflow_calendar_connect_hint")
            }
        }
    }

    private var calendarMonthPager: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            ZStack(alignment: .leading) {
                if calendarDragOffset > 0, selectedMonthIndex > 0 {
                    monthPage(monthIndex: selectedMonthIndex - 1, pageWidth: width)
                        .offset(x: -width + calendarDragOffset)
                }

                if calendarDragOffset < 0, selectedMonthIndex < monthCountInScope - 1 {
                    monthPage(monthIndex: selectedMonthIndex + 1, pageWidth: width)
                        .offset(x: width + calendarDragOffset)
                }

                monthPage(monthIndex: selectedMonthIndex, pageWidth: width)
                    .offset(x: calendarDragOffset)
            }
            .frame(width: width, height: calendarPagerHeight, alignment: .leading)
            .compositingGroup()
            .clipShape(Rectangle())
            .mask(Rectangle())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let canDragPrev = selectedMonthIndex > 0
                        let canDragNext = selectedMonthIndex < monthCountInScope - 1
                        if value.translation.width > 0, !canDragPrev {
                            calendarDragOffset = value.translation.width * 0.18
                        } else if value.translation.width < 0, !canDragNext {
                            calendarDragOffset = value.translation.width * 0.18
                        } else {
                            calendarDragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            resetCalendarDragOffset()
                            return
                        }
                        let threshold = width * 0.22
                        let predicted = value.predictedEndTranslation.width
                        if predicted > threshold, selectedMonthIndex > 0 {
                            completeMonthSwipe(delta: -1, width: width)
                        } else if predicted < -threshold, selectedMonthIndex < monthCountInScope - 1 {
                            completeMonthSwipe(delta: 1, width: width)
                        } else {
                            resetCalendarDragOffset()
                        }
                    }
            )
            .accessibilityIdentifier("cashflow_calendar_month_pager")
        }
        .frame(height: calendarPagerHeight)
    }

    private var calendarPagerHeight: CGFloat {
        let titleHeight: CGFloat = 18
        let titleGap: CGFloat = 12
        let weekdayHeight: CGFloat = 18
        let weekdayGap: CGFloat = 6
        let rowHeight: CGFloat = 64
        let rowGap: CGFloat = 6
        return titleHeight + titleGap + weekdayHeight + weekdayGap + (rowHeight * 6) + (rowGap * 5)
    }

    @ViewBuilder
    private func monthPage(monthIndex: Int, pageWidth: CGFloat) -> some View {
        if (0..<monthCountInScope).contains(monthIndex) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(monthShort[monthIndex]) \(currentYear)".uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.heroTextSoft)
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(weekdayShort, id: \.self) { day in
                        Text(day)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.heroTextHint)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(calendarGrid(monthIndex: monthIndex)) { cell in
                        dayCellView(cell, monthIndex: monthIndex)
                    }
                }
                .accessibilityIdentifier(monthIndex == selectedMonthIndex ? "cashflow_calendar_grid" : "cashflow_calendar_grid_\(monthIndex)")
            }
            .frame(width: pageWidth, alignment: .top)
        } else {
            Color.clear.frame(width: pageWidth)
        }
    }

    private func completeMonthSwipe(delta: Int, width: CGFloat) {
        let duration = 0.24
        let targetOffset = delta > 0 ? -width : width

        withAnimation(.easeInOut(duration: duration)) {
            calendarDragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            var reset = SwiftUI.Transaction(animation: nil)
            reset.disablesAnimations = true
            withTransaction(reset) {
                shiftMonth(delta)
                calendarDragOffset = 0
            }
        }
    }

    private func resetCalendarDragOffset() {
        withAnimation(.easeInOut(duration: 0.18)) {
            calendarDragOffset = 0
        }
    }

    @ViewBuilder
    private func dayCellView(_ cell: DayCell, monthIndex: Int) -> some View {
        if let day = cell.day {
            Button(action: {
                selectedMonthIndex = monthIndex
                selectedDay = day
                calendarDragOffset = 0
            }) {
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
                        .fill(day == selectedDay && monthIndex == selectedMonthIndex ? AppColors.accentBlueBright.opacity(0.52) : AppColors.overlayWhiteWash)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(day == selectedDay && monthIndex == selectedMonthIndex ? AppColors.overlayWhiteHigh : AppColors.overlayWhiteStroke, lineWidth: 1)
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
                Text("Net Cash Flow")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.heroTextHint)
                    .textCase(.uppercase)
                Text(isPlaceholder ? "—" : netCashFlowLabel)
                    .font(.h1)
                    .foregroundStyle(AppColors.heroTextPrimary)
                    .monospacedDigit()
            }

            if isPlaceholder {
                trendUnconnectedEmptyState
            } else {
                trendBarChart
                trendDetailCard
            }
        }
    }

    private var trendUnconnectedEmptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.h1)
                .foregroundStyle(AppColors.heroTextHint)
            Text("Connect a bank account to see whether each month ended in surplus or deficit.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.heroTextHint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_trend_empty_state")
    }

    private var trendBarChart: some View {
        let maxAbsValue = max(trendPoints.compactMap { $0.value }.map { abs($0) }.max() ?? 1, 1)
        return HStack(alignment: .center, spacing: 6) {
            ForEach(trendPoints) { point in
                Button(action: {
                    triggerLightHaptic()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedMonthIndex = point.id
                    }
                }) {
                    VStack(spacing: 6) {
                        netPositiveBar(point, maxAbsValue: maxAbsValue)
                            .frame(height: 66, alignment: .bottom)
                        Text(monthInitials[point.id])
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(monthLabelColor(for: point))
                            .frame(height: 18)
                        netNegativeBar(point, maxAbsValue: maxAbsValue)
                            .frame(height: 66, alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(point.value == nil)
            }
        }
        .frame(height: 170, alignment: .bottom)
        .padding(.vertical, 8)
    }

    private func monthLabelColor(for point: TrendPoint) -> Color {
        if point.id == selectedMonthIndex { return AppColors.heroTextPrimary }
        return point.value == nil ? AppColors.heroTextHint.opacity(0.34) : AppColors.heroTextHint
    }

    private func netBarFill(for point: TrendPoint) -> Color {
        guard let value = point.value else { return Color.clear }
        if value >= 0 {
            return netSurplusColor
        }
        return netDeficitColor
    }

    private func netBarHeight(for point: TrendPoint, maxAbsValue: Double) -> CGFloat {
        guard let value = point.value else { return 0 }
        let halfHeight: CGFloat = 66
        return max(8, CGFloat(abs(value) / maxAbsValue) * halfHeight)
    }

    private func triggerLightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func netPositiveBar(_ point: TrendPoint, maxAbsValue: Double) -> some View {
        let height = netBarHeight(for: point, maxAbsValue: maxAbsValue)
        let value = point.value
        let color = (value ?? -1) >= 0 ? netSurplusColor : Color.clear

        return VStack(spacing: 0) {
            if let value, value >= 0 {
                Spacer(minLength: 0)
                NetBarShape(roundedEdge: .top, radius: 6)
                    .fill(netBarFill(for: point))
                    .frame(width: 12, height: height)
                    .shadow(color: color.opacity(0.2), radius: 8, y: 3)
            } else {
                Spacer(minLength: 0)
                Color.clear.frame(width: 12, height: 8)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func netNegativeBar(_ point: TrendPoint, maxAbsValue: Double) -> some View {
        let height = netBarHeight(for: point, maxAbsValue: maxAbsValue)

        return VStack(spacing: 0) {
            if let value = point.value, value < 0 {
                NetBarShape(roundedEdge: .bottom, radius: 6)
                    .fill(netBarFill(for: point))
                    .frame(width: 12, height: height)
                    .shadow(color: netDeficitColor.opacity(0.2), radius: 8, y: 3)
                Spacer(minLength: 0)
            } else {
                Color.clear.frame(width: 12, height: 8)
                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var trendDetailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            trendDetailHeader
            cashFlowBreakdown
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
        .accessibilityIdentifier("cashflow_net_detail_section")
    }

    private var trendDetailHeader: some View {
        HStack {
            Text("Cash Flow Breakdown")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.inkMeta)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
    }

    private var cashFlowBreakdown: some View {
        VStack(spacing: 8) {
            breakdownRow(title: "Income", value: NumberFormatter.appCurrency(selectedIncome), color: AppColors.inkPrimary)
            breakdownRow(title: "Expense", value: "-\(NumberFormatter.appCurrency(selectedExpense))", color: AppColors.inkPrimary)
            breakdownRow(title: "Net", value: netCashFlowLabel, color: netBreakdownColor)
        }
    }

    @ViewBuilder
    private var incomeSourcesSection: some View {
        if !incomeRows.isEmpty {
            trendMiniSection(title: "Income Sources", rows: incomeRows, tint: AppColors.heroTextHint)
        }
    }

    @ViewBuilder
    private var expenseSplitSection: some View {
        if !expenseSplitRows.isEmpty {
            trendMiniSection(title: "Expense Split", rows: expenseSplitRows, tint: AppColors.heroTextHint)
        }
    }

    private func trendMiniSection(title: String, rows: [CashCategoryRow], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.inkMeta)
                .textCase(.uppercase)
                .tracking(0.7)

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    summaryRow(
                        title: row.name,
                        value: NumberFormatter.appCurrency(row.amount),
                        subtitle: "\(Int((row.percentage * 100).rounded()))%",
                        icon: row.icon,
                        color: tint
                    )
                }
            }
        }
    }

    private func summaryRow(title: String, value: String, subtitle: String? = nil, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9)
                .fill(color.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.inkMeta)
                }
            }

            Spacer()

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
        .padding(10)
        .background(categoryRowBackground)
        .overlay(categoryRowBorder)
    }

    private func breakdownRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.inkPrimary)
                .lineLimit(1)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(10)
        .background(categoryRowBackground)
        .overlay(categoryRowBorder)
    }

    private var categoryRowBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.8), Color.white.opacity(0.56)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    private var categoryRowBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.7), lineWidth: 1)
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

    private func shiftMonth(_ delta: Int) {
        let next = max(0, min(monthCountInScope - 1, selectedMonthIndex + delta))
        guard next != selectedMonthIndex else { return }
        selectedMonthIndex = next
        clampSelectedDayForCurrentMonth()
    }

    private func clampSelectedDayForCurrentMonth() {
        guard let firstDay = cal.date(from: DateComponents(year: currentYear, month: selectedMonthIndex + 1, day: 1)),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return }
        selectedDay = min(max(selectedDay, 1), range.count)
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
