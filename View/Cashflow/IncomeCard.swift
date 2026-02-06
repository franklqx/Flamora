//
//  IncomeCard.swift
//  Flamora app
//

import SwiftUI

struct IncomeCard: View {
    let income: Income
    let monthLabel: String
    var onCardTapped: (() -> Void)? = nil
    var onActiveTapped: (() -> Void)? = nil
    var onPassiveTapped: (() -> Void)? = nil

    private let breakdownColors: [Color] = [
        Color(hex: "#A78BFA"),
        Color(hex: "#93C5FD")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onCardTapped?()
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
        let items = breakdownItems
        let actions: [(() -> Void)?] = [onActiveTapped, onPassiveTapped]

        return HStack(spacing: 24) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                let action = actions[index]

                Button {
                    action?()
                } label: {
                    IncomeBreakdownItem(
                        title: item.title,
                        amount: formatCurrencyWithCents(item.amount).full,
                        color: breakdownColors[index % breakdownColors.count],
                        hasAction: action != nil
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var breakdownItems: [IncomeBreakdown] {
        [
            IncomeBreakdown(title: "Active Income", amount: income.active),
            IncomeBreakdown(title: "Passive income", amount: income.passive)
        ]
    }

    private var miniChart: some View {
        let heights: [CGFloat] = [10, 20, 14, 26, 18, 30, 16]
        let colors: [Color] = [
            Color(hex: "#A78BFA"),
            Color(hex: "#C4B5FD"),
            Color(hex: "#93C5FD"),
            Color(hex: "#60A5FA"),
            Color(hex: "#A78BFA"),
            Color(hex: "#93C5FD"),
            Color(hex: "#60A5FA")
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
        IncomeCard(
            income: MockData.cashflowData.income,
            monthLabel: "Jan 2026",
            onCardTapped: {},
            onActiveTapped: {},
            onPassiveTapped: {}
        )
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
    var hasAction: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#9CA3AF"))

                    if hasAction {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#6B7280"))
                    }
                }

                Text(amount)
                    .font(.system(size: 18, weight: .bold))
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
