//
//  BudgetCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending

    private var needsColor: Color { Color(hex: "#A78BFA") }
    private var wantsColor: Color { Color(hex: "#93C5FD") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Total Spend")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#7C7C7C"))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(spending.total))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("/ \(formatCurrency(spending.budgetLimit))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            segmentedBar

            VStack(spacing: 12) {
                BudgetRowItem(
                    title: "Needs",
                    current: formatCurrency(spending.needs),
                    total: formatCurrency(spending.budgetLimit * 0.75),
                    color: needsColor,
                    icon: "house.fill"
                )

                BudgetRowItem(
                    title: "Wants",
                    current: formatCurrency(spending.wants),
                    total: formatCurrency(spending.budgetLimit * 0.25),
                    color: wantsColor,
                    icon: "bag.fill"
                )
            }
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
    }

    private var segmentedBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let safeWidth = width.isFinite && width >= 0 ? width : 0
            let limit = max(spending.budgetLimit, 1)
            let needsRatio = min(max(spending.needs / limit, 0), 1)
            let wantsRatio = min(max(spending.wants / limit, 0), 1)
            let needsWidth = max(0, safeWidth * CGFloat(needsRatio))
            let wantsWidth = max(0, safeWidth * CGFloat(wantsRatio))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#2C2C2E"))
                    .frame(height: 8)

                Capsule()
                    .fill(needsColor)
                    .frame(width: needsWidth, height: 8)

                Capsule()
                    .fill(wantsColor)
                    .frame(width: wantsWidth, height: 8)
                    .offset(x: needsWidth)
            }
        }
        .frame(height: 8)
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

private struct BudgetRowItem: View {
    let title: String
    let current: String
    let total: String
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(color.opacity(0.2))
            .clipShape(Capsule())

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(current)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("/ \(total)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BudgetCard(spending: MockData.cashflowData.spending)
            .padding()
    }
}
