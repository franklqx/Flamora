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

