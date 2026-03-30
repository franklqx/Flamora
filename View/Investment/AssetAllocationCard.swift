//
//  AssetAllocationCard.swift
//  Flamora app
//

import SwiftUI

struct AssetAllocationCard: View {
    let allocation: Allocation
    var isConnected: Bool = true
    @State private var showDetail = false

    private var totalAmount: Double {
        allocation.stocks.amount + allocation.bonds.amount + allocation.cash.amount + (allocation.other?.amount ?? 0)
    }

    private struct AllocRow {
        let title: String
        let percent: Int
        let amount: Double
        let color: Color
    }

    private var sortedRows: [AllocRow] {
        var rows = [
            AllocRow(title: "U.S. Stocks", percent: allocation.stocks.percent, amount: allocation.stocks.amount, color: AppColors.chartSteelBlue),
            AllocRow(title: "Crypto", percent: allocation.bonds.percent, amount: allocation.bonds.amount, color: AppColors.chartYellow),
            AllocRow(title: "Cash", percent: allocation.cash.percent, amount: allocation.cash.amount, color: AppColors.chartSageGreen)
        ]
        if let other = allocation.other, other.percent > 0 {
            rows.append(AllocRow(title: "Other", percent: other.percent, amount: other.amount, color: AppColors.chartCoral))
        }
        return rows.sorted { $0.percent > $1.percent }
    }

    private var allocationSegments: [ChartSegment] {
        sortedRows.map { ChartSegment(percent: $0.percent, color: $0.color) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("ASSET ALLOCATION")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                if isConnected {
                    Image(systemName: "chevron.right")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { if isConnected { showDetail = true } }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isConnected {
                // Chart + breakdown
                HStack(spacing: 20) {
                    ZStack {
                        DonutChart(segments: allocationSegments)
                            .frame(width: 110, height: 110)

                        VStack(spacing: 1) {
                            Text("TOTAL")
                                .font(.miniLabel)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(AppTypography.Tracking.miniUppercase)
                            Text(formatCompact(totalAmount))
                                .font(.inlineFigureBold)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedRows.indices, id: \.self) { i in
                            AllocationRow(
                                title: sortedRows[i].title,
                                percent: sortedRows[i].percent,
                                amount: sortedRows[i].amount,
                                color: sortedRows[i].color
                            )
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.cardPadding)
            } else {
                disconnectedContent
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .fullScreenCover(isPresented: $showDetail) {
            AssetAllocationDetailView(allocation: allocation)
        }
    }

    private var disconnectedContent: some View {
        HStack(spacing: 20) {
            // Ghost donut
            ZStack {
                Circle()
                    .stroke(AppColors.surfaceInput, lineWidth: 14)
                    .frame(width: 110, height: 110)
                    .opacity(0.35)

                VStack(spacing: 1) {
                    Text("TOTAL")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.miniUppercase)
                    Text("$—")
                        .font(.inlineFigureBold)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            // Ghost rows (locked placeholder)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(["U.S. Stocks", "Crypto", "Cash"], id: \.self) { label in
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.textTertiary.opacity(0.45))
                        Circle()
                            .fill(AppColors.textTertiary.opacity(0.3))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.footnoteSemibold)
                                .foregroundStyle(AppColors.textTertiary)
                            Text("—% · $—")
                                .font(.cardRowMeta)
                                .foregroundColor(AppColors.textTertiary.opacity(0.5))
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.cardPadding)
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.0fk", value / 1_000)
        }
        return "$\(Int(value))"
    }
}

private struct AllocationRow: View {
    let title: String
    let percent: Int
    let amount: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(percent)% · \(formatCurrency(amount))")
                    .font(.cardRowMeta)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }
}

private struct DonutChart: View {
    let segments: [ChartSegment]
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.surfaceInput, lineWidth: 14)

            ForEach(segments.indices, id: \.self) { i in
                if segments[i].percent > 0 {
                    DonutSegmentShape(startAngle: startAngle(for: i), endAngle: endAngle(for: i))
                        .stroke(segments[i].color, lineWidth: 14)
                }
            }
        }
    }
    private func startAngle(for i: Int) -> Angle {
        .degrees(Double(segments.prefix(i).map(\.percent).reduce(0, +)) / 100 * 360 - 90)
    }
    private func endAngle(for i: Int) -> Angle {
        .degrees(Double(segments.prefix(i + 1).map(\.percent).reduce(0, +)) / 100 * 360 - 90)
    }
}

private struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: min(rect.width, rect.height) / 2,
                 startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return p
    }
}

private struct ChartSegment { let percent: Int; let color: Color }

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        AssetAllocationCard(allocation: MockData.investmentData.allocation).padding()
    }
}
