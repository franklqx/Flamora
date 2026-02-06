//
//  IncomeCard.swift
//  Flamora app
//

import SwiftUI

struct IncomeCard: View {
    let income: Income
    let monthLabel: String

    private let breakdownColors: [Color] = [
        Color(hex: "#F9A8D4"),
        Color(hex: "#A78BFA"),
        Color(hex: "#93C5FD")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("My Income")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text(monthLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    totalAmountView
                }

                Spacer()

                miniChart
            }

            breakdownRow
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
    }

    private var totalAmountView: some View {
        let parts = formatCurrencyWithCents(income.total)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.dollars)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Text(parts.cents)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: "#6B7280"))
        }
    }

    private var breakdownRow: some View {
        HStack(spacing: 18) {
            ForEach(breakdownItems.indices, id: \.self) { index in
                let item = breakdownItems[index]
                IncomeBreakdownItem(
                    title: item.title,
                    amount: formatCurrencyWithCents(item.amount).full,
                    color: breakdownColors[index % breakdownColors.count]
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var breakdownItems: [IncomeBreakdown] {
        let sources = income.sources
        if sources.count >= 3 {
            return Array(sources.prefix(3)).map { IncomeBreakdown(title: $0.name, amount: $0.amount) }
        }

        var items = sources.map { IncomeBreakdown(title: $0.name, amount: $0.amount) }
        if items.count == 2 {
            let remainder = max(income.total - items[0].amount - items[1].amount, 0)
            items.append(IncomeBreakdown(title: "Investment", amount: remainder))
        } else if items.count == 1 {
            let remainder = max(income.total - items[0].amount, 0)
            items.append(IncomeBreakdown(title: "Salary", amount: remainder * 0.6))
            items.append(IncomeBreakdown(title: "Investment", amount: remainder * 0.4))
        } else {
            items = [
                IncomeBreakdown(title: "Business", amount: income.total * 0.4),
                IncomeBreakdown(title: "Salary", amount: income.total * 0.35),
                IncomeBreakdown(title: "Investment", amount: income.total * 0.25)
            ]
        }
        return items
    }

    private var miniChart: some View {
        let heights: [CGFloat] = [10, 20, 14, 26, 18, 30, 16]
        let colors: [Color] = [
            Color(hex: "#F9A8D4"),
            Color(hex: "#FBCFE8"),
            Color(hex: "#A78BFA"),
            Color(hex: "#C4B5FD"),
            Color(hex: "#93C5FD"),
            Color(hex: "#60A5FA"),
            Color(hex: "#3B82F6")
        ]

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(heights.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index])
                    .frame(width: 6, height: heights[index])
            }
        }
        .padding(.top, 6)
    }

    private func formatCurrencyWithCents(_ value: Double) -> CurrencyParts {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "$0.00"
        let pieces = formatted.split(separator: ".")
        let dollars = pieces.first.map(String.init) ?? "$0"
        let cents = pieces.count > 1 ? ".\(pieces[1])" : ".00"
        return CurrencyParts(dollars: dollars, cents: cents, full: formatted)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        IncomeCard(income: MockData.cashflowData.income, monthLabel: "Jan 2026")
            .padding()
    }
}

private struct IncomeBreakdown {
    let title: String
    let amount: Double
}

private struct IncomeBreakdownItem: View {
    let title: String
    let amount: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#9CA3AF"))

                Text(amount)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

private struct CurrencyParts {
    let dollars: String
    let cents: String
    let full: String
}
