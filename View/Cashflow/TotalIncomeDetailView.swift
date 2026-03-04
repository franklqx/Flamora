//
//  TotalIncomeDetailView.swift
//  Flamora app
//
//  Total Income drill-down detail page
//  - Header: title + total amount + month label
//  - Annual Trend: 12-month bar chart (tappable)
//  - Sources: Active Income (purple) & Passive Income (blue) per month
//

import SwiftUI

struct TotalIncomeDetailView: View {
    let data: TotalIncomeDetailData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int = 0

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private let activeColor = Color(hex: "#A78BFA")  // purple
    private let passiveColor = Color(hex: "#93C5FD")  // blue

    private var maxChartValue: Double {
        let values = data.annualTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    private var selectedMonthData: TotalIncomeMonthData? {
        data.monthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        selectedMonthData?.total ?? data.annualTrend[selectedBarIndex] ?? 0
    }

    private var selectedMonthLabel: String {
        monthsFull[selectedBarIndex]
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .gesture(
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
private extension TotalIncomeDetailView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(selectedTotal))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("earned in \(selectedMonthLabel)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .tracking(1.5)

                Spacer()

                Text("Jan - Dec 2026")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }

            chartView
                .frame(height: 220)
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
                    barColumn(
                        index: index,
                        barWidth: barWidth,
                        maxHeight: barAreaHeight
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedBarIndex = index
                        }
                    }
                }
            }
        }
    }

    func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount = data.annualTrend[index]
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        // For the selected bar, use a gradient of purple + blue
        let selectedGradient = LinearGradient(
            colors: [activeColor, passiveColor],
            startPoint: .bottom,
            endPoint: .top
        )
        let unselectedFill = Color(hex: "#D1D5DB").opacity(0.25)

        return VStack(spacing: 10) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(selectedGradient)
                        .frame(width: barWidth, height: height)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(unselectedFill)
                        .frame(width: barWidth, height: height)
                }
            }
            .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
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
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            if let monthData = selectedMonthData {
                VStack(spacing: 12) {
                    sourceCard(
                        name: "Active Income",
                        amount: monthData.activeAmount,
                        percentage: monthData.activePercentage,
                        color: activeColor
                    )

                    sourceCard(
                        name: "Passive Income",
                        amount: monthData.passiveAmount,
                        percentage: monthData.passivePercentage,
                        color: passiveColor
                    )
                }
            }
        }
    }

    func sourceCard(name: String, amount: Double, percentage: Double, color: Color) -> some View {
        HStack(spacing: 14) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 5, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(selectedMonthLabel) 2026")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(Int(percentage))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.15))
        )
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
