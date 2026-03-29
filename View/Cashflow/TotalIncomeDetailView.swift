//
//  TotalIncomeDetailView.swift
//  Flamora app
//
//  Total Income drill-down detail page
//  - Header: title + total amount + month label
//  - Annual Trend: 12-month stacked bar chart (same as IncomeCard: active green / passive purple)
//  - Sources: Active & Passive income cards with fill-width proportion
//    → tapping either card navigates to the corresponding IncomeDetailView
//

import SwiftUI

struct TotalIncomeDetailView: View {
    let data: TotalIncomeDetailData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int
    @State private var selectedYear: Int
    @State private var showActiveDetail = false
    @State private var showPassiveDetail = false

    init(data: TotalIncomeDetailData, initialSelectedMonth: Int = 0) {
        self.data = data
        let latest = data.availableYears.last ?? 2026
        _selectedYear = State(initialValue: latest)
        _selectedBarIndex = State(initialValue: initialSelectedMonth)
    }

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private let activeColor  = AppColors.accentGreenDeep  // matches IncomeCard — Active
    private let passiveColor = AppColors.accentPurpleMid  // matches IncomeCard — Passive

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
            Color.black.ignoresSafeArea()

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
        .fullScreenCover(isPresented: $showActiveDetail) {
            IncomeDetailView(data: MockData.activeIncomeDetail, initialSelectedMonth: selectedBarIndex)
        }
        .fullScreenCover(isPresented: $showPassiveDetail) {
            IncomeDetailView(data: MockData.passiveIncomeDetail, initialSelectedMonth: selectedBarIndex)
        }
    }
}

// MARK: - Header
private extension TotalIncomeDetailView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
                    .font(.cardFigurePrimary)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(.white)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(selectedTotal))
                    .font(.h1)
                    .foregroundStyle(.white)

                Text("earned in \(selectedMonthLabel)")
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
            let barAreaHeight = geometry.size.height - 30
            let barSpacing: CGFloat = 8
            let totalSpacing = barSpacing * 11
            let barWidth = (geometry.size.width - totalSpacing) / 12

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
                    stackedBarFill(for: monthData)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.textTertiary.opacity(0.25))
                }
            }
            .frame(width: barWidth, height: height)
            .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.segmentLabel(selected: isSelected))
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    func stackedBarFill(for monthData: TotalIncomeMonthData) -> some View {
        let total = max(monthData.total, 0.0001)
        return GeometryReader { geometry in
            let h = geometry.size.height
            VStack(spacing: 0) {
                // Passive on top
                Rectangle()
                    .fill(passiveColor)
                    .frame(height: h * CGFloat(monthData.passiveAmount / total))
                // Active on bottom
                Rectangle()
                    .fill(activeColor)
                    .frame(height: h * CGFloat(monthData.activeAmount / total))
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

// MARK: - Sources
private extension TotalIncomeDetailView {
    var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sources")
                .font(.detailTitle)
                .foregroundStyle(.white)

            if let monthData = selectedMonthData {
                VStack(spacing: 12) {
                    Button { showActiveDetail = true } label: {
                        sourceCard(
                            name: "Active Income",
                            amount: monthData.activeAmount,
                            percentage: monthData.activePercentage,
                            color: activeColor
                        )
                    }
                    .buttonStyle(.plain)

                    Button { showPassiveDetail = true } label: {
                        sourceCard(
                            name: "Passive Income",
                            amount: monthData.passiveAmount,
                            percentage: monthData.passivePercentage,
                            color: passiveColor
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func sourceCard(name: String, amount: Double, percentage: Double, color: Color) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let ratio = min(max(percentage / 100, 0), 1)
            let fillWidth = ratio == 0 ? 0 : max(56, width * CGFloat(ratio))

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
                            .foregroundStyle(.white)

                        Text("\(selectedMonthLabel) \(selectedYear)")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(amount))
                            .font(.bodySemibold)
                            .foregroundStyle(.white)

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
