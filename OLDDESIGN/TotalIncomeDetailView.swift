//
//  TotalIncomeDetailView.swift
//  Flamora app
//
//  Total Income drill-down detail page
//  - Header: title + total amount + month label
//  - Annual Trend: 多来源时按 `sourceCategories` 堆叠色条；否则整柱绿色
//  - Categories：`AppColors.incomeSegmentPalette` 与主卡同色索引；点击轻量 Sheet 说明
//

import SwiftUI

struct TotalIncomeDetailView: View {
    let data: TotalIncomeDetailData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int
    @State private var selectedYear: Int
    @State private var selectedCategoryForSheet: SpendingDetailCategory?

    init(data: TotalIncomeDetailData, initialSelectedMonth: Int = 0) {
        self.data = data
        let latest = data.availableYears.last ?? 2026
        let trend = data.trendsByYear[latest] ?? []
        _selectedYear = State(initialValue: latest)
        _selectedBarIndex = State(initialValue: preferredInitialMonthIndex(in: trend, requested: initialSelectedMonth))
    }

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private let singleIncomeBarColor = AppColors.accentGreenDeep

    private var currentTrend: [Double?] {
        data.trendsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
    }
    private var currentMonthlyData: [Int: TotalIncomeMonthData] {
        data.monthlyDataByYear[selectedYear] ?? [:]
    }

    private var maxChartValue: Double {
        let values = currentTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    private var selectedMonthData: TotalIncomeMonthData? {
        currentMonthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        selectedMonthData?.total ?? (currentTrend.indices.contains(selectedBarIndex) ? currentTrend[selectedBarIndex] : nil) ?? 0
    }

    private var selectedMonthLabel: String {
        monthsFull[selectedBarIndex]
    }

    private var canGoPrev: Bool { (data.availableYears.first ?? Int.max) < selectedYear }
    private var canGoNext: Bool { (data.availableYears.last  ?? Int.min) > selectedYear }

    private func navigateYear(_ delta: Int) {
        let years = data.availableYears
        guard let idx = years.firstIndex(of: selectedYear) else { return }
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < years.count else { return }
        let newYear = years[newIdx]
        let trend = data.trendsByYear[newYear] ?? []
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedYear = newYear
            selectedBarIndex = trend.indices.last(where: { trend[$0] != nil }) ?? 0
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    annualTrendSection
                    sourcesSection
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, 100)
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
        .sheet(item: $selectedCategoryForSheet) { cat in
            IncomeSourceDetailSheet(
                category: cat,
                monthLabel: "\(selectedMonthLabel) \(selectedYear)"
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.backgroundPrimary)
        }
    }
}

private func preferredInitialMonthIndex(in trend: [Double?], requested: Int?) -> Int {
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

// MARK: - Header
private extension TotalIncomeDetailView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
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

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(selectedTotal))
                    .font(.h1)
                    .foregroundStyle(AppColors.textPrimary)

                Text("received in \(selectedMonthLabel)")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Annual Trend
private extension TotalIncomeDetailView {
    var annualTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        }
    }

    var yearPicker: some View {
        HStack(spacing: 12) {
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

    var chartView: some View {
        GeometryReader { geometry in
            let rawHeight = geometry.size.height.isFinite ? geometry.size.height : 0
            let barAreaHeight = max(rawHeight - 30, 0)
            let barSpacing: CGFloat = 8
            let totalSpacing = barSpacing * 11
            let availableWidth = geometry.size.width.isFinite ? max(geometry.size.width, 0) : 0
            let barWidth = max((availableWidth - totalSpacing) / 12, 0)

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<12, id: \.self) { index in
                    barColumn(index: index, barWidth: barWidth, maxHeight: barAreaHeight)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedBarIndex = index
                            }
                        }
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

    func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount = currentTrend.indices.contains(index) ? currentTrend[index] : nil
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        return VStack(spacing: 10) {
            Group {
                if isSelected, amount != nil, let monthData = currentMonthlyData[index] {
                    if monthData.sourceCategories.isEmpty {
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .fill(singleIncomeBarColor)
                    } else {
                        stackedBarFill(for: monthData)
                    }
                } else {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.textTertiary.opacity(0.25))
                }
            }
            .frame(width: barWidth, height: height)
            .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.segmentLabel(selected: isSelected))
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    func stackedBarFill(for monthData: TotalIncomeMonthData) -> some View {
        let cats = monthData.sourceCategories
        let total = max(monthData.total, 0.0001)
        let palette = AppColors.incomeSegmentPalette
        return GeometryReader { geometry in
            let h = geometry.size.height.isFinite ? max(geometry.size.height, 0) : 0
            VStack(spacing: 0) {
                ForEach(Array(cats.enumerated().reversed()), id: \.element.id) { index, cat in
                    Rectangle()
                        .fill(palette[index % palette.count])
                        .frame(height: h * CGFloat(cat.amount / total))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 16 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(16, maxHeight * CGFloat(ratio))
    }
}

// MARK: - Sources
private extension TotalIncomeDetailView {
    var sourcesSection: some View {
        Group {
            if let monthData = selectedMonthData, !monthData.sourceCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Categories")
                        .font(.detailTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    VStack(spacing: AppSpacing.md) {
                        ForEach(Array(monthData.sourceCategories.enumerated()), id: \.element.id) { index, cat in
                            Button {
                                selectedCategoryForSheet = cat
                            } label: {
                                incomeCategoryCard(cat, colorIndex: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    func incomeCategoryCard(_ category: SpendingDetailCategory, colorIndex: Int) -> some View {
        let fillColor = AppColors.incomeSegmentPalette[colorIndex % AppColors.incomeSegmentPalette.count]
        return GeometryReader { geometry in
            let width = geometry.size.width.isFinite ? max(geometry.size.width, 0) : 0
            let ratioValue = category.percentage.isFinite ? min(max(category.percentage / 100, 0), 1) : 0
            let ratio = CGFloat(ratioValue)
            let fillWidth = ratio == 0 ? 0 : min(width, max(56, width * ratio))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(AppColors.cardTopHighlight)

                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(fillColor.opacity(0.88))
                    .frame(width: fillWidth)

                HStack(spacing: AppSpacing.md) {
                    Image(systemName: category.icon)
                        .font(.categoryRowIcon)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(category.name)
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(selectedMonthLabel) \(selectedYear)")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                        Text(formatCurrency(category.amount))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(Int(category.percentage.rounded()))%")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
        .frame(height: 92)
    }

}

// MARK: - Income Source Detail (light sheet)

private struct IncomeSourceDetailSheet: View {
    let category: SpendingDetailCategory
    let monthLabel: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(category.name)
                        .font(.detailTitle)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.bodySmallSemibold)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(monthLabel)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textTertiary)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(formatCurrency(category.amount))
                        .font(.h2)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(Int(category.percentage.rounded()))% of monthly income")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, AppSpacing.xs)

                incomeMetaCard
                    .padding(.top, AppSpacing.sm)

                if shouldShowFallbackBlurb {
                    Text(incomeSourceBlurb(for: category.name))
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, AppSpacing.sm)
                } else {
                    Text("Figures reflect linked cash and credit accounts for \(monthLabel).")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.top, AppSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(AppSpacing.screenPadding)
        .background(AppColors.backgroundPrimary)
    }

    private var shouldShowFallbackBlurb: Bool {
        let a = category.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let d = category.creditDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return a.isEmpty && d.isEmpty
    }

    private var incomeMetaCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("SOURCE")
                .font(.cardHeader)
                .foregroundStyle(AppColors.textTertiary)
                .tracking(1.2)

            detailRow(
                icon: "building.columns.fill",
                title: "Account",
                value: accountDisplayLine
            )

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)

            detailRow(
                icon: "calendar",
                title: "Last credited",
                value: creditDateDisplayLine
            )
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColors.cardTopHighlight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var accountDisplayLine: String {
        let t = category.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if t.isEmpty {
            return "Not linked to a specific account in this summary"
        }
        return t
    }

    private var creditDateDisplayLine: String {
        if let s = formattedCreditDate(category.creditDate) {
            return s
        }
        return "—"
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.chromeIconMedium)
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: AppSpacing.lg, alignment: .center)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textTertiary)
                Text(value)
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Parses `YYYY-MM-DD` from API; displays a medium-style local date.
    private func formattedCreditDate(_ iso: String?) -> String? {
        let raw = iso?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.count >= 10 else { return nil }
        let prefix = String(raw.prefix(10))
        let inFmt = DateFormatter()
        inFmt.calendar = Calendar(identifier: .gregorian)
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"
        guard let d = inFmt.date(from: prefix) else { return nil }
        let outFmt = DateFormatter()
        outFmt.dateStyle = .medium
        outFmt.timeStyle = .none
        return outFmt.string(from: d)
    }

    private func incomeSourceBlurb(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("payroll") || lower.contains("salary") || lower.contains("wage") {
            return "Employment income such as salary or wages, as recorded from your linked accounts for this month."
        }
        if lower.contains("interest") || lower.contains("dividend") {
            return "Interest, dividends, or similar investment income credited in this period."
        }
        if (lower.contains("rent") && lower.contains("income")) || lower.contains("rental") {
            return "Rental or lease-related income included in this category."
        }
        if lower.contains("active") {
            return "Income typically tied to work or services, aggregated from your connected accounts."
        }
        if lower.contains("passive") {
            return "Income typically from investments, interest, or other non-wage sources, as summarized for this month."
        }
        return "This amount is part of your total income for the month, based on data from your linked accounts."
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

// MARK: - Helper
private extension TotalIncomeDetailView {
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Previews
#Preview("Total Income") {
    TotalIncomeDetailView(data: MockData.totalIncomeDetail)
}
