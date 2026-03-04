//
//  NetWorthCard.swift
//  Flamora app
//

import SwiftUI

struct NetWorthCard: View {
    let totalNetWorth: Double
    let growthAmount: Double
    let growthPercentage: Double

    @State private var selectedRange: NetWorthTimeRange = .oneMonth

    // Static mock sparkline data – values are relative, not real dollars
    private let chartDataByRange: [NetWorthTimeRange: [Double]] = [
        .oneWeek:      [200100, 201500, 203200, 202800, 205500, 207000, 208240],
        .oneMonth:     [194000, 195800, 193500, 196200, 199000, 201500, 200800,
                        202600, 204100, 203000, 205800, 207400, 208240],
        .threeMonths:  [182000, 185000, 181000, 188000, 190500, 193000, 191000,
                        196000, 194000, 199000, 201500, 204000, 203000, 206000, 208240],
        .ytd:          [170000, 176000, 181000, 188000, 193000, 198000, 203000, 208240],
        .all:          [50000, 72000, 95000, 120000, 145000, 160000, 172000,
                        185000, 190000, 196000, 202000, 208240]
    ]

    private var chartValues: [Double] {
        chartDataByRange[selectedRange] ?? [208240]
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("TOTAL NET WORTH")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.0)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(formatCurrencyInteger(totalNetWorth))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)

                Text(formatCurrencyDecimal(totalNetWorth))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }

            growthBadge

            netWorthChart
                .frame(height: 100)
                .padding(.top, 4)

            rangeSelector
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .appCard(cornerRadius: AppRadius.xl)
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: - Sub-views

    private var growthBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: growthAmount >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
            Text("\(growthAmount >= 0 ? "+" : "")\(formatCurrency(growthAmount)) (\(String(format: "%.1f", growthPercentage))%)")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(growthAmount >= 0 ? AppColors.successAlt : AppColors.error)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background((growthAmount >= 0 ? AppColors.successAlt : AppColors.error).opacity(0.16))
        .cornerRadius(AppRadius.xl)
    }

    private var netWorthChart: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            guard w > 0, h > 0 else { return AnyView(Color.clear) }

            let vals = chartValues
            let minV = vals.min() ?? 0
            let maxV = vals.max() ?? 1
            let range = max(maxV - minV, 1)
            let count = max(vals.count - 1, 1)

            let pts = vals.enumerated().map { (i, v) -> CGPoint in
                let x = w * CGFloat(i) / CGFloat(count)
                let y = h - (h * CGFloat((v - minV) / range) * 0.85) - h * 0.05
                return CGPoint(
                    x: max(0, min(x, w)),
                    y: max(0, min(y, h))
                )
            }

            return AnyView(
                ZStack {
                    // Area fill with gradient from line down to X axis
                    Path { path in
                        guard let first = pts.first else { return }
                        path.move(to: CGPoint(x: first.x, y: h))
                        path.addLine(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                        if let last = pts.last {
                            path.addLine(to: CGPoint(x: last.x, y: h))
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line stroke
                    Path { path in
                        guard let first = pts.first else { return }
                        path.move(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(Color.white, lineWidth: 1.5)
                }
            )
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(NetWorthTimeRange.allCases, id: \.self) { range in
                Text(range.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(range == selectedRange ? .white : AppColors.textTertiary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(range == selectedRange ? AppColors.surfaceElevated : Color.clear)
                            .overlay(
                                Capsule()
                                    .stroke(range == selectedRange ? AppColors.surfaceBorder : Color.clear, lineWidth: 0.75)
                            )
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRange = range
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Formatters

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func formatCurrencyInteger(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: Double(Int(value)))) ?? "$0"
    }

    private func formatCurrencyDecimal(_ value: Double) -> String {
        let cents = Int(value.truncatingRemainder(dividingBy: 1) * 100)
        return String(format: ".%02d", cents)
    }
}

// MARK: - Time Range

enum NetWorthTimeRange: CaseIterable {
    case oneWeek, oneMonth, threeMonths, ytd, all
    var label: String {
        switch self {
        case .oneWeek:     return "1W"
        case .oneMonth:    return "1M"
        case .threeMonths: return "3M"
        case .ytd:         return "YTD"
        case .all:         return "ALL"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NetWorthCard(
            totalNetWorth: MockData.apiNetWorthSummary.totalNetWorth,
            growthAmount: MockData.apiNetWorthSummary.growthAmount,
            growthPercentage: MockData.apiNetWorthSummary.growthPercentage
        )
    }
}
