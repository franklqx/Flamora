//
//  AssetAllocationCard.swift
//  Flamora app
//

import SwiftUI

struct AssetAllocationCard: View {
    let allocation: Allocation

    private var totalAmount: Double {
        allocation.stocks.amount + allocation.bonds.amount + allocation.cash.amount
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("ASSET ALLOCATION")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Image(systemName: "chevron.right")
                    .font(.miniLabel)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, 12)

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            // Chart + breakdown
            HStack(spacing: 20) {
                // Donut with center total
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
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    AllocationRow(
                        title: "U.S. Stocks",
                        percent: allocation.stocks.percent,
                        amount: allocation.stocks.amount,
                        color: AppColors.accentBlue
                    )
                    AllocationRow(
                        title: "Cash",
                        percent: allocation.cash.percent,
                        amount: allocation.cash.amount,
                        color: AppColors.accentGreen
                    )
                    AllocationRow(
                        title: "Crypto",
                        percent: allocation.bonds.percent,
                        amount: allocation.bonds.amount,
                        color: AppColors.accentAmber
                    )
                    AllocationRow(
                        title: "Other",
                        percent: max(100 - allocation.stocks.percent - allocation.bonds.percent - allocation.cash.percent, 0),
                        amount: max(totalAmount * 0.02, 0),
                        color: AppColors.accentPink
                    )
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.cardPadding)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var allocationSegments: [ChartSegment] {
        let otherPct = max(100 - allocation.stocks.percent - allocation.bonds.percent - allocation.cash.percent, 0)
        return [
            ChartSegment(percent: allocation.stocks.percent, color: AppColors.accentBlue),
            ChartSegment(percent: allocation.cash.percent,   color: AppColors.accentGreen),
            ChartSegment(percent: allocation.bonds.percent,  color: AppColors.accentAmber),
            ChartSegment(percent: otherPct,                  color: AppColors.accentPink)
        ]
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
                    .foregroundStyle(.white)
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
            // Background track
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
        Color.black.ignoresSafeArea()
        AssetAllocationCard(allocation: MockData.investmentData.allocation).padding()
    }
}
