//
//  IncomeDetailView.swift
//  Flamora app
//
//  Income drill-down detail page (Active / Passive)
//  - Header: title + total amount + month label
//  - Annual Trend: 12-month bar chart (tappable)
//  - Sources: list of income sources (updates per selected month)
//

import SwiftUI

struct IncomeDetailView: View {
    let data: IncomeDetailData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int
    @State private var selectedYear: Int
    @State private var editableDataByYear: [Int: [Int: IncomeMonthData]]

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    init(data: IncomeDetailData, initialSelectedMonth: Int = 0) {
        self.data = data
        let latest = data.availableYears.last ?? 2026
        let trend = data.trendsByYear[latest] ?? []
        _selectedYear = State(initialValue: latest)
        _editableDataByYear = State(initialValue: data.monthlyDataByYear)
        _selectedBarIndex = State(initialValue: preferredCashflowMonthIndex(in: trend, requested: initialSelectedMonth))
    }

    private var currentTrend: [Double?] {
        data.trendsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
    }
    private var currentMonthlyData: [Int: IncomeMonthData] {
        editableDataByYear[selectedYear] ?? [:]
    }

    private var maxChartValue: Double {
        let values = currentTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    private var selectedMonthData: IncomeMonthData? {
        currentMonthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        selectedMonthData?.total ?? (currentTrend.indices.contains(selectedBarIndex) ? currentTrend[selectedBarIndex] : nil) ?? 0
    }

    private var selectedSources: [IncomeDetailSource] {
        selectedMonthData?.sources ?? []
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
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
    }
}

// MARK: - Header
private extension IncomeDetailView {
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
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
    }
}

// MARK: - Annual Trend
private extension IncomeDetailView {
    var annualTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ANNUAL TREND")
                    .font(.segmentLabel(selected: false))
                    .foregroundColor(Color(hex: "#6B7280"))
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

    func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount: Double? = currentTrend.indices.contains(index) ? currentTrend[index] : nil
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        return VStack(spacing: 10) {
            Group {
                if isSelected, amount != nil,
                   let monthData = currentMonthlyData[index], !monthData.sources.isEmpty {
                    stackedBarFill(for: monthData)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#D1D5DB").opacity(0.25))
                }
            }
            .frame(width: barWidth, height: height)
            .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.segmentLabel(selected: isSelected))
                .foregroundColor(isSelected ? AppColors.textPrimary : Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
    }

    func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 16 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(16, maxHeight * 0.5 * CGFloat(ratio))
    }

    func stackedBarFill(for monthData: IncomeMonthData) -> some View {
        let total = max(monthData.sources.reduce(0) { $0 + $1.amount }, 0.0001)
        let stackedSources = Array(monthData.sources.reversed())
        let colors = colorMap(for: monthData.sources)

        return GeometryReader { geometry in
            let availableHeight = geometry.size.height.isFinite ? max(geometry.size.height, 0) : 0

            VStack(spacing: 0) {
                ForEach(stackedSources) { source in
                    Rectangle()
                        .fill(colors[source.id] ?? colorScale[0])
                        .frame(maxWidth: .infinity)
                        .frame(height: availableHeight * CGFloat(source.amount / total))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Sources
private extension IncomeDetailView {
    var sourcesSection: some View {
        let colors = colorMap(for: selectedSources)
        return Group {
            if !selectedSources.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sources")
                        .font(.detailTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    VStack(spacing: 12) {
                        ForEach(selectedSources) { source in
                            sourceCard(
                                source: source,
                                fillColor: colors[source.id] ?? colorScale[0]
                            )
                        }
                    }
                }
            }
        }
    }

    func sourceCard(source: IncomeDetailSource, fillColor: Color) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width.isFinite ? max(geometry.size.width, 0) : 0
            let ratioValue = source.percentage.isFinite ? min(max(source.percentage / 100, 0), 1) : 0
            let ratio = CGFloat(ratioValue)
            let fillWidth = ratio == 0 ? 0 : min(width, max(56, width * ratio))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.cardTopHighlight)

                RoundedRectangle(cornerRadius: 20)
                    .fill(fillColor.opacity(0.88))
                    .frame(width: fillWidth)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.name)
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(source.account) · \(source.type.displayName)")
                            .font(.footnoteRegular)
                            .foregroundColor(Color(hex: "#D1D5DB").opacity(0.8))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(source.amount))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(Int(source.percentage.rounded()))%")
                            .font(.footnoteRegular)
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .frame(height: 92)
    }

}

// MARK: - Helper
private extension IncomeDetailView {
    var colorScale: [Color] {
        data.accentColor == "#34D399"
            ? AppColors.activeIncomeScale
            : AppColors.passiveIncomeScale
    }

    func colorMap(for sources: [IncomeDetailSource]) -> [String: Color] {
        let sorted = sources.sorted { $0.percentage > $1.percentage }
        var map: [String: Color] = [:]
        for (index, source) in sorted.enumerated() {
            map[source.id] = colorScale[min(index, colorScale.count - 1)]
        }
        return map
    }

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
#Preview("Active Income") {
    IncomeDetailView(data: MockData.activeIncomeDetail)
}

#Preview("Passive Income") {
    IncomeDetailView(data: MockData.passiveIncomeDetail)
}

private extension IncomeSourceType {
    var helperDescription: String {
        switch self {
        case .active:
            return "Active income comes from your work and services."
        case .passive:
            return "Passive income contributes to your retirement withdrawal coverage."
        }
    }
}

private struct IncomeSourceEditorSheet: View {
    @Binding var sourceName: String
    @Binding var selectedType: IncomeSourceType
    @Binding var applySmartRules: Bool

    let onClose: () -> Void
    let onSave: () -> Void

    private var isSaveDisabled: Bool {
        sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(AppColors.surfaceBorder)
                    .frame(width: 44, height: 5)
                    .padding(.top, AppSpacing.sm)

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Text("Edit Source")
                            .font(.h1)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.figureSecondarySemibold)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Source Name")
                            .font(.figureSecondarySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        TextField("Rental Property", text: $sourceName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .font(.fieldBodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.sm + 2)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .fill(AppColors.overlayWhiteStroke)
                            )
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Income Type")
                            .font(.figureSecondarySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.xs) {
                            ForEach(IncomeSourceType.allCases, id: \.self) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    Text(type.displayName)
                                        .font(.bodySemibold)
                                        .foregroundColor(
                                            selectedType == type
                                            ? AppColors.textInverse
                                            : AppColors.textTertiary
                                        )
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(
                                            Capsule()
                                                .fill(selectedType == type ? AppColors.textPrimary : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(AppSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .fill(AppColors.overlayWhiteStroke)
                        )

                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: "info.circle.fill")
                                .font(.footnoteSemibold)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.top, 1)

                            Text(selectedType.helperDescription)
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()
                        .overlay(AppColors.overlayWhiteStroke)

                    HStack(spacing: AppSpacing.sm) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Smart Rules")
                                .font(.statRowSemibold)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Apply to all history & future records")
                                .font(.inlineLabel)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        SmartRulesGradientToggle(isOn: $applySmartRules)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.md)

                Spacer(minLength: AppSpacing.md)

                Divider()
                    .overlay(AppColors.overlayWhiteStroke)

                Button(action: onSave) {
                    Text("Save Changes")
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .fill(AppColors.overlayWhiteStroke)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm + 2)
                .disabled(isSaveDisabled)
                .opacity(isSaveDisabled ? 0.45 : 1)
            }
        }
    }
}

/// iOS `Toggle` tint cannot be a gradient; custom track uses `AppColors.gradientFire` when on.
private struct SmartRulesGradientToggle: View {
    @Binding var isOn: Bool

    private let trackW: CGFloat = 51
    private let trackH: CGFloat = 31
    private let thumbSize: CGFloat = 26

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(
                        isOn
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(AppColors.surfaceInput)
                    )
                    .frame(width: trackW, height: trackH)

                Circle()
                    .fill(AppColors.textPrimary)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: AppColors.cardShadow.opacity(0.35), radius: 2, y: 1)
                    .padding(.horizontal, AppSpacing.xs)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Smart Rules")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Spending Detail View (Needs / Wants)

struct SpendingAnalysisDetailView: View {
    let data: SpendingDetailData
    /// "needs" 或 "wants"，用于向 get-transactions 传递正确的分类过滤。
    let flamoraCategory: String
    var linkedAccounts: [Account] = []
    /// 来自 Cashflow 时传入 `persistTransactionClassification`；未传时在子页内调 API 并广播 `transactionClassificationDidPersist`。
    var onTransactionPersist: ((Transaction) async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int
    @State private var selectedYear: Int
    @State private var selectedCategory: SpendingDetailCategory?

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let monthsLong = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    init(
        data: SpendingDetailData,
        flamoraCategory: String = "needs",
        initialSelectedMonth: Int? = nil,
        linkedAccounts: [Account] = [],
        onTransactionPersist: ((Transaction) async throws -> Void)? = nil
    ) {
        self.data = data
        self.flamoraCategory = flamoraCategory
        self.linkedAccounts = linkedAccounts
        self.onTransactionPersist = onTransactionPersist
        let latest = data.availableYears.last ?? 2026
        let trend = data.trendsByYear[latest] ?? []
        _selectedYear = State(initialValue: latest)
        _selectedBarIndex = State(initialValue: preferredCashflowMonthIndex(in: trend, requested: initialSelectedMonth))
    }

    private var accentColor: Color { Color(hex: data.accentColor) }

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
        selectedMonthData?.total ?? (currentTrend.indices.contains(selectedBarIndex) ? currentTrend[selectedBarIndex] : nil) ?? 0
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

    private var selectedCategories: [SpendingDetailCategory] {
        (selectedMonthData?.categories ?? []).sorted { $0.amount > $1.amount }
    }

    private var selectedMonthLabel: String {
        monthsFull[selectedBarIndex]
    }

    private var selectedMonthLongLabel: String {
        monthsLong[selectedBarIndex]
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    chartSection

                    categoriesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
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
        .fullScreenCover(item: $selectedCategory) { category in
            let monthStr = String(format: "%04d-%02d", selectedYear, selectedBarIndex + 1)
            SpendingCategoryTransactionsDetailView(
                category: category,
                monthLabel: selectedMonthLongLabel,
                month: monthStr,
                flamoraCategory: flamoraCategory,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: onTransactionPersist
            )
        }
    }
}

private extension SpendingAnalysisDetailView {
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
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrencyNoCents(selectedTotal))
                    .font(.h1)
                    .foregroundStyle(AppColors.textPrimary)

                Text("spend in \(selectedMonthLabel)")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
}

private extension SpendingAnalysisDetailView {
    var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ANNUAL TREND")
                    .font(.segmentLabel(selected: false))
                    .foregroundColor(Color(hex: "#6B7280"))
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

    func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount: Double? = currentTrend.indices.contains(index) ? currentTrend[index] : nil
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        return VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? accentColor : Color(hex: "#D1D5DB").opacity(0.25))
                .frame(width: barWidth, height: height)
                .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.segmentLabel(selected: isSelected))
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 16 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(16, maxHeight * 0.5 * CGFloat(ratio))
    }
}

private extension SpendingAnalysisDetailView {
    var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.detailTitle)
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 12) {
                ForEach(selectedCategories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        categoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func categoryCard(category: SpendingDetailCategory) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width.isFinite ? max(geometry.size.width, 0) : 0
            let ratioValue = category.percentage.isFinite ? min(max(category.percentage / 100, 0), 1) : 0
            let ratio = CGFloat(ratioValue)
            let fillWidth = ratio == 0 ? 0 : min(width, max(56, width * ratio))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.overlayWhiteWash)

                RoundedRectangle(cornerRadius: 20)
                    .fill(accentColor.opacity(0.82))
                    .frame(width: fillWidth)

                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .font(.categoryRowIcon)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 24)

                        Text(category.name)
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(category.amount))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(Int(category.percentage.rounded()))%")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 84)
    }
}

private extension SpendingAnalysisDetailView {
    func formatCurrencyNoCents(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}


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

private struct SpendingCategoryTransactionsDetailView: View {
    let category: SpendingDetailCategory
    let monthLabel: String
    /// 月份字符串，如 "2026-03"，用于向 get-transactions 传递日期范围过滤。
    let month: String
    /// "needs" 或 "wants"
    let flamoraCategory: String
    var linkedAccounts: [Account] = []
    var onTransactionPersist: ((Transaction) async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var groups: [SpendingCategoryTransactionGroup] = []
    @State private var isLoading = true
    @State private var selectedTransaction: Transaction? = nil

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    backButton

                    headerSection

                    if isLoading {
                        ProgressView()
                            .tint(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.lg)
                    } else {
                        groupsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
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
        .task {
            await loadTransactions()
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction, linkedAccounts: linkedAccounts) { updated in
                try await persistClassification(updated)
                await loadTransactions(mergingSticky: updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.backgroundPrimary)
        }
    }

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
                    subtitle: tx.flamoraSubcategory?.replacingOccurrences(of: "_", with: " ").capitalized ?? "",
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
}

private extension SpendingCategoryTransactionsDetailView {
    var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.navChevron)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.name)
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text(formatCurrency(category.amount))
                .font(.currencyHero)
                .foregroundStyle(AppColors.textPrimary)

            Text("Total spend in \(monthLabel)")
                .font(.bodyRegular)
                .foregroundColor(Color(hex: "#94A3B8"))
        }
    }

    var groupsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.title)
                        .font(.inlineFigureBold)
                        .tracking(2)
                        .foregroundColor(Color(hex: "#94A3B8"))

                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            transactionRow(item)

                            if index < group.items.count - 1 {
                                Divider()
                                    .background(AppColors.glassBorder)
                            }
                        }
                    }
                }
            }
        }
    }

    func transactionRow(_ item: SpendingCategoryTransaction) -> some View {
        Button {
            selectedTransaction = Transaction(from: item.raw)
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.merchant)
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(item.subtitle)
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                Text(formatCurrency(item.amount))
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, AppSpacing.xs)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .buttonStyle(.plain)
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

#Preview("Spending Needs") {
    SpendingAnalysisDetailView(data: MockData.needsSpendingDetail)
}

#Preview("Spending Wants") {
    SpendingAnalysisDetailView(data: MockData.wantsSpendingDetail)
}

// MARK: - Spending Detail View (Total)

struct TotalSpendingAnalysisDetailView: View {
    let data: TotalSpendingDetailData
    let needsDetailData: SpendingDetailData
    let wantsDetailData: SpendingDetailData
    var linkedAccounts: [Account] = []
    var onTransactionPersist: ((Transaction) async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int
    @State private var selectedYear: Int
    @State private var showNeedsDetail = false
    @State private var showWantsDetail = false

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private var needsColor: Color { AppColors.chartBlue }
    private var wantsColor: Color { AppColors.chartAmber }

    init(
        data: TotalSpendingDetailData,
        needsDetailData: SpendingDetailData = .emptyNeeds,
        wantsDetailData: SpendingDetailData = .emptyWants,
        initialSelectedMonth: Int? = nil,
        linkedAccounts: [Account] = [],
        onTransactionPersist: ((Transaction) async throws -> Void)? = nil
    ) {
        self.data = data
        self.needsDetailData = needsDetailData
        self.wantsDetailData = wantsDetailData
        self.linkedAccounts = linkedAccounts
        self.onTransactionPersist = onTransactionPersist
        let latest = data.availableYears.last ?? Calendar.current.component(.year, from: Date())
        let trend = data.trendsByYear[latest] ?? []
        _selectedYear = State(initialValue: latest)
        _selectedBarIndex = State(initialValue: preferredCashflowMonthIndex(in: trend, requested: initialSelectedMonth))
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

                    chartSection

                    sourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
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
        .fullScreenCover(isPresented: $showNeedsDetail) {
            SpendingAnalysisDetailView(
                data: needsDetailData,
                flamoraCategory: "needs",
                initialSelectedMonth: selectedBarIndex,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: onTransactionPersist
            )
        }
        .fullScreenCover(isPresented: $showWantsDetail) {
            SpendingAnalysisDetailView(
                data: wantsDetailData,
                flamoraCategory: "wants",
                initialSelectedMonth: selectedBarIndex,
                linkedAccounts: linkedAccounts,
                onTransactionPersist: onTransactionPersist
            )
        }
        .onChange(of: data.trendsByYear.isEmpty) { _, isEmpty in
            guard !isEmpty else { return }
            let trend = data.trendsByYear[selectedYear] ?? []
            if let lastIndex = trend.indices.last(where: { trend[$0] != nil }) {
                selectedBarIndex = lastIndex
            }
        }
    }
}

private func preferredCashflowMonthIndex(in trend: [Double?], requested: Int?) -> Int {
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

private extension TotalSpendingAnalysisDetailView {
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
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrencyNoCents(selectedTotal))
                    .font(.h1)
                    .foregroundStyle(AppColors.textPrimary)

                Text("spend in \(selectedMonthLabel)")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
}

private extension TotalSpendingAnalysisDetailView {
    var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ANNUAL TREND")
                    .font(.segmentLabel(selected: false))
                    .foregroundColor(Color(hex: "#6B7280"))
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
        let amount: Double? = currentTrend.indices.contains(index) ? currentTrend[index] : nil
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        return VStack(spacing: 10) {
            Group {
                if isSelected, amount != nil, let monthData = currentMonthlyData[index] {
                    stackedBarFill(for: monthData)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#D1D5DB").opacity(0.25))
                }
            }
            .frame(width: barWidth, height: height)
            .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.segmentLabel(selected: isSelected))
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    func stackedBarFill(for monthData: TotalSpendingMonthData) -> some View {
        let total = max(monthData.total, 0.0001)
        return GeometryReader { geometry in
            let h = geometry.size.height.isFinite ? max(geometry.size.height, 0) : 0
            VStack(spacing: 0) {
                Rectangle().fill(wantsColor)
                    .frame(height: h * CGFloat(monthData.wantsAmount / total))
                Rectangle().fill(needsColor)
                    .frame(height: h * CGFloat(monthData.needsAmount / total))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 16 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(16, maxHeight * CGFloat(ratio))
    }
}

private extension TotalSpendingAnalysisDetailView {
    var sourcesSection: some View {
        Group {
            if let monthData = selectedMonthData {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Categories")
                        .font(.detailTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    VStack(spacing: 12) {
                        Button { showNeedsDetail = true } label: {
                            sourceCard(
                                name: "Needs",
                                amount: monthData.needsAmount,
                                percentage: monthData.needsPercentage,
                                color: needsColor
                            )
                        }
                        .buttonStyle(.plain)

                        Button { showWantsDetail = true } label: {
                            sourceCard(
                                name: "Wants",
                                amount: monthData.wantsAmount,
                                percentage: monthData.wantsPercentage,
                                color: wantsColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    func sourceCard(name: String, amount: Double, percentage: Double, color: Color) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width.isFinite ? max(geometry.size.width, 0) : 0
            let ratioValue = percentage.isFinite ? min(max(percentage / 100, 0), 1) : 0
            let ratio = CGFloat(ratioValue)
            let fillWidth = ratio == 0 ? 0 : min(width, max(56, width * ratio))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(AppColors.cardTopHighlight)

                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(color.opacity(0.88))
                    .frame(width: fillWidth)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(selectedMonthLabel) \(selectedYear)")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(amount))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        HStack(spacing: 4) {
                            Text("\(Int(percentage.rounded()))%")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textSecondary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .frame(height: 92)
    }
}

private extension TotalSpendingAnalysisDetailView {
    func formatCurrencyNoCents(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - TotalSpendingDetailContainer
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
        .onAppear {
            syncFromCache()
        }
        .task {
            await loadData()
        }
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
