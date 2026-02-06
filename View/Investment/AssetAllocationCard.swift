//
//  AssetAllocationCard.swift
//  Flamora app
//

import SwiftUI

struct AssetAllocationCard: View {
    let allocation: Allocation

    var body: some View {
        HStack(spacing: 20) {
            DonutChart(
                segments: [
                    ChartSegment(percent: allocation.stocks.percent, color: Color(hex: "#93C5FD")),
                    ChartSegment(percent: allocation.bonds.percent, color: Color(hex: "#A78BFA")),
                    ChartSegment(percent: allocation.cash.percent, color: Color(hex: "#F9A8D4"))
                ]
            )
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 12) {
                AllocationRow(
                    title: "Stocks",
                    percent: allocation.stocks.percent,
                    amount: allocation.stocks.amount,
                    color: Color(hex: "#93C5FD")
                )
                AllocationRow(
                    title: "Bonds",
                    percent: allocation.bonds.percent,
                    amount: allocation.bonds.amount,
                    color: Color(hex: "#A78BFA")
                )
                AllocationRow(
                    title: "Cash",
                    percent: allocation.cash.percent,
                    amount: allocation.cash.amount,
                    color: Color(hex: "#F9A8D4")
                )
            }

            Spacer()
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
    }
}

private struct AllocationRow: View {
    let title: String
    let percent: Int
    let amount: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("\(percent)% · \(formatCurrency(amount))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct DonutChart: View {
    let segments: [ChartSegment]

    var body: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                DonutSegmentShape(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .stroke(segments[index].color, lineWidth: 14)
            }
        }
    }

    private func startAngle(for index: Int) -> Angle {
        let sum = segments.prefix(index).map(\.percent).reduce(0, +)
        return .degrees(Double(sum) / 100 * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let sum = segments.prefix(index + 1).map(\.percent).reduce(0, +)
        return .degrees(Double(sum) / 100 * 360 - 90)
    }
}

private struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

private struct ChartSegment {
    let percent: Int
    let color: Color
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AssetAllocationCard(allocation: MockData.investmentData.allocation)
            .padding()
    }
}
