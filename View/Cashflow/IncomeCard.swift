//
//  IncomeCard.swift
//  Flamora app
//

import SwiftUI

struct IncomeCard: View {
    let income: Income

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Total Income")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#7C7C7C"))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(income.total))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("/mo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            VStack(spacing: 12) {
                IncomeRowItem(
                    title: "Active Income",
                    amount: formatCurrency(income.active),
                    color: Color(hex: "#93C5FD"),
                    icon: "briefcase.fill"
                )

                IncomeRowItem(
                    title: "Passive Income",
                    amount: formatCurrency(income.passive),
                    color: Color(hex: "#C4B5FD"),
                    icon: "leaf.fill"
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

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct IncomeRowItem: View {
    let title: String
    let amount: String
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.2))
                    .cornerRadius(8)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(color.opacity(0.15))
            .clipShape(Capsule())

            Spacer()

            Text(amount)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        IncomeCard(income: MockData.cashflowData.income)
            .padding()
    }
}
