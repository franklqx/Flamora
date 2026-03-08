//
//  PortfolioCard.swift
//  Flamora app
//

import SwiftUI

struct PortfolioCard: View {
    let portfolio: Portfolio
    @State private var selectedRange: PortfolioTimeRange = .oneMonth

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header inside card
            HStack {
                Text("PORTFOLIO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(1.0)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, 10)

            // Amount + change
            VStack(alignment: .leading, spacing: 6) {
                Text(formatCurrency(portfolio.totalBalance))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(formattedChange)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppColors.accentGreen)
            }
            .padding(.horizontal, AppSpacing.cardPadding)

            // Chart
            LineChart(values: portfolio.chartData.map(\.value))
                .frame(height: 140)
                .padding(.top, 16)
                .padding(.bottom, 4)

            // Range selector
            rangeSelector
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(PortfolioTimeRange.allCases, id: \.self) { range in
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
                    .onTapGesture { selectedRange = range }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var formattedChange: String {
        let percent = portfolio.performance.oneMonth
        let amount = portfolio.totalBalance * (percent / 100)
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(formatCurrency(abs(amount))) (\(String(format: "%.1f%%", abs(percent))))"
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Time Range

enum PortfolioTimeRange: CaseIterable {
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

// MARK: - Line Chart

private struct LineChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            guard w.isFinite && w > 0 && h.isFinite && h > 0 else {
                return AnyView(Color.clear)
            }
            let safeW = max(0, w), safeH = max(0, h)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 1)
            let count = max(values.count - 1, 1)
            let pts = values.enumerated().map { (i, v) -> CGPoint in
                let x = safeW * CGFloat(i) / CGFloat(count)
                let y = safeH - (safeH * 0.85 * CGFloat((v - minV) / range)) - safeH * 0.06
                return CGPoint(
                    x: x.isFinite ? max(0, min(x, safeW)) : 0,
                    y: y.isFinite ? max(0, min(y, safeH)) : 0
                )
            }
            return AnyView(
                ZStack {
                    // Area fill with gradient from line to bottom (X axis)
                    Path { path in
                        guard let first = pts.first else { return }
                        path.move(to: CGPoint(x: first.x, y: safeH))
                        path.addLine(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: pts.last?.x ?? 0, y: safeH))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentGreen.opacity(0.30), Color.clear],
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
                    .stroke(AppColors.accentGreen, lineWidth: 2)
                }
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PortfolioCard(portfolio: MockData.investmentData.portfolio).padding()
    }
}
