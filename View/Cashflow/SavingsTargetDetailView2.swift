//
//  SavingsTargetDetailView2.swift
//  Flamora app
//
//  Savings target detail view - complete rewrite
//

import SwiftUI

struct SavingsTargetDetailView2: View {
    private let targetRate: Double = 0.20
    private let targetAmount: Double = 2000

    @Environment(\.dismiss) private var dismiss

    @State private var monthlyAmounts: [Double?] = [
        2150, 1800, 2400, 1950, 3100, 1200, 2200, 3500, 1900, nil, nil, nil
    ]
    @State private var editingMonthIndex: Int? = nil
    @State private var editingAmount: Double = 0
    @State private var isShowingEditSheet: Bool = false
    @State private var chartHoverIndex: Int? = nil
    @State private var dragOffset: CGFloat = 0

    private let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private let monthsShort = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private var annualSaved: Double {
        monthlyAmounts.compactMap { $0 }.reduce(0, +)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    HStack(alignment: .firstTextBaseline) {
                        Text("Saving overview")
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
                    .padding(.bottom, -4)

                    // Total saved
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatMoney(annualSaved))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)

                        Text("Total saved this year")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }

                    // Chart
                    chartView
                        .frame(height: 220)
                        .padding(.top, 10)

                    // Target info
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TARGET SAVING RATE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#6B7280"))

                            Text("20%")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Divider()
                            .frame(height: 50)
                            .background(Color(hex: "#2A2A2A"))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("TARGET SAVING")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#6B7280"))

                            Text(formatMoney(targetAmount))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 10)

                    // Monthly milestones
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MONTHLY MILESTONES")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#6B7280"))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<12) { index in
                                monthCard(index: index)
                            }
                        }
                    }
                    .padding(.top, 10)
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
                .foregroundColor(Color(hex: "#6B7280"))

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<12) { index in
                        barView(index: index, maxHeight: barAreaHeight)
                    }
                }

                chartHoverOverlay(geometry: geometry)

                // Target label
                Text("TARGET")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .position(x: geometry.size.width - 30, y: targetY - 10)
            }
        }
    }

    private func barView(index: Int, maxHeight: CGFloat) -> some View {
        let amount = monthlyAmounts[index]
        let height = calculateHeight(amount: amount, maxHeight: maxHeight)
        let isTarget = (amount ?? 0) >= targetAmount

        return VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(barColor(amount: amount, isTarget: isTarget))
                .frame(height: height)

            Text(monthsShort[index])
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
    }

    private func chartHoverOverlay(geometry: GeometryProxy) -> some View {
        let step = geometry.size.width / 12
        let maxHeight = geometry.size.height - 30

        return ZStack {
            if let index = chartHoverIndex {
                let amount = monthlyAmounts[index]
                let barHeight = calculateHeight(amount: amount, maxHeight: maxHeight)
                let xPosition = step * (CGFloat(index) + 0.5)
                let yPosition = max(18, geometry.size.height - barHeight - 40)

                VStack(spacing: 6) {
                    Text(months[index])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "#9CA3AF"))

                    Text(amount == nil ? "--" : formatMoney(amount ?? 0))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color(hex: "#121212"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#2A2A2A"), lineWidth: 1)
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
            return AnyShapeStyle(Color(hex: "#2B2B2B"))
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
        return AnyShapeStyle(Color(hex: "#3B3B3B"))
    }

    // MARK: - Month Card
    private func monthCard(index: Int) -> some View {
        let amount = monthlyAmounts[index]
        let isTarget = (amount ?? 0) >= targetAmount
        let hasData = amount != nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(months[index])
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(hasData ? Color(hex: "#9CA3AF") : Color(hex: "#6B7280"))

                Spacer()

                if isTarget {
                    flameBadge
                }
            }

            if let amount = amount {
                Text("\(formatMoney(amount)) / \(formatMoney(targetAmount))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("-- / \(formatMoney(targetAmount))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#121212"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(hasData ? Color(hex: "#2A2A2A") : Color(hex: "#1F1F1F"), lineWidth: 1)
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
        editingAmount = monthlyAmounts[index] ?? 0
        isShowingEditSheet = true
    }

    private func applyEditedAmount() {
        guard let index = editingMonthIndex else { return }
        if editingAmount > 0 {
            monthlyAmounts[index] = editingAmount
        } else {
            monthlyAmounts[index] = nil
        }
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
