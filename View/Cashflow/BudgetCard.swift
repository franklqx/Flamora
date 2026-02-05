//
//  BudgetCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending

    private var progress: Double {
        guard spending.budgetLimit > 0 else { return 0 }
        return min(max(spending.total / spending.budgetLimit, 0), 1)
    }

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

            ProgressBar(progress: progress, color: Color(hex: "#8B5CF6"), height: 8)

            VStack(spacing: 12) {
                BudgetRowItem(
                    title: "Needs",
                    current: formatCurrency(spending.needs),
                    total: formatCurrency(spending.budgetLimit * 0.75),
                    color: Color(hex: "#93C5FD"),
                    icon: "house.fill"
                )

                BudgetRowItem(
                    title: "Wants",
                    current: formatCurrency(spending.wants),
                    total: formatCurrency(spending.budgetLimit * 0.25),
                    color: Color(hex: "#C4B5FD"),
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
