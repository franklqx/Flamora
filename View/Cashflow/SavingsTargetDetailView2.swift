//
//  SavingsTargetDetailView2.swift
//  Flamora app
//
//  Savings target detail view - complete rewrite
//

import SwiftUI

struct SavingsTargetDetailView2: View {
    private let targetRate: Double = MockData.apiMonthlyBudget.savingsRatio / 100.0
    private let targetAmount: Double = MockData.apiMonthlyBudget.savingsBudget

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

    init() {
        let byYear = MockData.savingsByYear
        let latest = byYear.keys.sorted().last ?? 2026
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
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    HStack(alignment: .firstTextBaseline) {
                        Text("Saving overview")
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
                    .padding(.bottom, -4)

                    // Total saved
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatMoney(annualSaved))
                            .font(.display)
                            .foregroundStyle(.white)

                        Text("Total saved this year")
                            .font(.supportingText)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    // Chart section with year picker
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
                            .padding(.top, AppSpacing.xs)
                    }
                    .padding(.top, AppSpacing.sm)

                    // Target info
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TARGET SAVING RATE")
                                .font(.cardHeader)
                                .foregroundColor(AppColors.textTertiary)

                            Text("\(Int(MockData.apiMonthlyBudget.savingsRatio))%")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Divider()
                            .frame(height: 50)
                            .background(AppColors.surfaceBorder)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("TARGET SAVING")
                                .font(.cardHeader)
                                .foregroundColor(AppColors.textTertiary)

                            Text(formatMoney(targetAmount))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.sm)

                    // Monthly milestones
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MONTHLY MILESTONES")
                            .font(.smallLabel)
                            .foregroundColor(AppColors.textTertiary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<12) { index in
                                monthCard(index: index)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.sm)
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
        .sheet(isPresented: $isShowingEditSheet, onDismiss: {
            applyEditedAmount()
        }) {
            SavingsInputSheet(amount: $editingAmount)
                .ignoresSafeArea(.container, edges: .bottom)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color.black)
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
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

    // MARK: - Chart View

    private let maxChartAmount: Double = 3500

    private var chartView: some View {
        GeometryReader { geometry in
            let barAreaHeight = geometry.size.height - 30 // 30 for month labels
            let targetRatio = CGFloat(targetAmount / maxChartAmount)
            let targetY = geometry.size.height - 30 - barAreaHeight * targetRatio

            ZStack(alignment: .bottomLeading) {
                // Target line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: targetY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: targetY))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundColor(AppColors.textTertiary)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<12) { index in
                        barView(index: index, maxHeight: barAreaHeight)
                    }
                }

                chartHoverOverlay(geometry: geometry)

                // Target label
                Text("TARGET")
                    .font(.label)
                    .foregroundColor(AppColors.textTertiary)
                    .position(x: geometry.size.width - 30, y: targetY - 10)
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
        let isTarget = (amount ?? 0) >= targetAmount

        return VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
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

                VStack(spacing: 6) {
                    Text(months[index])
                        .font(.label)
                        .foregroundColor(AppColors.textSecondary)

                    Text(amount == nil ? "--" : formatMoney(amount ?? 0))
                        .font(.smallLabel)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.surfaceBorder, lineWidth: 1)
                )
                .cornerRadius(10)
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
                    colors: [Color(hex: "#A78BFA"), Color(hex: "#F9A8D4"), Color(hex: "#FCD34D")],
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
        let isTarget = (amount ?? 0) >= targetAmount
        let hasData = amount != nil

        return VStack(alignment: .leading, spacing: 10) {
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
                Text("\(formatMoney(amount)) / \(formatMoney(targetAmount))")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(.white)
            } else {
                Text("-- / \(formatMoney(targetAmount))")
                    .font(.bodySmallSemibold)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(hasData ? AppColors.surfaceBorder : AppColors.surfaceBorder.opacity(0.5), lineWidth: 1)
        )
        .opacity(hasData ? 1.0 : 0.7)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            beginEditMonth(index: index)
        }
    }

    private var flameBadge: some View {
        LinearGradient(
            colors: [Color(hex: "#A78BFA"), Color(hex: "#F9A8D4"), Color(hex: "#FCD34D")],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask(
            FlameIcon(size: 16, color: .white)
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
    SavingsTargetDetailView2()
}
