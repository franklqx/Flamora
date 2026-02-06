//
//  PortfolioCard.swift
//  Flamora app
//

import SwiftUI

struct PortfolioCard: View {
    let portfolio: Portfolio
    @State private var selectedRange: TimeRange = .threeMonths

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PORTFOLIO")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#7C7C7C"))
                .tracking(1.2)

            Text(formatCurrency(portfolio.totalBalance))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("\(formattedChange)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#93C5FD"))

            LineChart(values: portfolio.chartData.map(\.value))
                .frame(height: 140)

            rangeSelector
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
    }

    private var rangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(range == selectedRange ? .white : Color(hex: "#6B7280"))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(
                        Capsule()
                            .fill(range == selectedRange ? Color(hex: "#1A1A1A") : Color.clear)
                            .overlay(
                                Capsule()
                                    .stroke(range == selectedRange ? Color(hex: "#222222") : Color.clear, lineWidth: 1)
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
        let amountText = formatCurrency(abs(amount))
        let percentText = String(format: "%.1f%%", abs(percent))
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(amountText) (\(percentText))"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

private enum TimeRange: CaseIterable {
    case day
    case week
    case threeMonths
    case year
    case all

    var label: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .threeMonths: return "3M"
        case .year: return "1Y"
        case .all: return "All"
        }
    }
}

private struct LineChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            guard width.isFinite && width > 0 && height.isFinite && height > 0 else {
                return AnyView(Color.clear)
            }

            let safeWidth = max(0, width)
            let safeHeight = max(0, height)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 1)
            let count = max(values.count - 1, 1)

            let points = values.enumerated().map { index, value -> CGPoint in
                let x = safeWidth * CGFloat(index) / CGFloat(count)
                let normalizedValue = (value - minValue) / range
                let y = safeHeight - (safeHeight * CGFloat(normalizedValue))
                let safeX = x.isFinite ? max(0, min(x, safeWidth)) : 0
                let safeY = y.isFinite ? max(0, min(y, safeHeight)) : 0
                return CGPoint(x: safeX, y: safeY)
            }

            return AnyView(
                ZStack {
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color(hex: "#A78BFA"), lineWidth: 2)

                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: safeHeight))
                        path.addLine(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: safeHeight))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA").opacity(0.25), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PortfolioCard(portfolio: MockData.investmentData.portfolio)
            .padding()
    }
}
